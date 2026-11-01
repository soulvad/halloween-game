extends Node3D
## Story flow of «Підземелля старого міста» (stages in GameState.Stage):
## HAUNT (memories 1–4) → (ДОПОМОЖІТЬ on the mirror) PRIEST_COMING → (priest walks in) SEARCH (time-lapse cutscene,
## the collapsed wall is cleared) → EVIDENCE (they look over your things and read your name = memory 5; you knock 3–1)
## → RITUAL → (priest prayed, E held in the circle) finale comic, end.
## Linear, no way to lose. Comics: prologue at start, one per memory, finale. All UI lives in scripts/hud.gd.

const MIRROR_THOUGHT_DELAY := 4.0  ## s after «Я згадав…» for the mirror thought
const Station = preload("res://scripts/station.gd")
const Visitor = preload("res://scripts/visitor.gd")
const Wall = preload("res://scripts/wall.gd")
const Ambient = preload("res://scripts/ambient.gd")
const Lanterns = preload("res://scripts/lanterns.gd")
const Decor = preload("res://scripts/decor.gd")
const Paintings = preload("res://scripts/paintings.gd")
const Look = preload("res://scripts/look.gd")
const Labels = preload("res://scripts/labels.gd")
const Fx = preload("res://scripts/fx.gd")
const UI = preload("res://scripts/ui.gd")
const COMIC_SCENE := "res://scenes/comic.tscn"
const Tour = preload("res://scripts/tour.gd")
const RELEASE_TIME := 2.5  ## seconds to hold E in the circle
const TIMELAPSE := "res://scripts/timelapse.gd"
const PRIEST_DELAY := 15.0  ## from the call to the priest walking in
const RITUAL_TIME := 20.0
const LOOK_NEAR := 1.8  ## EVIDENCE: an archaeologist this close to a thing is looking at it
const LOOK_TIME := 2.5  ## ...for this long
const LOOK_GIVE_UP := 15.0  ## can't get close (navmesh): counts as seen anyway
## EVIDENCE: what they look at, in order, and what they say. The last one is your name on the wall (memory 5).
const LOOKS := [
	["Shackles", "Олена", "Кайдани… Такі малі. На дитячу руку."],
	["Tally", "Тарас", "Подряпини, рядами по сім. Він рахував дні."],
	["Bowl", "Олена", "Миска. Сюди йому подавали їжу… а потім перестали."],
	["Memory5", "Тарас", "Тут щось надряпано… Ти… міш? Тиміш!"],
]
const WAIT_LINES := [  ## PRIEST_COMING: [seconds left, who, line]
	[10.0, "Тарас", "У книзі обліку прислуги є хлопець без імені, «Сімнадцятий». Записано: «втік»."],
	[5.0, "Олена", "Втік… з підземелля, де на кожних дверях засув?"],
]
const RITUAL_LINES := [  ## RITUAL: [progress, line of the priest]
	[0.3, "Двісті років тебе вважали втікачем. Тепер усі знатимуть правду."],
	[0.65, "Господи, прийми душу раба Твого Тимоша. Він довго чекав."],
]
const ARCH_COLOR := Color("8BEA4E")
const PRIEST_COLOR := Color("FFC531")
const LAYER_FLOOR := 32  ## layer 6: only the navmesh baker sees it
const NAV_MASK := 7 | 64  ## walls, furniture, the collapsed wall (people-only)
const MEMORY_SLOW := 0.3  ## time scale for the beat before a memory comic...
const MEMORY_SLOW_TIME := 0.5  ## ...this many real seconds

var comics_enabled := true  ## the smoke test turns comics off
var hold := 0.0  ## seconds E has been held in the circle
var priest_in := 0.0  ## PRIEST_COMING: seconds until he arrives
var looked := 0  ## EVIDENCE: index into LOOKS (things seen)
var _look_t := 0.0  ## EVIDENCE: seconds near the current thing
var _look_all := 0.0  ## EVIDENCE: seconds on the current thing
var _region: NavigationRegion3D

@onready var player = $Player


## Before the children's _ready: stations read GameState when they build (the mirror's writing), a restart must
## not show them the last round.
func _enter_tree() -> void:
	GameState.reset()


func _ready() -> void:
	_bake_nav()
	Wall.textured($Level/Floor.mesh.material, "floor", 0.25)
	Wall.uneven($Level/Floor)
	Wall.textured($Level/Ceiling.mesh.material, "ceiling", 0.25)
	var ambient := Ambient.new()
	ambient.name = "Ambient"
	add_child(ambient)
	GameState.memory_found.connect(_on_memory_found)
	GameState.power_gained.connect(_on_power_gained)
	GameState.finished.connect(_on_finished)
	GameState.think("Холодно… Темно… Хто я? Я нічого не пам'ятаю.")
	GameState.hint("start")
	var decor := Decor.new()
	decor.name = "Decor"
	add_child(decor)
	var paintings := Paintings.new()
	paintings.name = "Paintings"
	add_child(paintings)
	var look := Look.new()
	look.name = "Look"
	add_child(look)
	var labels := Labels.new()
	labels.name = "Labels"
	add_child(labels)
	var lanterns := Lanterns.new()
	lanterns.name = "Lanterns"
	add_child(lanterns)
	if not GameState.intro_seen:
		GameState.intro_seen = true
		_intro.call_deferred()


## Navmesh for visitors, baked from wall/furniture/collapsed wall colliders + an invisible floor.
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
	$Stations.add_to_group("nav_source")  # doors
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
	rebake_nav()


## A door opened/closed or the wall came down (station.gd calls this).
func rebake_nav() -> void:
	_region.bake_navigation_mesh(false)


## Play a comic over the game (pauses the tree) and wait for it.
func comic(id: String) -> void:
	if not comics_enabled or not ResourceLoader.exists(COMIC_SCENE):
		return
	var c = load(COMIC_SCENE).instantiate()
	add_child(c)
	c.play(id)
	await c.finished


## First start: the prologue comic, then the 3D guide.
func _intro() -> void:
	await comic("prologue")
	if comics_enabled:
		await tour()


## Fly the 3D guide over the dungeon (pauses the tree) and wait for it; also from the pause menu.
func tour() -> void:
	var t := Tour.new()
	add_child(t)
	t.play(self)
	await t.finished


func _process(delta: float) -> void:
	if GameState.phase != GameState.Phase.PLAY:
		return
	match GameState.stage:
		GameState.Stage.HAUNT:
			if GameState.mirror_written:
				GameState.say("Олена", "«ДОПОМОЖІТЬ»… Тарасе, це не жарт. Я дзвоню отцю Василю.", ARCH_COLOR)
				priest_in = PRIEST_DELAY
				GameState.set_stage(GameState.Stage.PRIEST_COMING)
		GameState.Stage.PRIEST_COMING:
			for l in WAIT_LINES:
				if priest_in > l[0] and priest_in - delta <= l[0]:
					GameState.say(l[1], l[2], ARCH_COLOR)
			priest_in -= delta
			if priest_in <= 0:
				priest().arrive($Markers/Entrance.global_position)
				GameState.say("Отець Василь", "Душа просить допомоги — значить, її тут тримає щось незавершене. Шукаймо.", PRIEST_COLOR)
				GameState.set_stage(GameState.Stage.SEARCH)
				_search()
		GameState.Stage.EVIDENCE:
			if looked < LOOKS.size():
				_look_over(delta)
			elif GameState.wall_knocked:
				GameState.say("Отець Василь", "Чули? Три і один… Він тут. Тиміш Ковальчук, тебе не забули, сину. Я відпущу тебе.", PRIEST_COLOR)
				GameState.set_stage(GameState.Stage.RITUAL)
		GameState.Stage.RITUAL:
			var p := priest()
			if GameState.ritual < 1.0 and p.global_position.distance_to($Markers/RoomCenter.global_position) < 1.5:
				var was := GameState.ritual
				GameState.ritual = minf(GameState.ritual + delta / RITUAL_TIME, 1.0)
				for l in RITUAL_LINES:
					if was < l[0] and GameState.ritual >= l[0]:
						GameState.say("Отець Василь", l[1], PRIEST_COLOR)
				if GameState.ritual >= 1.0:
					GameState.say("Отець Василь", "Іди з миром, Тимоше. Тебе більше ніщо тут не тримає.", PRIEST_COLOR)
	_release(Input.is_action_pressed("interact") and at_release(), delta)


func priest() -> Node3D:
	for v in get_tree().get_nodes_in_group("visitor"):
		if v.kind == Visitor.Kind.PRIEST:
			return v
	return null


## SEARCH: the time-lapse (search the rooms, find the plan, clear the collapsed wall), then your room is open.
## The smoke test (comics off) skips the cutscene.
func _search() -> void:
	if comics_enabled:
		var t = load(TIMELAPSE).new()
		add_child(t)
		t.play(self)
		await t.finished
	_open_room()


## The collapsed wall is cleared: remove it, let people path into your room.
func _open_room() -> void:
	var r := get_node_or_null("Level/Rubble")
	if r:
		r.free()
	rebake_nav()
	GameState.say("Олена", "Боже… тут хтось жив.", ARCH_COLOR)
	looked = 0
	_look_t = 0.0
	_look_all = 0.0
	GameState.set_stage(GameState.Stage.EVIDENCE)


## EVIDENCE: the archaeologists look at LOOKS one by one; the name on the wall last, which is memory 5.
func _look_over(delta: float) -> void:
	var thing := $Stations.get_node(LOOKS[looked][0]) as Node3D
	var archs := get_tree().get_nodes_in_group("visitor").filter(func(v): return v.kind == Visitor.Kind.ARCH)
	var near := false
	for v in archs:
		v.focus = thing.global_position
		v.focus_side = 1.0 if archs.find(v) % 2 == 0 else -1.0  # one each side of it, not both on one spot
		near = near or Vector2(v.global_position.x - thing.global_position.x, v.global_position.z - thing.global_position.z).length() < LOOK_NEAR
	_look_all += delta
	if near and _look_t == 0.0 and thing.kind != Station.Kind.EVIDENCE:
		thing.scratch(LOOK_TIME)  # the name comes out of the dark as they read it
	_look_t = _look_t + delta if near else 0.0
	if _look_t < LOOK_TIME and _look_all < LOOK_GIVE_UP:
		return
	GameState.say(LOOKS[looked][1], LOOKS[looked][2], ARCH_COLOR)
	if thing.kind == Station.Kind.EVIDENCE:
		thing.see()
	else:
		GameState.remember(5)
		GameState.hint("knock")
	looked += 1
	_look_t = 0.0
	_look_all = 0.0
	if looked == LOOKS.size():
		for v in archs:
			v.focus = Vector3.INF


## The ghost aims at the ritual circle and may leave.
func at_release() -> bool:
	var s = player.target_station()
	return s is Station and s.kind == Station.Kind.CIRCLE and GameState.release_ready()


## Hold E in the circle for RELEASE_TIME to leave; releasing starts over.
func _release(holding: bool, delta: float) -> void:
	hold = hold + delta if holding and GameState.phase == GameState.Phase.PLAY else 0.0
	if hold >= RELEASE_TIME:
		GameState.finish(true)


## A memory comes back: a cyan flash, the world slows for a breath, then its comic.
## Slow motion only with comics on: the smoke test drives Engine.time_scale itself.
func _on_memory_found(id: int) -> void:
	Fx.flash(get_tree(), Color(UI.CYAN, 0.55), 0.6)
	Fx.sound_ui(get_tree(), "memory")
	if comics_enabled:
		Engine.time_scale = MEMORY_SLOW
		await get_tree().create_timer(MEMORY_SLOW_TIME, true, false, true).timeout
		Engine.time_scale = 1.0
	await comic("memory_%d" % id)
	GameState.gain(GameState.MEMORY_POWER.get(id, ""))  # the power comes after the comic


func _exit_tree() -> void:
	Engine.time_scale = 1.0  # left mid slow motion (back to the menu)


func _on_power_gained(p: String) -> void:
	GameState.think("Я згадав… Тепер я можу %s." % GameState.POWER_HELP[p])
	if p == "hands":  # the last power opens the mirror: say where to go next, once the first line has been read
		await get_tree().create_timer(MIRROR_THOUGHT_DELAY).timeout
		if not GameState.mirror_written:
			GameState.think("Дзеркало… Там, у кімнаті. Якщо напишу на ньому — вони прочитають.")


func _on_finished(_won: bool) -> void:
	player.set_physics_process(false)
	player.set_process_unhandled_input(false)
	comic("finale")
