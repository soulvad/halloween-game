extends RefCounted
## CPU painting core of the texture painter: one RGBA8 Image, per-stroke coverage mask
## (soft brushes don't build up where dabs overlap), dirty-rect undo. No UI, so the self-check can drive it headless.

const MAX_UNDO := 40

var img: Image
var tileable := false  ## painting and fills wrap across edges
var color := Color.BLACK
var size := 16.0  ## brush diameter, px
var hardness := 0.8  ## 0 soft .. 1 hard (1 px antialiased edge)
var erase := false
var lazy := 0.0  ## stabilizer: the stroke trails the cursor on a string this long (px)
var modified := false  ## unsaved changes
var version := 0  ## bumps on every pixel change; views re-upload the texture when it moves

var _undo: Array[Dictionary] = []  ## {rect, before, after}; `after` is captured when undone
var _redo: Array[Dictionary] = []
var _before: Image
var _mask := PackedFloat32Array()
var _dirty := Rect2i()
var _last := Vector2.ZERO
var _last_p := 1.0
var _lazy_pos := Vector2.ZERO
var _dabbed := false
var _stroking := false


func new_image(px: int, bg := Color(0, 0, 0, 0)) -> void:
	img = Image.create_empty(px, px, false, Image.FORMAT_RGBA8)
	img.fill(bg)
	_reset()


func load_png(path: String) -> Error:
	var i := Image.new()
	var err := i.load(ProjectSettings.globalize_path(path))
	if err != OK:
		return err
	i.convert(Image.FORMAT_RGBA8)
	img = i
	_reset()
	return OK


func save_png(path: String) -> Error:
	var err := img.save_png(ProjectSettings.globalize_path(path))
	if err == OK:
		modified = false
	return err


func _reset() -> void:
	_undo.clear()
	_redo.clear()
	_stroking = false
	modified = false
	version += 1


func begin_stroke(pos: Vector2) -> void:
	_begin_edit()
	_mask.resize(img.get_width() * img.get_height())
	_mask.fill(0.0)
	_last = pos
	_lazy_pos = pos
	_last_p = 1.0
	_dabbed = false


## Dabs along the segment from the last point, spaced by a quarter radius, so fast moves leave no gaps.
func stroke_to(pos: Vector2, pressure := 1.0) -> void:
	if not _stroking:
		return
	if lazy > 0.0:
		var d := pos - _lazy_pos
		if d.length() <= lazy:
			return
		_lazy_pos = pos - d.normalized() * lazy
		pos = _lazy_pos
	if not _dabbed:
		_dab(_last, pressure)
		_dabbed = true
	var step := maxf(0.5, _radius(minf(pressure, _last_p)) * 0.25)
	var n := ceili(_last.distance_to(pos) / step)
	for i in range(1, n + 1):
		var t := float(i) / n
		_dab(_last.lerp(pos, t), lerpf(_last_p, pressure, t))
	_last = pos
	_last_p = pressure


func end_stroke() -> void:
	if not _stroking:
		return
	if not _dabbed:
		_dab(_last, _last_p)
	_end_edit()


## Flood fill (scanline) replacing pixels within `tolerance` (0..1 per RGBA channel) of the clicked one.
func fill(pos: Vector2, tolerance := 0.1) -> void:
	var w := img.get_width()
	var h := img.get_height()
	var sx := floori(pos.x)
	var sy := floori(pos.y)
	if tileable:
		sx = posmod(sx, w)
		sy = posmod(sy, h)
	elif sx < 0 or sy < 0 or sx >= w or sy >= h:
		return
	_begin_edit()
	var data := img.get_data().to_int32_array()  # one int per pixel: cheap compare + write
	var target := data[sy * w + sx]
	var fc := PackedByteArray([color.r8, color.g8, color.b8, color.a8]).to_int32_array()[0]
	var tol := int(tolerance * 255.0)
	var seen := PackedByteArray()
	seen.resize(w * h)
	var stack: Array[int] = [sy * w + sx]
	var lo := Vector2i(w, h)
	var hi := Vector2i(-1, -1)
	while not stack.is_empty():
		var p: int = stack.pop_back()
		if seen[p]:
			continue
		var y := p / w
		var x := p % w
		var row := y * w
		var l := x
		while (tileable or l > 0) and x - l < w - 1:
			var q := row + posmod(l - 1, w)
			if seen[q] or not _near(data, q, target, tol):
				break
			l -= 1
		var r := x
		while (tileable or r < w - 1) and r - l < w - 1:
			var q := row + posmod(r + 1, w)
			if seen[q] or not _near(data, q, target, tol):
				break
			r += 1
		for xx in range(l, r + 1):
			var px := posmod(xx, w)
			var q := row + px
			seen[q] = 1
			data[q] = fc
			lo = Vector2i(mini(lo.x, px), mini(lo.y, y))
			hi = Vector2i(maxi(hi.x, px), maxi(hi.y, y))
			for k in 2:
				var ny := y - 1 + 2 * k
				if not tileable and (ny < 0 or ny >= h):
					continue
				var nq := posmod(ny, h) * w + px
				if not seen[nq] and _near(data, nq, target, tol):
					stack.append(nq)
	img.set_data(w, h, false, Image.FORMAT_RGBA8, data.to_byte_array())
	_dirty = Rect2i(lo, hi - lo + Vector2i.ONE)
	version += 1
	_end_edit()


func pick(pos: Vector2) -> Color:
	var x := floori(pos.x)
	var y := floori(pos.y)
	if tileable:
		x = posmod(x, img.get_width())
		y = posmod(y, img.get_height())
	elif x < 0 or y < 0 or x >= img.get_width() or y >= img.get_height():
		return color
	return img.get_pixel(x, y)


func undo() -> bool:
	if _stroking or _undo.is_empty():
		return false
	var e: Dictionary = _undo.pop_back()
	e.after = img.get_region(e.rect)
	img.blit_rect(e.before, Rect2i(Vector2i.ZERO, e.rect.size), e.rect.position)
	_redo.append(e)
	modified = true
	version += 1
	return true


func redo() -> bool:
	if _stroking or _redo.is_empty():
		return false
	var e: Dictionary = _redo.pop_back()
	img.blit_rect(e.after, Rect2i(Vector2i.ZERO, e.rect.size), e.rect.position)
	_undo.append(e)
	modified = true
	version += 1
	return true


func _begin_edit() -> void:
	_before = img.duplicate()
	_dirty = Rect2i()
	_stroking = true


func _end_edit() -> void:
	_stroking = false
	if _dirty.has_area():
		_undo.append({rect = _dirty, before = _before.get_region(_dirty)})
		if _undo.size() > MAX_UNDO:
			_undo.pop_front()
		_redo.clear()
		modified = true
	_before = null


func _radius(pressure: float) -> float:
	return maxf(0.5, size * 0.5 * clampf(pressure, 0.15, 1.0))


func _dab(c: Vector2, pressure: float) -> void:
	var r := _radius(pressure)
	var edge := maxf(r * (1.0 - hardness), 1.0)
	var w := img.get_width()
	var h := img.get_height()
	var x0 := floori(c.x - r)
	var x1 := ceili(c.x + r)
	var y0 := floori(c.y - r)
	var y1 := ceili(c.y + r)
	if not tileable:
		x0 = maxi(x0, 0)
		y0 = maxi(y0, 0)
		x1 = mini(x1, w - 1)
		y1 = mini(y1, h - 1)
	for y in range(y0, y1 + 1):
		var py := posmod(y, h)
		var dy := y + 0.5 - c.y
		for x in range(x0, x1 + 1):
			var dx := x + 0.5 - c.x
			var cov := clampf((r - sqrt(dx * dx + dy * dy)) / edge, 0.0, 1.0)
			if cov <= 0.0:
				continue
			cov = cov * cov * (3.0 - 2.0 * cov)
			var px := posmod(x, w)
			var i := py * w + px
			if cov <= _mask[i]:
				continue
			_mask[i] = cov
			var b := _before.get_pixel(px, py)
			if erase:
				b.a *= 1.0 - cov
			else:
				b = b.blend(Color(color, color.a * cov))
			img.set_pixel(px, py, b)
	_mark(Rect2i(x0, y0, x1 - x0 + 1, y1 - y0 + 1))
	version += 1


## Grows the dirty rect by `r`, folding the parts that hang over an edge back in when tileable.
func _mark(r: Rect2i) -> void:
	if r.size.x <= 0 or r.size.y <= 0:
		return
	var s := img.get_size()
	var full := Rect2i(Vector2i.ZERO, s)
	var n := 1 if tileable else 0
	for oy in range(-n, n + 1):
		for ox in range(-n, n + 1):
			var rr := Rect2i(r.position + Vector2i(ox * s.x, oy * s.y), r.size).intersection(full)
			if rr.has_area():
				_dirty = rr if not _dirty.has_area() else _dirty.merge(rr)


func _near(d: PackedInt32Array, i: int, t: int, tol: int) -> bool:
	var v := d[i]
	if v == t:
		return true
	for sh in [0, 8, 16, 24]:
		if absi(((v >> sh) & 0xFF) - ((t >> sh) & 0xFF)) > tol:
			return false
	return true
