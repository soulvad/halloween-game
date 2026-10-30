extends RefCounted
## Full-screen menus from the "ВІДПУСТИ — UI" design: board 02 «Як грати», board 03 «Налаштування».
## Used by the main menu and the pause menu: add the returned Control as a child, free it in on_back.
## Both run while the tree is paused and close on Esc (shortcut on «Назад»).

const UI = preload("res://scripts/ui.gd")


## Board 02. «Почати» is shown only when on_start is valid.
static func how_to(on_back: Callable, on_start := Callable()) -> Control:
	var root := _screen()
	place(root, UI.title("Як грати", 110), 96, 56)
	var sub := UI.label("що видиміший — то страшніше живим", 40, UI.CYAN, "hand", 700)
	sub.rotation_degrees = -2
	place(root, sub, 640, 110)

	var cards := UI.hbox(36)
	cards.add_child(_card("1", UI.CYAN, "Тінь", [
		"Тебе не бачить ніхто",
		"Пропливаєш крізь стіни підземелля",
	], [
		"Ворушиш лише легкі речі",
	], UI.label("з цього починаєш", 30, UI.MUTED, "hand", 700)))
	cards.add_child(_card("2", UI.GOLD, "Відлуння", [
		"Люди тебе бачать — і лякаються сильніше",
		"Рухаєш важчі речі",
	], [
		"Стіни вже тримають",
	], _altar_cost(4)))
	cards.add_child(_card("3", UI.MOM, "Присутність", [
		"Без неї ритуал не вийде",
	], [
		"Тебе бачать усі",
		"Аура священника пече",
	], _altar_cost(8)))
	place(root, cards, 96, 230, 1728)

	var keys := HFlowContainer.new()
	keys.add_theme_constant_override("h_separation", 14)
	keys.add_theme_constant_override("v_separation", 14)
	for k in [["WASD", UI.PAPER, "пливти · миша — огляд"], ["Shift", UI.PAPER, "спринт · тратить заряд"], ["E", UI.GOLD, "заряд · шум · кістки · докази"],
			["Q", UI.CYAN, "сховатися 4 с · 2 заряду"], ["M", UI.PAPER, "карта"],
			["J / Tab", UI.PAPER, "книга"], ["Esc", UI.PAPER, "пауза"]]:
		keys.add_child(_key_chip(k[0], k[1], k[2]))
	place(root, keys, 96, 680, 1728)

	var goal := UI.panel(UI.SHADE, 22, 0, 18, 4, UI.GOLD)
	var row := UI.hbox(16)
	row.add_child(UI.chip("ЦІЛЬ", UI.GOLD, UI.INK, 16, 0))
	var text := UI.label("Налякай археологів → вони кличуть священника → заведи всіх до завалу → розкопки → покажи докази → ритуал: утримуй E у колі на рівні 3.", 21, UI.PAPER, "body", 700)
	text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(text)
	goal.add_child(row)
	place(root, goal, 96, -56, 1200)

	var btns := UI.hbox(18)
	var back := _back_button(on_back)
	var focus := back
	if on_start.is_valid():
		var start := UI.button("Почати", "primary", "", "play", 30)
		start.pressed.connect(on_start)
		btns.add_child(start)
		focus = start
	btns.add_child(back)
	place(root, btns, -96, -64)
	root.ready.connect(focus.grab_focus, CONNECT_ONE_SHOT)
	return root


## Board 03, only the settings that work: master volume, fullscreen, item labels, subtitles.
static func settings(on_back: Callable) -> Control:
	var root := _screen()
	place(root, UI.title("Налаштування", 100), 96, 56)

	var box := UI.panel(UI.PAPER, 30, 10, 40)
	var col := UI.vbox(26)
	var head := UI.hbox()
	var vol_title := UI.label("Гучність", 24, UI.INK, "body", 900, true)
	vol_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var vol_value := UI.label("", 24, UI.INK, "body", 900)
	head.add_child(vol_title)
	head.add_child(vol_value)
	col.add_child(head)
	var slider := _slider()
	slider.value_changed.connect(func(v: float) -> void:
		vol_value.text = str(int(v))
		AudioServer.set_bus_volume_db(0, linear_to_db(v / 100.0)))
	slider.value = roundf(db_to_linear(AudioServer.get_bus_volume_db(0)) * 100.0)
	vol_value.text = str(int(slider.value))
	col.add_child(slider)
	col.add_child(UI.rule())

	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 18)
	grid.add_theme_constant_override("v_separation", 18)
	grid.add_child(_toggle("Повний екран", DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN, func(on: bool) -> void:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN if on else DisplayServer.WINDOW_MODE_WINDOWED)))
	grid.add_child(_toggle("Підказки над речами", GameState.show_labels, func(on: bool) -> void: GameState.show_labels = on))
	grid.add_child(_toggle("Субтитри", GameState.subtitles, func(on: bool) -> void: GameState.subtitles = on))
	col.add_child(grid)

	var foot := UI.hbox()
	var note := UI.label("привиди теж люблять субтитри", 30, UI.MUTED, "hand", 700)
	note.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	foot.add_child(note)
	var back := _back_button(on_back)
	foot.add_child(back)
	col.add_child(foot)
	box.add_child(col)
	place(root, box, 96, 210, 1300)

	var keys := UI.panel(UI.INK, 22, 0, 20, 4, UI.PAPER)
	var kcol := UI.vbox(12)
	kcol.add_child(UI.label("Клавіші", 18, UI.GOLD, "body", 900, true))
	for k in [["Рух", "WASD + миша", UI.PAPER], ["Взаємодія", "E / Пробіл", UI.GOLD],
			["Спринт", "Shift", UI.PAPER], ["Сховатися", "Q", UI.CYAN], ["Карта", "M", UI.PAPER],
			["Книга", "J / Tab", UI.PAPER], ["Пауза", "Esc", UI.PAPER]]:
		var r := UI.hbox()
		var l := UI.label(k[0], 19, UI.PAPER, "body", 700)
		l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		r.add_child(l)
		r.add_child(UI.chip(k[1], k[2], UI.INK, 18, 0))
		kcol.add_child(r)
	keys.add_child(kcol)
	place(root, keys, 1470, 260, 360)

	place(root, key_hint("Esc", "назад"), 96, -30)
	root.ready.connect(back.grab_focus, CONNECT_ONE_SHOT)
	return root


## Adds `c` to `parent` at design px. Negative x / y = distance of the right / bottom edge from the screen edge.
## w = fixed width (0 = minimum width).
static func place(parent: Control, c: Control, x: float, y: float, w := 0.0) -> Control:
	parent.add_child(c)
	if x < 0:
		c.anchor_left = 1
		c.anchor_right = 1
		c.grow_horizontal = Control.GROW_DIRECTION_BEGIN
		c.offset_right = x
		c.offset_left = x - w
	else:
		c.offset_left = x
		c.offset_right = x + w
	if y < 0:
		c.anchor_top = 1
		c.anchor_bottom = 1
		c.grow_vertical = Control.GROW_DIRECTION_BEGIN
		c.offset_top = y
		c.offset_bottom = y
	else:
		c.offset_top = y
		c.offset_bottom = y
	return c


## Outlined key + caption on dark ("Esc назад у меню", "↑↓ обрати").
static func key_hint(key: String, text: String) -> HBoxContainer:
	var row := UI.hbox(8)
	var k := UI.chip(key, Color(0, 0, 0, 0), UI.PAPER, 18, 3)
	(k.get_theme_stylebox("panel") as StyleBoxFlat).border_color = UI.PAPER
	row.add_child(k)
	row.add_child(UI.label(text, 18, UI.PAPER, "body", 600))
	return row


static func _screen() -> Control:
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.process_mode = Node.PROCESS_MODE_ALWAYS
	root.add_child(UI.backdrop())
	root.add_child(UI.vignette(Color(UI.INK, 0.8)))
	return root


static func _back_button(on_back: Callable) -> Button:
	var b := UI.button("Назад", "secondary", "Esc", "", 26)
	var esc := InputEventKey.new()
	esc.keycode = KEY_ESCAPE
	b.shortcut = Shortcut.new()
	b.shortcut.events = [esc]
	b.shortcut_in_tooltip = false
	b.pressed.connect(on_back)
	return b


static func _card(num: String, color: Color, name: String, plus: Array, minus: Array, footer: Control) -> PanelContainer:
	var card := UI.panel(UI.PAPER, 26, 8, 28)
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var col := UI.vbox(16)
	var head := UI.hbox(14)
	var tile := UI.panel(color, 16, 0, 0, 4)
	var ts := tile.get_theme_stylebox("panel") as StyleBoxFlat
	ts.shadow_color = UI.INK
	ts.shadow_size = 1
	ts.shadow_offset = Vector2(0, 5)
	tile.custom_minimum_size = Vector2(64, 64)
	var n := UI.label(num, 34, UI.INK, "body", 900)
	n.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	n.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	tile.add_child(n)
	head.add_child(tile)
	head.add_child(UI.label(name, 40, UI.INK, "body", 900, true))
	col.add_child(head)
	for t in plus:
		col.add_child(_point(t, true))
	for t in minus:
		col.add_child(_point(t, false))
	var gap := Control.new()
	gap.size_flags_vertical = Control.SIZE_EXPAND_FILL
	col.add_child(gap)
	col.add_child(UI.rule())
	col.add_child(footer)
	card.add_child(col)
	return card


static func _point(text: String, good: bool) -> HBoxContainer:
	var row := UI.hbox(10)
	var dot := UI.panel(UI.GREEN if good else UI.RED, 13, 0, 0, 3)
	dot.custom_minimum_size = Vector2(26, 26)
	dot.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	var s := UI.label("+" if good else "−", 16, UI.INK, "body", 900)
	s.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	s.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	dot.add_child(s)
	row.add_child(dot)
	var l := UI.label(text, 20, UI.INK, "body", 600)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(l)
	return row


static func _altar_cost(n: int) -> VBoxContainer:
	var col := UI.vbox(6)
	var row := UI.hbox(10)
	row.add_child(UI.label("Твої кістки", 20, UI.INK, "body", 800))
	row.add_child(UI.pill("%d заряду" % n, UI.CHARGE, 18))
	col.add_child(row)
	col.add_child(UI.label("не витрачається, але тане", 16, UI.MUTED, "body", 600))
	return col


static func _key_chip(key: String, color: Color, text: String) -> PanelContainer:
	var p := UI.panel(UI.INK, 18, 0, 12, 4, UI.PAPER)
	(p.get_theme_stylebox("panel") as StyleBoxFlat).content_margin_left = 18
	(p.get_theme_stylebox("panel") as StyleBoxFlat).content_margin_right = 18
	var row := UI.hbox(12)
	row.add_child(UI.chip(key, color, UI.INK, 20, 0))
	row.add_child(UI.label(text, 20, UI.PAPER, "body", 700))
	p.add_child(row)
	return p


## Checkbox tile: paper when off, green with a tick when on.
static func _toggle(text: String, on: bool, cb: Callable) -> Button:
	var b := UI.button(text, "secondary", "", "", 21)
	b.toggle_mode = true
	b.custom_minimum_size = Vector2(440, 0)
	var on_style := (b.get_theme_stylebox("normal") as StyleBoxFlat).duplicate() as StyleBoxFlat
	on_style.bg_color = UI.GREEN
	b.add_theme_stylebox_override("pressed", on_style)
	b.add_theme_stylebox_override("hover_pressed", on_style)
	b.add_theme_constant_override("h_separation", 14)
	b.button_pressed = on
	b.icon = UI.icon_texture("check" if on else "", 28)
	b.toggled.connect(func(v: bool) -> void:
		b.icon = UI.icon_texture("check" if v else "", 28)
		cb.call(v))
	return b


static func _slider() -> HSlider:
	var s := HSlider.new()
	s.max_value = 100
	s.step = 1
	s.custom_minimum_size = Vector2(0, 36)
	s.focus_mode = Control.FOCUS_ALL
	var track := UI.style(UI.LILAC, 12, 4)
	track.content_margin_top = 8
	track.content_margin_bottom = 8
	var fill := UI.style(UI.ORANGE, 12, 4)
	fill.content_margin_top = 8
	fill.content_margin_bottom = 8
	s.add_theme_stylebox_override("slider", track)
	s.add_theme_stylebox_override("grabber_area", fill)
	s.add_theme_stylebox_override("grabber_area_highlight", fill)
	var img := Image.new()
	img.load_svg_from_string('<svg xmlns="http://www.w3.org/2000/svg" width="34" height="34"><circle cx="17" cy="17" r="14" fill="#FFFDF8" stroke="#17111C" stroke-width="4"/></svg>')
	var knob := ImageTexture.create_from_image(img)
	s.add_theme_icon_override("grabber", knob)
	s.add_theme_icon_override("grabber_highlight", knob)
	return s
