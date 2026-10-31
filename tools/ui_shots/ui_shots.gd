extends Node

const SETTLE_FRAMES := 8

var _out := "user://ui_shots/"


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		_out = args[0].trim_suffix("/") + "/"
	DirAccess.make_dir_recursive_absolute(_out)
	await _menu()
	await _game()
	get_tree().quit()


func _menu() -> void:
	var menu: Node = load("res://scenes/main_menu.tscn").instantiate()
	add_child(menu)
	await _shot("menu")
	menu.free()


func _game() -> void:
	GameState.intro_seen = true
	var g: Node = load("res://scenes/game.tscn").instantiate()
	g.set("comics_enabled", false)
	add_child(g)
	await get_tree().create_timer(1.0).timeout
	GameState.remember(1)
	GameState.say("Олена", "Ви це чули? Звідки цей звук?..", Color("8BEA4E"))
	await get_tree().create_timer(0.6).timeout
	await _shot("hud")
	var hud: Node = g.get_node("HUD")
	hud.toggle_map()
	await _shot("map")
	hud.toggle_map()
	hud.toggle_book()
	await _shot("book")
	hud.toggle_book()
	hud.open_pause()
	await _shot("pause")
	hud.resume()
	get_tree().paused = false
	g.set("comics_enabled", true)
	g.comic("prologue")
	await get_tree().create_timer(1.5, true, false, true).timeout
	await _shot("comic")
	for c in g.get_children():
		if c.has_signal("finished") and c != hud:
			c.free()
	get_tree().paused = false
	GameState.finish(true)
	await get_tree().create_timer(1.0, true, false, true).timeout
	for c in g.get_children():
		if c.has_signal("finished") and c != hud and c.name != "Player":
			c.free()
	get_tree().paused = false
	await get_tree().create_timer(2.0, true, false, true).timeout
	await _shot("end")


func _shot(shot_name: String) -> void:
	for i in SETTLE_FRAMES:
		await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(_out + shot_name + ".png")
