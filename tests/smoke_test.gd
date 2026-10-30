extends Node

func _frames(n: int) -> void:
	for i in n: await get_tree().physics_frame


func _ready() -> void:
	var menu = load("res://scenes/main_menu.tscn").instantiate()
	add_child(menu)
	assert(menu.get_node("Box/Play") is Button)
	menu.queue_free()

	var g = load("res://scenes/game.tscn").instantiate()
	add_child(g)
	var p = g.get_node("Player")
	var st = func(n): return g.find_child(n, true, false)
	var spawn: Vector3 = p.global_position
	await _frames(1)

	# level 1: invisible, only outer walls block, hunters absent, priest walks
	assert(GameState.level == 1 and p.collision_mask == 1)
	assert(not st.call("HunterKitchen").visible and st.call("Priest").visible)
	st.call("Mirror").interact(p)
	st.call("Mirror").interact(p)  # cooldown: no second charge
	assert(GameState.charge == 1.0)
	st.call("CrystalBall").interact(p)  # needs level 2
	st.call("Letter").interact(p)  # too weak to carry
	assert(GameState.charge == 1.0 and p.held == "")
	for n in ["Clock", "Ouija", "MusicBox"]: st.call(n).interact(p)
	assert(GameState.charge == 4.0)

	# altar needs the threshold but spends nothing; the level then burns charge
	st.call("Altar").interact(p)
	assert(GameState.level == 2 and GameState.charge == 4.0 and p.collision_mask == 3)
	assert(st.call("HunterKitchen").visible and not st.call("HunterHall").visible)
	st.call("Altar").interact(p)  # 4 < 8: no level 3 yet
	assert(GameState.level == 2)
	await _frames(10)
	assert(GameState.charge < 4.0)

	# memories go to Mom one by one; she can't be let go before level 3
	var mom = st.call("Mom")
	for n in ["Letter", "Ring", "Photo"]:
		st.call(n).interact(p)
		assert(p.held != "")
		mom.interact(p)
		assert(p.held == "")
	assert(GameState.memories == 3)
	mom.interact(p)
	assert(GameState.phase == GameState.Phase.PLAY)

	# blow out a holy candle for charge
	var c1 = st.call("Candle1")
	GameState.charge = 5.0
	c1.interact(p)
	assert(not c1.lit and GameState.charge == 4.0)

	# holy ground burns: empty charge drops a level, then a grace period
	p.global_position = st.call("Candle2").global_position
	GameState.charge = 0.05
	await _frames(5)
	assert(GameState.level == 1 and GameState.grace > 0)
	# at level 1 an empty charge banishes back to the spawn
	GameState.grace = 0.0
	GameState.charge = 0.05
	await _frames(5)
	assert(p.global_position.distance_to(spawn) < 0.1)

	# upkeep alone drops the level when charge runs out
	GameState.grace = 0.0
	GameState.set_level(2)
	GameState.charge = 0.001
	await _frames(3)
	assert(GameState.level == 1)

	# win: level 3 + all memories
	GameState.charge = 9.0
	assert(GameState.level_up() and GameState.level_up() and GameState.level == 3)
	g._update_hud()
	print("HUD: ", g.get_node("HUD/InfoLabel").text.replace("\n", " | "))
	mom.interact(p)
	assert(GameState.phase == GameState.Phase.END and GameState.won)
	g.queue_free()
	await _frames(2)

	# loss: the priest walks his route and lights every candle (fast-forwarded)
	g = load("res://scenes/game.tscn").instantiate()
	add_child(g)
	g.get_node("Player").set_physics_process(false)
	Engine.time_scale = 30.0
	Engine.max_physics_steps_per_frame = 64
	var t0 := Time.get_ticks_msec()
	var game_t := 0.0
	while GameState.phase == GameState.Phase.PLAY and Time.get_ticks_msec() - t0 < 60000:
		await get_tree().physics_frame
		game_t += get_physics_process_delta_time()
	Engine.time_scale = 1.0
	var lit := get_tree().get_nodes_in_group("holy_candle").filter(func(c): return c.lit).size()
	print("Priest lit %d candles, round lasted ~%d s, priest at %s" % [lit, game_t, g.find_child("Priest", true, false).global_position])
	assert(GameState.phase == GameState.Phase.END and not GameState.won)
	print("ALL TESTS OK")
	get_tree().quit()
