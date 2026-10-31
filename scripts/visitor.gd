extends CharacterBody3D

## Dungeon visitor: an archaeologist (ARCH, carries a lantern) or the priest (PRIEST, holy aura).
## Walks the navmesh (game.gd bakes it). What it does depends on GameState.stage:
## HAUNT: archaeologists explore dig sites and go check every noise / light change in earshot.
## PRIEST_COMING: they wait at the entrance. LURE: they work at their camp table (still check noises); once the plan
## is pushed they head for the bricked wall (a closed door stops them). The priest follows the nearest archaeologist.
## DIG: they take the wall apart. EVIDENCE: everyone looks around your room. RITUAL: the priest prays in the circle.

const Wall = preload("res://scripts/wall.gd")
const UI = preload("res://scripts/ui.gd")

enum Kind { ARCH, PRIEST }

const SPEED := [1.6, 1.4]  ## calm walk by kind
const INVESTIGATE_SPEED := 2.4
const HEAR := 12.0  ## noises farther than this are not heard
const INVESTIGATE_TIME := 8.0
const STAY := Vector2(5, 10)  ## seconds spent at a dig site
const FOLLOW := 1.8  ## the priest keeps this far behind the archaeologists
const ROOM_SPOTS := [Vector3(-1.5, 0, 1.3), Vector3(1.4, 0, 1.5), Vector3(0, 0, -1.6)]  ## around your room's centre
const LAYER_VISITOR := 16
const MASK := 7 | 64  ## walls, furniture, rubble
const HEARD_LINES := ["Ви це чули?", "Звідки цей звук?..", "Там щось є. Ходімо подивимось.", "Знову… Це не вітер."]
const WALL_LINES := ["На плані тут порожнеча… а кімнати немає. Ходімо глянемо.", "Дивно — коридор є, а кімнати нема."]

@export var kind := Kind.ARCH
@export var title_text := "Олена"
@export var color := Color(0.35, 0.55, 0.4)

var _target := Vector3.INF  ## noise to check
var _investigate := 0.0
var _stay := 0.0
var _site := Vector3.INF
var _talk := 0.0  ## line cooldown
var _told := false  ## LURE: said the plan line
var _agent: NavigationAgent3D
var _label: Label3D


func _ready() -> void:
	add_to_group("visitor")
	collision_layer = LAYER_VISITOR
	collision_mask = MASK
	var ps := Wall.model(name)  # art/models/<node name>, origin at the feet
	var m: Node3D = ps.instantiate() if ps else Wall.box(Vector3(0.6, 1.7, 0.6), color)
	if not ps:
		m.position.y = 0.85
	add_child(m)
	var shape := CollisionShape3D.new()
	shape.shape = CapsuleShape3D.new()
	shape.shape.radius = 0.35
	shape.position.y = 0.9
	add_child(shape)
	_label = Label3D.new()
	_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_label.font_size = 48
	_label.outline_size = 12
	_label.pixel_size = 0.0013
	_label.fixed_size = true
	_label.position.y = 2.1
	_label.layers = 2  ## the minimap camera culls labels
	_label.visibility_range_end = 12.0
	_label.font = UI.font()
	_label.modulate = UI.GOLD if kind == Kind.PRIEST else UI.PAPER
	add_child(_label)
	_agent = NavigationAgent3D.new()
	_agent.path_desired_distance = 0.5
	_agent.target_desired_distance = 0.4
	_agent.radius = 0.35
	add_child(_agent)
	if kind == Kind.ARCH:
		var lantern := OmniLight3D.new()
		lantern.light_color = Color(1, 0.78, 0.45)
		lantern.omni_range = 5.0
		lantern.light_energy = 1.3
		lantern.position = Vector3(0.4, 1.2, -0.3)
		add_child(lantern)
	else:
		add_child(Wall.holy_glow(1.2))
		visible = false  # arrives later (game.gd calls arrive())
		set_physics_process(false)
	GameState.haunted.connect(_on_haunted)


## PRIEST: walk in from the entrance.
func arrive(at: Vector3) -> void:
	global_position = at
	visible = true
	set_physics_process(true)


func _on_haunted(pos: Vector3, power: float) -> void:
	if kind != Kind.ARCH or _flat(pos) > HEAR * power:
		return
	if GameState.stage == GameState.Stage.HAUNT or (GameState.stage == GameState.Stage.LURE and not GameState.plan_moved):
		_target = pos
		_investigate = INVESTIGATE_TIME
		_line(HEARD_LINES.pick_random())


func _physics_process(delta: float) -> void:
	_talk = maxf(_talk - delta, 0)
	_investigate = maxf(_investigate - delta, 0)
	var target := global_position
	var speed: float = SPEED[kind]
	var stage := GameState.stage
	match stage:
		GameState.Stage.HAUNT:
			if _investigate > 0:
				target = _target
				speed = INVESTIGATE_SPEED
			else:
				target = _explore(delta)
		GameState.Stage.PRIEST_COMING:
			target = _marker("Entrance")
		GameState.Stage.LURE:
			if kind == Kind.PRIEST:
				target = _behind_group()
			elif GameState.plan_moved:
				if not _told:
					_told = true
					_line(WALL_LINES.pick_random(), true)
				target = _dig_spot()
			elif _investigate > 0:
				target = _target
				speed = INVESTIGATE_SPEED
			else:
				target = _marker("Camp") + _room_spot() * 0.6
		GameState.Stage.DIG:
			target = _behind_group() if kind == Kind.PRIEST else _dig_spot()
		GameState.Stage.EVIDENCE:
			target = _marker("RoomCenter") + _room_spot()
		GameState.Stage.RITUAL:
			target = _marker("RoomCenter") + (Vector3.ZERO if kind == Kind.PRIEST else _room_spot())
	_walk(target, speed)
	_label.text = _label_text()
	_label.visible = GameState.show_labels


## HAUNT, nothing to check: walk between dig sites and stay a while at each.
func _explore(delta: float) -> Vector3:
	if _site == Vector3.INF or (_flat(_site) < 0.6 and _stay <= 0):
		var sites := get_tree().get_nodes_in_group("dig_site")
		if sites.is_empty():
			return global_position
		_site = sites.pick_random().global_position
		_stay = randf_range(STAY.x, STAY.y)
	elif _flat(_site) < 0.6:
		_stay -= delta
	return _site


## Follow the nearest archaeologist (priest, or an archaeologist that heard nothing), keeping a little distance.
func _behind_group() -> Vector3:
	var best: Node3D = null
	for v in get_tree().get_nodes_in_group("visitor"):
		if v != self and v.kind == Kind.ARCH and (best == null or _flat(v.global_position) < _flat(best.global_position)):
			best = v
	if best == null or _flat(best.global_position) < FOLLOW:
		return global_position
	return best.global_position


func _dig_spot() -> Vector3:
	var r := _rubble()
	return r.global_position + Vector3(-1.3, 0, 0.4 if title_text == "Олена" else -0.4) if r else global_position


func _rubble() -> Node3D:
	return owner.get_node_or_null("Level/Rubble") if owner else null


func _marker(n: String) -> Vector3:
	var m := owner.get_node_or_null("Markers/" + n) as Node3D if owner else null
	return m.global_position if m else global_position


## A stable spot of its own around your room's centre.
func _room_spot() -> Vector3:
	var i := get_tree().get_nodes_in_group("visitor").find(self)
	return ROOM_SPOTS[i % ROOM_SPOTS.size()]


## Step along the navmesh towards `target`.
func _walk(target: Vector3, speed: float) -> void:
	_agent.target_position = target
	var to := _agent.get_next_path_position() - global_position
	to.y = 0
	var close := _flat(target) < 0.3
	velocity = Vector3.ZERO if close or to.length() < 0.01 else to.normalized() * speed
	move_and_slide()
	if velocity.length() > 0.1:
		rotation.y = lerp_angle(rotation.y, atan2(-velocity.x, -velocity.z), 0.15)


func _line(text: String, force := false) -> void:
	if _talk > 0 and not force:
		return
	_talk = 5.0
	GameState.say(title_text, text, UI.GOLD if kind == Kind.PRIEST else UI.GREEN)


func _label_text() -> String:
	match GameState.stage:
		GameState.Stage.HAUNT:
			return title_text + (": що це було?" if _investigate > 0 else (": досліджує" if _flat(_site) < 0.6 else ""))
		GameState.Stage.DIG:
			return title_text + (": молиться" if kind == Kind.PRIEST else ": розбирає стіну")
		GameState.Stage.RITUAL:
			return title_text + (": ритуал %d%%" % int(GameState.ritual * 100) if kind == Kind.PRIEST else "")
	return title_text


func _flat(p: Vector3) -> float:
	return Vector2(p.x - global_position.x, p.z - global_position.z).length()
