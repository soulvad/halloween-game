extends CanvasLayer
## «Минають години…»: non-interactive cutscene after the priest arrives. The guide's cut-away top view (as tour.gd)
## follows the visitors, sped up along navmesh paths: two rooms searched, the room with the old plan, then the
## collapsed wall `Level/Rubble`, which they clear. Paused tree, Space / Esc skips to the same end state:
## wall gone + navmesh rebaked, visitors standing at the opening, player camera current, tree running.
## The ghost (its cloud body, player.show_body) trails the group the whole way and stays where it ends up.

signal finished

const UI = preload("res://scripts/ui.gd")
const Station = preload("res://scripts/station.gd")
const Fx = preload("res://scripts/fx.gd")
const PROJECTOR_DB := -8.0  ## the reel rattling under the cutscene
const FILM = preload("res://scripts/film.gdshader")
const EDGE := 170  ## px: the pills stay clear of the film strips at the sides
const LAYER_CEILING := 8  ## visual layer 4: the ceiling, cut away
const LAYER_LABELS := 2  ## visual layer 2: world labels
const SPEED := 5.0  ## m/s on screen: people walk sped up
const SEARCH := 2.2  ## seconds of «searching» per room
const CAM_H := 13.0
const CAM_D := 6.0
const CLOCK_FROM := 21.0  ## the clock pill runs 21:00 → 05:00
const CLOCK_HOURS := 8.0
const ARCH_COLOR := Color("8BEA4E")
const PRIEST_COLOR := Color("FFC531")
const GHOST_GAP := 1.6  ## m the ghost keeps behind the group's centre
const GHOST_FOLLOW := 2.5  ## how fast it catches up (1/s)

var game: Node3D
var _ghost: Node3D  ## the player, drifting after the searchers
var _visitors: Array = []
var _legs: Array = []  ## per leg: Array of PackedVector3Array, one path per visitor
var _tween: Tween
var _total := 1.0  ## seconds the whole cutscene runs
var _cam: Camera3D
var _light: DirectionalLight3D
var _fog := 0.0
var _clock: Label
var _line: RichTextLabel
var _line_t := 0.0
var _done := false
var _mouse_before := Input.MOUSE_MODE_CAPTURED
var _reel := AudioStreamPlayer.new()


func play(g: Node3D) -> void:
	game = g
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 45
	get_tree().paused = true
	_mouse_before = Input.mouse_mode
	var hud := g.get_node_or_null("HUD") as CanvasLayer
	if hud:
		hud.visible = false
	_cam = Camera3D.new()
	_cam.fov = 55
	_cam.far = 120
	_cam.cull_mask = 0xFFFFF & ~LAYER_CEILING & ~LAYER_LABELS
	g.add_child(_cam)
	_ghost = g.get_node("Player")
	_ghost.show_body(true)
	_cam.global_transform = _ghost.camera.global_transform
	_cam.current = true
	_light = DirectionalLight3D.new()  # soft top light so the cut-away reads from above
	_light.light_energy = 0.55
	_light.light_color = Color(0.75, 0.75, 1.0)
	_light.rotation_degrees = Vector3(-70, 30, 0)
	g.add_child(_light)
	var env: Environment = g.get_node("WorldEnvironment").environment
	_fog = env.fog_density
	env.fog_density = _fog * 0.35
	_visitors = get_tree().get_nodes_in_group("visitor")
	var entrance := g.get_node_or_null("Markers/Entrance") as Node3D
	for v in _visitors:
		if not v.visible:  # the priest, if he has not walked in yet
			v.arrive(entrance.global_position if entrance else v.global_position)
	_build_ui()
	var s := Fx.stream("projector") as AudioStreamOggVorbis
	if s:
		s.loop = true
		_reel.stream = s
		_reel.volume_db = -40.0
		add_child(_reel)
		_reel.play()
		_reel.create_tween().tween_property(_reel, "volume_db", PROJECTOR_DB + Fx.MIX_DB, 0.6)
	GameState.said.connect(_on_said)
	_plan_route()
	_build_tween()


func _build_ui() -> void:
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)
	var film := ColorRect.new()  # old film reel over the whole view, the pills and lines sit on top
	film.set_anchors_preset(Control.PRESET_FULL_RECT)
	film.mouse_filter = Control.MOUSE_FILTER_IGNORE
	film.material = ShaderMaterial.new()
	film.material.shader = FILM
	root.add_child(film)
	var pill := UI.pill("", UI.GOLD, 20, "moon")
	root.add_child(pill)
	pill.position = Vector2(EDGE, 36)
	_clock = pill.get_child(0).get_child(-1)
	var hint := UI.pill("Пробіл / Esc — пропустити", UI.LILAC, 15)
	root.add_child(hint)
	hint.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT, Control.PRESET_MODE_MINSIZE, EDGE)
	hint.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	_line = RichTextLabel.new()  # the HUD (and its subtitles) is hidden while this plays
	_line.bbcode_enabled = true
	_line.fit_content = true
	_line.scroll_active = false
	_line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_line.add_theme_font_size_override("normal_font_size", 26)
	_line.add_theme_font_size_override("bold_font_size", 26)
	_line.add_theme_constant_override("outline_size", 8)
	_line.add_theme_color_override("font_outline_color", UI.INK)
	root.add_child(_line)
	_line.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM, Control.PRESET_MODE_MINSIZE, 60)
	_line.custom_minimum_size.x = 1100
	_line.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_line.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_set_clock(0.0)


## Rooms to walk through: the two nearest unsearched rooms (greedy from where the group stands), the plan's room,
## then the bricked wall. Every leg is a navmesh path per visitor, precomputed so a skip lands on the same spot.
func _plan_route() -> void:
	var rooms: Dictionary = game.get_meta("rooms", {})
	var plan := _plan()
	var plan_room := _room_key(rooms, plan.global_position) if plan else ""
	var used := ["YourRoom", plan_room]
	var at := _centre()
	var stops: Array[Vector3] = []
	for i in 2:
		var best := ""
		for k in rooms:
			if k in used or k.begins_with("Corridor") or k.begins_with("Passage"):
				continue
			if best == "" or _room_pos(rooms[k]).distance_to(at) < _room_pos(rooms[best]).distance_to(at):
				best = k
		if best == "":
			break
		used.append(best)
		at = _room_pos(rooms[best])
		stops.append(at)
	if plan:
		stops.append(plan.global_position)
	var rubble := game.get_node_or_null("Level/Rubble") as Node3D
	if rubble:
		stops.append(rubble.global_position)
	var map := game.get_world_3d().navigation_map
	var from: Array = _visitors.map(func(v): return v.global_position)
	for s in stops:
		var leg := []
		for i in _visitors.size():
			var off := Vector3(cos(i * TAU / _visitors.size()), 0, sin(i * TAU / _visitors.size())) * 0.9
			var path := NavigationServer3D.map_get_path(map, from[i], s + off, true)
			if path.is_empty():
				path = PackedVector3Array([from[i], s + off])
			for j in path.size():  # keep everyone at their own height, navmesh points sit on the floor
				path[j].y = from[i].y
			leg.append(path)
			from[i] = path[path.size() - 1]
		_legs.append(leg)


## The old plan: the PLAN station, else any instance of the plan model.
func _plan() -> Node3D:
	var st := game.get_node_or_null("Stations")
	if st:
		for s in st.get_children():
			if s is Station and s.kind == Station.Kind.PLAN:
				return s
	for n in game.find_children("*", "Node3D", true, false):
		if n.scene_file_path == "res://art/models/Plan.tscn":
			return n
	return null


func _room_key(rooms: Dictionary, p: Vector3) -> String:
	for k in rooms:
		if rooms[k].has_point(Vector2(p.x, p.z)):
			return k
	return ""


func _room_pos(r: Rect2) -> Vector3:
	return Vector3(r.get_center().x, 0, r.get_center().y)


func _centre() -> Vector3:
	var c := Vector3.ZERO
	for v in _visitors:
		c += v.global_position
	return c / maxf(_visitors.size(), 1)


func _build_tween() -> void:
	_tween = create_tween()
	_tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	var lines := [
		["Олена", "Отче, ми обшукаємо кожну кімнату. Щось тут мусить бути.", ARCH_COLOR],
		["Тарас", "Тут нічого… Ходімо далі.", ARCH_COLOR],
		["Олена", "Дивіться — старий план маєтку! Кімнати пораховані…", ARCH_COLOR],
		["Отець Василь", "Тут бракує кімнати. Вона за тією стіною — розбираймо.", PRIEST_COLOR],
	]
	var n := _legs.size()
	var line_at := {0: 0, 1: 1, n - 2: 2, n - 1: 3}  # first rooms, the plan's room, the wall
	_total = 1.2
	for i in n:
		if line_at.has(i):
			_tween.tween_callback(GameState.say.bindv(lines[line_at[i]]))
		var leg: Array = _legs[i]
		var far := 0.0
		for p in leg:
			far = maxf(far, _length(p))
		var walk := maxf(far / SPEED, 0.3)
		var stay := SEARCH if i < n - 1 else 1.5
		_total += walk + stay
		_tween.tween_method(_walk.bind(leg), 0.0, far, walk)
		_tween.tween_interval(stay)
	_tween.tween_callback(_clear_rubble)
	_tween.tween_interval(1.2)
	_tween.tween_callback(_end)


func _length(p: PackedVector3Array) -> float:
	var l := 0.0
	for i in range(1, p.size()):
		l += p[i - 1].distance_to(p[i])
	return l


## Everyone `d` metres along their path for this leg (clamped at its end), facing the way they walk.
func _walk(d: float, leg: Array) -> void:
	for i in _visitors.size():
		var p: PackedVector3Array = leg[i]
		var v: Node3D = _visitors[i]
		var left := d
		var pos := p[p.size() - 1]
		for j in range(1, p.size()):
			var seg := p[j - 1].distance_to(p[j])
			if left <= seg:
				pos = p[j - 1].lerp(p[j], left / maxf(seg, 0.001))
				break
			left -= seg
		var dir := pos - v.global_position
		dir.y = 0
		if dir.length() > 0.01:
			v.look_at(v.global_position + dir, Vector3.UP)
		v.global_position = pos


## As the DIG stage did (game.gd `_open_room`): the wall is gone and people can path into your room.
func _clear_rubble() -> void:
	var r := game.get_node_or_null("Level/Rubble")
	if r:
		r.free()
	for region in game.find_children("*", "NavigationRegion3D", true, false):
		region.bake_navigation_mesh(false)


func _set_clock(k: float) -> void:
	var h := CLOCK_FROM + CLOCK_HOURS * k
	_clock.text = ("Минають години… %02d:%02d" % [int(h) % 24, int(fmod(h, 1.0) * 60.0) / 10 * 10]).to_upper()


func _process(delta: float) -> void:
	if _done or _cam == null:
		return
	if _tween and _tween.is_valid():
		_set_clock(clampf(_tween.get_total_elapsed_time() / _total, 0.0, 1.0))
	var c := _centre()
	var to := Transform3D(Basis(), c + Vector3(0, CAM_H, CAM_D)).looking_at(c, Vector3.UP)
	var k := 1.0 - exp(-2.0 * delta)
	_cam.global_transform = Transform3D(_cam.global_transform.basis.slerp(to.basis, k), _cam.global_position.lerp(to.origin, k))
	_trail(c, 1.0 - exp(-GHOST_FOLLOW * delta))
	_line_t -= delta
	_line.visible = _line_t > 0


## The ghost drifts after the group's centre `c`, GHOST_GAP behind, facing it; `k` = how far it closes in (1 = all).
func _trail(c: Vector3, k: float) -> void:
	var to := c - _ghost.global_position
	to.y = 0
	if to.length() < 0.01:
		return
	_ghost.rotation.y = atan2(-to.x, -to.z)
	if to.length() > GHOST_GAP:
		_ghost.global_position += to.normalized() * (to.length() - GHOST_GAP) * k


func _on_said(who: String, text: String, color: Color) -> void:
	_line.text = "[center][b][color=#%s]%s:[/color][/b] %s[/center]" % [color.to_html(false), who, text]
	_line_t = 4.5


func _input(e: InputEvent) -> void:
	if not _done and (e.is_action_pressed("ui_cancel") or e.is_action_pressed("ui_accept")):
		get_viewport().set_input_as_handled()
		skip()


## Jump to the end state.
func skip() -> void:
	if _done:
		return
	if _tween:
		_tween.kill()
	for leg in _legs.slice(-1):
		_walk(INF, leg)
	_trail(_centre(), 1.0)
	_clear_rubble()
	_end()


func _end() -> void:
	if _done:
		return
	_done = true
	GameState.said.disconnect(_on_said)
	_ghost.show_body(false)
	_ghost.camera.current = true
	_cam.queue_free()
	_light.queue_free()
	game.get_node("WorldEnvironment").environment.fog_density = _fog
	var hud := game.get_node_or_null("HUD") as CanvasLayer
	if hud:
		hud.visible = true
	get_tree().paused = false
	Input.mouse_mode = _mouse_before
	finished.emit()
	queue_free()
