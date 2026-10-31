extends RefCounted
## Full-screen menus from the "ВІДПУСТИ — UI" design: board 03 «Налаштування».
## Used by the main menu and the pause menu: add the returned Control as a child, free it in on_back.
## It runs while the tree is paused and closes on Esc (shortcut on «Назад»).

const UI = preload("res://scripts/ui.gd")


## Board 03, only the settings that work: master volume, fullscreen, item labels, subtitles.
static func settings(on_back: Callable) -> Control:
	var root := _screen()
	place(root, UI.title("Налаштування", 100), 96, 56)

	var box := UI.panel(UI.CARD, 30, 10, 40)
	var col := UI.vbox(26)
	var head := UI.hbox()
	var vol_title := UI.label("Гучність", 24, UI.GOLD, "body", 900, true)
	vol_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var vol_value := UI.label("", 24, UI.PAPER, "body", 900)
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

	var keys := UI.panel(UI.CARD, 22, 6, 20, 2, UI.EDGE)
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
	var k := UI.chip(key, Color(0, 0, 0, 0), UI.PAPER, 18, 3)
	(k.get_theme_stylebox("panel") as StyleBoxFlat).border_color = UI.PAPER
	row.add_child(k)
	row.add_child(UI.label(text, 18, UI.PAPER, "body", 600))
	return row


static func _screen() -> Control:
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.process_mode = Node.PROCESS_MODE_ALWAYS
	root.add_child(UI.picture("crypt", 0.55))
	root.add_child(UI.vignette(Color(UI.INK, 0.75)))
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


## Checkbox tile: paper when off, green with a tick when on.
static func _toggle(text: String, on: bool, cb: Callable) -> Button:
	var b := UI.button(text, "secondary", "", "", 21)
	b.toggle_mode = true
	b.custom_minimum_size = Vector2(440, 0)
	var on_style := b.get_theme_stylebox("normal").duplicate() as StyleBox
	if on_style is StyleBoxTexture:
		(on_style as StyleBoxTexture).modulate_color = UI.GREEN.lightened(0.3)
	b.add_theme_color_override("font_pressed_color", UI.INK)
	b.add_theme_color_override("font_hover_pressed_color", UI.INK)
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
	var track := UI.style(UI.INK, 12, 2)
	track.content_margin_top = 8
	track.content_margin_bottom = 8
	var fill := UI.style(UI.PUMPKIN, 12, 0, 4)
	fill.content_margin_top = 8
	fill.content_margin_bottom = 8
	s.add_theme_stylebox_override("slider", track)
	s.add_theme_stylebox_override("grabber_area", fill)
	s.add_theme_stylebox_override("grabber_area_highlight", fill)
	var img := Image.new()
	img.load_svg_from_string('<svg xmlns="http://www.w3.org/2000/svg" width="34" height="34"><circle cx="17" cy="17" r="14" fill="#F6EEFF" stroke="#FF4FD8" stroke-width="4"/></svg>')
	var knob := ImageTexture.create_from_image(img)
	s.add_theme_icon_override("grabber", knob)
	s.add_theme_icon_override("grabber_highlight", knob)
	return s
