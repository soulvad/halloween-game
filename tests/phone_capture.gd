extends Node
## Windowed only: the phone on the camp table, saved to argv[0] dir as phone_<view>.png: from about 2 m through the
## ghost's eyes, from close by (the close-up), straight down on it, and two low shots along the table top (floating, clipping).


func _ready() -> void:
	var dir: String = OS.get_cmdline_user_args()[0] if OS.get_cmdline_user_args().size() > 0 else "user://"
	GameState.intro_seen = true
	var g = load("res://scenes/game.tscn").instantiate()
	g.comics_enabled = false
	add_child(g)
	var p = g.get_node("Player")
	for i in 5:
		await get_tree().physics_frame
	var phone: Node3D = g.get_node("Eggs")._phone
	var at := phone.global_position
	var down: Vector3 = phone.global_basis.z  # the picture's bottom edge, the room side
	var across: Vector3 = phone.global_basis.x
	await _eyes(p, at + down * 2.0, at, dir, "2m")
	await _eyes(p, at + down * 0.55, at, dir, "closeup")
	p.global_position = at + down * 1.0  # near enough to keep the screen awake
	p.global_position.y = 0
	var cam := Camera3D.new()
	cam.near = 0.005
	cam.fov = 40
	g.add_child(cam)
	await _shot(cam, at + Vector3(0, 0.32, 0) + down * 0.001, at, dir, "top")
	await _shot(cam, at + down * 0.35 + Vector3(0, 0.012, 0), at + Vector3(0, 0.004, 0), dir, "low_end")
	await _shot(cam, at + across * 0.32 + down * 0.05 + Vector3(0, 0.01, 0), at + Vector3(0, 0.004, 0), dir, "low_side")
	print("PHONE SHOTS OK")
	get_tree().quit()


func _eyes(p, from: Vector3, target: Vector3, dir: String, view: String) -> void:
	p.global_position = Vector3(from.x, 0, from.z)
	var look: Vector3 = target - (p.global_position + Vector3(0, p.EYE, 0))
	p.rotation.y = atan2(-look.x, -look.z)
	p.head.rotation.x = atan2(look.y, Vector2(look.x, look.z).length())
	p.camera.make_current()
	await _save(dir, view, 60)


func _shot(cam: Camera3D, from: Vector3, target: Vector3, dir: String, view: String) -> void:
	cam.global_position = from
	cam.look_at(target, Vector3.FORWARD if from.distance_to(target) < 0.01 or absf((target - from).normalized().y) > 0.99 else Vector3.UP)
	cam.make_current()
	await _save(dir, view, 30)


func _save(dir: String, view: String, frames: int) -> void:
	for i in frames:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(dir.path_join("phone_%s.png" % view))
