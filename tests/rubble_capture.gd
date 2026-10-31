extends Node
## Windowed only: screenshots of the collapsed wall (Level/Rubble) from the corridor, saved to user:// or argv[0] dir.

const SHOTS := [[Vector3(12.2, 1.6, -10.4), Vector3(14.75, 1.1, -10.875)], [Vector3(13.2, 2.4, -10.2), Vector3(14.6, 0.8, -11.1)]]


func _ready() -> void:
	var dir: String = OS.get_cmdline_user_args()[0] if OS.get_cmdline_user_args().size() > 0 else "user://"
	GameState.intro_seen = true
	var g = load("res://scenes/game.tscn").instantiate()
	g.comics_enabled = false
	add_child(g)
	g.get_node("HUD").visible = false
	var knock = g.find_child("Wall", true, false)  # KNOCK slab on the wall face, moves into your room in the rework
	if knock:
		knock.visible = false
	var cam := Camera3D.new()
	cam.fov = 70
	add_child(cam)
	for i in SHOTS.size():
		cam.look_at_from_position(SHOTS[i][0], SHOTS[i][1])
		cam.make_current()
		for f in 20:
			await get_tree().process_frame
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png(dir.path_join("rubble_%d.png" % i))
	print("RUBBLE SHOTS OK")
	get_tree().quit()
