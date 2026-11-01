extends Node
## Every candle stands on something real: rays down from around its foot meet a mesh right at the foot, above the floor;
## its stand pokes through no wall and no decor; the flame is on top; aim and E still work. Prints `CANDLES OK`, else quits with 1.

const FOOT := 0.025  ## m, the candle's foot; four rays go down from this far around its centre
const TOUCH := 0.012  ## m, the largest gap (or sink) between foot and support
const CLEAR := 0.01  ## m, a stand may graze a wall by this much
const AIM_FROM := 1.2  ## m, how far off the ghost aims from

var _errors := 0


func _ready() -> void:
	GameState.intro_seen = true
	var g = load("res://scenes/game.tscn").instantiate()
	g.comics_enabled = false
	add_child(g)
	for i in 3:
		await get_tree().physics_frame
	var candles := get_tree().get_nodes_in_group("candle")
	_check(candles.size() >= 7, "only %d candles" % candles.size())
	GameState.gain("breath")
	for c in candles:
		_support(g, c)
		_clear(g, c)
		_flame(c)
		_room(g, c)
		await _reach(g, c)
	if _errors == 0:
		print("CANDLES OK")
	get_tree().quit(1 if _errors else 0)


func _check(ok: bool, what: String) -> void:
	if not ok:
		_errors += 1
		printerr("CANDLE FAIL: ", what)


func _foot_y(c: Node3D) -> float:
	return c.global_position.y - c.size.y / 2


## Each ray down from the foot meets the first surface right at the foot's height, and it isn't the floor.
func _support(g: Node, c: Node3D) -> void:
	var foot := _foot_y(c)
	var tris := _triangles(g, c)
	var line := "%s: foot at %.3f" % [c.name, foot]
	for a in 4:
		var at: Vector3 = c.global_position + Vector3.RIGHT.rotated(Vector3.UP, a * PI / 2) * FOOT
		at.y = foot + 0.05
		var top := -INF
		for i in range(0, tris.size(), 3):
			var hit = Geometry3D.ray_intersects_triangle(at, Vector3.DOWN, tris[i], tris[i + 1], tris[i + 2])
			if hit != null:
				top = maxf(top, hit.y)
		line += ", %.3f" % top
		_check(top > 0.1 and absf(top - foot) <= TOUCH, "%s: under the foot the first surface is at %.3f, the foot at %.3f" % [c.name, top, foot])
	print(line, " on ", c.stand if c.stand != "" else "NOTHING")


## World triangles of every mesh near the candle except the candle itself, its label and what's above it.
func _triangles(g: Node, c: Node3D) -> PackedVector3Array:
	var out := PackedVector3Array()
	var column := AABB(c.global_position - Vector3(0.2, 3, 0.2), Vector3(0.4, 6, 0.4))
	for m: MeshInstance3D in g.find_children("*", "MeshInstance3D", true, false):
		if not m.is_visible_in_tree() or not m.mesh or m.name == "Ceiling" or m.name == "Floor":
			continue
		if c._mesh == m or c._mesh.is_ancestor_of(m) or c._flame == m:
			continue
		if not (m.global_transform * m.get_aabb()).intersects(column):
			continue
		for f in m.mesh.get_faces():
			out.append(m.global_transform * f)
	return out


## The stand keeps out of walls, furniture and other decor.
func _clear(g: Node, c: Node3D) -> void:
	var stand := _stand_verts(c)
	if stand.is_empty():
		return
	for w in g.get_node("Level").get_children():
		if w is StaticBody3D and w.get("size") != null:
			var box := AABB(w.global_position - w.size / 2, w.size).grow(-CLEAR)
			for v in stand:
				if box.has_point(v):
					_check(false, "%s: its stand pokes into %s" % [c.name, w.name])
					break
	var bounds := _aabb(stand).grow(-CLEAR)
	for d in g.get_node("Decor").get_children():
		for m: MeshInstance3D in d.find_children("*", "MeshInstance3D", true, false):
			_check(not (m.global_transform * m.get_aabb()).intersects(bounds), "%s: its stand overlaps decor %s" % [c.name, d.name])


func _stand_verts(c: Node3D) -> PackedVector3Array:
	var out := PackedVector3Array()
	if c._stand:
		for m: MeshInstance3D in c._stand.find_children("*", "MeshInstance3D", true, false):
			for f in m.mesh.get_faces():
				out.append(m.global_transform * f)
	return out


func _aabb(points: PackedVector3Array) -> AABB:
	var box := AABB(points[0], Vector3.ZERO)
	for p in points:
		box = box.expand(p)
	return box


## Both flames (the model's and the station's) rest on the candle's top, right above its centre.
func _flame(c: Node3D) -> void:
	var top := -INF
	for m: MeshInstance3D in c._mesh.find_children("*", "MeshInstance3D", true, false):
		if m.get_parent().name != "On":
			top = maxf(top, (m.global_transform * m.get_aabb()).end.y)
	for f in [c._flame, c._mesh.get_node("On/Flame")]:
		var off: Vector3 = f.global_position - c.global_position
		_check(Vector2(off.x, off.z).length() < 0.01 and absf(f.global_position.y - top) < 0.06, "%s: flame %s is off the candle (top %.3f)" % [c.name, f.global_position, top])


## Inside a room or a door gap of the dungeon's plan.
func _room(g: Node, c: Node3D) -> void:
	var at := Vector2(c.global_position.x, c.global_position.z)
	var inside := false
	for r: Rect2 in g.get_meta("rooms").values():
		inside = inside or r.has_point(at)
	_check(inside, "%s: outside every room" % c.name)


## The ghost, a little way off, aims at it and it's the target; E still blows it out and lights it again.
func _reach(g: Node, c: Node3D) -> void:
	var p = g.get_node("Player")
	for a in 8:  # from the first side that's inside a room
		var from: Vector3 = c.global_position + Vector3.RIGHT.rotated(Vector3.UP, a * PI / 4) * AIM_FROM
		if g.get_meta("rooms").values().any(func(r): return r.has_point(Vector2(from.x, from.z))):
			p.global_position = Vector3(from.x, 0, from.z)
			break
	p.velocity = Vector3.ZERO
	var look: Vector3 = c.global_position - (p.global_position + Vector3(0, p.EYE, 0))
	p.rotation.y = atan2(-look.x, -look.z)
	p.head.rotation.x = atan2(look.y, Vector2(look.x, look.z).length())
	for i in 3:
		await get_tree().physics_frame
	_check(p.ray.get_collider() == c and p.target_station() == c, "%s: not the target when aimed at, got %s" % [c.name, p.ray.get_collider()])
	_check(c.can_use(), "%s: can't be used" % c.name)
	c.cooldown = 0.0
	var was: bool = c.lit
	c.interact(p)
	_check(c.lit != was, "%s: E didn't toggle it" % c.name)
	c.cooldown = 0.0
	c.interact(p)
	_check(c.lit == was, "%s: E didn't toggle it back" % c.name)
	c.lit = true
	c._refresh()
	_check(c._light.visible and c._flame.visible, "%s: lit, but no light or flame" % c.name)
	c.lit = was
	c._refresh()
