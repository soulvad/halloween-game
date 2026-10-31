extends Node3D

const Station = preload("res://scripts/station.gd")
const Visitor = preload("res://scripts/visitor.gd")
const Wall = preload("res://scripts/wall.gd")
const COMIC_SCENE := "res://scenes/comic.tscn"
const RELEASE_TIME := 2.5
const PRIEST_DELAY := 15.0
const DIG_TIME := 12.0
const DIG_RANGE := 3.0
const RITUAL_TIME := 20.0
const LAYER_FLOOR := 32
const NAV_MASK := 7 | 64
const AMBIENT := {
	"res://audio/ambient/dungeon.ogg": -9.0,
	"res://audio/ambient/drips.ogg": -16.0,
	"res://audio/ambient/ghosts.ogg": -22.0,
}

var comics_enabled := true
var hold := 0.0
var priest_in := 0.0
var _region: NavigationRegion3D

@onready var player = $Player


func _ready() -> void:
	_bake_nav()
	Wall.textured($Level/Floor.mesh.material, "floor", 0.25)
	Wall.textured($Level/Ceiling.mesh.material, "ceiling", 0.25)
	_play_ambient()
	GameState.reset()
	GameState.memory_found.connect(_on_memory_found)
	GameState.power_gained.connect(_on_power_gained)
	GameState.finished.connect(_on_finished)
	GameState.think("Холодно… Темно… Хто я? Я нічого не пам'ятаю.")
	GameState.hint("start")
	if not GameState.intro_seen:
		GameState.intro_seen = true
		comic.call_deferred("prologue")


func _play_ambient() -> void:
	for path in AMBIENT:
		if not ResourceLoader.exists(path):
			continue
		var stream: AudioStream = load(path)
		if "loop" in stream:
			stream.loop = true
		var p := AudioStreamPlayer.new()
		p.stream = stream
		p.volume_db = AMBIENT[path]
		p.process_mode = Node.PROCESS_MODE_ALWAYS
		p.autoplay = true
		add_child(p)


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
	$Stations.add_to_group("nav_source")
	var nm := NavigationMesh.new()
	nm.geometry_parsed_geometry_type = NavigationMesh.PARSED_GEOMETRY_STATIC_COLLIDERS
	nm.geometry_collision_mask = NAV_MASK | LAYER_FLOOR
	nm.geometry_source_geometry_mode = NavigationMesh.SOURCE_GEOMETRY_GROUPS_WITH_CHILDREN
	nm.geometry_source_group_name = "nav_source"
	nm.agent_radius = 0.5
	nm.agent_height = 1.75
	nm.agent_max_climb = 0.25
	_region = NavigationRegion3D.new()
	_region.navigation_mesh = nm
	add_child(_region)
	rebake_nav()


func rebake_nav() -> void:
	_region.bake_navigation_mesh(false)


func comic(id: String) -> void:
	if not comics_enabled or not ResourceLoader.exists(COMIC_SCENE):
		return
	var c = load(COMIC_SCENE).instantiate()
	add_child(c)
	c.play(id)
	await c.finished


func _process(delta: float) -> void:
	if GameState.phase != GameState.Phase.PLAY:
		return
	match GameState.stage:
		GameState.Stage.HAUNT:
			if GameState.mirror_written:
				GameState.say("Олена", "«ДОПОМОЖІТЬ»… Тарасе, це не жарт. Я дзвоню отцю Василю.", Color("8BEA4E"))
				priest_in = PRIEST_DELAY
				GameState.set_stage(GameState.Stage.PRIEST_COMING)
		GameState.Stage.PRIEST_COMING:
			priest_in -= delta
			if priest_in <= 0:
				priest().arrive($Markers/Entrance.global_position)
				GameState.say("Отець Василь", "Душа просить допомоги — значить, її тут тримає щось незавершене.", Color("FFC531"))
				GameState.set_stage(GameState.Stage.LURE)
		GameState.Stage.LURE:
			if GameState.plan_moved:
				GameState.hint("door")
				if GameState.has_power("hands"):
					GameState.hint("knock")
			if GameState.wall_knocked:
				GameState.say("Тарас", "Чули? Хтось стукає… А за стіною — порожнеча. Розбираймо!", Color("8BEA4E"))
				GameState.set_stage(GameState.Stage.DIG)
		GameState.Stage.DIG:
			if _digger():
				GameState.dig = minf(GameState.dig + delta / DIG_TIME, 1.0)
			if GameState.dig >= 1.0:
				_open_room()
		GameState.Stage.EVIDENCE:
			if GameState.evidence >= GameState.EVIDENCE_NEEDED and GameState.name_known():
				GameState.say("Отець Василь", "Тиміш Ковальчук. Тебе не забули, сину. Я відпущу тебе.", Color("FFC531"))
				GameState.set_stage(GameState.Stage.RITUAL)
		GameState.Stage.RITUAL:
			var p := priest()
			if GameState.ritual < 1.0 and p.global_position.distance_to($Markers/RoomCenter.global_position) < 1.5:
				GameState.ritual = minf(GameState.ritual + delta / RITUAL_TIME, 1.0)
				if GameState.ritual >= 1.0:
					GameState.say("Отець Василь", "Іди з миром, Тимоше. Тебе більше ніщо тут не тримає.", Color("FFC531"))
	_release(Input.is_action_pressed("interact") and at_release(), delta)


func priest() -> Node3D:
	for v in get_tree().get_nodes_in_group("visitor"):
		if v.kind == Visitor.Kind.PRIEST:
			return v
	return null


func _digger() -> bool:
	var r := get_node_or_null("Level/Rubble") as Node3D
	return r != null and get_tree().get_nodes_in_group("visitor").any(
		func(v): return v.kind == Visitor.Kind.ARCH and v.global_position.distance_to(r.global_position) < DIG_RANGE)


func _open_room() -> void:
	var r := get_node_or_null("Level/Rubble")
	if r:
		r.free()
	rebake_nav()
	GameState.say("Олена", "Боже… тут хтось жив. Ланцюги, миска… подряпини на стіні.", Color("8BEA4E"))
	GameState.say("Тарас", "А в книзі обліку біля Сімнадцятого написано «втік». Не втік він…", Color("8BEA4E"))
	GameState.set_stage(GameState.Stage.EVIDENCE)


func at_release() -> bool:
	var s = player.target_station()
	return s is Station and s.kind == Station.Kind.CIRCLE and GameState.release_ready()


func _release(holding: bool, delta: float) -> void:
	hold = hold + delta if holding and GameState.phase == GameState.Phase.PLAY else 0.0
	if hold >= RELEASE_TIME:
		GameState.finish(true)


func _on_memory_found(id: int) -> void:
	comic("memory_%d" % id)


func _on_power_gained(p: String) -> void:
	GameState.think("Я згадав… Тепер я можу %s." % GameState.POWER_HELP[p])


func _on_finished(_won: bool) -> void:
	player.set_physics_process(false)
	player.set_process_unhandled_input(false)
	comic("finale")
