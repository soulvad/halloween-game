extends Control
## One comic page from scripts/comic_data.gd, drawn letterboxed inside this Control. No input handling.
## Usage: var p = ComicPage.new(); add_child(p); p.setup("memories"); p.set_panel_state("A", true); p.reveal("B")
## Panels start locked (dark + «?»); `show_locked = false` draws nothing for them instead (prologue).

const UI = preload("res://scripts/ui.gd")
const Data = preload("res://scripts/comic_data.gd")
const LOCKED := Color("0F0C14")
const PLACEHOLDER := Color("1A1622")
const REVEAL := 0.6
const TILT := [-3.5, 2.6, -1.6, 3.1, -2.4, 1.9]  ## sticker tilt per panel, degrees
const SHIFT := [Vector2(-3, 2), Vector2(2, -4), Vector2(4, 3), Vector2(-2, -3), Vector2(3, 4), Vector2(-4, 2)]  ## × 0.4% page height
const STICKER_SCALE := 0.93  ## a little smaller, so tilted stickers don't overlap

var page_id := ""
var stickers := false:  ## panels drawn as stuck-on stickers: tilted, shifted, paper rim, shadow, tape (the book)
	set(v):
		stickers = v
		queue_redraw()
var show_locked := true:
	set(v):
		show_locked = v
		queue_redraw()

var _shapes := {}  # letter -> Array[Vector2], normalized
var _notes := {}  # letter -> String
var _alpha := {}  # letter -> 0 (locked) .. 1 (shown)
var _art := {}  # letter -> Texture2D, only when the file exists
var _frame: Texture2D
var _fades: Array[Tween] = []  # running reveals: killed on a page turn, or they'd fade in the new page's same letter
var _aspect := 1.0


func _init() -> void:
	mouse_filter = MOUSE_FILTER_IGNORE
	resized.connect(queue_redraw)


func setup(id: String) -> void:
	page_id = id
	for t in _fades:
		t.kill()
	_fades.clear()
	var page: Dictionary = Data.PAGES.get(id, {"layout": "", "panels": {}})
	var layout: Dictionary = Data.LAYOUTS.get(page.layout, {"aspect": 1.0, "shapes": {}})
	_aspect = layout.aspect
	_shapes = layout.shapes
	_notes.clear()
	_alpha.clear()
	_art.clear()
	_frame = null
	for letter: String in page.panels:
		_notes[letter] = page.panels[letter].get("note", "")
		_alpha[letter] = 0.0
		var path := "res://art/comic/%s/%s.png" % [id, letter]
		if ResourceLoader.exists(path):
			_art[letter] = load(path)
	if ResourceLoader.exists("res://art/comic/%s/frame.png" % id):
		_frame = load("res://art/comic/%s/frame.png" % id)
	var img: Texture2D = _frame if _frame else _art.values().front() if not _art.is_empty() else null
	if img:
		_aspect = img.get_width() / float(img.get_height())
	queue_redraw()


func set_panel_state(letter: String, shown: bool) -> void:
	if _alpha.has(letter):
		_alpha[letter] = 1.0 if shown else 0.0
		queue_redraw()


## Fades the panel in over its locked look; returns the tween (null for an unknown letter).
func reveal(letter: String) -> Tween:
	if not _alpha.has(letter):
		return null
	_alpha[letter] = 0.0
	var t := create_tween()
	t.tween_method(_set_alpha.bind(letter), 0.0, 1.0, REVEAL)
	_fades.append(t)
	return t


func is_shown(letter: String) -> bool:
	return _alpha.get(letter, 0.0) >= 1.0


## The page area inside this Control (aspect kept, centered).
func page_rect() -> Rect2:
	var s := Vector2(size.y * _aspect, size.y)
	if s.x > size.x:
		s = Vector2(size.x, size.x / _aspect)
	return Rect2((size - s) / 2, s)


func _set_alpha(a: float, letter: String) -> void:
	_alpha[letter] = a
	queue_redraw()


func _draw() -> void:
	var r := page_rect()
	var font := UI.font("body", 700)
	var n := -1
	for letter: String in _alpha:
		n += 1
		var a: float = _alpha[letter]
		var pts := PackedVector2Array()
		for v: Vector2 in _shapes.get(letter, []):
			pts.append(r.position + v * r.size)
		if pts.size() < 3:
			continue
		var art_rect := r
		if stickers:
			var c := Vector2.ZERO
			for p in pts:
				c += p
			c /= pts.size()
			draw_set_transform(c + SHIFT[n % SHIFT.size()] * r.size.y * 0.004, deg_to_rad(TILT[n % TILT.size()]), Vector2.ONE * STICKER_SCALE)
			for k in pts.size():
				pts[k] -= c
			art_rect.position -= c
			_sticker_back(pts, a, r.size.y)
		if a < 1.0 and show_locked:
			draw_colored_polygon(pts, LOCKED)
			var c := Vector2.ZERO
			for p in pts:
				c += p
			c /= pts.size()
			var q := int(r.size.y * 0.07)
			draw_string(font, c + Vector2(-q, q * 0.35), "?", HORIZONTAL_ALIGNMENT_CENTER, q * 2, q, Color(UI.GREY, 0.18 * (1.0 - a)))
		if a > 0.0:
			if _art.has(letter):
				draw_texture_rect(_art[letter], art_rect, false, Color(1, 1, 1, a))
			else:
				draw_colored_polygon(pts, Color(PLACEHOLDER, a))
				var fs := maxi(8, int(r.size.y * 0.016))
				draw_multiline_string(font, pts[0] + Vector2(fs, fs * 2), _notes[letter], HORIZONTAL_ALIGNMENT_LEFT,
					pts[1].x - pts[0].x - fs * 2, fs, -1, Color(UI.GREY, 0.45 * a))
		if not _frame and (a > 0.0 or show_locked):
			var line := pts.duplicate()
			line.append(pts[0])
			draw_polyline(line, Color(UI.PAPER, a if not show_locked else 1.0), maxf(1.0, r.size.y * 0.003))
		if stickers:
			_tape(pts, a, r.size.y)
			draw_set_transform(Vector2.ZERO)
	if _frame and not stickers:
		draw_texture_rect(_frame, r, false)


## A sticker's shadow and paper rim, under the panel (pts around the origin).
func _sticker_back(pts: PackedVector2Array, a: float, h: float) -> void:
	var rim := _grow(pts, h * 0.008)
	var shadow := rim.duplicate()
	for k in shadow.size():
		shadow[k] += Vector2(h * 0.004, h * 0.007)
	draw_colored_polygon(shadow, Color(0, 0, 0, 0.18 + 0.12 * a))
	draw_colored_polygon(rim, Color(UI.PAPER.lightened(0.3), 0.35 + 0.65 * a))


## A strip of translucent tape across the sticker's top edge, once it's shown.
func _tape(pts: PackedVector2Array, a: float, h: float) -> void:
	if a <= 0.0:
		return
	var top := (pts[0] + pts[1]) / 2.0
	var w := h * 0.07
	var t := h * 0.022
	draw_colored_polygon(PackedVector2Array([top + Vector2(-w, -t), top + Vector2(w, -t * 0.6), top + Vector2(w, t * 1.2),
		top + Vector2(-w, t)]), Color(0.93, 0.88, 0.72, 0.55 * a))


## The polygon pushed out by d from its centre (the panels are near-rectangles around the origin).
func _grow(pts: PackedVector2Array, d: float) -> PackedVector2Array:
	var out := PackedVector2Array()
	for p in pts:
		out.append(p + Vector2(signf(p.x), signf(p.y)) * d)
	return out
