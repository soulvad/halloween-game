extends Node3D
## Story flow of «Підземелля старого міста» (stages in GameState.Stage):
## HAUNT → (unease full) PRIEST_COMING → (priest walks in) LURE → (archaeologist at the rubble) DIG → (dug through)
## EVIDENCE → (all evidence shown) RITUAL → (priest prayed in the circle, ghost at level 3, E held in the circle) win.
## Linear, no way to lose. All UI (HUD, overlays, Esc / M / J) lives in scripts/hud.gd.

const Station = preload("res://scripts/station.gd")
const Visitor = preload("res://scripts/visitor.gd")
const RELEASE_TIME := 2.5  ## seconds to hold E in the circle
const PRIEST_DELAY := 15.0  ## from the call to the priest walking in
const DIG_TIME := 12.0
const DIG_RANGE := 3.0  ## an archaeologist this close to the rubble starts / keeps digging
const RITUAL_TIME := 20.0
const LAYER_FLOOR := 32  ## layer 6: only the navmesh baker sees it
const NAV_MASK := 7 | 64  ## walls, furniture, rubble (people-only)

var hold := 0.0  ## seconds E has been held in the circle
var priest_in := 0.0  ## PRIEST_COMING: seconds until he arrives
var _last_level := 1
var _spawn: Vector3
var _region: NavigationRegion3D

@onready var player = $Player


func _ready() -> void:
	_bake_nav()
	GameState.reset()
	_spawn = player.global_position
	GameState.visibility_changed.connect(_on_visibility_changed)
	GameState.banished.connect(_on_banished)
	GameState.finished.connect(_on_finished)
	GameState.think("Знову ці кроки нагорі… Хтось прийшов. Може, хоч вони мене почують.")
	GameState.hint("start")
	GameState.hint("haunt")


## Navmesh for visitors, baked from wall/furniture/rubble colliders + an invisible floor.
func _bake_nav() -> void:
	var floor_body := StaticBody3D.new()
	floor_body.collision_layer = LAYER_FLOOR
	floor_body.collision_mask = 0
	var shape := CollisionShape3D.new()
	shape.shape = BoxShape3D.new()
	shape.shape.size = Vector3(40, 0.2, 28)
	shape.position = Vector3(4.75, -0.1, -0.25)
	floor_body.add_child(shape)
	$Level.add_child(floor_body)
	$Level.add_to_group("nav_source")
	var nm := NavigationMesh.new()
	nm.geometry_parsed_geometry_type = NavigationMesh.PARSED_GEOMETRY_STATIC_COLLIDERS
	nm.geometry_collision_mask = NAV_MASK | LAYER_FLOOR
	nm.geometry_source_geometry_mode = NavigationMesh.SOURCE_GEOMETRY_GROUPS_WITH_CHILDREN
	nm.geometry_source_group_name = "nav_source"
	nm.agent_radius = 0.5  # multiples of the 0.25 cell size
	nm.agent_height = 1.75
	nm.agent_max_climb = 0.25
	_region = NavigationRegion3D.new()
	_region.navigation_mesh = nm
	add_child(_region)
	_region.bake_navigation_mesh(false)


func _process(delta: float) -> void:
	if GameState.phase != GameState.Phase.PLAY:
		return
	match GameState.stage:
		GameState.Stage.HAUNT:
			if GameState.unease >= GameState.UNEASE_TO_CALL:
				GameState.say("Олена", "Все, досить. Я дзвоню отцю Василю — тут щось нечисте.", Color("8BEA4E"))
				priest_in = PRIEST_DELAY
				GameState.set_stage(GameState.Stage.PRIEST_COMING)
		GameState.Stage.PRIEST_COMING:
			priest_in -= delta
			if priest_in <= 0:
				priest().arrive($Markers/Entrance.global_position)
				GameState.say("Отець Василь", "Ну, показуйте, де ваш неспокійний дух.", Color("FFC531"))
				GameState.set_stage(GameState.Stage.LURE)
		GameState.Stage.LURE:
			if _digger():
				GameState.say("Тарас", "Тут завал… а за ним порожнеча. Розкопаймо!", Color("8BEA4E"))
				GameState.set_stage(GameState.Stage.DIG)
		GameState.Stage.DIG:
			if _digger():
				GameState.dig = minf(GameState.dig + delta / DIG_TIME, 1.0)
			if GameState.dig >= 1.0:
				_open_room()
		GameState.Stage.EVIDENCE:
			if GameState.evidence >= GameState.EVIDENCE_NEEDED:
				GameState.say("Отець Василь", "Тут жила й померла людина. Душа досі тут. Я її відпущу.", Color("FFC531"))
				GameState.set_stage(GameState.Stage.RITUAL)
		GameState.Stage.RITUAL:
			var p := priest()
			if GameState.ritual < 1.0 and p.global_position.distance_to($Markers/RoomCenter.global_position) < 1.5:
				GameState.ritual = minf(GameState.ritual + delta / RITUAL_TIME, 1.0)
				if GameState.ritual >= 1.0:
					GameState.say("Отець Василь", "Іди з миром, душе. Тебе більше ніщо тут не тримає.", Color("FFC531"))
	_release(Input.is_action_pressed("interact") and at_release(), delta)


func priest() -> Node3D:
	for v in get_tree().get_nodes_in_group("visitor"):
		if v.kind == Visitor.Kind.PRIEST:
			return v
	return null


## An archaeologist is at the rubble.
func _digger() -> bool:
	var r := get_node_or_null("Level/Rubble") as Node3D
	return r != null and get_tree().get_nodes_in_group("visitor").any(
		func(v): return v.kind == Visitor.Kind.ARCH and v.global_position.distance_to(r.global_position) < DIG_RANGE)


## Rubble cleared: remove it, let people path into your room.
func _open_room() -> void:
	var r := get_node_or_null("Level/Rubble")
	if r:
		r.free()
	_region.bake_navigation_mesh(false)
	GameState.say("Олена", "Боже… тут хтось жив. Ланцюги, миска… подряпини на стіні.", Color("8BEA4E"))
	GameState.set_stage(GameState.Stage.EVIDENCE)


## The ghost aims at the ritual circle and may leave.
func at_release() -> bool:
	var s = player.target_station()
	return s is Station and s.kind == Station.Kind.CIRCLE and GameState.release_ready()


## Hold E in the circle for RELEASE_TIME to leave; releasing starts over.
func _release(holding: bool, delta: float) -> void:
	hold = hold + delta if holding and GameState.phase == GameState.Phase.PLAY else 0.0
	if hold >= RELEASE_TIME:
		GameState.finish(true)


func _on_visibility_changed() -> void:
	var l: int = GameState.level
	if l > _last_level:
		GameState.think("Тепер вони можуть мене побачити… Стіни більше не пускають." if l == 2 else "Я Присутність. Нехай бачать — нехай знають, що я тут був.")
	elif l < _last_level:
		GameState.think("Я слабшаю… Рівень %d." % l)
	_last_level = l


func _on_banished() -> void:
	player.global_position = _spawn
	GameState.think("Святе світло відкинуло мене назад, до моїх кісток.")


func _on_finished(_won: bool) -> void:
	player.set_physics_process(false)
	player.set_process_unhandled_input(false)
