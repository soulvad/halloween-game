extends Node
## Windowed only: every candle through the ghost's own eyes, HUD and all, saved to argv[0] dir as candle_<name>.png.

const OFF := 1.1  ## m, how far off it hovers


func _ready() -> void:
	var dir: String = OS.get_cmdline_user_args()[0] if OS.get_cmdline_user_args().size() > 0 else "user://"
	GameState.intro_seen = true
	var g = load("res://scenes/game.tscn").instantiate()
	g.comics_enabled = false
	add_child(g)
	var p = g.get_node("Player")
	for i in 5:
		await get_tree().physics_frame
	GameState.gain("breath")
	await get_tree().create_timer(6.0).timeout  # the new power's card and thought pass
	for c in get_tree().get_nodes_in_group("candle"):
		var side := _side(g, c)
		p.global_position = c.global_position + side * OFF
		p.global_position.y = 0
		var look: Vector3 = c.global_position - (p.global_position + Vector3(0, p.EYE, 0))
		p.rotation.y = atan2(-look.x, -look.z)
		p.head.rotation.x = atan2(look.y, Vector2(look.x, look.z).length())
		for i in 25:
			await get_tree().process_frame
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png(dir.path_join("candle_%s.png" % c.name))
	print("CANDLE SHOTS OK")
	get_tree().quit()


## The first side that leaves the camera clear of the walls.
func _side(g: Node, c: Node3D) -> Vector3:
	for a in 16:
		var dir := Vector3.RIGHT.rotated(Vector3.UP, a * PI / 8)
		var from: Vector3 = c.global_position + dir * OFF
		if g.get_meta("rooms").values().any(func(r): return r.grow(-0.4).has_point(Vector2(from.x, from.z))):
			return dir
	return Vector3.FORWARD
