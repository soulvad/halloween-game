extends CanvasLayer
## 3D guide: a camera flies over the cut-away dungeon (no ceiling) and stops at each key mechanic, which glows with
## a ring + light beam and a pointer pill; a card at the bottom explains it. Short, paused, skippable, replayable
## from the pause. Plays once after the prologue comic (game.gd), then the camera dives back into the ghost's eyes.
## Space / Enter / → / click — next, ← / Backspace — back, Esc — skip.

signal finished

const UI = preload("res://scripts/ui.gd")
const FLY_TIME := 1.4  ## seconds between two shots
const ORBIT := 0.07  ## rad/s slow drift while a shot holds
const LAYER_CEILING := 8  ## visual layer 4: the ceiling, cut away
const LAYER_LABELS := 2  ## visual layer 2: world labels (the pointer pill names the target instead)

## target: node path in the game scene (or "" = dungeon centre); h / d = camera height and distance; keys = chips.
const STEPS := [
	{"target": "", "h": 26.0, "d": 9.0, "icon": "moon", "title": "Підземелля старого міста",
		"text": "Ти — привид. Ти забув, хто ти. Тут немає ворогів і не можна програти: досліджуй спокійно.", "keys": []},
	{"target": "Player", "h": 8.0, "d": 3.5, "icon": "ghost", "title": "Ти пролітаєш крізь стіни",
		"text": "Внутрішні стіни й меблі тебе не тримають: у стіні екран темніє, і тебе виносить на інший бік. Зовнішні стіни — край підземелля.",
		"keys": ["W A S D", "Shift — швидше", "Миша — огляд"]},
	{"target": "Stations/Memory1", "h": 7.0, "d": 3.0, "icon": "eye", "title": "Блакитний блиск — спогад",
		"text": "Підлети і натисни E. Кожен спогад повертає силу. Наступний блиск з'явиться, щойно згадаєш попередній.", "keys": ["E — згадати"]},
	{"target": "Stations/CandleBedroom", "h": 7.0, "d": 3.5, "icon": "candle", "title": "Сили: світло і звук",
		"text": "Подих гасить і запалює свічки, Поштовх гримить предметами. Люди поруч підуть подивитися, що сталося.", "keys": ["E — діяти"]},
	{"target": "Visitors/Olena", "h": 8.5, "d": 3.5, "icon": "search", "title": "Археологи — твої свідки",
		"text": "Олена й Тарас не бачать тебе, але чують і помічають світло. Веди їх туди, де вони мають щось побачити.", "keys": []},
	{"target": "Level/Rubble", "h": 9.0, "d": 4.0, "icon": "lock", "title": "Твоя кімната за стіною",
		"text": "Тут тебе замурували. Допоможи людям знайти цю кімнату — тоді тебе зможуть відпустити.", "keys": []},
	{"target": "Player", "h": 6.0, "d": 3.0, "icon": "map", "title": "Книга і карта",
		"text": "У книзі — цілі та спогади, на карті — де ти і де люди. Гайд можна переглянути з паузи.",
		"keys": ["J — книга", "M — карта", "Esc — пауза"]},
]

var game: Node3D
var step := -1
var _cam: Camera3D
var _from := Transform3D()  ## camera when the current flight started
var _fly := 1.0  ## 0..1 progress of the flight to the current shot
var _orbit := 0.0
var _mark: Node3D
var _light: DirectionalLight3D
var _fog := 0.0
var _card_icon: TextureRect
var _card_title: Label
var _card_text: Label
var _card_keys: HBoxContainer
var _count: Label
var _dots: Array[Panel] = []
var _back: Button
var _next: Button
var _pointer: PanelContainer
var _diving := false
var _mouse_before := Input.MOUSE_MODE_CAPTURED


func play(g: Node3D) -> void:
	game = g
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 45
	get_tree().paused = true
	_mouse_before = Input.mouse_mode
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	var hud := g.get_node_or_null("HUD") as CanvasLayer
	if hud:
		hud.visible = false
	g.get_node("Player").show_body(true)
	_cam = Camera3D.new()
	_cam.fov = 55
	_cam.far = 120
	_cam.cull_mask = 0xFFFFF & ~LAYER_CEILING & ~LAYER_LABELS
	g.add_child(_cam)
	var pc: Camera3D = g.get_node("Player").camera
	_from = pc.global_transform
	_cam.global_transform = _from
	_cam.current = true
	_light = DirectionalLight3D.new()  # soft top light so the cut-away reads from above
	_light.light_energy = 0.55
	_light.light_color = Color(0.75, 0.75, 1.0)
	_light.rotation_degrees = Vector3(-70, 30, 0)
	g.add_child(_light)
	var env: Environment = g.get_node("WorldEnvironment").environment
	_fog = env.fog_density
	env.fog_density = _fog * 0.35
	_build_ui()
	go(0)


func _build_ui() -> void:
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)
	var shade := UI.vignette(UI.NIGHT)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(shade)

	var tag := UI.pill("Гайд", UI.GOLD, 18, "map")
	root.add_child(tag)
	tag.position = Vector2(40, 36)

	_pointer = UI.pill("", UI.CYAN, 18)
	_pointer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(_pointer)

	var card := UI.panel(UI.PAPER, 26, 8, 26)
	card.custom_minimum_size.x = 860
	root.add_child(card)
	card.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM, Control.PRESET_MODE_MINSIZE, 40)
	card.grow_horizontal = Control.GROW_DIRECTION_BOTH
	card.grow_vertical = Control.GROW_DIRECTION_BEGIN
	var col := UI.vbox(14)
	card.add_child(col)
	var head := UI.hbox(14)
	col.add_child(head)
	_card_icon = UI.icon("ghost", 40, UI.MUTED)
	head.add_child(_card_icon)
	_card_title = UI.label("", 34, UI.INK, "body", 900)
	_card_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(_card_title)
	_count = UI.label("", 18, UI.LABEL, "body", 900)
	head.add_child(_count)
	_card_text = UI.label("", 22, UI.MUTED, "body", 600)
	_card_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_card_text.custom_minimum_size.x = 800
	col.add_child(_card_text)
	_card_keys = UI.hbox(10)
	col.add_child(_card_keys)
	col.add_child(UI.rule())

	var foot := UI.hbox(12)
	col.add_child(foot)
	var dots := UI.hbox(8)
	dots.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	for i in STEPS.size():
		var d := Panel.new()
		d.custom_minimum_size = Vector2(14, 14)
		d.add_theme_stylebox_override("panel", UI.style(UI.GREY, 999, 0))
		dots.add_child(d)
		_dots.append(d)
	foot.add_child(dots)
	var gap := Control.new()
	gap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	foot.add_child(gap)
	var skip := UI.button("Пропустити", "secondary", "Esc", "", 20)
	skip.pressed.connect(close)
	_back = UI.button("Назад", "secondary", "←", "", 20)
	_back.pressed.connect(func(): go(step - 1))
	_next = UI.button("Далі", "primary", "Пробіл", "play", 20)
	_next.pressed.connect(func(): go(step + 1))
	for b in [skip, _back, _next]:
		b.focus_mode = Control.FOCUS_NONE  # Space must not press a focused button twice
		foot.add_child(b)


## Fly to step `i`; past the last step the camera dives back into the ghost.
func go(i: int) -> void:
	if _diving or i < 0:
		return
	if i >= STEPS.size():
		close()
		return
	step = i
	var s: Dictionary = STEPS[i]
	_from = _cam.global_transform
	_fly = 0.0
	_orbit = 0.0
	_card_title.text = s.title
	_card_text.text = s.text
	_card_icon.texture = UI.icon_texture(s.icon, 40, UI.MUTED)
	_count.text = "%d / %d" % [i + 1, STEPS.size()]
	for c in _card_keys.get_children():
		c.queue_free()
	for k in s["keys"]:
		_card_keys.add_child(UI.chip(k, UI.LILAC, UI.INK, 18, 3))
	_card_keys.visible = not s["keys"].is_empty()
	for d in _dots.size():
		(_dots[d].get_theme_stylebox("panel") as StyleBoxFlat).bg_color = UI.GOLD if d == i else (UI.MUTED if d < i else UI.GREY)
	_back.disabled = i == 0
	_next.text = ("Далі" if i < STEPS.size() - 1 else "Грати").to_upper()
	if _mark:
		_mark.queue_free()
		_mark = null
	var t := _target(s)
	if s.target != "":
		_mark = _marker()
		game.add_child(_mark)
		_mark.global_position = Vector3(t.x, 0.03, t.z)
	_pointer.visible = false


func _target(s: Dictionary) -> Vector3:
	if s.target == "":
		return Vector3(4.75, 0, -0.25)  # dungeon centre (tools/gen_dungeon.py)
	var n := game.get_node_or_null(NodePath(s.target)) as Node3D
	return n.global_position if n else Vector3(4.75, 0, -0.25)


## Where the camera holds for step `s`, slowly orbiting.
func _shot(s: Dictionary) -> Transform3D:
	var t := _target(s)
	var a := 0.35 + _orbit
	var eye := t + Vector3(sin(a) * s.d, s.h, cos(a) * s.d)
	var toward: Vector3 = Vector3(sin(a), 0, cos(a)) * s.d * 0.4  # look a bit short of the target: it sits above the card
	return Transform3D(Basis(), eye).looking_at(t + toward, Vector3.UP)


func _marker() -> Node3D:
	var root := Node3D.new()
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color = Color(UI.GOLD, 0.9)
	var ring := TorusMesh.new()
	ring.inner_radius = 0.75
	ring.outer_radius = 0.95
	ring.material = mat
	var m := MeshInstance3D.new()
	m.mesh = ring
	root.add_child(m)
	var beam_mat := mat.duplicate()
	beam_mat.albedo_color = Color(UI.GOLD, 0.08)
	beam_mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	beam_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	var beam := CylinderMesh.new()
	beam.top_radius = 0.0
	beam.bottom_radius = 0.6
	beam.height = 3.0
	beam.cap_top = false
	beam.cap_bottom = false
	beam.material = beam_mat
	var b := MeshInstance3D.new()
	b.mesh = beam
	b.position.y = 1.5
	root.add_child(b)
	var light := OmniLight3D.new()
	light.light_color = UI.GOLD
	light.light_energy = 1.2
	light.omni_range = 3.5
	light.position.y = 1.5
	root.add_child(light)
	return root


func _process(delta: float) -> void:
	if _cam == null:
		return
	var ease := func(x: float) -> float: return x * x * (3.0 - 2.0 * x)
	if _diving:
		_fly = minf(_fly + delta / 0.9, 1.0)
		var pc: Camera3D = game.get_node("Player").camera
		_cam.global_transform = _from.interpolate_with(pc.global_transform, ease.call(_fly))
		_cam.fov = lerpf(55.0, pc.fov, _fly)
		if _fly >= 1.0:
			_finish()
		return
	var s: Dictionary = STEPS[step]
	_orbit += ORBIT * delta
	_fly = minf(_fly + delta / FLY_TIME, 1.0)
	var to := _shot(s)
	var k: float = ease.call(_fly)
	var pos := _from.origin.lerp(to.origin, k)
	pos.y += sin(PI * k) * 3.0 * (1.0 if _from.origin.distance_to(to.origin) > 6.0 else 0.0)  # arc over the walls
	_cam.global_transform = Transform3D(_from.basis.slerp(to.basis, k), pos)
	if _mark:
		var p := 1.0 + 0.12 * sin(Time.get_ticks_msec() / 220.0)
		_mark.get_child(0).scale = Vector3(p, 1, p)
	if s.target != "" and _fly >= 1.0 and not _cam.is_position_behind(_target(s)):
		_pointer.get_child(0).get_child(-1).text = _pointer_text(s).to_upper()
		_pointer.reset_size()
		_pointer.visible = true
		_pointer.position = _cam.unproject_position(_target(s) + Vector3(0, 2.2, 0)) - Vector2(_pointer.size.x / 2, _pointer.size.y)
	else:
		_pointer.visible = false


func _pointer_text(s: Dictionary) -> String:
	match s.target:
		"Player": return "Ти"
		"Stations/Memory1": return "Спогад"
		"Stations/CandleBedroom": return "Свічка"
		"Visitors/Olena": return "Олена і Тарас"
		"Level/Rubble": return "Завал"
	return ""


func _input(e: InputEvent) -> void:
	if _cam == null or _diving:
		return
	if e.is_action_pressed("ui_cancel"):
		close()
	elif e.is_action_pressed("ui_accept") or e.is_action_pressed("ui_right") or (e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT and not _over_button()):
		go(step + 1)
	elif e.is_action_pressed("ui_left") or (e is InputEventKey and e.pressed and e.keycode == KEY_BACKSPACE):
		go(step - 1)
	else:
		return
	get_viewport().set_input_as_handled()


func _over_button() -> bool:
	var h := get_viewport().gui_get_hovered_control()
	return h is Button


## Skip / last step: dive back into the ghost's eyes, then hand control back.
func close() -> void:
	if _diving or _cam == null:
		return
	_diving = true
	_from = _cam.global_transform
	_fly = 0.0
	_pointer.visible = false
	for c in get_children():
		c.visible = false
	if _mark:
		_mark.queue_free()
		_mark = null


func _finish() -> void:
	game.get_node("Player").show_body(false)
	game.get_node("Player").camera.current = true
	_cam.queue_free()
	_light.queue_free()
	game.get_node("WorldEnvironment").environment.fog_density = _fog
	var hud := game.get_node_or_null("HUD") as CanvasLayer
	if hud:
		hud.visible = true
	get_tree().paused = false
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	finished.emit()
	queue_free()
