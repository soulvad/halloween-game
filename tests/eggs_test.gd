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
	for m in bones._mesh.find_children("*", "MeshInstance3D", true, false):
		assert(m.layers == Eggs.LAYER_HIDDEN)

	# the skeleton and the cat have sealed rooms of their own, the cat's is the bigger one; no way in for people
	var rooms: Dictionary = g.get_meta("rooms")
	var bones_at := Vector2(bones.global_position.x, bones.global_position.z)
	var cat_at: Vector2 = Vector2(g.get_node("Stations/Pedestal").global_position.x, g.get_node("Stations/Pedestal").global_position.z)
	assert(rooms["BonesRoom"].has_point(bones_at) and rooms["CatRoom"].has_point(cat_at))
	assert(rooms["CatRoom"].get_area() > rooms["BonesRoom"].get_area())
	var map := g.get_world_3d().navigation_map as RID
	var entrance: Vector3 = g.get_node("Markers/Entrance").global_position
	assert(not g.get_node("Lanterns").in_dungeon(map, entrance, Vector3(cat_at.x, 0, cat_at.y)))
	assert(not g.get_node("Lanterns").in_dungeon(map, entrance, Vector3(bones_at.x + 0.5, 0, bones_at.y)))

	# cat: nothing until E on the pedestal (no text); it rises, waits, spins for the track's length, stays frozen
	var pedestal = g.get_node("Stations/Pedestal")
	p.global_position = pedestal.global_position + Vector3(1, -pedestal.global_position.y, 0)
	await _frames(3)
	assert(pedestal.can_use() and pedestal.title() == "" and not eggs._cat_body.visible and eggs.found.is_empty())
	pedestal.interact(p)
	await _frames(1)
	assert(eggs._cat_body.visible and not eggs._cat_sound.playing and eggs.cat_spin <= 0)
	assert(pedestal.shown)
	pedestal.cooldown = 0
	pedestal.interact(p)  # E while it rises: no second start
	assert(eggs.cat_wait > 0 and eggs.cat_wait <= Eggs.CAT_DELAY)
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
	# E again: it spins again, right away, and the egg is not counted twice
	pedestal.cooldown = 0
	assert(pedestal.can_use())
	pedestal.interact(p)
	await _until(func(): return eggs.cat_spin > 0, 1)
	assert(eggs._cat_sound.playing and eggs.found.count("cat") == 1)
	await _until(func(): return eggs.cat_spin <= 0, 12)

	# skeleton: E on the bones, it dances with music, then lies down and can do it again
	assert(bones.can_use() and bones.title() == "Купа кісток: вселитися")
	bones.interact(p)
	await _frames(1)
	assert("skeleton" in eggs.found and eggs._skeleton.visible and eggs._music.playing)
	assert(not bones.visible and bones.collision_layer == 0)
	var skel: Skeleton3D = eggs._skeleton.find_children("*", "Skeleton3D", true, false)[0]  # the rigged model, feet down
	var hand := skel.find_bone("HAND.L")
	assert(eggs._dance_anim != null and hand >= 0)
	var low: Vector3 = skel.get_bone_global_pose(hand).origin
	await _until(func(): return eggs.dancing < Eggs.DANCE_TIME - 0.4, 2)
	await _frames(2)
	assert(skel.get_bone_global_pose(hand).origin.distance_to(low) > 0.05)
	var head_y: float = (skel.global_transform * skel.get_bone_global_pose(skel.find_bone("HEAD")).origin).y
	assert(head_y > 1.2 and head_y < 2.0)
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
	assert(p.wall_depth() < 0 and not p.hollow)  # just rock
	p.global_position = Vector3(-11, 0, -2)
	await _frames(2)
	p.global_position = Vector3(-8, 0, 1)
	await _frames(2)
	assert(not eggs._room.visible)
	p.global_position = Vector3(-8.7, 0, 1)
	await _frames(2)
	assert(eggs._room.visible and eggs._rat.visible and "turtles" in eggs.found and eggs._turtles.size() == 4)
	assert(p.hollow)  # dug in the rock: no veil, no drift
	p.global_position = Vector3(-11, 0, -2)
	await _frames(2)
	assert(not eggs._room.visible)

	# phone: lies flat on the real top of the table, inside its edges, clear of the plan, screen in the picture's proportions
	var phone = eggs._phone
	var table = g.get_node("Level/TableR4R")
	var table_box := AABB()
	for m: MeshInstance3D in table.find_children("*", "MeshInstance3D", true, false):
		table_box = m.global_transform * m.get_aabb()
	assert(absf(phone.global_position.y - table_box.end.y) < 0.005)
	assert(phone.rotation.x == 0.0 and phone.rotation.z == 0.0)
	var reach: float = Vector2(phone.BODY.x, phone.BODY.z).length() / 2.0
	var at := Vector2(phone.global_position.x, phone.global_position.z)
	assert(Rect2(table_box.position.x, table_box.position.z, table_box.size.x, table_box.size.z).grow(-reach).has_point(at))
	var plan = g.get_node("Stations/Plan")
	assert(absf(at.x - plan.global_position.x) > plan.size.x / 2.0 + reach)
	var screen: Vector2 = phone.screen_size()
	assert(is_equal_approx(screen.x / screen.y, 277.0 / 600.0))
	assert(screen.x < phone.BODY.x and screen.y < phone.BODY.z)
	assert(phone.get_node("Screen").layers == Eggs.LAYER_HIDDEN)

	# the screen wakes when the ghost is close and sleeps again; a close look brings up the close-up, looking away drops it
	phone.level = phone.LEVEL_ASLEEP
	eggs.phone_at = INF
	p.global_position = phone.global_position + Vector3(phone.WAKE_NEAR + 2, 0, 0)
	await _frames(3)
	assert(is_equal_approx(phone.level, phone.LEVEL_ASLEEP) and phone.closeup == 0.0)
	p.global_position = Vector3(phone.global_position.x, 0, phone.global_position.z + 0.5)
	p.rotation.y = 0.0  # facing -Z, at the phone
	p.head.rotation.x = -atan2(p.head.position.y - phone.global_position.y, 0.5)
	await _until(func(): return phone.closeup >= 1.0, 3)
	assert(is_equal_approx(phone.level, phone.LEVEL_AWAKE) and phone.closeup == 1.0 and phone._overlay.visible)
	p.head.rotation.x = 0.5
	await _until(func(): return phone.closeup <= 0.0, 3)
	assert(not phone._overlay.visible)
	p.head.rotation.x = 0.0

	# the alert: not while far away, once when near after the time has come; it plays on the phone, pulses, then ends
	eggs.phone_at = 0.0
	p.global_position = phone.global_position + Vector3(Eggs.PHONE_NEAR + 5, 0, 0)
	await _frames(2)
	assert("phone" not in eggs.found and phone.alert_left == 0.0)
	p.global_position = phone.global_position + Vector3(2, 0, 0)
	await _frames(2)
	assert("phone" in eggs.found and eggs.found.size() == Eggs.EGGS.size())
	assert(phone.alert_left > 0.0)
	assert(not phone.find_children("*", "AudioStreamPlayer3D", true, false).is_empty())
	await _until(func(): return phone._light.light_energy > 0.1, 2)
	phone.alert_left = 0.01
	await _frames(3)
	assert(phone.alert_left == 0.0 and phone._light.light_energy == 0.0)

	# no effect on the story
	assert(GameState.stage == stage and GameState.haunts == 0 and GameState.memories.is_empty())
	g.queue_free()
	await _frames(2)
	print("EGGS OK")
	get_tree().quit()
