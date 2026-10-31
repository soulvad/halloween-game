extends Node
## Screenshots of every look (scripts/look.gd) from fixed viewpoints → docs/looks/<look>_<view>.jpg.
## Needs a window (not --headless): Godot_v4.7.2-stable_win64.exe --path . --resolution 1280x720 res://tests/look_capture.tscn

const Look = preload("res://scripts/look.gd")
const OUT := "res://docs/looks/"
const VIEWS := {  ## name: [eye, target]
	"entrance": [Vector3(0, 1.6, 11), Vector3(0, 1.2, 4)],
	"camp": [Vector3(4.5, 1.7, 8.5), Vector3(7.5, 0.6, 5.5)],
	"mirror": [Vector3(5.5, 1.6, -2.6), Vector3(9.35, 1.2, -2.6)],
	"corridor": [Vector3(-10, 1.6, -5.9), Vector3(10, 1.2, -5.9)],
	"rubble": [Vector3(11.2, 1.6, -10.9), Vector3(14.75, 1.0, -10.9)],
	"room": [Vector3(18, 1.7, -8.2), Vector3(22.5, 0.8, -11.5)],
}


func _ready() -> void:
	GameState.intro_seen = true
	var g = load("res://scenes/game.tscn").instantiate()
	g.comics_enabled = false
	add_child(g)
	g.get_node("HUD").visible = false
	var cam := Camera3D.new()
	cam.fov = 75
	g.add_child(cam)
	cam.current = true
	await _frames(30)
	for i in Look.LOOKS.size():
		g.get_node("Look").apply(i)
		for v in VIEWS:
			cam.look_at_from_position(VIEWS[v][0], VIEWS[v][1])
			await _frames(25)  # volumetric fog / SSAO settle over a few frames
			get_viewport().get_texture().get_image().save_jpg(ProjectSettings.globalize_path(OUT + "%d_%s.jpg" % [i, v]), 0.85)
	print("LOOKS CAPTURED")
	get_tree().quit()


func _frames(n: int) -> void:
	for _i in n:
		await get_tree().process_frame
