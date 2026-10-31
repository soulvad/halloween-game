extends RefCounted

const UI = preload("res://scripts/ui.gd")


static func settings(on_back: Callable) -> Control:
	var root := _screen()
	place(root, UI.painted_title("nalashtuvannia", 117), 82, 50)

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


static func key_hint(key: String, text: String) -> HBoxContainer:
	var row := UI.hbox(8)
	row.add_child(UI.chip(key, UI.PAPER, UI.INK, 18, 3))
	row.add_child(UI.label(text, 20, UI.DIM, "body", 600))
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


static func _toggle(text: String, on: bool, cb: Callable) -> Button:
	var b := UI.button(text, "secondary", "", "", 22)
	b.toggle_mode = true
	b.custom_minimum_size = Vector2(440, 0)
	b.add_theme_stylebox_override("pressed", b.get_theme_stylebox("normal"))
	b.add_theme_stylebox_override("hover_pressed", b.get_theme_stylebox("hover"))
	b.add_theme_constant_override("h_separation", 14)
	b.add_theme_constant_override("icon_max_width", 42)
	b.button_pressed = on
	b.icon = UI.icon_texture("check_on" if on else "check_off")
	b.toggled.connect(func(v: bool) -> void:
		b.icon = UI.icon_texture("check_on" if v else "check_off")
		cb.call(v))
	return b


static func _slider() -> HSlider:
	var s := HSlider.new()
	s.max_value = 100
	s.step = 1
	s.custom_minimum_size = Vector2(0, 52)
	s.focus_mode = Control.FOCUS_ALL
	var track := UI.box("bar", UI.LILAC, 0)
	track.content_margin_top = 14
	track.content_margin_bottom = 14
	var fill := UI.box("bar", UI.ORANGE, 0)
	fill.content_margin_top = 14
	fill.content_margin_bottom = 14
	s.add_theme_stylebox_override("slider", track)
	s.add_theme_stylebox_override("grabber_area", fill)
	s.add_theme_stylebox_override("grabber_area_highlight", fill)
	var knob := UI.icon_texture("knob_small")
	s.add_theme_icon_override("grabber", knob)
	s.add_theme_icon_override("grabber_highlight", knob)
	return s
