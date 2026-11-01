extends Node
## Autopilot through the whole story with comics on, for watching a build (the web one: preset "WebTest" runs this
## as its main scene). Same steps as smoke_test.gd, slower, with the ghost moved in front of each thing; comics,
## the guide and the time-lapse play and are paged on by themselves. Prints `WALK: <step>`, then `WALK OK`.

const PAGE := 1.2  ## s per comic panel


func _say(s: String) -> void:
	print("WALK: ", s)


func _wait(s: float) -> void:
	await get_tree().create_timer(s, true, false, true).timeout


func _until(cond: Callable, max_s: float, fast := 4.0) -> void:
	Engine.time_scale = fast
	var t := 0.0
	while not cond.call() and t < max_s:
		await get_tree().process_frame
		t += get_process_delta_time()
	Engine.time_scale = 1.0
	assert(cond.call(), "timed out")


## Pages any open comic on and closes the guide, in real time, while the tree is paused.
func _process(_delta: float) -> void:
	var g := get_node_or_null("Game")
	if g == null:
		return
	for c in g.get_children():
		if c.has_method("advance") and not c.has_meta("walk_t"):
			c.set_meta("walk_t", true)
			_page(c)
		elif c.has_method("go") and not c.has_meta("walk_t"):
			c.set_meta("walk_t", true)
			_tour(c)


func _page(c: Node) -> void:
	while is_instance_valid(c) and c.is_inside_tree():
		await _wait(PAGE)
		if is_instance_valid(c):
			c.advance()


func _tour(t: Node) -> void:
	for i in range(1, 3):
		await _wait(2.0)
		if is_instance_valid(t):
			t.go(i)
	await _wait(2.0)
	if is_instance_valid(t):
		t.go(t.STEPS.size())


## The ghost stands `back` m in front of the thing and looks at it.
func _look_at(g: Node, p: Node3D, n: Node3D, back := 2.2) -> void:
	var to := n.global_position
	var from := Vector3(to.x, 0, to.z) + (Vector3(p.global_position.x, 0, p.global_position.z) - Vector3(to.x, 0, to.z)).normalized() * back
	p.global_position = from
	p.look_at(Vector3(to.x, p.global_position.y, to.z))
	p.camera.look_at(to)


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	Engine.max_physics_steps_per_frame = 16
	var g = load("res://scenes/game.tscn").instantiate()
	g.name = "Game"
	add_child(g)
	_say("start (prologue + guide)")
	var p = g.get_node("Player")
	var hud = g.get_node("HUD")
	var st = func(n): return g.find_child(n, true, false)
	var olena = st.call("Olena")
	var taras = st.call("Taras")
	var near = func(n, dx := 3.0): return Vector3(n.global_position.x + dx, 0, n.global_position.z)
	await _until(func(): return get_tree().paused, 10, 1.0)  # the prologue opens a frame later
	await _until(func(): return not get_tree().paused, 90, 1.0)
	await _wait(2.0)

	_say("memory 1")
	_look_at(g, p, st.call("Memory1"))
	await _wait(1.5)
	st.call("Memory1").interact(p)
	await _until(func(): return GameState.has_power("breath") and not get_tree().paused, 60, 1.0)

	_say("candle lures Olena to memory 2")
	var c2 = st.call("CandleShackles")
	olena.global_position = near.call(c2)
	_look_at(g, p, c2, 3.0)
	c2.interact(p)
	await _until(func(): return 2 in GameState.memories, 40)
	await _until(func(): return GameState.has_power("sound") and not get_tree().paused, 60, 1.0)

	_say("jug noise, memory 3")
	var jug = st.call("Jug")
	olena.global_position = near.call(jug, -3.0)
	_look_at(g, p, jug, 3.0)
	jug.interact(p)
	await _until(func(): return 3 in GameState.memories, 40)
	await _until(func(): return GameState.has_power("write") and not get_tree().paused, 60, 1.0)

	_say("dust writing, memory 4")
	var dust = st.call("Dust")
	olena.global_position = Vector3(-13, 0, -4)
	_look_at(g, p, dust, 2.0)
	dust.interact(p)
	await _until(func(): return 4 in GameState.memories, 40)
	await _until(func(): return GameState.has_power("hands") and not get_tree().paused, 60, 1.0)

	_say("mirror")
	var mirror = st.call("Mirror")
	taras.global_position = g.get_node("Markers/Entrance").global_position
	olena.global_position = near.call(mirror, -2.0)
	_look_at(g, p, mirror, 2.0)
	await _wait(1.5)
	mirror.interact(p)
	await _wait(4.0)
	assert(GameState.stage == GameState.Stage.PRIEST_COMING)

	_say("priest coming, time-lapse")
	hud.toggle_book()
	await _wait(2.5)
	hud.toggle_book()
	hud.toggle_map()
	await _wait(2.5)
	hud.toggle_map()
	g.priest_in = 0.01
	await _until(func(): return GameState.stage == GameState.Stage.EVIDENCE and not get_tree().paused, 90, 1.0)

	_say("evidence")
	var wall = st.call("Wall")
	_look_at(g, p, wall, 3.5)
	await _until(func(): return GameState.name_known(), 120)
	await _until(func(): return not get_tree().paused, 60, 1.0)
	await _until(func(): return wall.witness(), 30)

	_say("knock")
	_look_at(g, p, wall, 2.0)
	for attempt in 6:  # a slow software-rendered browser can land a beat late: try again, like a player would
		_say("knock attempt %d, %d fps" % [attempt + 1, Engine.get_frames_per_second()])
		for i in wall.KNOCK_BEATS.size():
			if i > 0:
				await get_tree().create_timer(maxf(0.0, wall.KNOCK_BEATS[i] - wall.knock_time()), true, false, true).timeout
			wall.interact(p)
		if GameState.wall_knocked:
			break
		await _wait(1.0)
	if not GameState.wall_knocked and Engine.get_frames_per_second() < 20:  # software WebGL: no beat can land at 3 fps
		_say("knock: too slow to keep the beat, three knocks back-dated")
		var now: float = wall.knock_clock()
		wall._knocks.assign([now - 2.25, now - 1.75, now - 1.25])
		wall.interact(p)
	assert(GameState.wall_knocked)

	_say("ritual")
	await _wait(1.0)
	_look_at(g, p, st.call("Circle"), 3.0)
	await _until(func(): return GameState.ritual >= 1.0, 60)
	await _wait(2.0)
	for i in 3:  # in one go: game._process lets go of E every frame it is not really held
		g._release(true, 1.0)
	await _until(func(): return GameState.phase == GameState.Phase.END and hud._end != null, 60, 1.0)

	_say("end screen (arrow at 15.5 s)")
	await _wait(18.0)
	hud._credits()
	_say("credits")
	await _wait(5.0)
	print("WALK OK")
