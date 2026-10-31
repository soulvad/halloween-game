extends Control
## Flat drawn map of the dungeon (HUD minimap and the M map): carved floor from the generator's `rooms` / `doors`
## metadata on the game root, furniture, the bricked wall, doors, lit candles, the next memory, people and you.
## `follow` set = minimap (centred on it at `px_per_m`), else the whole dungeon fits the control.

const Station = preload("res://scripts/station.gd")
const Visitor = preload("res://scripts/visitor.gd")
const UI = preload("res://scripts/ui.gd")

## Story names of the rooms (tools/gen_dungeon.py), shown on the big map and when you float into a room.
const ROOM_NAMES := {
	"CorridorV": "Вхідний коридор", "CorridorH": "Коридор кайданів", "FarLeft": "Комірчина управителя",
	"R1L": "Спальня слуг", "R1R": "Комора", "R2L": "Нари", "R2R": "Кімната з дзеркалом",
	"R3L": "Майстерня", "R3R": "Кухня", "R4L": "Льох", "R4R": "Табір археологів",
	"RightTall": "Склеп", "PassageUp": "Прохід за дверима", "PassageTop": "Прохід за дверима",
	"YourRoom": "Твоя кімната",
}
const ROCK := Color("0E0A14")
const FLOOR := Color("4A3F5C")
const FLOOR_EDGE := Color("A99BC4")
const FURNITURE := Color("6E5440")
const HIDDEN := Color("2A2236")  ## your room before the wall is down

var game: Node3D
var follow: Node3D
var px_per_m := 9.0
var names := false  ## room names (big map)
var _rooms := {}
var _doors: Array = []
var _furniture: Array[Rect2] = []
var _stations: Array = []
var _bounds := Rect2()
var _t := 0.0


func setup(g: Node3D) -> void:
	game = g
	_rooms = g.get_meta("rooms", {})
	_doors = g.get_meta("doors", [])
	for r in _rooms.values():
		_bounds = r if _bounds.size == Vector2.ZERO else _bounds.merge(r)
	for w in g.get_node("Level").get_children():
		if w.get("solid_from") == 3:
			_furniture.append(Rect2(Vector2(w.position.x, w.position.z) - Vector2(w.size.x, w.size.z) / 2, Vector2(w.size.x, w.size.z)))
	_stations = g.get_node("Stations").get_children()
	clip_contents = true
	mouse_filter = Control.MOUSE_FILTER_IGNORE


## Room name at a world position, "" outside every room (door gaps, inside walls).
func room_at(p: Vector3) -> String:
	for k in _rooms:
		if _rooms[k].has_point(Vector2(p.x, p.z)):
			return ROOM_NAMES.get(k, "")
	return ""


func _scale() -> float:
	if follow:
		return px_per_m
	return minf(size.x / _bounds.size.x, size.y / _bounds.size.y) * 0.96


## World position → control pixels (north up: −z is up, like the old top-down camera).
func to_map(p: Vector3) -> Vector2:
	var s := _scale()
	var c := Vector2(follow.global_position.x, follow.global_position.z) if follow else _bounds.get_center()
	return size / 2 + (Vector2(p.x, p.z) - c) * s


func _rect(r: Rect2) -> Rect2:
	var a := to_map(Vector3(r.position.x, 0, r.position.y))
	return Rect2(a, r.size * _scale())


func _process(delta: float) -> void:
	_t += delta
	if is_visible_in_tree():
		queue_redraw()


func _draw() -> void:
	if game == null:
		return
	var s := _scale()
	draw_rect(Rect2(Vector2.ZERO, size), ROCK)
	var sealed: bool = game.get_node_or_null("Level/Rubble") != null
	for k in _rooms:  # outline pass, then floors over it: one clean edge around joined rooms
		draw_rect(_rect(_rooms[k]).grow(maxf(1.5, s * 0.12)), FLOOR_EDGE)
	for d in _doors:
		draw_rect(_rect(d).grow(maxf(1.5, s * 0.12)), FLOOR_EDGE)
	for k in _rooms:
		draw_rect(_rect(_rooms[k]), HIDDEN if sealed and k == "YourRoom" else FLOOR)
	for d in _doors:
		draw_rect(_rect(d), FLOOR)
	for f in _furniture:
		draw_rect(_rect(f), FURNITURE)
	var rubble := game.get_node_or_null("Level/Rubble") as Node3D
	if rubble:
		var c := to_map(rubble.global_position)
		var half: Vector2 = Vector2(rubble.size.x, rubble.size.z) * s / 2
		draw_rect(Rect2(c - half, half * 2).grow(1), UI.ORANGE)
	var font := UI.font("body", 800)
	if names:
		for k in _rooms:
			var n: String = ROOM_NAMES.get(k, "")
			if n == "" or (k == "PassageTop") or (sealed and k == "YourRoom"):
				continue
			var r := _rect(_rooms[k])
			var fs := 18 if r.size.x > 110 else 13
			draw_string(font, r.get_center() + Vector2(-r.size.x / 2, fs * 0.35), n, HORIZONTAL_ALIGNMENT_CENTER, r.size.x, fs, Color(UI.PAPER, 0.75))
	var pulse := 0.5 + 0.5 * sin(_t * 4.0)
	for st in _stations:
		var p := to_map(st.global_position)
		match st.kind:
			Station.Kind.DOOR:
				if not st.open:
					var half := Vector2(st.size.x, st.size.z) * s / 2
					draw_rect(Rect2(p - half, half * 2).grow(1.5), Color("C08A4A"))
			Station.Kind.CANDLE:
				if st.lit:
					draw_circle(p, maxf(2.0, s * 0.18), UI.GOLD)
			Station.Kind.MEMORY:
				if st.visible:  # only the next memory in order is shown in the world
					draw_circle(p, maxf(5.0, s * 0.45) * (1.0 + 0.35 * pulse), Color(UI.CYAN, 0.35))
					draw_circle(p, maxf(3.0, s * 0.25), UI.CYAN)
			Station.Kind.CIRCLE:
				if not sealed:
					draw_arc(p, s * 1.2, 0, TAU, 32, UI.MOM, maxf(1.5, s * 0.1))
	for v in get_tree().get_nodes_in_group("visitor"):
		if v.visible:
			var col: Color = UI.GOLD if v.kind == Visitor.Kind.PRIEST else UI.GREEN
			var p := to_map(v.global_position)
			draw_circle(p, maxf(4.0, s * 0.32), UI.INK)
			draw_circle(p, maxf(3.0, s * 0.25), col)
	var pl: Node3D = game.get_node("Player")
	var at := to_map(pl.global_position)
	var fwd := Vector2(-sin(pl.rotation.y), -cos(pl.rotation.y))  # −z forward, north up
	var side := Vector2(-fwd.y, fwd.x)
	var r := maxf(7.0, s * 0.55)
	var tri := PackedVector2Array([at + fwd * r * 1.3, at - fwd * r * 0.7 + side * r * 0.8, at - fwd * r * 0.35, at - fwd * r * 0.7 - side * r * 0.8])
	draw_colored_polygon(tri, UI.CYAN)
	draw_polyline(tri + PackedVector2Array([tri[0]]), UI.INK, 2.0)
