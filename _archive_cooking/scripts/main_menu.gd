extends Control


func _ready() -> void:
	$Box/Play.pressed.connect(get_tree().change_scene_to_file.bind("res://scenes/game.tscn"))
	$Box/Quit.pressed.connect(get_tree().quit)
	$Box/Play.grab_focus()
