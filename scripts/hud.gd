extends CanvasLayer
## In-game UI from the "ВІДПУСТИ — UI" design (boards 04–14), built in code with the UI kit:
## HUD (visibility card, goal, stage panel, minimap, action tiles, E prompt, subtitles),
## altar (your bones) modal, fade / holy banners, map (M), quest + hints book (J), pause (Esc), hold-to-release card and the end screen.
## Runs while the tree is paused (the altar, pause and end screens pause it).

const UI = preload("res://scripts/ui.gd")
const Station = preload("res://scripts/station.gd")
const SCREENS := "res://scripts/screens.gd"  ## how-to / settings, written by the menu side

const LINE_TIME := 4.5  ## seconds a subtitle stays
const LEVEL_TINT := [Color(), Color(0.47, 0.92, 1, 0.45), Color(1, 0.77, 0.19, 0.22), Color(1, 0.56, 0.69, 0.35)]
const FADE_TINT := Color(0.47, 0.92, 1, 0.7)
const HURT_TINT := Color(1, 0.16, 0.24, 0.75)
const LEVEL_HINT := ["", "крізь стіни — вільно", "стіни кімнат тримають", "ритуал може тебе відпустити"]
const DARK_RED := Color("B3122A")
const DARK_GREEN := Color("3E8E1E")
const BOOK_SVG := '<path d="M4 5.5A2.5 2.5 0 0 1 6.5 3H20v15H6.5A2.5 2.5 0 0 0 4 20.5Z"/><path d="M4 20.5V5.5M8.5 8h7M8.5 11.5h5"/>'
const STAGE_NAMES := ["Страх", "Священник", "Заманювання", "Розкопки", "Докази", "Ритуал"]  ## by GameState.Stage
const STAGE_SHORT := ["Налякати", "Священник", "До завалу", "Розкопки", "Докази", "Ритуал"]  ## goal-panel steps
const ROOM := Rect2(17.5, -12.5, 6, 4.7)  ## your sealed room (x, z), from the level layout
const RUBBLE_POS := Vector3(17.5, 0, -10)  ## shortcut: map marker spot if the level has no "Rubble" node; use the node once it exists
const ALTAR_PROS := {
	2: ["+Люди можуть тебе побачити — це лякає ще дужче", "+Важкі речі шумлять сильніше", "+Можна підсвічувати докази у своїй кімнаті",
		"−Стіни кімнат більше не пропустять", "−Заряд тане: −0.05 за секунду"],
	3: ["+Тебе бачать усі — тільки так ритуал тебе відпустить", "+Утримуй E у колі, коли ритуал завершено", "−Меблі теж тримають", "−Заряд тане: −0.25 за секунду"],
}

var game  ## game.gd (untyped: its methods are not known statically)
var end_title: Label  ## set when the end screen is up (tests read it)
var _hud: Control  ## everything shown while playing
var _vignette: ColorRect
var _lvl_tile: PanelContainer
var _lvl_name: Label
var _lvl_num: Label
var _segs: Array[StyleBoxFlat] = []
var _charge_val: Label
var _pips: Array[StyleBoxFlat] = []
var _hint_l: Label
var _hint_r: Label
var _goal_text: Label
var _steps: Array[Dictionary] = []
var _stage_name: Label
var _stage_val: Label
var _stage_fill: Panel
var _priest_line: Label
var _mini_cam: Camera3D
var _room: Label
var _tiles := {}  ## "E"/"Q" -> {col, sb, icon, cap, badge}
var _prompt: PanelContainer
var _prompt_key: StyleBoxFlat
var _prompt_title: Label
var _prompt_sub: Label
var _line: PanelContainer
var _line_text: RichTextLabel
var _line_t := 0.0
var _banner: VBoxContainer
var _banner_title: Label
var _banner_pill: PanelContainer
var _banner_text: Label
var _letgo: Control
var _hold_fill: Panel
var _hold_label: Label
var _map: Control
var _map_cam: Camera3D
var _markers: Array = []  ## [node, pill]
var _spirit_rows: Array = []  ## [station, status label]
var _haunt_rows: Array = []  ## [station, status label]
var _altar: Control
var _altar_frame := -1
var _pause: Control
var _resume_btn: Button
var _sub: Control  ## how-to / settings screen opened from the pause
var _sub_frame := -1
var _end: Control
var _book: PanelContainer
var _book_badge: PanelContainer
var _quests: Array[Dictionary] = []
var _quest_priest: Label
var _hint_list: VBoxContainer
var _read := {}  ## hint ids seen in the open book
var _mouse_before := Input.MOUSE_MODE_VISIBLE  ## restored after pause / altar (captured in first person)
var _priest: Node3D
var _visitors: Array = []


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	game = get_parent()
	_visitors = get_tree().get_nodes_in_group("visitor")
	for n in _visitors:
		if _kind(n) == "PRIEST":
			_priest = n
	_hud = _full()
	add_child(_hud)
	_vignette = UI.vignette(LEVEL_TINT[1])
	_hud.add_child(_vignette)
	_build_card()
	_build_goal()
	_build_right()
	_build_bottom()
	_build_prompt()
	var dot := UI.panel(UI.PAPER, 999, 0, 0, 3)  # first-person crosshair
	dot.custom_minimum_size = Vector2(12, 12)
	dot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hud.add_child(dot)
	dot.set_anchors_and_offsets_preset(Control.PRESET_CENTER, Control.PRESET_MODE_MINSIZE)
	_build_banner()
	_build_letgo()
	_build_map()
	_build_book()
	GameState.said.connect(_on_said)
	GameState.hint_unlocked.connect(func(_id): _rebuild_hints())
	GameState.altar_requested.connect(_open_altar)
	GameState.finished.connect(_on_finished)


func _exit_tree() -> void:
	get_tree().paused = false
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func _unhandled_input(e: InputEvent) -> void:
	if _end:
		return
	var frame := Engine.get_process_frames()
	if e.is_action_pressed("ui_cancel"):
		if is_instance_valid(_sub) or frame == _sub_frame:
			return  # the how-to / settings screen handles its own Esc
		if _altar:
			_close_altar()
		elif _book.visible:
			toggle_book()
		elif _map.visible:
			_map.hide()
		elif _pause:
			resume()
		else:
			open_pause()
		get_viewport().set_input_as_handled()
	elif e.is_action_pressed("interact") and _altar and frame != _altar_frame:
		_altar_confirm()
		get_viewport().set_input_as_handled()
	elif e.is_action_pressed("map") and not get_tree().paused:
		toggle_map()
		get_viewport().set_input_as_handled()
	elif e.is_action_pressed("journal") and not get_tree().paused:
		toggle_book()
		get_viewport().set_input_as_handled()


func _process(delta: float) -> void:
	_line_t -= delta
	_line.visible = _line_t > 0 and GameState.subtitles
	if _end:
		return
	var t = game.player.target_station()
	if not t is Station:
		t = null  # visitors are not aim targets
	_update_card()
	_update_goal()
	_update_right()
	_update_bottom(t)
	var letting: bool = game.at_release()
	_letgo.visible = letting
	_update_banner()
	if letting:
		var f: float = game.hold / game.RELEASE_TIME
		_hold_fill.size = Vector2((_hold_fill.get_parent().size.x - 8) * f, 26)
		_hold_label.text = "%.1f с" % maxf(game.RELEASE_TIME - game.hold, 0)
	_update_prompt(null if letting else t)
	if _map.visible:
		_update_map()
	if _book.visible:
		_update_book()


# --- layout helpers ---

func _full() -> Control:
	var c := Control.new()
	c.set_anchors_preset(Control.PRESET_FULL_RECT)
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return c


## Pin `c` to an edge / corner of `parent` (preset) with a margin; it grows away from that edge.
func _pin(c: Control, preset: int, mx := 40.0, my := 36.0, parent: Control = null) -> Control:
	(parent if parent else _hud).add_child(c)
	c.set_anchors_preset(preset)
	var grow := [Control.GROW_DIRECTION_END, Control.GROW_DIRECTION_BOTH, Control.GROW_DIRECTION_BEGIN]
	c.grow_horizontal = grow[int(c.anchor_left * 2)]
	c.grow_vertical = grow[int(c.anchor_top * 2)]
	var ox: float = [mx, 0.0, -mx][int(c.anchor_left * 2)]
	var oy: float = [my, 0.0, -my][int(c.anchor_top * 2)]
	c.offset_left = ox
	c.offset_right = ox
	c.offset_top = oy
	c.offset_bottom = oy
	return c


func _sb(p: Control) -> StyleBoxFlat:
	return p.get_theme_stylebox("panel") as StyleBoxFlat


func _expand(c: Control, align := HORIZONTAL_ALIGNMENT_RIGHT) -> Control:
	c.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if c is Label:
		(c as Label).horizontal_alignment = align
	return c


func _wrap(l: Label, width: float) -> Label:
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size.x = width
	return l


func _hand(text: String, size := 24, color := UI.MUTED) -> Label:
	return UI.label(text, size, color, "hand", 700)


func _set_color(l: Label, c: Color) -> void:
	l.label_settings.font_color = c


func _ring(color: Color, size := 16) -> PanelContainer:
	var r := UI.panel(Color(0, 0, 0, 0), 999, 0, 0, 3, color)
	r.custom_minimum_size = Vector2(size, size)
	r.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	return r


## Goal step: ring (todo / current) or check (done) + text.
func _step(parent: Control, size := 17) -> Dictionary:
	var row := UI.hbox(6)
	var d := {ring = _ring(UI.DIM), check = UI.icon("check", size + 2, UI.GREEN), label = UI.label("", size, UI.DIM, "body", 600)}
	for k in ["ring", "check", "label"]:
		row.add_child(d[k])
	parent.add_child(row)
	return d


func _set_step(d: Dictionary, text: String, state: int) -> void:  ## 0 later, 1 current, 2 done
	d.label.text = text
	d.ring.visible = state < 2
	d.check.visible = state == 2
	_sb(d.ring).border_color = UI.GOLD if state == 1 else UI.DIM
	_set_color(d.label, [UI.DIM, UI.PAPER, UI.GREEN][state])


## Stage step state: 0 later, 1 current, 2 done (the last stage is done once you are free).
func _stage_state(i: int) -> int:
	if i < GameState.stage or GameState.won:
		return 2
	return 1 if i == GameState.stage else 0


## Enum key of a station / visitor kind ("HAUNT", "PRIEST"...), so new kinds need no preload here.
func _kind(n) -> String:
	var k = n.get_script().get_script_constant_map().get("Kind", {})
	return str(k.find_key(n.kind)) if n.get("kind") != null else ""


## Current stage progress: [0..1 or -1 for none, text].
func _stage_progress() -> Array:
	match GameState.stage:
		GameState.Stage.HAUNT:
			return [GameState.unease / GameState.UNEASE_TO_CALL, "страх %d%%" % int(100 * minf(GameState.unease / GameState.UNEASE_TO_CALL, 1))]
		GameState.Stage.DIG:
			return [GameState.dig, "%d%%" % int(100 * GameState.dig)]
		GameState.Stage.EVIDENCE:
			return [float(GameState.evidence) / GameState.EVIDENCE_NEEDED, "%d / %d" % [GameState.evidence, GameState.EVIDENCE_NEEDED]]
		GameState.Stage.RITUAL:
			return [GameState.ritual, "%d%%" % int(100 * GameState.ritual)]
	return [-1.0, ""]


func _priest_status() -> String:
	if GameState.stage == GameState.Stage.HAUNT:
		return "Священник: ще не кликали"
	return "Священник: тут" if _priest and _priest.visible else "Священник: в дорозі"


func _room_at(p: Vector3) -> String:
	if ROOM.has_point(Vector2(p.x, p.z)):
		return "Твоя кімната"
	return "Біля входу" if p.z > 8 else "Підземелля"


## Pause / modal UI needs the cursor; play may have it captured (first person).
func _free_mouse() -> void:
	_mouse_before = Input.mouse_mode
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func _times(n: int) -> String:
	if n % 10 == 1 and n % 100 != 11:
		return "%d раз" % n
	if n % 10 in [2, 3, 4] and not n % 100 in [12, 13, 14]:
		return "%d рази" % n
	return "%d разів" % n


func _clock(sec: float) -> String:
	return "%d:%02d" % [int(sec) / 60, int(sec) % 60]


func _orbit_cam(size: float) -> Camera3D:
	var cam := Camera3D.new()
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	cam.size = size
	cam.far = 100
	cam.cull_mask = 1  # world only: labels live on layer 2
	cam.rotation_degrees.x = -90  # straight down, north up
	cam.current = true
	return cam


## SubViewport showing the world from `cam`, sized `sz`.
func _view(cam: Camera3D, sz: Vector2) -> Control:
	var holder := Control.new()
	holder.custom_minimum_size = sz
	var svc := SubViewportContainer.new()
	svc.stretch = true
	svc.set_anchors_preset(Control.PRESET_FULL_RECT)
	svc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var vp := SubViewport.new()
	vp.add_child(cam)
	svc.add_child(vp)
	holder.add_child(svc)
	return holder


# --- HUD ---

func _build_card() -> void:
	var card := UI.panel(UI.PAPER, 26, 7, 20)
	card.custom_minimum_size.x = 540
	_pin(card, Control.PRESET_TOP_LEFT)
	var col := UI.vbox(12)
	card.add_child(col)
	var head := UI.hbox(14)
	col.add_child(head)
	_lvl_tile = UI.panel(UI.CYAN, 14, 0, 6, 4)
	_lvl_tile.add_child(UI.icon("ghost", 30))
	head.add_child(_lvl_tile)
	var names := UI.vbox(0)
	names.add_child(UI.label("Видимість", 14, UI.LABEL, "body", 900, true))
	_lvl_name = UI.label("", 30, UI.INK, "body", 900, true)
	names.add_child(_lvl_name)
	head.add_child(names)
	_lvl_num = UI.label("", 40, UI.INK, "body", 900)
	head.add_child(_expand(_lvl_num))
	var bar := UI.hbox(4)
	var caps := UI.hbox(4)
	col.add_child(bar)
	col.add_child(caps)
	for i in 3:
		var seg := UI.panel(UI.LILAC, 12, 0, 0, 4)
		seg.custom_minimum_size.y = 30
		bar.add_child(_expand(seg))
		_segs.append(_sb(seg))
		caps.add_child(_expand(UI.label(GameState.LEVEL_NAMES[i + 1], 14, UI.LABEL, "body", 800, true), [HORIZONTAL_ALIGNMENT_LEFT, HORIZONTAL_ALIGNMENT_CENTER, HORIZONTAL_ALIGNMENT_RIGHT][i]))
	col.add_child(UI.rule())
	var row := UI.hbox(10)
	col.add_child(row)
	row.add_child(UI.icon("bolt", 26))
	row.add_child(UI.label("Заряд", 22, UI.INK, "body", 900, true))
	_charge_val = UI.label("", 28, UI.INK, "body", 900)
	row.add_child(_expand(_charge_val))
	var pips := UI.hbox(7)
	col.add_child(pips)
	for i in int(GameState.MAX_CHARGE):
		var p := UI.panel(UI.LILAC, 9, 0, 0, 4)
		p.custom_minimum_size = Vector2(38, 34)
		pips.add_child(p)
		_pips.append(_sb(p))
	var hints := UI.hbox(24)
	col.add_child(hints)
	_hint_l = _hand("", 22)
	_hint_r = _hand("", 22)
	hints.add_child(_expand(_hint_l, HORIZONTAL_ALIGNMENT_LEFT))
	hints.add_child(_expand(_hint_r))


func _update_card() -> void:
	var l: int = GameState.level
	var hurt: bool = GameState.hurt > 0
	_sb(_lvl_tile).bg_color = UI.CYAN if GameState.is_fading() else UI.LEVEL_COLORS[l]
	_lvl_name.text = GameState.LEVEL_NAMES[l]
	_lvl_num.text = "%d/%d" % [l, GameState.MAX_LEVEL]
	for i in 3:
		_segs[i].bg_color = UI.LEVEL_COLORS[i + 1] if i < l else UI.LILAC
	_charge_val.text = "%.1f / %d" % [GameState.charge, GameState.MAX_CHARGE]
	_set_color(_charge_val, DARK_RED if hurt or (l > 1 and GameState.charge < 1) else UI.INK)
	var full := UI.RED if hurt else UI.CHARGE
	for i in _pips.size():
		var fill := clampf(GameState.charge - i, 0, 1)
		_pips[i].bg_color = full if fill >= 0.999 else (full.lerp(UI.LILAC, 0.55) if fill > 0.05 else UI.LILAC)
		_pips[i].shadow_offset = Vector2(0, 4) if fill >= 0.999 else Vector2.ZERO
	if GameState.is_fading():
		_hint_l.text = "крізь усі стіни"
	elif hurt:
		_hint_l.text = "на нулі — " + ("рівень %d" % (l - 1) if l > 1 else "назад на старт")
	else:
		_hint_l.text = LEVEL_HINT[l]
	if l < GameState.MAX_LEVEL:
		var need: float = GameState.LEVEL_REQ[l + 1] - GameState.charge
		_hint_r.text = "до рівня %d ще %d →" % [l + 1, ceili(need)] if need > 0 else "на вівтар →"
	else:
		_hint_r.text = "тане −%.2f/с" % GameState.UPKEEP[l]


func _build_goal() -> void:
	var g := UI.panel(UI.SHADE, 22, 0, 18, 4, UI.GOLD)
	g.custom_minimum_size.x = 740
	_pin(g, Control.PRESET_CENTER_TOP)
	var col := UI.vbox(10)
	g.add_child(col)
	var row := UI.hbox(12)
	col.add_child(row)
	row.add_child(UI.chip("ЦІЛЬ", UI.GOLD, UI.INK, 16, 0))
	_goal_text = UI.label("", 21, UI.PAPER, "body", 700)
	_goal_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	row.add_child(_expand(_goal_text, HORIZONTAL_ALIGNMENT_LEFT))
	var steps := UI.hbox(14)
	col.add_child(steps)
	for i in STAGE_SHORT.size():
		_steps.append(_step(steps, 15))


func _update_goal() -> void:
	_goal_text.text = GameState.goal()
	for i in _steps.size():
		_set_step(_steps[i], STAGE_SHORT[i], _stage_state(i))


func _build_right() -> void:
	var col := UI.vbox(12)
	_pin(col, Control.PRESET_TOP_RIGHT)
	var c := UI.panel(UI.INK, 18, 0, 12, 4, UI.GOLD)
	_sb(c).content_margin_right = 20  # bold glyphs overhang the measured width
	c.custom_minimum_size.x = 300
	var cv := UI.vbox(6)
	c.add_child(cv)
	cv.add_child(UI.label("Етап", 13, UI.DIM, "body", 900, true))
	var row := UI.hbox(10)
	cv.add_child(row)
	_stage_name = UI.label("", 26, UI.PAPER, "body", 900)
	row.add_child(_stage_name)
	_stage_val = UI.label("", 18, UI.GOLD, "body", 900)
	row.add_child(_expand(_stage_val))
	var bar := Panel.new()
	bar.custom_minimum_size.y = 18
	bar.add_theme_stylebox_override("panel", UI.style(UI.LILAC, 999, 3))
	_stage_fill = Panel.new()
	_stage_fill.position = Vector2(3, 3)
	_stage_fill.add_theme_stylebox_override("panel", UI.style(UI.GOLD, 999, 0))
	bar.add_child(_stage_fill)
	cv.add_child(bar)
	_priest_line = UI.label("", 16, UI.DIM, "body", 700)
	cv.add_child(_priest_line)
	var mm := UI.panel(UI.INK, 26, 0, 12, 5, UI.PAPER)
	var mv := UI.vbox(8)
	mm.add_child(mv)
	_mini_cam = _orbit_cam(18)
	var view := _view(_mini_cam, Vector2(226, 170))
	var me := UI.icon("ghost", 26, UI.CYAN)
	view.add_child(me)
	me.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	mv.add_child(view)
	var foot := UI.hbox(8)
	mv.add_child(foot)
	_room = UI.label("", 15, UI.PAPER, "body", 700)
	foot.add_child(_expand(_room, HORIZONTAL_ALIGNMENT_LEFT))
	foot.add_child(UI.chip("M", UI.PAPER, UI.INK, 14, 2))
	for p in [_book_tile(), c, mm]:
		p.size_flags_horizontal = Control.SIZE_SHRINK_END
		col.add_child(p)


func _update_right() -> void:
	_stage_name.text = STAGE_NAMES[GameState.stage]
	var pr := _stage_progress()
	_stage_val.text = pr[1]
	_stage_fill.get_parent().visible = pr[0] >= 0
	_stage_fill.size = Vector2((_stage_fill.get_parent().size.x - 6) * clampf(pr[0], 0, 1), 12)
	_priest_line.text = _priest_status()
	var p: Vector3 = game.player.global_position
	_mini_cam.global_position = Vector3(p.x, 30, p.z)
	_room.text = _room_at(p)


func _build_bottom() -> void:
	var esc := UI.panel(Color(UI.INK, 0.82), 14, 0, 8, 3, UI.PAPER)
	var er := UI.hbox(10)
	esc.add_child(er)
	er.add_child(UI.chip("Esc"))
	er.add_child(UI.label("Пауза", 17, UI.PAPER, "body", 700))
	_pin(esc, Control.PRESET_BOTTOM_LEFT, 40, 40)

	_line = UI.panel(Color(UI.INK, 0.82), 14, 0, 10, 0)
	_line_text = RichTextLabel.new()
	_line_text.bbcode_enabled = true
	_line_text.fit_content = true
	_line_text.custom_minimum_size.x = 600
	_line_text.add_theme_font_override("normal_font", UI.font("body", 500))
	_line_text.add_theme_font_override("bold_font", UI.font("body", 800))
	_line_text.add_theme_font_size_override("normal_font_size", 21)
	_line_text.add_theme_font_size_override("bold_font_size", 21)
	_line_text.add_theme_color_override("default_color", UI.PAPER)
	_line.add_child(_line_text)
	_pin(_line, Control.PRESET_CENTER_BOTTOM, 0, 40)
	_line.hide()

	var br := UI.hbox(14)
	br.alignment = BoxContainer.ALIGNMENT_END
	_pin(br, Control.PRESET_BOTTOM_RIGHT)
	var tiles := UI.hbox(12)
	br.add_child(tiles)
	for k in ["E", "Q"]:
		var col := UI.action_tile(k, "hand", UI.GOLD, "")
		var tile: PanelContainer = col.get_child(0)
		var badge := UI.chip("", UI.CHARGE, UI.INK, 14, 3)
		badge.size_flags_horizontal = Control.SIZE_SHRINK_END
		badge.size_flags_vertical = Control.SIZE_SHRINK_END
		tile.add_child(badge)
		tiles.add_child(col)
		_tiles[k] = {col = col, sb = _sb(tile), icon = tile.get_child(0), cap = col.get_child(1).get_child(0), badge = badge}


func _set_tile(k: String, bg: Color, icon_name: String, caption: String, badge := "", badge_bg := UI.CHARGE) -> void:
	var t: Dictionary = _tiles[k]
	t.sb.bg_color = bg
	t.icon.texture = UI.icon_texture(icon_name, 44, Color("5A4A6E") if bg == UI.GREY else UI.INK)
	t.cap.text = caption
	t.badge.visible = badge != ""
	t.badge.get_child(0).text = badge
	_sb(t.badge).bg_color = badge_bg


func _verb(t) -> String:
	return {"SPIRIT": "Зарядитися", "ALTAR": "Твої кістки", "HAUNT": "Шуміти", "EVIDENCE": "Підсвітити", "CIRCLE": "Утримуй"}.get(_kind(t), "Взаємодія")


func _update_bottom(t) -> void:
	if t == null:
		_set_tile("E", UI.GREY, "hand", "Взаємодія")
	elif t.can_use():
		_set_tile("E", UI.MOM if _kind(t) == "CIRCLE" else UI.GOLD, "hand", _verb(t))
	else:
		_set_tile("E", UI.GREY, "lock", _verb(t))
	if GameState.is_fading():
		_set_tile("Q", UI.CYAN, "ghost_dashed", "Невидимий %.1f" % GameState.fade_left)
	elif GameState.charge >= GameState.FADE_COST:
		_set_tile("Q", UI.CYAN, "ghost_dashed", "Сховатися", "−%d" % GameState.FADE_COST)
	else:
		_set_tile("Q", UI.GREY, "ghost_dashed", "Мало заряду", "−%d" % GameState.FADE_COST, UI.RED)


func _build_prompt() -> void:
	_prompt = UI.panel(UI.PAPER, 20, 6, 12)
	var row := UI.hbox(14)
	_prompt.add_child(row)
	var key := UI.panel(UI.GOLD, 12, 0, 0, 4)
	_prompt_key = _sb(key)
	_prompt_key.shadow_color = UI.INK
	_prompt_key.shadow_size = 1
	_prompt_key.shadow_offset = Vector2(0, 4)
	key.custom_minimum_size = Vector2(50, 50)
	var kl := UI.label("E", 26, UI.INK, "body", 900)
	kl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	kl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	key.add_child(kl)
	key.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(key)
	var col := UI.vbox(0)
	row.add_child(col)
	_prompt_title = UI.label("", 24, UI.INK, "body", 900, true)
	_prompt_sub = UI.label("", 17, UI.MUTED, "body", 600)
	col.add_child(_prompt_title)
	col.add_child(_prompt_sub)
	_hud.add_child(_prompt)
	_prompt.hide()


func _prompt_hint(t) -> String:
	match _kind(t):
		"SPIRIT":
			return "+%d заряд, потім %d с перерви" % [Station.SPIRIT_CHARGE, Station.SPIRIT_COOLDOWN]
		"ALTAR":
			return "вівтар · поріг заряду, нічого не витрачає"
		"HAUNT":
			return "ще %d с тиші" % ceili(t.cooldown) if t.cooldown > 0 else "−1 заряд · люди поруч підуть на звук"
		"EVIDENCE":
			if t.shown:
				return "вже показано"
			return "з рівня 2" if GameState.level < 2 else "люди мають бути поруч"
		"CIRCLE":
			if GameState.release_ready():
				return "ритуал завершено · утримуй E"
			return "стань Присутністю (рівень 3)" if GameState.stage == GameState.Stage.RITUAL and GameState.ritual >= 1.0 else "чекай, поки священник завершить ритуал"
	return ""


## E card floating above the target in the world.
func _update_prompt(t) -> void:
	var cam := get_viewport().get_camera_3d()
	var top: Vector3 = t.global_position + Vector3.UP * 1.6 if t else Vector3.ZERO
	_prompt.visible = t != null and cam and not cam.is_position_behind(top)
	if not _prompt.visible:
		return
	_prompt_title.text = t.title().replace(": ", " · ")
	_prompt_sub.text = _prompt_hint(t)
	_prompt_key.bg_color = UI.GOLD if t.can_use() else UI.GREY
	_prompt.size = Vector2.ZERO  # shrink to the new text
	_prompt.position = cam.unproject_position(top) - Vector2(_prompt.size.x / 2, _prompt.size.y + 20)


# --- fade / hurt (boards 08, 09) ---

func _build_banner() -> void:
	_banner = UI.vbox(8)
	_banner.alignment = BoxContainer.ALIGNMENT_CENTER
	_pin(_banner, Control.PRESET_CENTER_TOP, 0, 170)
	_banner_title = UI.title("", 96)
	_banner_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_banner.add_child(_banner_title)
	_banner_pill = UI.panel(UI.CYAN, 999, 4, 6, 4)
	_banner_pill.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_banner_text = UI.label("", 18, UI.INK, "body", 900, true)
	_banner_pill.add_child(_banner_text)
	_banner.add_child(_banner_pill)


func _update_banner() -> void:
	var tint: Color = LEVEL_TINT[GameState.level]
	_banner.visible = not _letgo.visible
	if GameState.hurt > 0:
		tint = HURT_TINT
		_banner_title.text = "Святе світло пече!"
		_set_color(_banner_title, UI.GOLD)
		_sb(_banner_pill).bg_color = UI.GOLD
		_banner_text.text = "відлети від священника · −%d заряду/с" % GameState.HOLY_DRAIN
	elif GameState.is_fading() and GameState.grace <= 0:
		_banner_title.text = "Зник! %.1f с" % GameState.fade_left
		_set_color(_banner_title, UI.CYAN)
		_sb(_banner_pill).bg_color = UI.CYAN
		_banner_text.text = "тебе не бачить ніхто · крізь усі стіни"
	else:
		_banner.visible = false
	if GameState.hurt <= 0 and GameState.is_fading():
		tint = FADE_TINT
	(_vignette.material as ShaderMaterial).set_shader_parameter("tint", tint)


# --- hold to release (board 12) ---

func _build_letgo() -> void:
	_letgo = _full()
	_hud.add_child(_letgo)
	var priest := UI.panel(UI.PAPER, 26, 7, 18)
	priest.position = Vector2(640, 180)
	var mv := UI.vbox(6)
	priest.add_child(mv)
	mv.add_child(UI.label(_priest.title_text if _priest else "Священник", 16, UI.MUTED, "body", 900, true))
	mv.add_child(_wrap(UI.label("Душе, що страждала тут, — тебе знайшли й пам'ятають. Іди з миром.", 24, UI.INK, "body", 600), 380))
	_letgo.add_child(priest)
	var me := UI.panel(Color("E6FCFF"), 26, 6, 18)
	me.position = Vector2(1060, 300)
	me.rotation_degrees = 2
	me.add_child(_hand("Двісті років у цій темряві…\nТепер я можу піти.", 38, UI.INK))
	_letgo.add_child(me)
	var card := UI.panel(UI.PAPER, 28, 9, 22)
	card.custom_minimum_size.x = 760
	_pin(card, Control.PRESET_CENTER_BOTTOM, 0, 150, _letgo)
	var col := UI.vbox(14)
	card.add_child(col)
	var row := UI.hbox(16)
	col.add_child(row)
	var key := UI.panel(UI.MOM, 12, 0, 0, 4)
	key.custom_minimum_size = Vector2(56, 56)
	var kl := UI.label("E", 28, UI.INK, "body", 900)
	kl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	kl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	key.add_child(kl)
	row.add_child(key)
	var tv := UI.vbox(2)
	tv.add_child(UI.label("Утримуй — піти", 34, UI.INK, "body", 900, true))
	tv.add_child(UI.label("ритуал завершено · залиш підземелля назавжди", 18, UI.MUTED, "body", 600))
	row.add_child(tv)
	_hold_label = UI.label("", 40, UI.INK, "body", 900)
	row.add_child(_expand(_hold_label))
	var bar := Panel.new()
	bar.custom_minimum_size.y = 34
	bar.add_theme_stylebox_override("panel", UI.style(UI.LILAC, 999, 4))
	_hold_fill = Panel.new()
	_hold_fill.position = Vector2(4, 4)
	_hold_fill.add_theme_stylebox_override("panel", UI.style(UI.MOM, 999, 0))
	bar.add_child(_hold_fill)
	col.add_child(bar)
	col.add_child(_hand("відпустиш кнопку — почнеш спочатку", 26))
	_letgo.hide()


# --- map (board 10) ---

func _build_map() -> void:
	_map = _full()
	_map.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_map)
	_map.add_child(UI.backdrop(Color(UI.INK, 0.86)))
	var t := UI.title("Карта", 80)
	t.position = Vector2(60, 24)
	_map.add_child(t)
	var frame := UI.panel(UI.NIGHT2, 26, 8, 10, 5, UI.PAPER)
	frame.position = Vector2(60, 150)
	_map.add_child(frame)
	_map_cam = _orbit_cam(28.5)
	_map_cam.position = Vector3(4.75, 40, -0.25)  # dungeon x −14.5..24, z −13..12.5
	var view := _view(_map_cam, Vector2(1080, 780))
	frame.add_child(view)
	var stations: Array = game.get_node("Stations").get_children()
	var mark := func(target, text: String, color: Color, until_dug := false):
		var pill := UI.pill(text, color, 15)
		view.add_child(pill)
		_markers.append([target, pill, until_dug])
	for s in stations:
		if _kind(s) == "ALTAR":
			mark.call(s, "Твої кістки", UI.CHARGE)
	var rubble = game.find_child("Rubble", true, false)
	mark.call(rubble if rubble is Node3D else RUBBLE_POS, "Завал", UI.ORANGE, true)
	for n in _visitors:
		mark.call(n, n.title_text, UI.PAPER if _kind(n) == "PRIEST" else UI.GOLD)
	mark.call(game.get_node("Player"), "Ти", UI.CYAN)  # last = on top; game.player is @onready, not set yet

	var leg := UI.panel(UI.PAPER, 26, 8, 24)
	leg.custom_minimum_size.x = 620
	_pin(leg, Control.PRESET_TOP_RIGHT, 60, 150, _map)
	var col := UI.vbox(8)
	leg.add_child(col)
	var head := func(text: String):
		col.add_child(UI.label(text, 22, UI.INK, "body", 900, true))
	head.call("Стіни")
	for line in ["Зовнішні — тримають завжди", "Стіни кімнат — тримають з рівня 2", "Меблі — тримають з рівня 3",
			"Q — %d с крізь усі внутрішні" % GameState.FADE_TIME, "Священник — святе світло, пече"]:
		col.add_child(UI.label("· " + line, 19, UI.MUTED, "body", 600))
	col.add_child(UI.rule())
	head.call("Де зарядитися")
	var row_of := func(text: String) -> Label:
		var r := UI.hbox(8)
		r.add_child(UI.label(text, 19, UI.INK, "body", 700))
		var st := UI.label("", 19, UI.INK, "body", 900)
		r.add_child(_expand(st))
		col.add_child(r)
		return st
	for s in stations:
		if _kind(s) == "SPIRIT":
			_spirit_rows.append([s, row_of.call(s.title_text)])
	col.add_child(_hand("Кожна річ дає +%d і відпочиває %d с." % [Station.SPIRIT_CHARGE, Station.SPIRIT_COOLDOWN], 24))
	col.add_child(UI.rule())
	head.call("Чим шуміти")
	for s in stations:
		if _kind(s) == "HAUNT":
			_haunt_rows.append([s, row_of.call(s.title_text)])
	col.add_child(_hand("−1 заряд · люди йдуть на звук", 24))
	var foot := UI.hbox(10)
	foot.add_child(UI.chip("M"))
	foot.add_child(UI.label("закрити карту", 18, UI.PAPER, "body", 700))
	foot.add_child(UI.label("· гра не на паузі", 18, UI.DIM, "body", 600))
	_pin(foot, Control.PRESET_BOTTOM_LEFT, 60, 40, _map)
	_map.hide()


func toggle_map() -> void:
	_map.visible = not _map.visible
	if _map.visible and _book.visible:
		toggle_book()


func _update_map() -> void:
	for m in _markers:
		var n = m[0]
		var pill: Control = m[1]
		var at: bool = n is Vector3 or (is_instance_valid(n) and n.is_visible_in_tree())
		pill.visible = at and not (m[2] and GameState.stage > GameState.Stage.DIG)
		if pill.visible:
			pill.position = _map_cam.unproject_position(n if n is Vector3 else n.global_position) - pill.size / 2
	for r in _spirit_rows + _haunt_rows:
		var s = r[0]
		var st: Label = r[1]
		if GameState.level < s.min_level:
			st.text = "рівень %d" % s.min_level
			_set_color(st, UI.LABEL)
		elif s.cooldown > 0:
			st.text = "%d с" % ceili(s.cooldown)
			_set_color(st, UI.ORANGE)
		else:
			st.text = "готово"
			_set_color(st, DARK_GREEN)


# --- quest + hints book (J) ---

func _book_icon(size: int) -> TextureRect:
	var img := Image.new()
	img.load_svg_from_string('<svg xmlns="http://www.w3.org/2000/svg" width="24" height="24" viewBox="0 0 24 24" fill="none" stroke="#17111C" stroke-width="2.4" stroke-linecap="round" stroke-linejoin="round">%s</svg>' % BOOK_SVG, size / 24.0)
	var t := UI.icon("ghost", size)
	t.texture = ImageTexture.create_from_image(img)
	return t


## Closed book: tile in the top-right column with the unread-hints badge.
func _book_tile() -> PanelContainer:
	var p := UI.panel(UI.GOLD, 18, 5, 10, 4)
	var row := UI.hbox(10)
	p.add_child(row)
	row.add_child(_book_icon(30))
	row.add_child(UI.label("Книга", 18, UI.INK, "body", 900, true))
	row.add_child(UI.chip("J"))
	_book_badge = UI.chip("0", UI.RED, UI.INK, 15, 3)
	row.add_child(_book_badge)
	_book_badge.hide()
	return p


func _build_book() -> void:
	_book = UI.panel(UI.INK, 30, 10, 14, 5)
	_pin(_book, Control.PRESET_TOP_RIGHT)
	var pages := UI.hbox(10)
	_book.add_child(pages)
	var page := func(title: String, color: Color, bg: Color) -> VBoxContainer:
		var pp := UI.panel(bg, 20, 0, 22, 0)
		pp.custom_minimum_size = Vector2(500, 760)
		var v := UI.vbox(8)
		pp.add_child(v)
		var head := UI.hbox(10)
		head.add_child(UI.title(title, 54, color))
		v.add_child(head)
		pages.add_child(pp)
		return v
	var left: VBoxContainer = page.call("Квести", UI.GOLD, UI.PAPER)
	left.get_child(0).add_child(_expand(_hand("J / Esc — закрити", 22)))
	for i in STAGE_NAMES.size():
		var row := UI.panel(Color(0, 0, 0, 0), 12, 0, 8, 0)
		var rv := UI.vbox(2)
		row.add_child(rv)
		var d := _step(rv, 20)
		d.panel = row
		d.sub = _wrap(UI.label("", 16, UI.MUTED, "body", 600), 430)
		rv.add_child(d.sub)
		left.add_child(row)
		_quests.append(d)
	left.add_child(UI.rule())
	_quest_priest = UI.label("", 19, UI.INK, "body", 900)
	left.add_child(_quest_priest)
	var right: VBoxContainer = page.call("Підказки", UI.CHARGE, Color("FFF6E0"))
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_hint_list = UI.vbox(10)
	_hint_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_hint_list)
	right.add_child(scroll)
	_book.hide()
	_rebuild_hints()


## J: the book drops from the top-right corner (the game keeps running); closing marks hints read.
func toggle_book() -> void:
	if _book.visible:
		for id in GameState.hints:
			_read[id] = true
		_book.hide()
	else:
		_map.hide()
		_book.show()
		_update_book()
		_book.position.y = -800
		create_tween().tween_property(_book, "position:y", 36.0, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_rebuild_hints()


## One quest per story stage; the current one shows the live goal and progress.
func _update_book() -> void:
	var pr := _stage_progress()
	for i in _quests.size():
		var d: Dictionary = _quests[i]
		var s := _stage_state(i)
		_set_step(d, "%d · %s" % [i + 1, STAGE_NAMES[i]], s)
		_set_color(d.label, [UI.LABEL, UI.INK, DARK_GREEN][s])
		_sb(d.ring).border_color = UI.INK if s == 1 else UI.LABEL
		_sb(d.panel).bg_color = Color(UI.GOLD, 0.85) if s == 1 else Color(0, 0, 0, 0)
		d.sub.text = GameState.goal() + (" · " + pr[1] if pr[1] != "" else "") if s == 1 else GameState.STAGE_GOALS[i]
	_quest_priest.text = _priest_status()


## Hints, newest first; unread ones stand out until the book is closed.
func _rebuild_hints() -> void:
	for c in _hint_list.get_children():
		c.queue_free()
	var unread := 0
	for i in range(GameState.hints.size() - 1, -1, -1):
		var id: String = GameState.hints[i]
		var fresh: bool = not _read.has(id)
		unread += int(fresh)
		var p := UI.panel(UI.PAPER if fresh else UI.LILAC, 16, 4 if fresh else 0, 12, 3, UI.ORANGE if fresh else UI.INK)
		var r := UI.hbox(10)
		p.add_child(r)
		if fresh:
			var chip := UI.chip("нове", UI.ORANGE, UI.INK, 14, 2)
			chip.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
			r.add_child(chip)
		r.add_child(_wrap(UI.label(GameState.HINTS[id], 18, UI.INK, "body", 600), 370 if fresh else 440))
		_hint_list.add_child(p)
	if GameState.hints.is_empty():
		_hint_list.add_child(_hand("Поки порожньо…", 26))
	_book_badge.visible = unread > 0
	_book_badge.get_child(0).text = str(unread)


# --- altar (board 07) ---

func _open_altar() -> void:
	if _altar or GameState.level >= GameState.MAX_LEVEL:
		return
	get_tree().paused = true
	_free_mouse()
	_altar_frame = Engine.get_process_frames()
	var l: int = GameState.level
	var need := int(GameState.LEVEL_REQ[l + 1])
	var have := mini(int(GameState.charge), need)
	_altar = _full()
	_altar.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_altar)
	_altar.add_child(UI.backdrop(Color(UI.INK, 0.45)))
	var box := UI.panel(UI.PAPER, 30, 10, 32)
	box.custom_minimum_size.x = 660
	_pin(box, Control.PRESET_TOP_RIGHT, 80, 150, _altar)
	var col := UI.vbox(20)
	box.add_child(col)
	var head := UI.hbox(12)
	col.add_child(head)
	head.add_child(UI.title("Твої кістки", 76, UI.CHARGE))
	head.add_child(_expand(_hand("ланцюги дзенькають…", 30)))
	var lv := UI.hbox(16)
	col.add_child(lv)
	for i in 2:
		var lvl := l + i
		var p := UI.panel(UI.LEVEL_COLORS[lvl] if i else UI.LEVEL_COLORS[lvl].lerp(UI.PAPER, 0.75), 18, 0, 14, 4)
		if i:
			_sb(p).shadow_color = UI.INK
			_sb(p).shadow_size = 1
			_sb(p).shadow_offset = Vector2(0, 5)
		var pv := UI.vbox(6)
		pv.add_child(UI.label(["Зараз", "Станеш"][i], 13, UI.LABEL, "body", 900, true))
		pv.add_child(UI.label("%d · %s" % [lvl, GameState.LEVEL_NAMES[lvl]], 30, UI.INK, "body", 900, true))
		p.add_child(pv)
		lv.add_child(_expand(p))
		if i == 0:
			lv.add_child(UI.label("→", 44, UI.INK, "body", 900))
	var list := UI.vbox(10)
	col.add_child(list)
	for line: String in ALTAR_PROS[l + 1]:
		var r := UI.hbox(12)
		var plus := line[0] == "+"
		var mark := UI.chip(line[0], UI.GREEN if plus else UI.RED, UI.INK, 18, 3)
		mark.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
		r.add_child(mark)
		r.add_child(_wrap(UI.label(line.substr(1), 20, UI.INK, "body", 600), 520))
		list.add_child(r)
	var price := UI.panel(UI.LILAC, 18, 0, 14, 4)
	col.add_child(price)
	var pr := UI.hbox(14)
	price.add_child(pr)
	pr.add_child(UI.label("Ціна", 20, UI.INK, "body", 900, true))
	var pips := UI.hbox(5)
	pr.add_child(pips)
	for i in need:
		var pip := UI.panel(UI.CHARGE if i < have else UI.PAPER, 8, 0, 0, 4)
		pip.custom_minimum_size = Vector2(26 if need > 4 else 34, 30)
		pips.add_child(pip)
	pr.add_child(_expand(UI.label("%d з %d" % [have, need], 22, UI.INK, "body", 900)))
	var ok: bool = GameState.can_level_up()
	pr.add_child(UI.pill("вистачає" if ok else "бракує", UI.GREEN if ok else UI.RED, 15))
	if not ok:
		col.add_child(_hand("заряд не витрачається — назбирай ще %d" % ceili(need - GameState.charge), 26, DARK_RED))
	var btns := UI.hbox(16)
	col.add_child(btns)
	var up := UI.button("Піднятися", "primary", "E", "", 26)
	up.disabled = not ok
	up.pressed.connect(_altar_confirm)
	btns.add_child(_expand(up))
	var later := UI.button("Пізніше", "secondary", "Esc", "", 22)
	later.pressed.connect(_close_altar)
	btns.add_child(later)
	(up if ok else later).grab_focus.call_deferred()
	var note := _hand("Що видиміший — то\nближче до волі", 32, UI.INK)
	var np := UI.panel(UI.PAPER, 20, 5, 16, 4)
	np.add_child(note)
	np.position = Vector2(600, 640)
	np.rotation_degrees = -3
	_altar.add_child(np)


func _altar_confirm() -> void:
	if _altar and GameState.level_up():
		_close_altar()


func _close_altar() -> void:
	if _altar:
		_altar.queue_free()
		_altar = null
		Input.mouse_mode = _mouse_before
	get_tree().paused = false


# --- pause (board 11) ---

func open_pause() -> void:
	_map.hide()
	_hud.hide()
	get_tree().paused = true
	_free_mouse()
	_pause = _full()
	_pause.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_pause)
	_pause.add_child(UI.backdrop(Color(UI.NIGHT, 0.82)))
	var t := UI.title("Пауза", 150)
	_pin(t, Control.PRESET_CENTER_TOP, 0, 70, _pause)
	_pin(_hand("підземелля затамувало подих", 38, UI.CYAN), Control.PRESET_CENTER_TOP, 0, 250, _pause)

	var btns := UI.vbox(14)
	btns.custom_minimum_size.x = 520
	_pin(btns, Control.PRESET_CENTER_TOP, 0, 340, _pause)
	var has_screens := ResourceLoader.exists(SCREENS)
	_resume_btn = UI.button("Продовжити", "primary", "Esc", "play")
	_resume_btn.pressed.connect(resume)
	var how := UI.button("Як грати", "secondary", "", "search")
	how.pressed.connect(_open_screen.bind("how_to"))
	var settings := UI.button("Налаштування", "secondary", "", "sliders")
	settings.pressed.connect(_open_screen.bind("settings"))
	how.disabled = not has_screens
	settings.disabled = not has_screens
	var again := UI.button("Почати знову", "ghost", "", "restart")
	again.pressed.connect(_restart)
	var menu := UI.button("У меню", "ghost", "", "exit")
	menu.pressed.connect(_to_menu)
	for b in [_resume_btn, how, settings, again, menu]:
		btns.add_child(b)
	btns.add_child(UI.label("прогрес не збережеться", 15, UI.DIM, "body", 600))
	_resume_btn.grab_focus.call_deferred()

	var stats := UI.panel(UI.PAPER, 26, 8, 22)
	stats.custom_minimum_size.x = 400
	_pin(stats, Control.PRESET_TOP_LEFT, 96, 380, _pause)
	var sv := UI.vbox(12)
	stats.add_child(sv)
	sv.add_child(UI.label("Ця ніч", 22, UI.INK, "body", 900, true))
	for kv in [["Етап", "%d · %s" % [GameState.stage + 1, STAGE_NAMES[GameState.stage]]], ["Видимість", "%d · %s" % [GameState.level, GameState.LEVEL_NAMES[GameState.level]]],
			["Заряд", "%.1f / %d" % [GameState.charge, GameState.MAX_CHARGE]], ["Шуму наробив", _times(GameState.haunts)],
			["Священник", _priest_status().trim_prefix("Священник: ")], ["Час", _clock(GameState.elapsed)]]:
		var r := UI.hbox(10)
		r.add_child(UI.label(kv[0], 15, UI.LABEL, "body", 900, true))
		r.add_child(_expand(UI.label(kv[1], 20, UI.INK, "body", 900)))
		sv.add_child(r)

	var goal := UI.panel(UI.SHADE, 22, 0, 20, 4, UI.GOLD)
	goal.custom_minimum_size.x = 400
	_pin(goal, Control.PRESET_TOP_RIGHT, 96, 380, _pause)
	var gv := UI.vbox(12)
	goal.add_child(gv)
	var chip := UI.chip("ЦІЛЬ", UI.GOLD, UI.INK, 16, 0)
	chip.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	gv.add_child(chip)
	gv.add_child(_wrap(UI.label(GameState.goal(), 19, UI.PAPER, "body", 700), 350))
	for i in STAGE_NAMES.size():
		_set_step(_step(gv, 19), STAGE_NAMES[i], _stage_state(i))


func resume() -> void:
	if _pause:
		_pause.queue_free()
		_pause = null
		Input.mouse_mode = _mouse_before
	_hud.show()
	get_tree().paused = false


func _open_screen(fn: String) -> void:
	var S = load(SCREENS)
	_sub = S.how_to(_close_screen) if fn == "how_to" else S.settings(_close_screen)
	add_child(_sub)


func _close_screen() -> void:
	if is_instance_valid(_sub):
		_sub.queue_free()
	_sub = null
	_sub_frame = Engine.get_process_frames()
	if is_instance_valid(_resume_btn):
		_resume_btn.grab_focus()


func _restart() -> void:
	get_tree().paused = false
	get_tree().reload_current_scene()


func _to_menu() -> void:
	get_tree().paused = false
	get_tree().change_scene_to_file("res://scenes/main_menu.tscn")


# --- ending (board 13) ---

func _on_finished(_won: bool) -> void:  # the dungeon story has no losing ending
	if is_instance_valid(_sub):
		_sub.queue_free()
	_close_altar()
	resume()
	_map.hide()
	_hud.hide()
	get_tree().paused = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_end = _full()
	_end.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_end)
	_end.add_child(UI.backdrop(UI.NIGHT))
	_end.add_child(UI.vignette(Color(1, 0.77, 0.19, 0.45)))
	var col := UI.vbox(22)
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	_pin(col, Control.PRESET_CENTER_TOP, 0, 90, _end)
	var centered := func(c: Control):
		c.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		col.add_child(c)
	centered.call(UI.pill("Фінал · Звільнення", UI.GOLD, 20, "ghost"))
	end_title = UI.title("Ти вільний", 150)
	centered.call(end_title)
	centered.call(UI.label("Тебе знайшли й пам'ятають. Підземелля старого міста відпустило тебе.", 40, UI.GOLD, "body", 900))
	var grid := UI.hbox(22)
	var peak: int = GameState.peak_level
	for kv in [["Час", _clock(GameState.elapsed)], ["Зібрано заряду", "%d" % GameState.gathered],
			["Шуму наробив", _times(GameState.haunts)], ["Найвищий рівень", "%d · %s" % [peak, GameState.LEVEL_NAMES[peak]]]]:
		var card := UI.panel(UI.PAPER, 22, 7, 20)
		card.custom_minimum_size.x = 270
		var cv := UI.vbox(8)
		cv.add_child(UI.label(kv[0], 16, UI.LABEL, "body", 900, true))
		cv.add_child(UI.label(kv[1], 40, UI.INK, "body", 900))
		card.add_child(cv)
		grid.add_child(card)
	centered.call(grid)
	var btns := UI.hbox(18)
	var again := UI.button("Ще раз", "primary", "", "restart")
	again.pressed.connect(_restart)
	var menu := UI.button("У меню", "secondary", "", "exit")
	menu.pressed.connect(_to_menu)
	btns.add_child(again)
	btns.add_child(menu)
	centered.call(btns)
	again.grab_focus.call_deferred()
	var line := UI.panel(Color(UI.INK, 0.82), 14, 0, 12, 0)
	var rt := RichTextLabel.new()
	rt.bbcode_enabled = true
	rt.fit_content = true
	rt.autowrap_mode = TextServer.AUTOWRAP_OFF
	rt.add_theme_font_override("normal_font", UI.font("body", 500))
	rt.add_theme_font_override("bold_font", UI.font("body", 800))
	rt.add_theme_font_size_override("normal_font_size", 21)
	rt.add_theme_font_size_override("bold_font_size", 21)
	rt.add_theme_color_override("default_color", UI.PAPER)
	rt.text = "[b][color=#%s]%s:[/color][/b] спочивай з миром." % [UI.GOLD.to_html(false), _priest.title_text if _priest else "Священник"]
	rt.custom_minimum_size.x = 480
	line.add_child(rt)
	_pin(line, Control.PRESET_CENTER_BOTTOM, 0, 60, _end)


func _on_said(who: String, text: String, color: Color) -> void:
	_line_text.text = "[center][b][color=#%s]%s:[/color][/b] %s[/center]" % [color.to_html(false), who, text]
	_line_t = LINE_TIME
