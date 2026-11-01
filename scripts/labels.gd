extends CanvasLayer
## World labels drawn flat over the comic look: the ink pass (look.gd, layer -2) posterizes and outlines whatever the
## 3D camera renders, which turned Label3D text into mush. Every Label3D in the group "world_label" stays in the world
## for its logic (text, visible, pixel_size, modulate), invisible (transparency 1), and is drawn here at its screen
## spot and size, only from the first-person camera, within its visibility range and not behind a wall.

const UI = preload("res://scripts/ui.gd")
const WALLS := 1 | 2 | 4  ## collision layers 1–3: rock, inner walls, furniture hide labels behind them
const OUTLINE := 2.0  ## × the label's own outline: a heavy ink rim so the text reads on any wall
const SHADOW := Color(0, 0, 0, 0.5)  ## a wider dark halo behind the rim

var _canvas := Control.new()


func _ready() -> void:
	layer = -1  # above the ink pass, under the HUD
	_canvas.set_anchors_preset(Control.PRESET_FULL_RECT)
	_canvas.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_canvas.draw.connect(_draw_labels)
	add_child(_canvas)


func _process(_delta: float) -> void:
	_canvas.queue_redraw()


func _draw_labels() -> void:
	var cam := get_viewport().get_camera_3d()
	if cam == null or GameState.player == null or cam != GameState.player.get("camera"):
		return  # the guide and the time-lapse cut labels out
	var space := cam.get_world_3d().direct_space_state
	var vp_h := get_viewport().get_visible_rect().size.y
	var per_m := vp_h / (2.0 * tan(deg_to_rad(cam.fov) / 2.0))  # screen px per metre at 1 m
	for l: Label3D in get_tree().get_nodes_in_group("world_label"):
		if not l.is_visible_in_tree() or l.text == "" or cam.is_position_behind(l.global_position):
			continue
		var d := cam.global_position.distance_to(l.global_position)
		if l.visibility_range_end > 0.0 and d > l.visibility_range_end:
			continue
		var q := PhysicsRayQueryParameters3D.create(cam.global_position, l.global_position, WALLS)
		if not space.intersect_ray(q).is_empty():
			continue
		var k := l.pixel_size * l.global_transform.basis.get_scale().y * per_m / (1.0 if l.fixed_size else d)
		var size := maxi(1, roundi(l.font_size * k))
		var font: Font = l.font if l.font else UI.font()
		var at := cam.unproject_position(l.global_position)
		var w := font.get_string_size(l.text, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
		var pos := at + Vector2(-w / 2.0, font.get_ascent(size) / 2.0 - font.get_descent(size) / 2.0)
		var a := l.modulate.a
		if l.outline_size > 0:
			var rim := maxi(2, roundi(l.outline_size * k * OUTLINE))
			_canvas.draw_string_outline(font, pos, l.text, HORIZONTAL_ALIGNMENT_LEFT, -1, size,
				rim * 3, Color(SHADOW, SHADOW.a * a))
			_canvas.draw_string_outline(font, pos, l.text, HORIZONTAL_ALIGNMENT_LEFT, -1, size,
				rim, Color(Color.BLACK, a))
		_canvas.draw_string(font, pos, l.text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, l.modulate)
