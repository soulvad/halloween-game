extends Node3D
## Framed portraits on the room walls, pure decoration: no collision, not in the navmesh. Files: art/paintings/.
## One of them is a looped video (Ogg Theora) whose sound is heard only right next to it; the video stops decoding when
## the eye is too far to see it, and pauses with the tree during comics and menus. Added by game.gd.

const Wall = preload("res://scripts/wall.gd")
const Fx = preload("res://scripts/fx.gd")
const DIR := "res://art/paintings/%s"
const E := 90.0  ## on a wall facing +X
const W := -90.0  ## facing -X
const S := 0.0  ## facing +Z
const N := 180.0  ## facing -Z

## file, the point on the wall surface at the picture's centre, the way the wall faces, picture height (m)
const PICTURES := [
	["shevchenko.jpg", Vector3(-2.875, 1.65, -10.5), S, 0.95],  # servants' bedroom, across from its door
	["bandera.jpg", Vector3(-8.0, 1.65, 7.125), E, 0.95],  # room by the entrance, across from its door
	["franko_mask.png", Vector3(5.0, 1.55, 3.75), N, 0.36],  # kitchen, on the way to memory 3
]
const VIDEO := ["franko.ogv", Vector3(10.0, 1.65, 7.125), W, 0.95]  ## archaeologists' camp, across from its door
const VIDEO_ASPECT := 704.0 / 456.0  ## the frame isn't known until the first one is decoded
const HEAR_RANGE := 3.0  ## m, the sound is gone from here on
const PLAY_RANGE := 14.0  ## m, the video is paused beyond this
const FRAME_WIDTH := 0.06
const FRAME_DEPTH := 0.05
const FRAME_COLOR := Color(0.5, 0.31, 0.15)
const BOARD_COLOR := Color(0.05, 0.04, 0.04)
const GLOW := 0.3  ## the rooms are dark and candles go out: a picture stays readable

var _video: VideoStreamPlayer
var _screen: MeshInstance3D


func _ready() -> void:
	for e in PICTURES:
		var tex: Texture2D = load(DIR % e[0])
		var canvas := _hang(e[1], e[2], Vector2(e[3] * tex.get_width() / tex.get_height(), e[3]))
		var mat: StandardMaterial3D = canvas.mesh.material
		mat.albedo_texture = tex
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR  # the mask's rounded corners
		mat.emission_enabled = true
		mat.emission = Color.BLACK
		mat.emission_texture = tex
		mat.emission_energy_multiplier = GLOW
	_screen = _hang(VIDEO[1], VIDEO[2], Vector2(VIDEO[3] * VIDEO_ASPECT, VIDEO[3]))
	_screen.mesh.material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_screen.mesh.material.albedo_color = Color(0.8, 0.8, 0.8)  # a lit screen, but not glaring in the dark
	_video = VideoStreamPlayer.new()
	_video.visible = false  # only feeds the screen's texture, never draws on the 2D canvas
	_video.stream = load(DIR % VIDEO[0])
	_video.loop = true
	_video.volume_db = linear_to_db(0.0)
	add_child(_video)
	_video.play()


## Cubic falloff: full next to the painting, nothing from HEAR_RANGE on.
static func gain(distance: float) -> float:
	return pow(clampf(1.0 - distance / HEAR_RANGE, 0.0, 1.0), 3.0)


func _process(_delta: float) -> void:
	var eye := get_viewport().get_camera_3d()
	var d := eye.global_position.distance_to(_screen.global_position) if eye else INF
	_video.paused = d > PLAY_RANGE
	_video.volume_db = linear_to_db(gain(d)) + Fx.MIX_DB  # gain 0 → -inf dB → truly silent
	var mat: StandardMaterial3D = _screen.mesh.material
	var tex := _video.get_video_texture()
	if mat.albedo_texture != tex:
		mat.albedo_texture = tex


## A dark board in a wooden frame with its back on the wall surface; returns the canvas, its size is what shows.
func _hang(at: Vector3, turn_deg: float, canvas_size: Vector2) -> MeshInstance3D:
	var holder := Node3D.new()
	holder.position = at
	holder.rotation.y = deg_to_rad(turn_deg)
	add_child(holder)
	var outer := canvas_size + Vector2.ONE * FRAME_WIDTH * 2
	_box(holder, Vector3(outer.x, outer.y, 0.02), BOARD_COLOR, Vector3(0, 0, 0.01))
	for side: float in [-1.0, 1.0]:
		var off := Vector2(canvas_size.x + FRAME_WIDTH, canvas_size.y + FRAME_WIDTH) / 2 * side
		_box(holder, Vector3(outer.x, FRAME_WIDTH, FRAME_DEPTH), FRAME_COLOR, Vector3(0, off.y, FRAME_DEPTH / 2))
		_box(holder, Vector3(FRAME_WIDTH, canvas_size.y, FRAME_DEPTH), FRAME_COLOR, Vector3(off.x, 0, FRAME_DEPTH / 2))
	var quad := QuadMesh.new()
	quad.size = canvas_size
	quad.material = StandardMaterial3D.new()
	var canvas := MeshInstance3D.new()
	canvas.mesh = quad
	canvas.position.z = 0.025
	canvas.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	holder.add_child(canvas)
	holder.set_meta("size", outer)
	return canvas


func _box(parent: Node3D, size: Vector3, color: Color, at: Vector3) -> void:
	var m := Wall.box(size, color)
	m.position = at
	m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(m)
