extends CharacterBody3D

## Dungeon visitor: an archaeologist (ARCH, carries a lantern) or the priest (PRIEST, holy aura).
## Walks the navmesh (game.gd bakes it). What it does depends on GameState.stage:
## HAUNT: archaeologists explore dig sites and go check every noise / light change in earshot; one lured with the right
## power next to a memory finds it (station.gd). PRIEST_COMING: they wait at the entrance. SEARCH: the time-lapse
## moves them. EVIDENCE: archaeologists go to `focus` (game.gd picks your things one by one), the priest waits in the
## room. RITUAL: the priest prays in the circle.

const Wall = preload("res://scripts/wall.gd")
const UI = preload("res://scripts/ui.gd")

enum Kind { ARCH, PRIEST }

const SPEED := [1.6, 1.4]  ## calm walk by kind
const INVESTIGATE_SPEED := 2.4
const HEAR := 12.0  ## noises farther than this are not heard
const INVESTIGATE_TIME := 8.0
const STAY := Vector2(5, 10)  ## seconds spent at a dig site
const ROOM_SPOTS := [Vector3(-1.5, 0, 1.3), Vector3(1.4, 0, 1.5), Vector3(0, 0, -1.6)]  ## around your room's centre
const LAYER_VISITOR := 16
const LABEL_PX := 0.0013  ## name label size up close (UI.world_label)
const MASK := 7 | 64  ## walls, furniture, rubble
const HEARD_LINES := ["Ви це чули?", "Звідки цей звук?..", "Там щось є. Ходімо подивимось.", "Знову… Це не вітер."]
const NOTICE_LINES := ["Стривайте… там щось є.", "А це що таке?", "Ось звідки… Ходімо глянемо."]
const CANDLE_LINES := ["Хто запалив свічку?", "Свічка сама згасла?!"]  ## by lit / out
const WRITE_LINE := "ТУТ?.. Хто це написав?"
const STARTLE := 0.5  ## on hearing: stands and turns to the noise this long before walking
const LANTERN_REST := Vector3(0.4, 1.2, -0.3)
const FOUND_LINES := ["Гляньте, яка стара річ…", "Хтось це беріг. Дуже давно.", "Це тут лежить, певно, років двісті."]

@export var kind := Kind.ARCH
@export var title_text := "Олена"
@export var color := Color(0.35, 0.55, 0.4)

var focus := Vector3.INF  ## EVIDENCE: the thing to look at (game.gd)
var _target := Vector3.INF  ## noise to check
var _by := ""  ## the power that made that noise
var _investigate := 0.0
var _stay := 0.0
var _site := Vector3.INF
var _talk := 0.0  ## line cooldown
var _agent: NavigationAgent3D
var _label: Label3D
var _anim: AnimationPlayer  ## the final model's `walk` and `idle`
var _startle := 0.0
var _lantern: OmniLight3D
var _mark: Label3D  ## «?» heard something, «!» noticed / found a memory
var _mark_tween: Tween


func _ready() -> void:
	add_to_group("visitor")
	collision_layer = LAYER_VISITOR
	collision_mask = MASK
	var ps := Wall.model(name)  # art/models/<node name>, origin at the feet
	var m: Node3D = ps.instantiate() if ps else Wall.box(Vector3(0.6, 1.7, 0.6), color)
	if not ps:
		m.position.y = 0.85
	add_child(m)
	var players := m.find_children("*", "AnimationPlayer", true, false)
	if not players.is_empty():
		_anim = players[0]
		for clip in ["walk", "idle"]:
			_anim.get_animation(clip).loop_mode = Animation.LOOP_LINEAR
		_anim.play("idle")
	var shape := CollisionShape3D.new()
	shape.shape = CapsuleShape3D.new()
	shape.shape.radius = 0.35
	shape.position.y = 0.9
	add_child(shape)
	_label = Label3D.new()
	_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_label.font_size = 48
	_label.outline_size = 12
	_label.pixel_size = LABEL_PX
	_label.fixed_size = true  ## no giant letters next to the camera; UI.world_label shrinks it further off
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
		_lantern = OmniLight3D.new()
		_lantern.light_color = Color(1, 0.78, 0.45)
		_lantern.omni_range = 5.0
		_lantern.light_energy = 1.3
		_lantern.position = LANTERN_REST
		add_child(_lantern)
		_mark = Label3D.new()
		_mark.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		_mark.font = UI.font()
		_mark.font_size = 96
		_mark.outline_size = 16
		_mark.pixel_size = 0.004
		_mark.position.y = 2.45
		_mark.layers = 2  ## the minimap camera culls labels
		_mark.visible = false
		add_child(_mark)
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


func _on_haunted(pos: Vector3, power: float, by: String) -> void:
	if kind != Kind.ARCH or _flat(pos) > HEAR * power or GameState.stage != GameState.Stage.HAUNT:
		return
	for v in get_tree().get_nodes_in_group("visitor"):  # only the nearest archaeologist goes to check
		if v != self and v.kind == Kind.ARCH and v._flat(pos) < _flat(pos):
			return
	_target = pos
	_by = by
	_investigate = INVESTIGATE_TIME
	_startle = STARTLE
	_show_mark("?", UI.PAPER)
	_line(_heard_line(pos, by))


## What it says about a noise: a candle that went out / lit itself, writing, else something heard.
func _heard_line(pos: Vector3, by: String) -> String:
	if by == "write":
		return WRITE_LINE
	if by == "breath":
		for c in get_tree().get_nodes_in_group("candle"):
			if c.global_position.distance_to(pos) < 0.1:
				return CANDLE_LINES[0 if c.lit else 1]
	return HEARD_LINES.pick_random()


## Pop a «?» / «!» over the head, fade it out after a while.
func _show_mark(text: String, col: Color) -> void:
	if _mark_tween:
		_mark_tween.kill()
	_mark.text = text
	_mark.modulate = col
	_mark.scale = Vector3.ONE * 0.2
	_mark.visible = true
	_mark_tween = create_tween()
	_mark_tween.tween_property(_mark, "scale", Vector3.ONE, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_mark_tween.tween_interval(1.6)
	_mark_tween.tween_property(_mark, "modulate:a", 0.0, 0.5)
	_mark_tween.tween_callback(_mark.hide)


## The power of the noise it is checking right now ("" = none).
func lured_by() -> String:
	return _by if _investigate > 0 else ""


## Walk up to a memory it noticed (station.gd) and keep looking; `notice` = say so the first time.
func inspect(pos: Vector3, notice: bool) -> void:
	_target = pos
	_investigate = maxf(_investigate, 1.0)
	if notice:
		_show_mark("!", UI.CYAN)
		_line(NOTICE_LINES.pick_random(), true)


## Found a memory where it was lured: says so and goes back to exploring.
func found() -> void:
	_investigate = 0.0
	_show_mark("!", UI.CYAN)
	_line(FOUND_LINES.pick_random(), true)


func _physics_process(delta: float) -> void:
	UI.world_label(_label, LABEL_PX)
	_talk = maxf(_talk - delta, 0)
	_investigate = maxf(_investigate - delta, 0)
	_startle = maxf(_startle - delta, 0)
	var target := global_position
	var speed: float = SPEED[kind]
	var stage := GameState.stage
	match stage:
		GameState.Stage.HAUNT:
			if _investigate > 0 and _startle > 0:  # freeze, turn to the noise
				var to := _target - global_position
				rotation.y = lerp_angle(rotation.y, atan2(-to.x, -to.z), 0.2)
			elif _investigate > 0:
				target = _target
				speed = INVESTIGATE_SPEED
			else:
				target = _explore(delta)
		GameState.Stage.PRIEST_COMING:
			target = _marker("Entrance")
		GameState.Stage.EVIDENCE:
			var at_focus := kind == Kind.ARCH and focus != Vector3.INF
			target = focus + _room_spot() * 0.3 if at_focus else _marker("RoomCenter") + _room_spot()
		GameState.Stage.RITUAL:
			target = _marker("RoomCenter") + (Vector3.ZERO if kind == Kind.PRIEST else _room_spot())
	_walk(target, speed)
	_swing_lantern(stage == GameState.Stage.HAUNT and _investigate > 0)
	_label.text = _label_text()
	_label.visible = GameState.show_labels


## The lantern is held out towards the noise while checking it, back at the side otherwise.
func _swing_lantern(at_noise: bool) -> void:
	if not _lantern:
		return
	var rest := LANTERN_REST
	if at_noise:
		var to := to_local(_target)
		to.y = 0
		if to.length() > 0.1:
			rest = to.normalized() * 0.6 + Vector3.UP * 1.45
	_lantern.position = _lantern.position.lerp(rest, 0.1)


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
	if _anim:
		_anim.play("walk" if velocity.length() > 0.1 else "idle", 0.2)
		_anim.speed_scale = velocity.length() / SPEED[0] if velocity.length() > 0.1 else 1.0


func _line(text: String, force := false) -> void:
	if _talk > 0 and not force:
		return
	_talk = 5.0
	GameState.say(title_text, text, UI.GOLD if kind == Kind.PRIEST else UI.GREEN)


func _label_text() -> String:
	match GameState.stage:
		GameState.Stage.HAUNT:
			return title_text + (": що це було?" if _investigate > 0 else (": досліджує" if _flat(_site) < 0.6 else ""))
		GameState.Stage.RITUAL:
			return title_text + (": ритуал %d%%" % int(GameState.ritual * 100) if kind == Kind.PRIEST else "")
	return title_text


func _flat(p: Vector3) -> float:
	return Vector2(p.x - global_position.x, p.z - global_position.z).length()
