extends Node

func _ready() -> void:
	var menu = load("res://scenes/main_menu.tscn").instantiate()
	add_child(menu)
	assert(menu.get_node("Box/Play") is Button)
	menu.queue_free()

	var g = load("res://scenes/game.tscn").instantiate()
	add_child(g)
	var p = g.get_node("Player")
	var st = func(n): return g.find_child(n, true, false)
	await get_tree().physics_frame

	# level 1: invisible, only outer/sealed walls block, hunters absent
	assert(GameState.level == 1 and p.collision_mask == 1)
	assert(not st.call("Hunter1").visible)
	st.call("Candle").interact(p)
	st.call("Candle").interact(p)  # cooldown: no second charge
	assert(GameState.charge == 1.0)
	st.call("Portrait").interact(p)  # needs level 2
	assert(GameState.charge == 1.0)
	for n in ["Clock", "Mirror", "Ouija"]: st.call(n).interact(p)
	assert(GameState.charge == 4.0)

	# altar: level 2, walls of solid_from 2 now block, hunters appear
	st.call("Altar").interact(p)
	assert(GameState.level == 2 and GameState.charge == 0.0 and p.collision_mask == 3)
	assert(st.call("Hunter1").visible and not st.call("Hunter2").visible)

	# a good person who notices the ghost believes once (+2)
	p.global_position = st.call("Neighbor").global_position + Vector3(1, 0, 0)
	for i in 3: await get_tree().physics_frame
	assert(st.call("Neighbor").believes and GameState.charge == 2.0)
	for i in 3: await get_tree().physics_frame
	assert(GameState.charge == 2.0)

	# door + memento
	var door = st.call("BedroomDoor")
	door.interact(p)
	assert(door.used and door.collision_layer == 8)
	st.call("Photo").interact(p)
	assert(p.held == "Фото")

	# fade: costs charge, nobody sees, inner walls pass
	GameState.charge = 3.0
	assert(GameState.fade())
	assert(GameState.is_fading() and p.collision_mask == 1 and not GameState.visible_to(1))
	assert(GameState.charge == 1.0)
	GameState.fade_left = 0.01
	await get_tree().process_frame
	await get_tree().process_frame
	assert(not GameState.is_fading() and p.collision_mask == 3)

	# hunter touch drains charge, empty charge drops a level
	GameState.charge = 5.0
	var hunter = st.call("Hunter1")
	p.global_position = hunter.global_position + Vector3(0.5, 0, 0)
	for i in 5: await get_tree().physics_frame
	assert(GameState.charge < 5.0)
	GameState.drain(100)
	assert(GameState.level == 1 and GameState.is_fading() and not hunter.visible)

	# goal: Mom hears only at level 3, memento in hands -> let go
	var mom = st.call("Mom")
	mom.interact(p)
	assert(GameState.phase == GameState.Phase.PLAY)
	GameState.set_level(3)
	assert(p.collision_mask == 7 or GameState.is_fading())
	g._update_hud()
	print("HUD: ", g.get_node("HUD/InfoLabel").text.replace("\n", " | "))
	mom.interact(p)
	assert(GameState.phase == GameState.Phase.END and GameState.won)
	assert(g.get_node("HUD/MenuButton").visible)

	# midnight = loss
	GameState.reset()
	g.time_left = 0.0
	await get_tree().process_frame
	await get_tree().process_frame
	assert(GameState.phase == GameState.Phase.END and not GameState.won)
	print("ALL TESTS OK")
	get_tree().quit()
