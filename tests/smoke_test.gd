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

	var g = load("res://scenes/game.tscn").instantiate()
	add_child(g)
	var p = g.get_node("Player")
	var hud = g.get_node("HUD")
	var st = func(n): return g.find_child(n, true, false)
	var olena = st.call("Olena")
	var taras = st.call("Taras")
	var priest = st.call("Priest")
	var spawn: Vector3 = p.global_position
	await _frames(2)

	# level 1: invisible shadow in its own room, the priest hasn't come yet
	assert(GameState.level == 1 and p.collision_mask == 1 and GameState.stage == GameState.Stage.HAUNT)
	assert(not priest.visible and olena.visible)
	st.call("Icon").interact(p)
	st.call("Icon").interact(p)  # cooldown: no second charge
	assert(GameState.charge == 1.0)
	for n in ["Toy", "Mirror", "Beads"]: st.call(n).interact(p)
	assert(GameState.charge == 4.0)

	# your bones = altar: the modal pauses, confirm needs the threshold but spends nothing
	st.call("Bones").interact(p)
	assert(hud._altar != null and get_tree().paused and GameState.level == 1)
	await _frames(1)
	hud._altar_confirm()
	assert(not get_tree().paused and GameState.level == 2 and GameState.charge == 4.0 and p.collision_mask == 3)

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

	# HAUNT: a noise costs charge, archaeologists in earshot get uneasy and go check it; far ones don't hear
	var bell = st.call("Bell")
	GameState.charge = 6.0
	bell.interact(p)  # archaeologists still at the entrance: too far
	assert(GameState.unease == 0.0 and GameState.charge == 5.0 and GameState.haunts == 1)
	bell.cooldown = 0.0
	olena.global_position = bell.global_position + Vector3(2, 0, 1)
	taras.global_position = bell.global_position + Vector3(3, 0, 1)
	bell.interact(p)
	assert(GameState.unease == 2.0 and olena._investigate > 0)
	# a sighting at level 2 scares them once per level
	p.global_position = olena.global_position + Vector3(1.5, 0, 0)
	await _frames(3)
	assert(GameState.unease == 6.0)
	await _frames(3)
	assert(GameState.unease == 6.0)

	# priest's holy aura: empty charge drops a level (grace), at level 1 you're banished to your bones
	GameState.unease = GameState.UNEASE_TO_CALL
	await _frames(2)
	assert(GameState.stage == GameState.Stage.PRIEST_COMING)
	g.priest_in = 0.01
	await _frames(3)
	assert(GameState.stage == GameState.Stage.LURE and priest.visible)
	p.global_position = priest.global_position
	GameState.charge = 0.05
	await _frames(3)
	assert(GameState.level == 1 and GameState.grace > 0)
	GameState.grace = 0.0
	GameState.charge = 0.05
	await _frames(3)
	assert(p.global_position.distance_to(spawn) < 0.1)
	# upkeep alone drops the level when charge runs out
	GameState.grace = 0.0
	GameState.set_level(2)
	GameState.charge = 0.001
	await _frames(3)
	assert(GameState.level == 1)

	# LURE: a knock behind the rubble pulls the group up the passage; they start digging
	GameState.charge = 9.0
	GameState.set_level(2)
	olena.global_position = Vector3(10.5, 0, -6)
	taras.global_position = Vector3(9.5, 0, -5.5)
	priest.global_position = Vector3(8, 0, -6)
	p.global_position = spawn
	st.call("Knock").interact(p)
	var t := await _until(func(): return GameState.stage == GameState.Stage.DIG, 30)
	print("Lured to the rubble in %.1f s" % t)
	assert(GameState.stage == GameState.Stage.DIG)
	t = await _until(func(): return GameState.stage == GameState.Stage.EVIDENCE, 30)
	print("Dug through in %.1f s" % t)
	assert(GameState.stage == GameState.Stage.EVIDENCE and g.get_node_or_null("Level/Rubble") == null)

	# EVIDENCE: shown only with an archaeologist close by; all three → ritual
	var ev := ["Shackles", "Tally", "Bowl"].map(func(n): return st.call(n))
	assert(not ev[0].can_use() or ev[0].witness())
	t = await _until(func(): return ev.all(func(e): return e.witness()), 40)
	print("Archaeologists in your room after %.1f s" % t)
	for e in ev:
		assert(e.can_use())
		e.interact(p)
		assert(e.shown and not e.can_use())
	assert(GameState.evidence == 3)
	await _frames(2)
	assert(GameState.stage == GameState.Stage.RITUAL)

	# RITUAL: the priest prays in the circle; then at level 3 hold E there; releasing starts over
	t = await _until(func(): return GameState.ritual >= 1.0, 60)
	print("Ritual done after %.1f s" % t)
	assert(GameState.ritual >= 1.0 and not GameState.release_ready())
	GameState.charge = 9.0
	GameState.set_level(3)
	assert(GameState.release_ready() and st.call("Circle").can_use())
	g._release(true, 1.0)
	g._release(false, 0.1)
	assert(g.hold == 0.0 and GameState.phase == GameState.Phase.PLAY)
	for i in 3: g._release(true, 1.0)
	assert(GameState.phase == GameState.Phase.END and GameState.won)
	await _frames(2)
	assert(hud._end != null)
	g.queue_free()
	await _frames(2)
	assert(not get_tree().paused)
	print("ALL TESTS OK")
	get_tree().quit()
