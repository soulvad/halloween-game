extends CanvasLayer

const UI = preload("res://scripts/ui.gd")
const Station = preload("res://scripts/station.gd")
const ComicPage = preload("res://scripts/comic_page.gd")
const MapView = preload("res://scripts/map_view.gd")
const Fx = preload("res://scripts/fx.gd")
const SCREENS := "res://scripts/screens.gd"

const PROMPT_OVER := 0.4
const PROMPT_GAP := 34.0
const LINE_TIME := 4.5
const TOAST_TIME := 3.5
const DONE := Color("5A4636")
const SPEECH := Color("3B2C22")
const STAGE_NAMES := ["Помітьте мене", "Священник", "Пошуки", "Твоя кімната", "Ритуал"]  ## by GameState.Stage
const ROOM := Rect2(17.5, -12.5, 6, 4.7)
const ROOM_BANNER_TIME := 1.8
const STAGE_CARD_TIME := 2.6  ## seconds the stage title card stays (counts only while the game runs)
const FLY_TIME := 0.7  ## a new power's icon flying from the screen centre into its slot
const KNOCK_DOT := 64.0  ## px, the beat dots ●●● ● while aiming at the knock wall
const RUBBLE_POS := Vector3(17.5, 0, -10)

var game
var end_title: Control
var _hud: Control
var _pow_count: Label
var _powers := {}
var _mini: Control
var _room: Label
var _room_banner: Label
var _room_now := ""
var _room_t := 0.0
var _tiles := {}
var _prompt: PanelContainer
var _prompt_key
var _prompt_title: Label
var _prompt_sub: Label
var _line: PanelContainer
var _line_text: RichTextLabel
var _line_t := 0.0
var _toast: VBoxContainer
var _toast_title: Label
var _toast_text: Label
var _toast_icon: TextureRect
var _toast_t := 0.0
var _stage_card: VBoxContainer
var _stage_title: Label
var _stage_sub: Label
var _knock_row: HBoxContainer
var _knock_dots: Array[TextureRect] = []
var _knock_rings: Array[Control] = []  ## one per dot: closes on its dot when that knock is due
var _knock_ring := [-1, 0.0, false]  ## which dot's ring shows, how closed (0..1+), in its window
var _knock_misses := 0
var _knock_n := 0
var _knocked := false
var _prompt_for: Node3D  ## the target the E card was built for: a new one pops in
var _fresh_power := ""
var _letgo: Control
var _hold_fill: Panel
var _hold_label: Label
var _map: Control
var _map_view: Control
var _markers: Array = []
var _haunt_rows: Array = []
var _map_mem: Array[Label] = []
var _pause: Control
var _resume_btn: Button
var _sub: Control
var _sub_frame := -1
var _end: Control
var _book: PanelContainer
var _book_badge: PanelContainer
var _book_btn: PanelContainer
var _goal_pulse := false  ## a new goal: pulse the book once the game runs again (not under a comic)
var _book_stage: Label
var _goal_rows: Array[Dictionary] = []
var _goal_now := 0
var _goal_seen := 0
var _quest_priest: Label
var _comic_view: Control
var _mem_seen := 0
var _hint_list: VBoxContainer
var _read := {}
var _mouse_before := Input.MOUSE_MODE_VISIBLE
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
	_build_powers()
	_build_right()
	_build_bottom()
	_build_prompt()
	var dot := Panel.new()
	dot.add_theme_stylebox_override("panel", UI.style(UI.PAPER, 999, 3, 0, UI.INK))
	dot.custom_minimum_size = Vector2(12, 12)
	dot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hud.add_child(dot)
	dot.set_anchors_and_offsets_preset(Control.PRESET_CENTER, Control.PRESET_MODE_MINSIZE)
	_build_toast()
	_build_stage_card()
	_build_knock()
	_build_letgo()
	_build_map()
	_build_book()
	GameState.said.connect(_on_said)
	GameState.hint_unlocked.connect(func(_id): _rebuild_hints())
	GameState.memory_found.connect(func(_id): _rebuild_hints(); _update_comic())
	GameState.power_gained.connect(_on_power)
	GameState.stage_changed.connect(_on_stage)
	GameState.finished.connect(_on_finished)


func _exit_tree() -> void:
	get_tree().paused = false
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func _unhandled_input(e: InputEvent) -> void:
	if _end or (get_tree().paused and not _pause):
		return
	var frame := Engine.get_process_frames()
	if e.is_action_pressed("ui_cancel"):
		if is_instance_valid(_sub) or frame == _sub_frame:
			return
		if _book.visible:
			toggle_book()
		elif _map.visible:
			_map.hide()
		elif _pause:
			resume()
		else:
			open_pause()
		get_viewport().set_input_as_handled()
	elif e.is_action_pressed("map") and not get_tree().paused:
		toggle_map()
		get_viewport().set_input_as_handled()
	elif e.is_action_pressed("journal") and not get_tree().paused:
		toggle_book()
		get_viewport().set_input_as_handled()
	elif e is InputEventKey and e.pressed and not e.echo and e.keycode >= KEY_1 and e.keycode <= KEY_6 and not get_tree().paused:
		_replay(e.keycode - KEY_0)
		get_viewport().set_input_as_handled()


## Keys 1–5 replay a memory's comic, 6 the finale; only the ones already seen.
func _replay(n: int) -> void:
	if not (GameState.won if n == 6 else n in GameState.memories):
		GameState.think("Цього я ще не пригадав…")
		return
	if _book.visible:
		toggle_book()
	_map.hide()
	game.comic("finale" if n == 6 else "memory_%d" % n)


func _process(delta: float) -> void:
	_line_t -= delta
	_line.visible = _line_t > 0 and GameState.subtitles
	if not get_tree().paused:
		_toast_t -= delta
	if _end:
		return
	var t = game.player.target_station()
	if not t is Station:
		t = null
	_update_powers()
	if _active_goal() != _goal_now:
		_goal_now = _active_goal()
		_goal_pulse = true
		_rebuild_hints()
	if _goal_pulse and not get_tree().paused:
		_goal_pulse = false
		_book_btn.pivot_offset = _book_btn.size / 2
		Fx.pop(_book_btn, 1.18, 0.45)
		Fx.sound_ui(get_tree(), "chime", -12.0, 1.3)
	_update_right()
	_update_bottom(t)
	var letting: bool = game.at_release()
	_letgo.visible = letting
	_toast.visible = _toast_t > 0 and not letting
	if letting:
		var f: float = game.hold / game.RELEASE_TIME
		_hold_fill.visible = f > 0.03
		_hold_fill.size = Vector2((_hold_fill.get_parent().size.x - 12) * f, 30)
		_hold_label.text = "%.1f с" % maxf(game.RELEASE_TIME - game.hold, 0)
	_update_prompt(null if letting else t)
	_update_knock(t)
	if _map.visible:
		_update_map()
	if _book.visible:
		_update_book()


func _full() -> Control:
	var c := Control.new()
	c.set_anchors_preset(Control.PRESET_FULL_RECT)
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return c


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


func _sb(p: Control):
	return p.get_theme_stylebox("panel")


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


func _ring(color: Color, size := 16) -> TextureRect:
	var r := UI.icon("current", size + 8, color)
	r.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	return r


func _step(parent: Control, size := 17) -> Dictionary:
	var row := UI.hbox(8)
	var d := {mark = UI.icon("later", size + 9, UI.PAPER), label = UI.label("", size, UI.DIM, "body", 600)}
	d.mark.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(d.mark)
	row.add_child(d.label)
	parent.add_child(row)
	return d


func _set_step(d: Dictionary, text: String, state: int) -> void:
	d.label.text = text
	d.mark.texture = UI.icon_texture(["later", "current", "done"][state], 0, UI.PAPER)
	_set_color(d.label, [UI.DIM, UI.CHARGE, UI.PAPER][state])


func _stage_state(i: int) -> int:
	if i < GameState.stage or GameState.won:
		return 2
	return 1 if i == GameState.stage else 0


func _kind(n) -> String:
	var k = n.get_script().get_script_constant_map().get("Kind", {})
	return str(k.find_key(n.kind)) if n.get("kind") != null else ""


func _stage_progress() -> Array:
	match GameState.stage:
		GameState.Stage.RITUAL:
			return [GameState.ritual, "%d%%" % int(100 * GameState.ritual)]
	return [-1.0, ""]


func _priest_status() -> String:
	if GameState.stage == GameState.Stage.HAUNT:
		return "Священник: ще не кликали"
	return "Священник: тут" if _priest and _priest.visible else "Священник: в дорозі"


func _room_at(p: Vector3) -> String:
	var n: String = _mini.room_at(p)
	return n if n != "" else _room_now


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


func _build_powers() -> void:
	var card := UI.panel(UI.PAPER, 26, 7, 20)
	card.custom_minimum_size.x = 460
	_pin(card, Control.PRESET_TOP_LEFT)
	var col := UI.vbox(10)
	card.add_child(col)
	var head := UI.hbox(12)
	col.add_child(head)
	head.add_child(UI.icon("bolt", 34))
	head.add_child(UI.label("Сили", 22, UI.INK, "body", 900, true))
	_pow_count = UI.label("", 26, UI.INK, "body", 900)
	head.add_child(_expand(_pow_count))
	col.add_child(UI.rule())
	for p in GameState.POWERS:
		var row := UI.hbox(14)
		col.add_child(row)
		var tile := UI.panel(UI.GREY, 12, 0, 2, 3, UI.INK, "power")
		var icon := _power_icon(p, 50)
		tile.add_child(icon)
		row.add_child(tile)
		var tv := UI.vbox(0)
		tv.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		var n := UI.label("", 20, UI.INK, "body", 900)
		var h := UI.label("", 17, UI.MUTED, "body", 600)
		tv.add_child(n)
		tv.add_child(h)
		row.add_child(tv)
		_powers[p] = {sb = _sb(tile), tile = tile, icon = icon, name = n, help = h, state = ""}


func _update_powers() -> void:
	_pow_count.text = "%d / %d" % [GameState.powers.size(), GameState.POWERS.size()]
	for p in _powers:
		var d: Dictionary = _powers[p]
		var has := GameState.has_power(p)
		var state := "locked"
		if has:
			state = "new" if p == _fresh_power and _toast_t > 0 else "on"
		if d.state != state:
			d.state = state
			d.sb.use("tile_power_" + state)
			d.icon.texture = UI.power_icon(p, state)
		d.name.text = GameState.POWER_NAMES[p] if has else "???"
		d.help.text = GameState.POWER_HELP[p] if has else "ще не згадав"
		_set_color(d.name, UI.INK if has else UI.LABEL)


func _power_icon(p: String, size: int) -> TextureRect:
	var t := UI.icon("ghost", size)
	t.texture = UI.power_icon(p, "locked")
	return t


func _build_right() -> void:
	var col := UI.vbox(12)
	_pin(col, Control.PRESET_TOP_RIGHT)
	var mm := UI.panel(UI.INK, 26, 0, 12, 5, UI.PAPER)
	var mv := UI.vbox(8)
	mm.add_child(mv)
	_mini = MapView.new()
	_mini.setup(game)
	_mini.follow = game.get_node("Player")
	_mini.px_per_m = 11.0
	_mini.custom_minimum_size = Vector2(260, 190)
	mv.add_child(_mini)
	var foot := UI.hbox(8)
	mv.add_child(foot)
	_room = UI.label("", 17, UI.PAPER, "body", 700)
	foot.add_child(_expand(_room, HORIZONTAL_ALIGNMENT_LEFT))
	foot.add_child(UI.chip("M", UI.PAPER, UI.INK, 15, 2))
	for p in [_book_tile(), mm]:
		p.size_flags_horizontal = Control.SIZE_SHRINK_END
		col.add_child(p)
	_room_banner = UI.label("", 72, Color(UI.PAPER, 0.8), "italic", 400)
	_room_banner.label_settings.shadow_size = 6
	_room_banner.label_settings.shadow_color = Color(UI.INK, 0.7)
	_room_banner.label_settings.shadow_offset = Vector2(0, 3)
	_room_banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_room_banner.modulate.a = 0
	_pin(_room_banner, Control.PRESET_CENTER_TOP, 0, 120)


func _update_right() -> void:
	var p: Vector3 = game.player.global_position
	var r := _room_at(p)
	if r != _room_now:
		if _room_now != "":
			_room_t = ROOM_BANNER_TIME
		_room_now = r
		_room_banner.text = r
	_room.text = r if r != "" else "Підземелля"
	_room_t -= get_process_delta_time()
	_room_banner.modulate.a = clampf(_room_t / 0.5, 0, 1) * clampf((ROOM_BANNER_TIME - _room_t) / 0.25, 0, 1)


func _build_bottom() -> void:
	var esc := UI.panel(Color(UI.INK, 0.82), 14, 0, 8, 3, UI.PAPER)
	var er := UI.hbox(10)
	esc.add_child(er)
	er.add_child(UI.chip("Esc"))
	er.add_child(UI.label("Пауза", 18, UI.PAPER, "body", 700))
	_pin(esc, Control.PRESET_BOTTOM_LEFT, 40, 40)

	_line = UI.panel(Color(UI.INK, 0.82), 14, 0, 10, 0, UI.INK, "wash_ink")
	var ls = _sb(_line)
	ls.content_margin_left = 74
	ls.content_margin_right = 74
	ls.content_margin_top = 14
	ls.content_margin_bottom = 14
	_line_text = RichTextLabel.new()
	_line_text.bbcode_enabled = true
	_line_text.fit_content = true
	_line_text.custom_minimum_size.x = 640
	_line_text.add_theme_font_override("normal_font", UI.font("body", 500))
	_line_text.add_theme_font_override("bold_font", UI.font("body", 900))
	_line_text.add_theme_font_override("italics_font", UI.font("hand"))
	_line_text.add_theme_font_size_override("normal_font_size", 22)
	_line_text.add_theme_font_size_override("bold_font_size", 22)
	_line_text.add_theme_font_size_override("italics_font_size", 30)
	_line_text.add_theme_color_override("default_color", UI.PAPER)
	_line.add_child(_line_text)
	_pin(_line, Control.PRESET_CENTER_BOTTOM, 0, 40)
	_line.hide()

	var br := UI.hbox(14)
	br.alignment = BoxContainer.ALIGNMENT_END
	_pin(br, Control.PRESET_BOTTOM_RIGHT)
	var tiles := UI.hbox(12)
	br.add_child(tiles)
	for k in ["E"]:
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
	t.icon.texture = UI.icon_texture(icon_name, 56, UI.PAPER if t.sb.is_dark() else UI.INK)
	t.cap.text = caption
	t.badge.visible = badge != ""
	t.badge.get_child(0).text = badge
	_sb(t.badge).bg_color = badge_bg


func _verb(t) -> String:
	return {"MEMORY": "Згадати", "CANDLE": "Подих", "HAUNT": "Шуміти", "MIRROR": "Писати", "PLAN": "Зсунути", "DOOR": "Відчинити",
		"KNOCK": "Стукати", "EVIDENCE": "Показати", "CIRCLE": "Утримуй"}.get(_kind(t), "Взаємодія")


func _missing(t) -> String:
	var need = t.get("need")
	return need if need is String and need != "" and not GameState.has_power(need) else ""


func _update_bottom(t) -> void:
	if t == null:
		_set_tile("E", UI.GREY, "hand", "Взаємодія")
	elif t.can_use():
		_set_tile("E", UI.MOM if _kind(t) == "CIRCLE" else UI.GOLD, "hand", _verb(t))
	else:
		_set_tile("E", UI.GREY, "lock", _verb(t))


func _build_prompt() -> void:
	_prompt = UI.panel(UI.PAPER, 20, 6, 12)
	var row := UI.hbox(14)
	_prompt.add_child(row)
	var key := UI.panel(UI.GOLD, 12, 0, 0, 4, UI.INK, "key")
	_prompt_key = _sb(key)
	_prompt_key.content_margin_bottom = 6
	key.custom_minimum_size = Vector2(56, 58)
	var kl := UI.label("E", 26, UI.INK, "body", 900)
	kl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	kl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	key.add_child(kl)
	key.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(key)
	var col := UI.vbox(0)
	row.add_child(col)
	_prompt_title = UI.label("", 23, UI.INK, "body", 800)
	_prompt_sub = UI.label("", 18, UI.MUTED, "body", 600)
	col.add_child(_prompt_title)
	col.add_child(_prompt_sub)
	_hud.add_child(_prompt)
	_prompt.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_prompt.hide()


func _prompt_hint(t) -> String:
	var need := _missing(t)
	if need != "":
		return "потрібна сила: %s" % GameState.POWER_NAMES.get(need, need)
	match _kind(t):
		"MEMORY":
			if t.memory_id == 1:
				return "торкнися — повернеться спогад"
			return "приведи сюди археолога: %s" % GameState.POWER_NAMES.get(t.need, t.need)
		"CANDLE":
			return "люди підуть на світло, що змінилося"
		"HAUNT":
			var cd = t.get("cooldown")
			return "ще %d с тиші" % ceili(cd) if cd is float and cd > 0 else "люди поруч підуть на звук"
		"MIRROR":
			if GameState.mirror_written:
				return "напис уже є"
			if not GameState.has_power("hands"):
				return "спершу згадай усі чотири спогади"
			return "напиши на склі · археолог має бути поруч"
		"KNOCK":
			return "три удари, пауза, один · хтось має бути в кімнаті"
		"EVIDENCE":
			return "вони вже бачили" if t.get("shown") else "хай роздивляться люди"
		"CIRCLE":
			return "ритуал завершено · утримуй E" if GameState.release_ready() else "чекай, поки священник завершить ритуал"
	return ""


func _update_prompt(t) -> void:
	var cam := get_viewport().get_camera_3d()
	var top: Vector3 = t.global_position + Vector3.UP * (t.size.y / 2 + PROMPT_OVER) if t else Vector3.ZERO
	_prompt.visible = t != null and cam and not cam.is_position_behind(top)
	if not _prompt.visible:
		_prompt_for = null
		return
	_prompt_title.text = t.title().replace(": ", " · ")
	_prompt_sub.text = _prompt_hint(t)
	_prompt_key.bg_color = UI.GOLD if t.can_use() else UI.GREY
	_prompt.size = Vector2.ZERO
	_prompt.position = cam.unproject_position(top) - Vector2(_prompt.size.x / 2, _prompt.size.y + PROMPT_GAP)
	_prompt.pivot_offset = Vector2(_prompt.size.x / 2, _prompt.size.y)
	if t != _prompt_for:  # a new target: the card swells up out of it instead of snapping in
		_prompt_for = t
		_prompt.modulate.a = 0.0
		_prompt.scale = Vector2(0.8, 0.8)
		var tw := _prompt.create_tween().set_parallel()
		tw.tween_property(_prompt, "modulate:a", 1.0, 0.15)
		tw.tween_property(_prompt, "scale", Vector2.ONE, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _build_toast() -> void:
	_toast = UI.vbox(8)
	_toast.alignment = BoxContainer.ALIGNMENT_CENTER
	_pin(_toast, Control.PRESET_CENTER_TOP, 0, 220)
	var banner := UI.panel(UI.PAPER, 26, 0, 0, 0, UI.INK, "banner_power")
	var bs = _sb(banner)
	bs.content_margin_left = 36
	bs.content_margin_right = 44
	bs.content_margin_top = 14
	bs.content_margin_bottom = 18
	banner.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	var row := UI.hbox(18)
	banner.add_child(row)
	_toast_icon = UI.icon("ghost", 92)
	row.add_child(_toast_icon)
	var tv := UI.vbox(2)
	tv.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_toast_title = UI.label("", 36, UI.INK, "display", 900)
	_toast_text = UI.label("", 21, SPEECH, "body", 600)
	tv.add_child(_toast_title)
	tv.add_child(_toast_text)
	row.add_child(tv)
	_toast.add_child(banner)
	_toast.hide()


func _on_power(p: String) -> void:
	_fresh_power = p
	_toast_icon.texture = UI.power_icon(p, "new")
	_toast_title.text = "Нова сила: %s" % GameState.POWER_NAMES.get(p, p)
	_toast_text.text = GameState.POWER_HELP.get(p, "")
	_toast_t = TOAST_TIME
	_fly_power(p)


## The new power's icon swells mid-screen, then flies into its slot in the powers card; a chime when it lands.
## The tween stops while the tree is paused, so under a memory comic it waits mid-screen for the comic to end.
func _fly_power(p: String) -> void:
	var d: Dictionary = _powers[p]
	var icon := _power_icon(p, 72)
	icon.texture = UI.power_icon(p, "new")
	_hud.add_child(icon)
	icon.size = Vector2(72, 72)
	icon.pivot_offset = icon.size / 2
	icon.position = get_viewport().get_visible_rect().size / 2 - icon.size / 2
	icon.scale = Vector2(0.3, 0.3)
	var tile: Control = d.tile
	var to: Vector2 = tile.global_position + tile.size / 2 - icon.size / 2
	var tw := icon.create_tween().set_pause_mode(Tween.TWEEN_PAUSE_STOP)
	tw.tween_property(icon, "scale", Vector2(1.3, 1.3), 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_interval(0.5)
	tw.tween_property(icon, "position", to, FLY_TIME).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
	tw.parallel().tween_property(icon, "scale", Vector2(0.45, 0.45), FLY_TIME).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.tween_callback(func():
		icon.queue_free()
		tile.pivot_offset = tile.size / 2
		Fx.pop(tile, 1.35, 0.4)
		Fx.sound_ui(get_tree(), "chime"))


## Big stage title mid-screen, «Етап 3 · Твоя кімната», fading in and out.
func _build_stage_card() -> void:
	_stage_card = UI.vbox(2)
	_stage_card.alignment = BoxContainer.ALIGNMENT_CENTER
	_pin(_stage_card, Control.PRESET_CENTER_TOP, 0, 300)
	_stage_sub = UI.label("", 22, UI.PAPER, "body", 900, true)
	_stage_sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_stage_card.add_child(_stage_sub)
	_stage_title = UI.title("", 104, UI.GOLD)
	_stage_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_stage_card.add_child(_stage_title)
	_stage_card.modulate.a = 0.0


func _on_stage(s: int) -> void:
	var i := clampi(s, 0, STAGE_NAMES.size() - 1)
	_stage_sub.text = "Етап %d" % (i + 1)
	_stage_title.text = STAGE_NAMES[i]
	var tw := _stage_card.create_tween().set_pause_mode(Tween.TWEEN_PAUSE_STOP)  # under the time-lapse it waits
	tw.tween_property(_stage_card, "modulate:a", 1.0, 0.4)
	tw.tween_interval(STAGE_CARD_TIME)
	tw.tween_property(_stage_card, "modulate:a", 0.0, 0.8)


## The knock code as four big painted dots, ●●● ●, below the crosshair while you aim at the knock wall.
func _build_knock() -> void:
	_knock_row = UI.hbox(14)
	_knock_row.alignment = BoxContainer.ALIGNMENT_CENTER
	_pin(_knock_row, Control.PRESET_CENTER)
	_knock_row.offset_top = 110  # under the crosshair (_pin centres with no offset)
	_knock_row.offset_bottom = 110
	for i in 4:
		if i == 3:
			var gap := Control.new()
			gap.custom_minimum_size.x = KNOCK_DOT
			_knock_row.add_child(gap)
		var d := UI.icon("later", int(KNOCK_DOT), UI.PAPER)
		_knock_row.add_child(d)
		_knock_dots.append(d)
		var ring := Control.new()
		ring.set_anchors_preset(Control.PRESET_FULL_RECT)
		ring.mouse_filter = Control.MOUSE_FILTER_IGNORE
		ring.draw.connect(_draw_knock_ring.bind(ring, i))
		d.add_child(ring)
		_knock_rings.append(ring)
	_knock_row.hide()


## Fill a dot per knock (station.gd keeps the attempt in `_knocks`); the code done = all cyan + a flash.
func _update_knock(t) -> void:
	if GameState.wall_knocked and not _knocked:
		_knocked = true
		Fx.flash(get_tree(), Color(UI.CYAN, 0.4), 0.7)
		for d in _knock_dots:
			d.texture = UI.icon_texture("done", int(KNOCK_DOT), UI.PAPER)
			d.modulate = UI.CYAN
		var tw := _knock_row.create_tween()
		tw.tween_interval(1.0)
		tw.tween_property(_knock_row, "modulate:a", 0.0, 0.6)
		tw.tween_callback(_knock_row.hide)
		return
	if _knocked:
		return
	var on: bool = t != null and _kind(t) == "KNOCK" and GameState.stage == GameState.Stage.EVIDENCE and GameState.name_known()
	_knock_row.visible = on
	if not on:
		return
	var n: int = t._knocks.size()
	for i in 4:
		_knock_dots[i].texture = UI.icon_texture("current" if i < n else "later", int(KNOCK_DOT), UI.PAPER)
	if t.knock_misses > _knock_misses:  # off the beat: the dots blush and the attempt starts over
		_knock_row.modulate = UI.RED
		_knock_row.create_tween().tween_property(_knock_row, "modulate", Color.WHITE, 0.5)
	_knock_misses = t.knock_misses
	_knock_ring = [-1, 0.0, false]
	if n > 0 and n < t.KNOCK_BEATS.size():  # the next knock's ring closes in on its dot right on the beat
		var at: float = t.knock_time()
		var w: Vector2 = t.knock_window(n)
		_knock_ring = [n, (at - t.KNOCK_BEATS[n - 1]) / (t.KNOCK_BEATS[n] - t.KNOCK_BEATS[n - 1]), at >= w.x and at <= w.y]
	for r in _knock_rings:
		r.queue_redraw()
	if n > _knock_n:
		var d := _knock_dots[n - 1]
		d.pivot_offset = d.size / 2
		Fx.pop(d, 1.3, 0.2)
	_knock_n = n


## The next knock's guide: a still target ring on the dot, and a ring shrinking onto it, right on it at the perfect
## moment (k = 1), cyan while a knock would count (±20%: station.gd knock_window()).
func _draw_knock_ring(ring: Control, i: int) -> void:
	if _knock_ring[0] != i:
		return
	var target := KNOCK_DOT * 0.55
	var k := clampf(_knock_ring[1], 0.0, 1.5)
	var col: Color = UI.CYAN if _knock_ring[2] else UI.PAPER
	ring.draw_arc(ring.size / 2, target, 0, TAU, 48, Color(col, 0.55), 3.0, true)
	ring.draw_arc(ring.size / 2, target * (1.0 + (1.0 - k) * 1.4), 0, TAU, 48, Color(col, 0.4 + 0.6 * minf(k, 1.0)),
		6.0 if _knock_ring[2] else 4.0, true)


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
	var me := UI.panel(UI.INK, 26, 6, 22)
	me.position = Vector2(1060, 300)
	me.rotation_degrees = 2
	me.add_child(_hand("Двісті років у цій темряві…\nТепер я можу піти.", 40, UI.CYAN))
	_letgo.add_child(me)
	var card := UI.panel(UI.PAPER, 28, 9, 30, 5, UI.INK, "card_holy")
	card.custom_minimum_size.x = 800
	_pin(card, Control.PRESET_CENTER_BOTTOM, 0, 150, _letgo)
	var col := UI.vbox(14)
	card.add_child(col)
	var row := UI.hbox(16)
	col.add_child(row)
	var key := UI.panel(UI.MOM, 12, 0, 0, 4, UI.INK, "tile")
	key.custom_minimum_size = Vector2(66, 66)
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
	bar.custom_minimum_size.y = 42
	bar.add_theme_stylebox_override("panel", UI.box("bar", UI.LILAC))
	_hold_fill = Panel.new()
	_hold_fill.position = Vector2(6, 6)
	_hold_fill.add_theme_stylebox_override("panel", UI.box("bar", UI.MOM))
	bar.add_child(_hold_fill)
	col.add_child(bar)
	col.add_child(_hand("відпустиш кнопку — почнеш спочатку", 26))
	_letgo.hide()


func _build_map() -> void:
	_map = _full()
	_map.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_map)
	_map.add_child(UI.backdrop(Color(UI.INK, 0.86)))
	var t := UI.painted_title("karta", 110)
	t.position = Vector2(54, 18)
	_map.add_child(t)
	var frame := UI.panel(UI.NIGHT2, 26, 8, 22, 5, UI.PAPER, "map_sheet")
	frame.position = Vector2(60, 150)
	_map.add_child(frame)
	var view := MapView.new()
	view.setup(game)
	view.names = true
	view.custom_minimum_size = Vector2(1080, 780)
	frame.add_child(view)
	_map_view = view
	var stations: Array = game.get_node("Stations").get_children()
	var mark := func(target, text: String, color: Color, until_dug := false):
		var pill := UI.pill(text, color, 15)
		view.add_child(pill)
		_markers.append([target, pill, until_dug])
	mark.call(Vector3(ROOM.get_center().x, 0, ROOM.get_center().y), "Твоя кімната", UI.CYAN)
	var rubble = game.find_child("Rubble", true, false)
	mark.call(rubble if rubble is Node3D else RUBBLE_POS, "Завал", UI.RED, true)
	for s in stations:
		if _kind(s) == "MEMORY":
			mark.call(s, "спогад", UI.CYAN)
	for n in _visitors:
		mark.call(n, n.title_text, UI.PAPER)
	mark.call(game.get_node("Player"), "Ти", UI.CYAN)

	var leg := UI.panel(UI.PAPER, 26, 8, 22)
	leg.custom_minimum_size.x = 620
	_pin(leg, Control.PRESET_TOP_RIGHT, 60, 150, _map)
	var col := UI.vbox(2)
	leg.add_child(col)
	var head := func(text: String):
		col.add_child(UI.label(text, 20, UI.INK, "body", 900, true))
	head.call("Як вести людей")
	for line in ["Люди йдуть на звук і на світло, що змінилося", "Священник ходить за археологами", "Твоя кімната — вгорі праворуч, за стіною"]:
		col.add_child(UI.label("· " + line, 17, UI.MUTED, "body", 600))
	col.add_child(UI.rule())
	var row_of := func(text: String) -> Label:
		var r := UI.hbox(8)
		r.add_child(UI.label(text, 17, UI.INK, "body", 700))
		var st := UI.label("", 17, UI.INK, "body", 900)
		r.add_child(_expand(st))
		col.add_child(r)
		return st
	head.call("Спогади")
	for id in GameState.MEMORY_COUNT:
		_map_mem.append(row_of.call("%d." % (id + 1)))
	col.add_child(UI.rule())
	head.call("Чим шуміти")
	for s in stations:
		if _kind(s) in ["HAUNT", "CANDLE"]:
			_haunt_rows.append([s, row_of.call(s.title_text)])
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
		pill.visible = at and not (m[2] and GameState.stage > GameState.Stage.SEARCH)
		if pill.visible:
			pill.position = _map_view.to_map(n if n is Vector3 else n.global_position) - Vector2(pill.size.x / 2, pill.size.y + 10)
	for i in _map_mem.size():
		_set_memory_row(_map_mem[i], i + 1)
	for r in _haunt_rows:
		var s = r[0]
		var st: Label = r[1]
		var cd = s.get("cooldown")
		if _missing(s) != "":
			st.text = "треба: " + GameState.POWER_NAMES.get(_missing(s), "")
			_set_color(st, UI.LABEL)
		elif cd is float and cd > 0:
			st.text = "%d с" % ceili(cd)
			_set_color(st, UI.RED)
		else:
			st.text = "готово"
			_set_color(st, DONE)


func _set_memory_row(l: Label, id: int) -> void:
	var found := id in GameState.memories
	l.text = "%d. %s" % [id, GameState.MEMORY_TITLES.get(id, "")] if found else "%d. ???" % id
	_set_color(l, UI.GHOST_INK if found else UI.LABEL)


func _book_tile() -> PanelContainer:
	var p := UI.panel(UI.INK, 18, 5, 12, 4)
	_book_btn = p
	var row := UI.hbox(10)
	p.add_child(row)
	row.add_child(UI.icon("book", 40))
	row.add_child(UI.label("Книга", 18, UI.PAPER, "body", 900, true))
	row.add_child(UI.chip("J"))
	_book_badge = UI.chip("0", UI.ORANGE, UI.INK, 15, 3)
	row.add_child(_book_badge)
	_book_badge.hide()
	return p


const COMIC_LETTERS := ["A", "B", "C", "D", "E", "F"]


func _build_book() -> void:
	_book = UI.panel(UI.INK, 30, 10, 26, 5, UI.INK, "book_cover")
	_pin(_book, Control.PRESET_TOP_RIGHT)
	var pages := UI.hbox(0)
	_book.add_child(pages)
	var page := func(title: String, side: String) -> VBoxContainer:
		var pp := UI.panel(UI.PAPER, 20, 0, 0, 0, UI.INK, "book_page_" + side)
		var ps = _sb(pp)
		ps.content_margin_top = 28
		ps.content_margin_bottom = 30
		ps.content_margin_left = 30 if side == "left" else 52
		ps.content_margin_right = 52 if side == "left" else 30
		pp.custom_minimum_size = Vector2(520, 780)
		var v := UI.vbox(8)
		pp.add_child(v)
		var head := UI.hbox(10)
		head.add_child(UI.label(title, 26, UI.INK, "body", 900, true))
		v.add_child(head)
		pages.add_child(pp)
		return v
	var left: VBoxContainer = page.call("Цілі", "left")
	left.get_child(0).add_child(_expand(UI.label("J / Esc — закрити", 17, UI.MUTED, "body", 600)))
	_book_stage = UI.label("", 20, UI.INK, "body", 900)
	left.add_child(_book_stage)
	_quest_priest = UI.label("", 16, UI.MUTED, "body", 700)
	left.add_child(_quest_priest)
	var goals := UI.vbox(2)
	left.add_child(goals)
	for i in GameState.goal_steps().size():
		var row := UI.panel(Color(0, 0, 0, 0), 10, 0, 8, 0)
		_sb(row).content_margin_top = 2
		_sb(row).content_margin_bottom = 2
		var rh := UI.hbox(8)
		row.add_child(rh)
		var d := {panel = row, check = UI.icon("done", 24, UI.INK), lock = UI.icon("lock", 24, UI.LABEL), ring = _ring(UI.INK, 16)}
		for k in ["check", "lock", "ring"]:
			d[k].size_flags_vertical = Control.SIZE_SHRINK_BEGIN
			rh.add_child(d[k])
		d.label = _expand(_wrap(UI.label("", 17, UI.INK, "body", 700), 370), HORIZONTAL_ALIGNMENT_LEFT)
		rh.add_child(d.label)
		goals.add_child(row)
		_goal_rows.append(d)
	left.add_child(UI.rule())
	left.add_child(UI.label("Підказки", 22, UI.INK, "body", 900, true))
	var scroll := ScrollContainer.new()  # takes what's left of the page, so a long hint never makes the book taller
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_NEVER
	_hint_list = UI.vbox(8)  # only the latest hint
	_hint_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_hint_list)
	left.add_child(scroll)
	var right: VBoxContainer = page.call("Спогади", "right")
	right.get_child(0).add_child(_expand(UI.label("1–6 — переглянути знову", 17, UI.MUTED, "body", 600), HORIZONTAL_ALIGNMENT_RIGHT))
	_comic_view = ComicPage.new()
	_comic_view.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_comic_view.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right.add_child(_comic_view)
	_comic_view.setup("memories")
	_comic_view.stickers = true
	_book.hide()
	_rebuild_hints()
	_update_comic()


func toggle_book() -> void:
	if _book.visible:
		for id in GameState.hints:
			_read[id] = true
		_mem_seen = GameState.memories.size()
		_goal_seen = _active_goal()
		_book.hide()
	else:
		_map.hide()
		_book.show()
		_update_book()
		_update_comic()
		_book.position.y = -800
		create_tween().tween_property(_book, "position:y", 36.0, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_rebuild_hints()


func _active_goal() -> int:
	var steps := GameState.goal_steps()
	for i in steps.size():
		if not steps[i].done:
			return i
	return steps.size()


func _update_book() -> void:
	var i := clampi(GameState.stage, 0, STAGE_NAMES.size() - 1)
	_book_stage.text = "Етап %d/%d · %s" % [i + 1, STAGE_NAMES.size(), STAGE_NAMES[i]]
	_quest_priest.text = _priest_status()
	var steps := GameState.goal_steps()
	var now := _active_goal()
	var pr := _stage_progress()
	for k in _goal_rows.size():
		var d: Dictionary = _goal_rows[k]
		var state := 2 if k < now else (1 if k == now else 0)
		d.check.visible = state == 2
		d.lock.visible = state == 0
		d.ring.visible = state == 1
		d.label.text = "???" if state == 0 else steps[k].text + (" · " + pr[1] if state == 1 and pr[1] != "" and not "/" in steps[k].text else "")
		d.label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART if state == 1 else TextServer.AUTOWRAP_OFF
		d.label.text_overrun_behavior = TextServer.OVERRUN_NO_TRIMMING if state == 1 else TextServer.OVERRUN_TRIM_ELLIPSIS
		d.label.clip_text = state != 1
		_set_color(d.label, [UI.LABEL, UI.INK, DONE][state])
		_sb(d.panel).bg_color = Color(UI.GOLD, 0.85) if state == 1 else Color(0, 0, 0, 0)


func _update_comic() -> void:
	for k in COMIC_LETTERS.size():
		_comic_view.set_panel_state(COMIC_LETTERS[k], GameState.won if k == 5 else (k + 1) in GameState.memories)


func _rebuild_hints() -> void:
	for c in _hint_list.get_children():
		c.queue_free()
	var unread := 0
	for id: String in GameState.hints:
		unread += int(not _read.has(id))
	if not GameState.hints.is_empty():
		var id: String = GameState.hints.back()
		var fresh: bool = not _read.has(id)
		var p := UI.panel(UI.PAPER if fresh else UI.LILAC, 14, 4 if fresh else 0, 12, 3, UI.ORANGE if fresh else UI.INK)
		var r := UI.hbox(10)
		p.add_child(r)
		if fresh:
			var chip := UI.chip("нове", UI.ORANGE, UI.INK, 15, 2)
			chip.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
			r.add_child(chip)
		r.add_child(_wrap(_hand(GameState.HINTS[id], 22, UI.INK), 340 if fresh else 410))
		_hint_list.add_child(p)
	if GameState.hints.is_empty():
		_hint_list.add_child(_hand("Поки порожньо…", 26))
	unread += maxi(GameState.memories.size() - _mem_seen, 0) + int(_goal_now > _goal_seen)
	_book_badge.visible = unread > 0
	_book_badge.get_child(0).text = str(unread)


func open_pause() -> void:
	_map.hide()
	_hud.hide()
	get_tree().paused = true
	_free_mouse()
	_pause = _full()
	_pause.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_pause)
	_pause.add_child(UI.backdrop(Color(UI.NIGHT, 0.82)))
	var t := UI.painted_title("pauza", 136)
	_pin(t, Control.PRESET_CENTER_TOP, 0, 70, _pause)
	_pin(_hand("підземелля затамувало подих", 38, UI.CYAN), Control.PRESET_CENTER_TOP, 0, 250, _pause)

	var btns := UI.vbox(14)
	btns.custom_minimum_size.x = 520
	_pin(btns, Control.PRESET_CENTER_TOP, 0, 340, _pause)
	var has_screens := ResourceLoader.exists(SCREENS)
	_resume_btn = UI.button("Продовжити", "primary", "Esc", "play")
	_resume_btn.pressed.connect(resume)
	var guide := UI.button("Гайд по підземеллю", "secondary", "", "map")
	guide.pressed.connect(func(): resume(); game.tour())
	var settings := UI.button("Налаштування", "secondary", "", "sliders")
	settings.pressed.connect(_open_settings)
	settings.disabled = not has_screens
	var again := UI.button("Почати знову", "ghost", "", "restart")
	again.pressed.connect(_restart)
	var menu := UI.button("У меню", "ghost", "", "exit")
	menu.pressed.connect(_to_menu)
	for b in [_resume_btn, guide, settings, again, menu]:
		btns.add_child(b)
	btns.add_child(UI.label("прогрес не збережеться", 17, UI.DIM, "body", 600))
	_resume_btn.grab_focus.call_deferred()

	var stats := UI.panel(UI.PAPER, 26, 8, 22)
	stats.custom_minimum_size.x = 400
	_pin(stats, Control.PRESET_TOP_LEFT, 96, 380, _pause)
	var sv := UI.vbox(12)
	stats.add_child(sv)
	sv.add_child(UI.label("Ця ніч", 22, UI.INK, "body", 900, true))
	var powers := PackedStringArray(GameState.powers.map(func(p): return GameState.POWER_NAMES[p]))
	for kv in [["Етап", "%d · %s" % [GameState.stage + 1, STAGE_NAMES[GameState.stage]]], ["Спогади", "%d / %d" % [GameState.memories.size(), GameState.MEMORY_COUNT]],
			["Сили", ", ".join(powers) if powers else "жодної"], ["Шуму наробив", _times(GameState.haunts)],
			["Священник", _priest_status().trim_prefix("Священник: ")], ["Час", _clock(GameState.elapsed)]]:
		var r := UI.hbox(10)
		r.add_child(UI.label(kv[0], 16, UI.LABEL, "body", 900, true))
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


func _open_settings() -> void:
	var S = load(SCREENS)
	_sub = S.settings(_close_screen)
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


func _on_finished(_won: bool) -> void:
	if is_instance_valid(_sub):
		_sub.queue_free()
	resume()
	_map.hide()
	_hud.hide()
	get_tree().paused = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_end = _full()
	_end.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_end)
	_end.add_child(UI.backdrop(UI.PAPER))
	_end.add_child(UI.backdrop(Color(UI.MOM, 0.5)))
	_end.add_child(UI.vignette(Color(UI.MOM, 0.6)))
	var col := UI.vbox(20)
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	_pin(col, Control.PRESET_CENTER_TOP, 0, 70, _end)
	var centered := func(c: Control):
		c.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		col.add_child(c)
	centered.call(UI.pill("Фінал · Звільнення", UI.GOLD, 20, "ghost"))
	end_title = UI.painted_title("ty_vilnyi", 200, "ink")
	centered.call(end_title)
	if GameState.name_known():
		var name_label := _hand("Тиміш Ковальчук", 76, UI.GHOST_INK)
		name_label.label_settings.shadow_size = 10
		name_label.label_settings.shadow_color = Color(UI.CYAN, 0.45)
		centered.call(name_label)
	centered.call(UI.label("Тебе знайшли й пам'ятають. Підземелля старого міста відпустило тебе.", 30, SPEECH, "body", 700))
	var grid := UI.hbox(22)
	for kv in [["Час", _clock(GameState.elapsed)], ["Спогади", "%d / %d" % [GameState.memories.size(), GameState.MEMORY_COUNT]],
			["Шуму наробив", _times(GameState.haunts)]]:
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
	rt.add_theme_font_override("bold_font", UI.font("body", 900))
	rt.add_theme_font_size_override("normal_font_size", 22)
	rt.add_theme_font_size_override("bold_font_size", 22)
	rt.add_theme_color_override("default_color", UI.PAPER)
	rt.text = "[center][b][color=#%s]%s:[/color][/b] спочивай з миром.[/center]" % [UI.MOM.to_html(false), _priest.title_text if _priest else "Священник"]
	rt.custom_minimum_size.x = 480
	line.add_child(rt)
	_pin(line, Control.PRESET_CENTER_BOTTOM, 0, 60, _end)


func _on_said(who: String, text: String, color: Color) -> void:
	if who == "Ти":
		_line_text.text = "[center][i][color=#%s]%s[/color][/i][/center]" % [UI.CYAN.to_html(false), text]
	else:
		_line_text.text = "[center][b][color=#%s]%s:[/color][/b] %s[/center]" % [_speaker_color(who, color).to_html(false), who, text]
	_line_t = LINE_TIME


func _speaker_color(who: String, color: Color) -> Color:
	if _priest and who == _priest.title_text:
		return UI.MOM
	if color.h > 0.2 and color.h < 0.45:
		return UI.GREEN
	if color.s > 0.45 and color.v > 0.7:
		return UI.GOLD
	return UI.PAPER
