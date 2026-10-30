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
	var rig = p.get_node("Rig")
	assert(is_equal_approx(rig.sample(rig.HIP, 1.0), rig.HIP[0]))  # curve wraps without a seam
	rig.weight = 1.0
	rig.phase = 0.0
	rig._pose()
	assert(is_equal_approx(rig.get_node("pelvis/l_hip").rotation.x, -rig.HIP[0]))  # left heel strike: leg forward
	assert(rig.get_node("pelvis").position.y > 0.8 and rig.get_node("pelvis").position.y < 1.0)
	rig.weight = 0.0
	for i in 2: st.call("ShelfTomato").interact(p)
	for i in 2: st.call("StandLettuce").interact(p)
	assert(GameState.cart == {"tomato": 2, "lettuce": 2})
	assert(p.get_node("Cart/Items").get_child_count() == 4)
	g.time_left = 0.0
	await get_tree().process_frame
	await get_tree().process_frame
	assert(GameState.phase == GameState.Phase.BREAK)
	await get_tree().create_timer(GameState.BREAK_TIME + 0.2).timeout
	assert(GameState.phase == GameState.Phase.COOK)
	assert(g.get_node_or_null("KitchenDoor") == null)

	var board = st.call("Board1")
	for item in ["tomato", "lettuce"]:
		st.call("ShelfTomato" if item == "tomato" else "StandLettuce").interact(p)
		assert(p.held == item)
		board.interact(p)  # put
		for i in 5: board.interact(p)  # chop
		assert(board.content == item + "_chopped")
		board.interact(p)  # take
		if item == "tomato":
			st.call("Counter1").interact(p)  # leave chopped tomato on the counter
	# plate route: hands hold lettuce_chopped, counter has tomato_chopped
	assert(p.held == "lettuce_chopped")
	st.call("Counter2").interact(p)  # drop lettuce on Counter2
	st.call("Plates").interact(p)
	assert(p.held == "plate")
	st.call("Counter1").interact(p)
	st.call("Counter2").interact(p)
	assert(p.plate.size() == 2)
	GameState.orders = ["Овочевий салат"]
	st.call("Serve").interact(p)
	assert(GameState.score == 20 and p.held == "")

	var stove = st.call("Stove1")
	stove.content = "meat"; stove.progress = 0
	await get_tree().create_timer(4.3).timeout
	assert(stove.content == "meat_cooked")
	g._update_hud()
	print("HUD: ", g.get_node("HUD/OrdersLabel").text.replace("\n", " | "))
	g.time_left = 0.0
	await get_tree().process_frame
	await get_tree().process_frame
	assert(GameState.phase == GameState.Phase.END)
	print("ALL TESTS OK")
	get_tree().quit()
