extends Control
## Paint canvas: draws the core's image (3×3 tiles in tileable mode), zoom/pan, routes the mouse/pen to the active tool.

signal color_picked(color: Color)
signal color_used(color: Color)  ## a brush stroke or fill started with this color (recent colors)

const UI = preload("res://scripts/ui.gd")
enum Tool { BRUSH, INK, ERASER, FILL, PICKER }

var core  ## paint_core.gd
var tool := Tool.BRUSH
var color := UI.INK
var sizes := {Tool.BRUSH: 24.0, Tool.INK: 8.0, Tool.ERASER: 40.0}  ## diameter per tool, image px
var hardness := 0.7
var tolerance := 0.15
var zoom := 1.0
var offset := Vector2.ZERO
var tex: ImageTexture

var _checker: ImageTexture
var _version := -1
var _drawing := false
var _panning := false
var _hover := false


func _ready() -> void:
	clip_contents = true
	mouse_filter = MOUSE_FILTER_STOP
	mouse_default_cursor_shape = CURSOR_CROSS
	texture_repeat = TEXTURE_REPEAT_ENABLED
	var c := Image.create_empty(32, 32, false, Image.FORMAT_RGBA8)
	c.fill(Color("E9E4F2"))
	c.fill_rect(Rect2i(0, 0, 16, 16), Color.WHITE)
	c.fill_rect(Rect2i(16, 16, 16, 16), Color.WHITE)
	_checker = ImageTexture.create_from_image(c)
	mouse_entered.connect(func(): _hover = true)
	mouse_exited.connect(func():
		_hover = false
		queue_redraw())


## Texture upload once per frame, however many dabs landed.
func _process(_delta: float) -> void:
	if core == null or core.version == _version:
		return
	_version = core.version
	if tex and Vector2i(tex.get_size()) == core.img.get_size():
		tex.update(core.img)
	else:
		tex = ImageTexture.create_from_image(core.img)
	queue_redraw()


func fit() -> void:
	if core == null or size.x < 2.0:
		return
	var s := Vector2(core.img.get_size())
	_zoom_to(minf(size.x / s.x, size.y / s.y) * 0.9)
	offset = (size - s * zoom) * 0.5
	queue_redraw()


func _draw() -> void:
	if tex == null:
		return
	var s := Vector2(core.img.get_size()) * zoom
	var n := 1 if core.tileable else 0
	for j in range(-n, n + 1):
		for i in range(-n, n + 1):
			var r := Rect2(offset + Vector2(i, j) * s, s)
			draw_texture_rect(_checker, r, true)
			draw_texture_rect(tex, r, false)
	draw_rect(Rect2(offset - Vector2.ONE * 2, s + Vector2.ONE * 4), UI.GOLD if core.tileable else UI.INK, false, 4.0)
	if _hover and sizes.has(tool) and not _panning:
		var m := get_local_mouse_position()
		var rad := maxf(2.0, sizes[tool] * 0.5 * zoom)
		draw_arc(m, rad, 0, TAU, 48, UI.INK, 3.0, true)
		draw_arc(m, rad, 0, TAU, 48, UI.PAPER, 1.0, true)


func _gui_input(ev: InputEvent) -> void:
	if ev is InputEventMouseButton:
		var mb := ev as InputEventMouseButton
		if mb.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN]:
			if mb.pressed:
				var f := 1.15 if mb.button_index == MOUSE_BUTTON_WHEEL_UP else 1.0 / 1.15
				_zoom_at(mb.position, zoom * f)
		elif mb.button_index == MOUSE_BUTTON_MIDDLE:
			_panning = mb.pressed
		elif mb.button_index == MOUSE_BUTTON_LEFT:
			if mb.pressed and Input.is_physical_key_pressed(KEY_SPACE):
				_panning = true
			elif mb.pressed:
				_press(mb.position, mb.alt_pressed)
			elif _panning:
				_panning = false
			else:
				_release()
		accept_event()
	elif ev is InputEventMouseMotion:
		var mm := ev as InputEventMouseMotion
		if _panning:
			offset += mm.relative
		elif _drawing:
			# Mice report 0 pressure; a pen reports 0..1.
			core.stroke_to(_to_img(mm.position), mm.pressure if mm.pressure > 0.0 else 1.0)
		queue_redraw()
		accept_event()


func _press(p: Vector2, alt: bool) -> void:
	var ip := _to_img(p)
	if alt or tool == Tool.PICKER:
		color_picked.emit(core.pick(ip))
		return
	if tool == Tool.FILL:
		core.color = color
		core.fill(ip, tolerance)
		color_used.emit(color)
		return
	core.size = sizes[tool]
	core.hardness = 1.0 if tool == Tool.INK else hardness
	core.color = UI.INK if tool == Tool.INK else color
	core.erase = tool == Tool.ERASER
	core.lazy = 10.0 / zoom if tool == Tool.INK else 0.0
	core.begin_stroke(ip)
	_drawing = true
	if tool == Tool.BRUSH:
		color_used.emit(color)


func _release() -> void:
	if _drawing:
		core.end_stroke()
		_drawing = false


func _to_img(p: Vector2) -> Vector2:
	return (p - offset) / zoom


func _zoom_at(p: Vector2, z: float) -> void:
	var old := zoom
	_zoom_to(z)
	offset = p - (p - offset) * (zoom / old)
	queue_redraw()


func _zoom_to(z: float) -> void:
	zoom = clampf(z, 0.05, 40.0)
	texture_filter = TEXTURE_FILTER_NEAREST if zoom >= 2.0 else TEXTURE_FILTER_LINEAR
