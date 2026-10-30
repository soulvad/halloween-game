extends Node
## Headless self-check for the texture painter. Prints PAINTER OK, or FAIL lines and exits with code 1.
## engine/Godot_v4.7.2-stable_win64_console.exe --headless --path . res://tools/painter/painter_test.tscn

const Core = preload("res://tools/painter/paint_core.gd")
const RED := Color(1, 0, 0)
const BLUE := Color(0, 0, 1)

var _fails := 0


func _check(ok: bool, what: String) -> void:
	if not ok:
		_fails += 1
		printerr("FAIL: " + what)


func _px(c, x: int, y: int) -> Color:
	return c.img.get_pixel(x, y)


func _ready() -> void:
	var c := Core.new()
	c.new_image(64, Color.WHITE)
	c.color = RED
	c.size = 6
	c.hardness = 1.0
	c.begin_stroke(Vector2(-5, 32.5))
	c.stroke_to(Vector2(70, 32.5))  # one big jump: interpolation must close it
	c.end_stroke()
	var gap := false
	for x in 64:
		gap = gap or not _px(c, x, 32).is_equal_approx(RED)
	_check(not gap, "fast stroke leaves no gaps")
	_check(_px(c, 30, 10) == Color.WHITE, "stroke stays its size")

	c.color = BLUE
	c.fill(Vector2(10, 10), 0.1)
	_check(_px(c, 10, 10) == BLUE and _px(c, 60, 0) == BLUE, "fill covers the area above the line")
	_check(_px(c, 10, 50) == Color.WHITE, "fill stops at the line")
	_check(c.pick(Vector2(30.5, 32.5)).is_equal_approx(RED), "picker reads the stroke color")

	c.undo()
	_check(_px(c, 10, 10) == Color.WHITE and _px(c, 30, 32).is_equal_approx(RED), "undo removes the fill only")
	c.undo()
	_check(_px(c, 30, 32) == Color.WHITE, "undo removes the stroke")
	c.redo()
	_check(_px(c, 30, 32).is_equal_approx(RED), "redo brings the stroke back")

	c.erase = true
	c.size = 4
	c.begin_stroke(Vector2(10, 50))
	c.end_stroke()
	_check(_px(c, 10, 50).a < 0.01, "eraser clears alpha")
	c.erase = false

	c.tileable = true
	c.color = BLUE
	c.size = 8
	c.begin_stroke(Vector2(1, 5))
	c.end_stroke()
	_check(_px(c, 62, 5) == BLUE, "tileable dab wraps across the left edge")
	c.tileable = false

	for i in 45:
		c.begin_stroke(Vector2(i, 1))
		c.end_stroke()
	var n := 0
	while c.undo():
		n += 1
	_check(n >= 30, "undo depth >= 30 (got %d)" % n)

	_check(c.save_png("user://painter_test.png") == OK, "save PNG")
	var d := Core.new()
	_check(d.load_png("user://painter_test.png") == OK, "load PNG")
	_check(d.img.get_data() == c.img.get_data(), "PNG round trip keeps every pixel")

	var big := Core.new()
	big.new_image(1024, Color.WHITE)
	big.color = RED
	var t := Time.get_ticks_msec()
	big.fill(Vector2(5, 5), 0.1)
	print("fill 1024x1024: %d ms" % (Time.get_ticks_msec() - t))
	_check(_px(big, 1023, 1023) == RED, "full-canvas fill at 1024")

	var ui: Node = load("res://tools/painter/painter.tscn").instantiate()
	add_child(ui)
	await get_tree().process_frame
	await get_tree().process_frame
	_check(ui.view.tex != null and ui.view.tex.get_width() == 512, "painter UI builds and shows the canvas")
	var v = ui.view
	var mid: Vector2 = v.offset + Vector2(256, 256) * v.zoom
	var press := InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_LEFT
	press.pressed = true
	press.position = mid
	v._gui_input(press)
	var move := InputEventMouseMotion.new()
	move.position = mid + Vector2(40, 0)
	v._gui_input(move)
	var up := press.duplicate()
	up.pressed = false
	v._gui_input(up)
	_check(ui.core.modified and ui.core.img.get_pixel(256, 256) != ui.UI.PAPER, "mouse stroke on the canvas paints")
	ui.queue_free()
	await get_tree().process_frame

	if _fails == 0:
		print("PAINTER OK")
	get_tree().quit(1 if _fails else 0)
