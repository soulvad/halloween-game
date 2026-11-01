extends Control
## Flat drawn map of the dungeon (HUD minimap and the M map): carved floor from the generator's `rooms` / `doors`
## metadata on the game root, furniture, the collapsed wall, lit candles, the next memory, people and you.
## `follow` set = minimap (centred on it at `px_per_m`), else the whole dungeon fits the control.
## A haunt (GameState.haunted) spreads a ring out to how far it carries; archaeologists inside it blink a while.

const Station = preload("res://scripts/station.gd")
const Visitor = preload("res://scripts/visitor.gd")
const UI = preload("res://scripts/ui.gd")

const ROOM_NAMES := {
	"CorridorV": "Вхідний коридор", "CorridorH": "Коридор кайданів", "FarLeft": "Комірчина управителя",
	"R1L": "Спальня слуг", "R1R": "Комора", "R2L": "Нари", "R2R": "Кімната з дзеркалом",
	"R3L": "Майстерня", "R3R": "Кухня", "R4L": "Льох", "R4R": "Табір археологів",
	"RightTall": "Склеп", "PassageUp": "Прохід за дверима", "PassageTop": "Прохід за дверима",
	"YourRoom": "Твоя кімната", "BonesRoom": "Келія", "CatRoom": "Постамент",
}
const ROCK := Color(0.78, 0.71, 0.6)
const FLOOR := Color("EBDDBF")
const FLOOR_EDGE := Color("3B2A1E")
const FURNITURE := Color("B49B76")
const HIDDEN := Color("C9B593")
const DOOR := Color("8E5A2E")
const RITUAL := Color("B07A2A")
const PAPER_TEX := preload("res://art/ui/textures/map_paper.png")
const YOU := preload("res://art/ui/icons/marker_you.png")
const CANDLE := preload("res://art/ui/icons/marker_candle_lit.png")
const MEMORY := preload("res://art/ui/icons/marker_memory.png")
const ARCHAEOLOGIST := preload("res://art/ui/icons/marker_archaeologist.png")
const PRIEST := preload("res://art/ui/icons/marker_priest.png")
const RING_TIME := 1.2  ## s, a haunt's ring spreading out and fading
const BLINK_TIME := 2.0  ## s the dots of those who heard it blink

var game: Node3D
var follow: Node3D
var px_per_m := 9.0
var names := false
var _rooms := {}
var _doors: Array = []
var _furniture: Array[Rect2] = []
var _stations: Array = []
var _bounds := Rect2()
var _t := 0.0
var _rings: Array = []  ## [world pos, radius m, seconds, colour]
var _blink := {}  ## visitor -> seconds left


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
	GameState.haunted.connect(_on_haunted)


func _on_haunted(pos: Vector3, power: float, by: String) -> void:
	var r := Visitor.HEAR * power
	_rings.append([pos, r, 0.0, RITUAL if by == "breath" else UI.ORANGE])
	if GameState.stage != GameState.Stage.HAUNT:  # visitor.gd: only then do they come to look
		return
	for v in get_tree().get_nodes_in_group("visitor"):
		if v.visible and v.kind == Visitor.Kind.ARCH and Vector2(v.global_position.x - pos.x, v.global_position.z - pos.z).length() <= r:
			_blink[v] = BLINK_TIME


func room_at(p: Vector3) -> String:
	for k in _rooms:
		if _rooms[k].has_point(Vector2(p.x, p.z)):
			return ROOM_NAMES.get(k, "")
	return ""


func _scale() -> float:
	if follow:
		return px_per_m
	return minf(size.x / _bounds.size.x, size.y / _bounds.size.y) * 0.96


func to_map(p: Vector3) -> Vector2:
	var s := _scale()
	var c := Vector2(follow.global_position.x, follow.global_position.z) if follow else _bounds.get_center()
	return size / 2 + (Vector2(p.x, p.z) - c) * s


func _rect(r: Rect2) -> Rect2:
	var a := to_map(Vector3(r.position.x, 0, r.position.y))
	return Rect2(a, r.size * _scale())


func _process(delta: float) -> void:
	_t += delta
	for g in _rings:
		g[2] += delta
	_rings = _rings.filter(func(g): return g[2] < RING_TIME)
	for v in _blink.keys():
		_blink[v] -= delta
		if _blink[v] <= 0 or not is_instance_valid(v):
			_blink.erase(v)
	if is_visible_in_tree():
		queue_redraw()


func _draw() -> void:
	if game == null:
		return
	var s := _scale()
	draw_texture_rect(PAPER_TEX, Rect2(Vector2.ZERO, size), true, ROCK)
	var sealed: bool = game.get_node_or_null("Level/Rubble") != null
	for k in _rooms:
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
		draw_rect(Rect2(c - half, half * 2).grow(1), UI.RED)
	var font := UI.font("hand")
	if names:
		for k in _rooms:
			var n: String = ROOM_NAMES.get(k, "")
			if n == "" or (k == "PassageTop") or (sealed and k == "YourRoom"):
				continue
			var r := _rect(_rooms[k])
			var fs := 22 if r.size.x > 110 else 16
			draw_string(font, r.get_center() + Vector2(-r.size.x / 2, fs * 0.35), n, HORIZONTAL_ALIGNMENT_CENTER, r.size.x, fs, Color(UI.INK, 0.72))
	var pulse := 0.5 + 0.5 * sin(_t * 4.0)
	for st in _stations:
		var p := to_map(st.global_position)
		match st.kind:
			Station.Kind.CANDLE:
				if st.lit:
					_marker(CANDLE, p, maxf(16.0, s * 0.9))
			Station.Kind.MEMORY:
				if st.visible:
					_marker(MEMORY, p, maxf(20.0, s * 1.1) * (1.0 + 0.25 * pulse))
			Station.Kind.CIRCLE:
				if not sealed:
					draw_arc(p, s * 1.2, 0, TAU, 32, RITUAL, maxf(1.5, s * 0.1))
	for g in _rings:
		var k: float = g[2] / RING_TIME
		draw_arc(to_map(g[0]), g[1] * s * ease(k, 0.4), 0, TAU, 48, Color(g[3], 0.85 * (1.0 - k)), maxf(2.5, s * 0.15))
	for v in get_tree().get_nodes_in_group("visitor"):
		if v.visible:
			var p := to_map(v.global_position)
			var side := maxf(16.0, s * 0.8)
			if _blink.has(v) and fmod(_t, 0.3) < 0.15:  # heard it: blinks
				draw_arc(p, side * 0.75, 0, TAU, 24, UI.RED, 3.0)
				side *= 1.3
			_marker(PRIEST if v.kind == Visitor.Kind.PRIEST else ARCHAEOLOGIST, p, side)
	var pl: Node3D = game.get_node("Player")
	var fwd := Vector2(-sin(pl.rotation.y), -cos(pl.rotation.y))
	draw_set_transform(to_map(pl.global_position), atan2(fwd.x, -fwd.y))
	_marker(YOU, Vector2.ZERO, maxf(22.0, s * 1.2))
	draw_set_transform(Vector2.ZERO)


func _marker(tex: Texture2D, at: Vector2, side: float) -> void:
	draw_texture_rect(tex, Rect2(at - Vector2(side, side) / 2, Vector2(side, side)), false)
