extends Node
## Headless: must print EGGS OK; if it hangs, an assert failed.

const Eggs = preload("res://scripts/easter_eggs.gd")


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
	GameState.intro_seen = true
	var g = load("res://scenes/game.tscn").instantiate()
	g.comics_enabled = false
	add_child(g)
	await _frames(2)
	var eggs = g.get_node("Eggs")
	var p = g.get_node("Player")
	var bones = g.get_node("Stations/Bones")
	var stage: int = GameState.stage
	assert(eggs.found.is_empty())
	assert(not eggs._music.playing and not eggs._cat_sound.playing)

	# nothing of it shows on the minimap / tour (they cull layer 2)
	for m in eggs.find_children("*", "MeshInstance3D", true, false):
		assert(m.layers == Eggs.LAYER_HIDDEN)
	assert(bones._mesh.layers == Eggs.LAYER_HIDDEN)

	# cat: nothing until E on the pedestal (no text); it rises, waits, spins for the track's length, stays frozen
	var pedestal = g.get_node("Stations/Pedestal")
	p.global_position = pedestal.global_position + Vector3(1, -pedestal.global_position.y, 0)
	await _frames(3)
	assert(pedestal.can_use() and pedestal.title() == "" and not eggs._cat_body.visible and eggs.found.is_empty())
	pedestal.interact(p)
	await _frames(1)
	assert(eggs._cat_body.visible and not eggs._cat_sound.playing and eggs.cat_spin <= 0)
	assert(pedestal.collision_layer == 0 and pedestal._mesh.transparency == 0.0)
	await _until(func(): return eggs.cat_spin > 0, Eggs.CAT_DELAY + 1)
	assert("cat" in eggs.found and eggs._cat_sound.playing)
	var spun: float = eggs._cat_body.rotation.y
	await _frames(2)
	assert(eggs._cat_body.rotation.y != spun)
	await _until(func(): return eggs.cat_spin <= 0, 12)
	spun = eggs._cat_body.rotation.y
	await _frames(3)
	assert(eggs._cat_body.rotation.y == spun and eggs._cat_body.visible)
	assert(is_equal_approx(eggs._cat_body.position.y, Eggs.CAT_TOP))

	# skeleton: E on the bones, it dances with music, then lies down and can do it again
	assert(bones.can_use() and bones.title() == "Купа кісток: вселитися")
	bones.interact(p)
	await _frames(1)
	assert("skeleton" in eggs.found and eggs._skeleton.visible and eggs._music.playing)
	assert(not bones.visible and bones.collision_layer == 0)
	await _until(func(): return eggs.dancing <= 0, Eggs.DANCE_TIME + 2)
	assert(not eggs._skeleton.visible and not eggs._music.playing and bones.visible and bones.collision_layer == bones.LAYER_STATION)

	# rat: sits until the ghost comes close, runs to the next point; the last one is in the turtles' room
	p.global_position = Vector3(0, 0, 11)
	await _frames(3)
	assert(eggs.rat_i == 0)
	for i in Eggs.ROUTE.size() - 1:
		p.global_position = eggs._rat.global_position + Vector3(0, 0, 1)
		await _frames(2)
		assert(eggs.rat_i == i + 1)
		p.global_position = Vector3(0, 0, 11)  # step back, or it runs on without stopping
		await _until(func(): return not eggs._rat_running, 8)
		assert(eggs._rat.position.distance_to(Eggs.ROUTE[i + 1]) < 0.05)
	assert(Eggs.ROOM.has_point(Vector2(eggs._rat.position.x, eggs._rat.position.z)))
	await _frames(1)
	assert(not eggs._rat.visible)

	# the turtles' room: not there when the ghost comes through the rock, only through the wall with the hole
	p.global_position = Vector3(-11, 0, -2)
	await _frames(2)
	p.global_position = eggs._room_center
	await _frames(2)
	assert(not eggs._room.visible and "turtles" not in eggs.found)
	p.global_position = Vector3(-11, 0, -2)
	await _frames(2)
	p.global_position = Vector3(-8, 0, 1)
	await _frames(2)
	assert(not eggs._room.visible)
	p.global_position = Vector3(-8.7, 0, 1)
	await _frames(2)
	assert(eggs._room.visible and eggs._rat.visible and "turtles" in eggs.found and eggs._turtles.size() == 4)
	p.global_position = Vector3(-11, 0, -2)
	await _frames(2)
	assert(not eggs._room.visible)

	# phone: not while far away, once when near after the time has come
	eggs.phone_at = 0.0
	var taras = g.get_node("Visitors/Taras")
	p.global_position = taras.global_position + Vector3(Eggs.PHONE_NEAR + 5, 0, 0)
	await _frames(2)
	assert("phone" not in eggs.found)
	p.global_position = taras.global_position + Vector3(2, 0, 0)
	await _frames(2)
	assert("phone" in eggs.found and eggs.found.size() == Eggs.EGGS.size())

	# no effect on the story
	assert(GameState.stage == stage and GameState.haunts == 0 and GameState.memories.is_empty())
	g.queue_free()
	await _frames(2)
	print("EGGS OK")
	get_tree().quit()
