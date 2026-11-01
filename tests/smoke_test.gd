extends Node

func _frames(n: int) -> void:
	for i in n:
		await get_tree().physics_frame
		await get_tree().process_frame


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
	var UI = load("res://scripts/ui.gd")
	for c in [UI.button("Грати", "primary", "Enter", "play"), UI.pill("1 · Тінь", UI.CYAN, 17, "ghost"), UI.action_tile("E", "hand", UI.GOLD, "Взаємодія"), UI.title("Відпусти"), UI.vignette(UI.RED)]:
		add_child(c)
		c.queue_free()
	assert(UI.icon_texture("ghost", 30).get_width() > 0)
	assert(UI.box("card", UI.PAPER).texture != null)
	var painted = UI.painted_title("pauza", 100)
	assert(painted.texture != null)
	painted.free()

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

	assert(not p.body.visible)
	var glass = st.call("Mirror").get_child(-1)
	assert(glass.get_script().resource_path.ends_with("mirror.gd") and glass.CULL & p.LAYER_SELF == 0)

	var decor = g.get_node("Decor")
	assert(decor.get_child_count() == decor.ON_WALLS.size() + decor.ON_FLOOR.size() + decor.WEBS.size() + 1)  # + the entrance door
	assert(decor.find_children("*", "CollisionObject3D", true, false).is_empty())

	var lanterns = g.get_node("Lanterns")
	await _until(func(): return lanterns.get_child_count() == lanterns.COUNT, 3.0)
	assert(lanterns.get_child_count() == lanterns.COUNT)
	var lantern: Node3D = lanterns.get_child(0)
	var lantern_from := lantern.position
	var entrance: Vector3 = g.get_node("Markers/Entrance").global_position
	for i in range(1, lanterns.COUNT):
		var c: Node3D = lanterns.get_child(i)
		assert(lanterns.in_dungeon(g.get_world_3d().navigation_map, entrance, Vector3(c.position.x, 0, c.position.z)))
	assert(Vector2(lantern_from.x, lantern_from.z).distance_to(Vector2(p.position.x, p.position.z)) < 6.0)
	p.velocity = Vector3(p.WALK, 0, 0)
	p._sway(1.0)
	assert(p.flight > 0.9)
	p._sway(0.2)
	assert(absf(p.camera.rotation.z) > 0.001)
	p.velocity = Vector3.ZERO
	await _until(func(): return false, 3.0)
	assert(p.flight < 0.05 and absf(p.camera.rotation.z) < 0.01)
	assert(lantern.position.distance_to(lantern_from) > 1.0 and lantern.position.y > 1 and lantern.position.y < 2.9)

	assert(GameState.stage == GameState.Stage.HAUNT and GameState.powers.is_empty() and p.collision_mask == 1)
	assert(not priest.visible and mem.call(1).can_use() and not mem.call(2).visible and not mem.call(5).visible)
	var candle = st.call("CandleBedroom")
	assert(not candle.can_use())
	await _frames(1)
	assert(not st.call("Circle").visible)  # the ritual circle appears with the ritual

	# feedback kit: every effect runs on a real station (sounds stay silent when a file is missing)
	var Fx = load("res://scripts/fx.gd")
	Fx.shake(candle)
	Fx.pop(candle)
	assert(Fx.puff(g, candle.global_position) is CPUParticles3D)
	Fx.flash(get_tree())
	Fx.kick(p.camera)
	Fx.sound(candle, "no_such_sound")
	Fx.sound_ui(get_tree(), "no_such_sound")
	p._wisp(candle.global_position)  # the E streak
	p._overlay(candle, p._aim_mat)  # the aim rim reaches every mesh of a station
	assert(candle.find_children("*", "MeshInstance3D", true, false).all(func(m): return m.material_overlay == p._aim_mat))
	p._overlay(candle, null)

	assert(hud._prompt.mouse_filter == Control.MOUSE_FILTER_IGNORE)
	var m1 = mem.call(1)
	assert(m1.global_position.y + m1.size.y / 2 + hud.PROMPT_OVER < 1.8)

	# world labels: full size up close, smaller further off, gone past the shared range (still seen from aim reach)
	var cam: Camera3D = p.camera
	var lbl: Label3D = m1._label
	assert(lbl.visibility_range_end == UI.LABEL_RANGE and UI.LABEL_RANGE > p.ray.target_position.length())
	for v in get_tree().get_nodes_in_group("visitor"):
		assert(v._label.visibility_range_end == UI.LABEL_RANGE)
	var near_pos := lbl.global_position + Vector3(0, 0, 1.0)
	var far_pos := lbl.global_position + Vector3(0, 0, 5.0)
	var cam_from := cam.global_transform
	cam.global_position = near_pos
	UI.world_label(lbl, m1.LABEL_PX)
	assert(is_equal_approx(lbl.pixel_size, m1.LABEL_PX))
	cam.global_position = far_pos
	UI.world_label(lbl, m1.LABEL_PX)
	assert(lbl.pixel_size < m1.LABEL_PX * 0.5)
	cam.global_transform = cam_from

	g.tour()
	var tour = g.get_children().filter(func(n): return n.has_method("go")).front()
	assert(get_tree().paused and tour.step == 0)
	tour.go(1)
	assert(tour.step == 1 and tour._mark != null)
	tour.go(tour.STEPS.size())
	await get_tree().create_timer(1.3, true).timeout
	assert(not is_instance_valid(tour) and not get_tree().paused and p.camera.current)

	# memory 1 → breath. Memory 2 glints but can't be touched: an archaeologist lured there with a candle finds it
	var near = func(n, dx := 3.0): return Vector3(n.global_position.x + dx, 0, n.global_position.z)
	mem.call(1).interact(p)
	assert(GameState.memories == [1] and GameState.has_power("breath") and candle.can_use())
	assert(mem.call(2).available() and not mem.call(2).can_use())
	var c2 = st.call("CandleShackles")
	olena.global_position = near.call(c2)
	c2.interact(p)
	assert(olena._investigate > 0 and olena.lured_by() == "breath" and GameState.haunts == 1)
	assert(st.call("Taras")._investigate <= 0)  # only the nearest one goes
	assert(hud._mini._rings.size() == 1 and hud._mini._blink.has(olena))  # the map: a ring spreads, she blinks
	var t := await _until(func(): return 2 in GameState.memories, 30)
	print("Memory 2 found after %.1f s" % t)
	assert(t >= mem.call(2).EXAMINE_TIME)  # she walks up and looks a while, not found on arrival
	assert(GameState.has_power("sound") and mem.call(3).available())

	# memory 3 wants a noise: a candle right next to it brings Олена, but she finds nothing
	var ck = st.call("CandleKitchen")
	olena.global_position = near.call(ck, -3.0)
	ck.interact(p)
	await _until(func(): return false, 10)
	assert(3 not in GameState.memories)
	st.call("Jug").interact(p)
	t = await _until(func(): return 3 in GameState.memories, 30)
	print("Memory 3 found after %.1f s" % t)
	assert(GameState.has_power("write"))
	var taras = st.call("Taras")  # writing alone can't call the priest yet: memory 4 (Сила рук) first
	var taras_at: Vector3 = taras.global_position
	taras.global_position = near.call(st.call("Mirror"), -2.0)
	assert(not st.call("Mirror").can_use())
	taras.global_position = taras_at

	# memory 4: writing in the dust of the steward's closet
	var dust = st.call("Dust")
	olena.global_position = Vector3(-13, 0, -4)
	dust.interact(p)
	t = await _until(func(): return 4 in GameState.memories, 30)
	print("Memory 4 found after %.1f s" % t)
	assert(GameState.has_power("hands") and not mem.call(5).available())

	# the mirror, only with a witness
	var mirror = st.call("Mirror")
	st.call("Taras").global_position = entrance
	olena.global_position = near.call(mirror, -10.0)
	assert(not mirror.can_use())  # nobody near the mirror
	olena.global_position = near.call(mirror, -2.0)
	assert(mirror.can_use())
	mirror.interact(p)
	await _frames(2)
	assert(GameState.mirror_written and GameState.stage == GameState.Stage.PRIEST_COMING)

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

	# the priest walks in; the search (cutscene, skipped here) clears the collapsed wall
	g.priest_in = 0.01
	await _frames(3)
	assert(priest.visible and GameState.stage == GameState.Stage.EVIDENCE and g.get_node_or_null("Level/Rubble") == null)
	assert(hud._stage_title.text == hud.STAGE_NAMES[GameState.Stage.EVIDENCE])  # the stage title card

	# your room: they look over your things, then read your name (memory 5); knocking only works after that
	var wall = st.call("Wall")
	assert(not wall.can_use())
	t = await _until(func(): return GameState.name_known(), 120)
	print("Things seen and name read after %.1f s" % t)
	assert(GameState.evidence == 3 and GameState.name_known())
	assert(["Shackles", "Tally", "Bowl"].all(func(n): return st.call(n).shown))
	t = await _until(func(): return wall.witness(), 30)
	assert(wall.can_use())

	for i in 4: wall.interact(p)
	assert(not GameState.wall_knocked)
	await get_tree().create_timer(1.0).timeout
	for i in 3: wall.interact(p)
	await get_tree().create_timer(1.1).timeout
	wall.interact(p)
	assert(GameState.wall_knocked)
	await _frames(2)
	assert(GameState.stage == GameState.Stage.RITUAL)
	assert(hud._knocked)  # the beat dots went cyan

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
	get_tree().paused = false
	p.set_physics_process(true)
	p.global_position = Vector3(1.5, 0, -2.5)
	await _frames(2)
	assert(p.wall_depth() < 0)
	await get_tree().create_timer(1.5).timeout
	assert(p.wall_depth() > 0 and p.phase < 0.5)
	assert(hud._map_view.to_map(Vector3(-30, 0, 0)).x < 0)
	g.queue_free()
	await _frames(2)
	assert(not get_tree().paused)
	print("ALL TESTS OK")
	get_tree().quit()
