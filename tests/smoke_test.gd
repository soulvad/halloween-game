extends Node

func _frames(n: int) -> void:
	for i in n:
		await get_tree().physics_frame
		await get_tree().process_frame


## Fast-forward (time_scale) until `cond` holds or `max_s` game seconds pass; returns game seconds waited.
func _until(cond: Callable, max_s: float) -> float:
	Engine.time_scale = 10.0
	var t := 0.0
	while not cond.call() and t < max_s:
		await get_tree().physics_frame
		t += get_physics_process_delta_time()
	Engine.time_scale = 1.0
	await get_tree().process_frame
	return t


func _ready() -> void:
	Engine.max_physics_steps_per_frame = 16
	var UI = load("res://scripts/ui.gd")  # UI kit builds without errors
	for c in [UI.button("Грати", "primary", "Enter", "play"), UI.pill("1 · Тінь", UI.CYAN, 17, "ghost"), UI.action_tile("E", "hand", UI.GOLD, "Взаємодія"), UI.title("Відпусти"), UI.vignette(UI.RED)]:
		add_child(c)
		c.queue_free()
	assert(UI.icon_texture("ghost", 30).get_width() == 30)

	var menu = load("res://scenes/main_menu.tscn").instantiate()
	add_child(menu)
	assert(menu.get_node("Box/Play") is Button)
	menu.queue_free()

	GameState.intro_seen = true
	var g = load("res://scenes/game.tscn").instantiate()
	g.comics_enabled = false
	add_child(g)
	var p = g.get_node("Player")
	var hud = g.get_node("HUD")
	var st = func(n): return g.find_child(n, true, false)
	var olena = st.call("Olena")
	var priest = st.call("Priest")
	var mem = func(i): return st.call("Memory%d" % i)
	await _frames(2)

	# flying rocks the view, hovering settles it; lanterns drift along the navmesh under the ceiling
	var lanterns = g.get_node("Lanterns")
	await _until(func(): return lanterns.get_child_count() == lanterns.COUNT, 3.0)
	assert(lanterns.get_child_count() == lanterns.COUNT)
	var lantern: Node3D = lanterns.get_child(0)
	var lantern_from := lantern.position
	var entrance: Vector3 = g.get_node("Markers/Entrance").global_position
	for i in range(1, lanterns.COUNT):  # never in the rock around the rooms
		var c: Node3D = lanterns.get_child(i)
		assert(lanterns.in_dungeon(g.get_world_3d().navigation_map, entrance, Vector3(c.position.x, 0, c.position.z)))
	assert(Vector2(lantern_from.x, lantern_from.z).distance_to(Vector2(p.position.x, p.position.z)) < 6.0)  # met right at the start
	p.velocity = Vector3(p.WALK, 0, 0)
	p._sway(1.0)
	assert(p.flight > 0.9)
	p._sway(0.2)
	assert(absf(p.camera.rotation.z) > 0.001)
	p.velocity = Vector3.ZERO
	await _until(func(): return false, 3.0)
	assert(p.flight < 0.05 and absf(p.camera.rotation.z) < 0.01)
	assert(lantern.position.distance_to(lantern_from) > 1.0 and lantern.position.y > 1 and lantern.position.y < 2.9)

	# start: no powers, only the first memory glints, the ghost floats through inner walls
	assert(GameState.stage == GameState.Stage.HAUNT and GameState.powers.is_empty() and p.collision_mask == 1)
	assert(not priest.visible and mem.call(1).can_use() and not mem.call(2).can_use() and not mem.call(5).can_use())
	var candle = st.call("CandleBedroom")
	assert(not candle.can_use())

	# 3D guide: pauses, shows its steps, Esc / last step dives back into the ghost and unpauses
	g.tour()
	var tour = g.get_children().filter(func(n): return n.has_method("go")).front()
	assert(get_tree().paused and tour.step == 0)
	tour.go(1)
	assert(tour.step == 1 and tour._mark != null)
	tour.go(tour.STEPS.size())
	await get_tree().create_timer(1.3, true).timeout
	assert(not is_instance_valid(tour) and not get_tree().paused and p.camera.current)

	# memory 1 → breath: candles; a light change makes archaeologists in earshot come
	mem.call(1).interact(p)
	assert(GameState.memories == [1] and GameState.has_power("breath") and mem.call(2).can_use())
	olena.global_position = Vector3(candle.global_position.x + 3, 0, candle.global_position.z + 2)
	var was_lit: bool = candle.lit
	candle.interact(p)
	assert(candle.lit != was_lit and olena._investigate > 0 and GameState.haunts == 1)

	# memory 2 → sound: noises; memory 3 → write: the mirror, but only with a witness
	mem.call(2).interact(p)
	st.call("Chains").interact(p)
	assert(GameState.has_power("sound") and GameState.haunts == 2)
	var mirror = st.call("Mirror")
	assert(not mirror.can_use())
	mem.call(3).interact(p)
	assert(GameState.has_power("write") and not mirror.can_use())  # nobody near the mirror
	olena.global_position = Vector3(mirror.global_position.x - 2, 0, mirror.global_position.z)
	assert(mirror.can_use())
	mirror.interact(p)
	await _frames(2)
	assert(GameState.mirror_written and GameState.stage == GameState.Stage.PRIEST_COMING)

	# book, map, pause overlays open and close
	hud.toggle_book()
	await _frames(2)
	assert(hud._book.visible)
	hud.toggle_book()
	hud.toggle_map()
	await _frames(2)
	assert(hud._map.visible)
	hud.toggle_map()
	hud.open_pause()
	assert(get_tree().paused)
	await _frames(1)
	hud.resume()
	assert(not get_tree().paused)

	# the priest walks in; archaeologists go back to their camp table
	g.priest_in = 0.01
	await _frames(3)
	assert(GameState.stage == GameState.Stage.LURE and priest.visible)
	var plan = st.call("Plan")
	var wall = st.call("Wall")
	var door = st.call("Door")
	assert(not wall.can_use())
	var t := await _until(func(): return plan.witness(), 30)
	print("Archaeologists at the camp after %.1f s" % t)
	plan.interact(p)
	assert(GameState.plan_moved)

	# they head for the bricked wall, but the closed door stops them
	await _until(func(): return false, 15)
	assert(not wall.witness() and GameState.stage == GameState.Stage.LURE)
	assert(not door.can_use())
	mem.call(4).interact(p)
	assert(GameState.has_power("hands") and door.can_use())
	door.interact(p)
	assert(door.open)
	t = await _until(func(): return wall.witness(), 30)
	print("At the wall after %.1f s" % t)
	assert(wall.can_use())

	# knock: four quick knocks are wrong, three quick + pause + one is the code
	for i in 4: wall.interact(p)
	assert(not GameState.wall_knocked)
	await get_tree().create_timer(1.0).timeout  # resets the attempt (gap too long for a quick knock)
	for i in 3: wall.interact(p)
	await get_tree().create_timer(1.1).timeout
	wall.interact(p)
	assert(GameState.wall_knocked)
	await _frames(2)
	assert(GameState.stage == GameState.Stage.DIG)
	t = await _until(func(): return GameState.stage == GameState.Stage.EVIDENCE, 30)
	print("Wall taken down in %.1f s" % t)
	assert(GameState.stage == GameState.Stage.EVIDENCE and g.get_node_or_null("Level/Rubble") == null)

	# your room: show three things to a witness, then the name on the wall
	var ev := ["Shackles", "Tally", "Bowl"].map(func(n): return st.call(n))
	t = await _until(func(): return ev.all(func(e): return e.witness()), 40)
	print("Archaeologists in your room after %.1f s" % t)
	assert(not mem.call(5).can_use())
	for e in ev:
		assert(e.can_use())
		e.interact(p)
		assert(e.shown and not e.can_use())
	assert(GameState.evidence == 3 and mem.call(5).can_use())
	mem.call(5).interact(p)
	await _frames(2)
	assert(GameState.name_known() and GameState.stage == GameState.Stage.RITUAL)

	# ritual, then hold E in the circle; releasing starts over
	t = await _until(func(): return GameState.ritual >= 1.0, 60)
	print("Ritual done after %.1f s" % t)
	assert(GameState.release_ready() and st.call("Circle").can_use())
	g._release(true, 1.0)
	g._release(false, 0.1)
	assert(g.hold == 0.0 and GameState.phase == GameState.Phase.PLAY)
	for i in 3: g._release(true, 1.0)
	assert(GameState.phase == GameState.Phase.END and GameState.won)
	await _frames(2)
	assert(hud._end != null)
	# floating through walls: inside an inner wall the veil is up; left alone the ghost drifts out
	get_tree().paused = false
	p.set_physics_process(true)
	p.global_position = Vector3(1.5, 0, -2.5)  # between CorridorV and R2R
	await _frames(2)
	assert(p.wall_depth() < 0)
	await get_tree().create_timer(1.5).timeout
	assert(p.wall_depth() > 0 and p.phase < 0.5)
	assert(hud._map_view.to_map(Vector3(-30, 0, 0)).x < 0)  # the whole-map projection is sane
	g.queue_free()
	await _frames(2)
	assert(not get_tree().paused)
	print("ALL TESTS OK")
	get_tree().quit()
