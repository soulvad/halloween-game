extends Control
## Hand-drawn texture painter (run paint.bat): cartoon-style PNGs into res://textures/ for walls, floors and props.
## Layout: tools on the left, canvas in the middle, 3D preview + palette on the right, shortcut strip at the bottom.

const UI = preload("res://scripts/ui.gd")
const Core = preload("res://tools/painter/paint_core.gd")
const View = preload("res://tools/painter/canvas_view.gd")
const SWATCHES := [UI.INK, UI.PAPER, UI.NIGHT, UI.NIGHT2, UI.MUTED, UI.GOLD, UI.ORANGE, UI.RED, UI.MOM, UI.CHARGE,
	UI.CYAN, UI.GREEN, UI.LILAC, UI.GREY, Color.WHITE]
const TOOLS := [
	[View.Tool.BRUSH, "Пензель", "B"],
	[View.Tool.INK, "Чорнило", "N"],
	[View.Tool.ERASER, "Гумка", "E"],
	[View.Tool.FILL, "Заливка", "G"],
	[View.Tool.PICKER, "Піпетка", "I"],
]
const HELP := [["B", "пензель"], ["N", "чорнило"], ["E", "гумка"], ["G", "заливка"], ["I / Alt+клік", "піпетка"],
	["[ ]", "розмір"], ["T", "тайлінг"], ["F", "вписати"], ["Колесо", "зум"], ["Пробіл / середня", "рух"],
	["Ctrl+Z / Y", "назад / вперед"], ["Ctrl+S", "зберегти"], ["Ctrl+N", "нова"], ["Ctrl+O", "відкрити"]]
const ASK_DISCARD := "Незбережені зміни зникнуть."

var tex_dir := "res://textures/"
var core := Core.new()
var view: View
var path := ""  ## current file; "" = new, unsaved

var _tool_buttons := {}
var _shape_buttons: Array[Button] = []
var _size_slider: HSlider
var _tile_btn: Button
var _file_label: Label
var _picker: ColorPickerButton
var _recent_row: HBoxContainer
var _recent: Array[Color] = []
var _mesh: MeshInstance3D
var _outline: MeshInstance3D
var _mat: StandardMaterial3D
var _overlay: Control


func _ready() -> void:
	theme = _theme()
	set_anchors_preset(PRESET_FULL_RECT)
	add_child(UI.backdrop(UI.NIGHT))
	var m := MarginContainer.new()
	m.set_anchors_preset(PRESET_FULL_RECT)
	for s in ["left", "right", "top", "bottom"]:
		m.add_theme_constant_override("margin_" + s, 22)
	add_child(m)
	var col := UI.vbox(16)
	m.add_child(col)
	col.add_child(_top_bar())
	view = View.new()
	view.core = core
	var main := UI.hbox(18)
	main.size_flags_vertical = SIZE_EXPAND_FILL
	col.add_child(main)
	main.add_child(_tools_panel())
	var frame := UI.panel(UI.NIGHT2, 18, 7, 0)
	frame.size_flags_horizontal = SIZE_EXPAND_FILL
	frame.add_child(view)
	main.add_child(frame)
	main.add_child(_side_panel())
	col.add_child(_help_strip())
	view.color_picked.connect(_on_picked)
	view.color_used.connect(_add_recent)
	view.resized.connect(view.fit)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(tex_dir))
	core.new_image(512, UI.PAPER)
	_set_color(UI.INK)
	_select_tool(View.Tool.BRUSH)
	get_tree().auto_accept_quit = false
	if DisplayServer.get_name() != "headless":
		get_window().mode = Window.MODE_MAXIMIZED


func _process(delta: float) -> void:
	var title_text := path.get_file() if path != "" else "без назви"
	_file_label.text = "%s%s · %d px" % [title_text, " •" if core.modified else "", core.img.get_width()]
	if _mat.albedo_texture != view.tex:
		_mat.albedo_texture = view.tex
	_mesh.rotate_y(delta * 0.7)


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		if core.modified:
			_ask("Вийти без збереження? " + ASK_DISCARD, get_tree().quit)
		else:
			get_tree().quit()


func _unhandled_input(ev: InputEvent) -> void:
	var k := ev as InputEventKey
	if k == null or not k.pressed:
		return
	if _overlay:
		if k.physical_keycode == KEY_ESCAPE:
			_close_modal()
			get_viewport().set_input_as_handled()
		return
	var code := k.physical_keycode  # physical: shortcuts work on the Ukrainian layout too
	if k.echo and code not in [KEY_BRACKETLEFT, KEY_BRACKETRIGHT]:
		return
	if k.ctrl_pressed:
		match code:
			KEY_Z:
				if k.shift_pressed:
					core.redo()
				else:
					core.undo()
			KEY_Y: core.redo()
			KEY_S:
				if k.shift_pressed:
					_save_dialog()
				else:
					save()
			KEY_N: _new_dialog()
			KEY_O: _open_dialog()
			_: return
	else:
		match code:
			KEY_B: _select_tool(View.Tool.BRUSH)
			KEY_N: _select_tool(View.Tool.INK)
			KEY_E: _select_tool(View.Tool.ERASER)
			KEY_G: _select_tool(View.Tool.FILL)
			KEY_I: _select_tool(View.Tool.PICKER)
			KEY_BRACKETLEFT: _bump_size(1.0 / 1.2)
			KEY_BRACKETRIGHT: _bump_size(1.2)
			KEY_T: _tile_btn.button_pressed = not _tile_btn.button_pressed
			KEY_F: view.fit()
			_: return
	get_viewport().set_input_as_handled()


# --- actions ---

func save() -> void:
	if path == "":
		_save_dialog()
	else:
		_write(path)  # the open document's own file: Ctrl+S overwrites it, Save As asks


func _write(p: String) -> void:
	_close_modal()
	var err := core.save_png(p)
	if err == OK:
		path = p
	else:
		_info("Не вдалося зберегти %s (%s)." % [p, error_string(err)])


func _load(p: String) -> void:
	_close_modal()
	var err := core.load_png(p)
	if err == OK:
		path = p
		view.fit()
	else:
		_info("Не вдалося відкрити %s (%s)." % [p, error_string(err)])


func _select_tool(t: int) -> void:
	view.tool = t
	for k in _tool_buttons:
		_tool_buttons[k].set_pressed_no_signal(k == t)
	_size_slider.editable = view.sizes.has(t)
	if view.sizes.has(t):
		_size_slider.value = view.sizes[t]
	view.queue_redraw()


func _bump_size(f: float) -> void:
	if view.sizes.has(view.tool):
		_size_slider.value = clampf(view.sizes[view.tool] * f, _size_slider.min_value, _size_slider.max_value)


func _set_color(c: Color) -> void:
	view.color = c
	_picker.color = c


func _on_picked(c: Color) -> void:
	_set_color(c)
	if view.tool == View.Tool.PICKER:
		_select_tool(View.Tool.BRUSH)


func _add_recent(c: Color) -> void:
	if not _recent.is_empty() and _recent[0] == c:
		return
	_recent.erase(c)
	_recent.push_front(c)
	_recent.resize(mini(_recent.size(), 10))
	for child in _recent_row.get_children():
		child.queue_free()
	for rc in _recent:
		_recent_row.add_child(_swatch(rc, 30))


func _set_shape(i: int) -> void:
	var meshes := [BoxMesh.new(), BoxMesh.new(), CapsuleMesh.new()]
	meshes[0].size = Vector3.ONE * 1.3
	meshes[1].size = Vector3(2.2, 1.5, 0.2)
	meshes[2].radius = 0.5
	meshes[2].height = 1.7
	_mesh.mesh = meshes[i]
	_outline.mesh = meshes[i]
	# BoxMesh UVs are a 3×2 atlas: scale so every face shows the whole (repeating) texture.
	_mat.uv1_scale = Vector3(3, 2, 1) if i < 2 else Vector3(2, 1, 1)
	for j in _shape_buttons.size():
		_shape_buttons[j].set_pressed_no_signal(j == i)


# --- dialogs ---

func _new_dialog() -> void:
	var box := _modal("Нова текстура")
	var px := [512]
	var row := UI.hbox(10)
	var group := ButtonGroup.new()
	for s in [256, 512, 1024]:
		var b := _toggle(UI.button("%d px" % s, "secondary", "", "", 22))
		b.button_group = group
		b.button_pressed = s == 512
		b.pressed.connect(func(): px[0] = s)
		row.add_child(b)
	box.add_child(row)
	var clear := CheckBox.new()
	clear.text = "Прозорий фон (інакше папір)"
	box.add_child(clear)
	var make := func():
		_close_modal()
		core.new_image(px[0], Color(0, 0, 0, 0) if clear.button_pressed else UI.PAPER)
		path = ""
		view.fit()
	_row(box, [["Створити", "primary", func(): _guard(make)], ["Скасувати", "secondary", _close_modal]])


func _open_dialog() -> void:
	var box := _modal("Відкрити")
	var files := _png_files()
	if files.is_empty():
		box.add_child(UI.label("У %s ще немає PNG." % tex_dir, 22, UI.MUTED))
		_row(box, [["Гаразд", "secondary", _close_modal]])
		return
	var list := _file_list(files)
	box.add_child(list)
	var open := func():
		var sel := list.get_selected_items()
		if not sel.is_empty():
			var p: String = tex_dir + files[sel[0]]
			_guard(func(): _load(p))
	list.item_activated.connect(func(_i): open.call())
	_row(box, [["Відкрити", "primary", open], ["Скасувати", "secondary", _close_modal]])


func _save_dialog() -> void:
	var box := _modal("Зберегти як")
	var files := _png_files()
	var name_edit := LineEdit.new()
	name_edit.placeholder_text = "назва, напр. wall_brick"
	name_edit.text = path.get_file().get_basename()
	if not files.is_empty():
		box.add_child(_caption("Вже є в " + tex_dir))
		var list := _file_list(files)
		list.item_selected.connect(func(i): name_edit.text = files[i].get_basename())
		box.add_child(list)
	box.add_child(_caption("Назва файлу"))
	box.add_child(name_edit)
	var err := UI.label("", 18, UI.RED)
	box.add_child(err)
	var ok := func():
		var n := _clean(name_edit.text)
		if n == "":
			err.text = "Введи назву."
			return
		var p := tex_dir + n + ".png"
		if FileAccess.file_exists(p):
			_ask("%s вже є. Перезаписати?" % p.get_file(), func(): _write(p))
		else:
			_write(p)
	name_edit.text_submitted.connect(func(_t): ok.call())
	_row(box, [["Зберегти", "primary", ok], ["Скасувати", "secondary", _close_modal]])
	name_edit.grab_focus.call_deferred()


## Runs `action` now, or after a "discard changes?" confirmation when there are unsaved changes.
func _guard(action: Callable) -> void:
	if core.modified:
		_ask(ASK_DISCARD + " Продовжити?", action)
	else:
		action.call()


func _ask(text: String, yes: Callable) -> void:
	var box := _modal("Точно?")
	box.add_child(_wrap_label(text))
	_row(box, [["Так", "primary", func():
		_close_modal()
		yes.call()], ["Ні", "secondary", _close_modal]])


func _info(text: String) -> void:
	var box := _modal("Ой")
	box.add_child(_wrap_label(text))
	_row(box, [["Гаразд", "secondary", _close_modal]])


func _modal(title_text: String) -> VBoxContainer:
	_close_modal()
	_overlay = Control.new()
	_overlay.set_anchors_preset(PRESET_FULL_RECT)
	_overlay.add_child(UI.backdrop(Color(UI.NIGHT, 0.75)))
	var cc := CenterContainer.new()
	cc.set_anchors_preset(PRESET_FULL_RECT)
	_overlay.add_child(cc)
	var p := UI.panel(UI.PAPER, 26, 9, 28)
	p.custom_minimum_size.x = 560
	cc.add_child(p)
	var box := UI.vbox(16)
	p.add_child(box)
	box.add_child(UI.label(title_text, 36, UI.INK, "display", 900))
	add_child(_overlay)
	return box


func _close_modal() -> void:
	if _overlay:
		_overlay.queue_free()
		_overlay = null


func _png_files() -> Array:
	var out := []
	for f in DirAccess.get_files_at(tex_dir):
		if f.get_extension().to_lower() == "png":
			out.append(f)
	out.sort()
	return out


func _clean(n: String) -> String:
	n = n.strip_edges()
	if n.get_extension().to_lower() == "png":
		n = n.get_basename()
	for ch in "/\\:*?\"<>|":
		n = n.replace(ch, "_")
	return n.lstrip(".")


# --- building blocks ---

func _top_bar() -> Control:
	var bar := UI.hbox(14)
	bar.add_child(UI.title("Малювалка", 54))
	_file_label = UI.label("", 22, UI.DIM)
	_file_label.size_flags_vertical = SIZE_SHRINK_CENTER
	_file_label.size_flags_horizontal = SIZE_EXPAND_FILL
	bar.add_child(_file_label)
	for b in [["Нова", "secondary", _new_dialog], ["Відкрити", "secondary", _open_dialog],
			["Зберегти", "primary", save], ["Зберегти як", "secondary", _save_dialog],
			["Назад", "ghost", func(): core.undo()], ["Вперед", "ghost", func(): core.redo()]]:
		var btn := UI.button(b[0], b[1], "", "", 20)
		btn.focus_mode = FOCUS_NONE
		btn.size_flags_vertical = SIZE_SHRINK_CENTER
		btn.pressed.connect(b[2])
		bar.add_child(btn)
	return bar


func _tools_panel() -> Control:
	var p := UI.panel(UI.PAPER, 22, 7, 18)
	p.custom_minimum_size.x = 300
	var box := UI.vbox(10)
	p.add_child(box)
	box.add_child(_caption("Інструменти"))
	var group := ButtonGroup.new()
	for t in TOOLS:
		var b := _toggle(UI.button(t[1], "secondary", t[2], "", 20))
		b.button_group = group
		b.pressed.connect(_select_tool.bind(t[0]))
		_tool_buttons[t[0]] = b
		box.add_child(b)
	box.add_child(UI.rule())
	_size_slider = _slider(box, "Розмір", 1, 300, 1, 24, func(v):
		if view.sizes.has(view.tool):
			view.sizes[view.tool] = v
			view.queue_redraw())
	_slider(box, "Жорсткість", 0, 1, 0.05, view.hardness, func(v): view.hardness = v)
	_slider(box, "Допуск заливки", 0, 1, 0.01, view.tolerance, func(v): view.tolerance = v)
	box.add_child(UI.rule())
	_tile_btn = _toggle(UI.button("Тайлінг", "secondary", "T", "", 20))
	_tile_btn.toggled.connect(func(on):
		core.tileable = on
		view.queue_redraw())
	box.add_child(_tile_btn)
	var tip := UI.label("Малюнок заходить за край і виходить з протилежного боку; навколо видно 3×3 плитки.", 15, UI.MUTED, "body", 700)
	tip.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(tip)
	var fit := UI.button("Вписати", "secondary", "F", "", 20)
	fit.focus_mode = FOCUS_NONE
	fit.pressed.connect(func(): view.fit())
	box.add_child(fit)
	return p


func _side_panel() -> Control:
	var col := UI.vbox(18)
	col.custom_minimum_size.x = 420
	var prev := UI.panel(UI.PAPER, 22, 7, 14)
	var pv := UI.vbox(10)
	prev.add_child(pv)
	pv.add_child(_caption("3D прев'ю"))
	pv.add_child(_preview_3d())
	var shapes := UI.hbox(8)
	var names := ["Куб", "Стіна", "Капсула"]
	for i in names.size():
		var b := _toggle(UI.button(names[i], "secondary", "", "", 18))
		b.size_flags_horizontal = SIZE_EXPAND_FILL
		b.pressed.connect(_set_shape.bind(i))
		_shape_buttons.append(b)
		shapes.add_child(b)
	pv.add_child(shapes)
	col.add_child(prev)
	_set_shape(0)

	var pal := UI.panel(UI.PAPER, 22, 7, 18)
	pal.size_flags_vertical = SIZE_EXPAND_FILL
	var box := UI.vbox(10)
	pal.add_child(box)
	box.add_child(_caption("Палітра"))
	var grid := GridContainer.new()
	grid.columns = 5
	grid.add_theme_constant_override("h_separation", 12)
	grid.add_theme_constant_override("v_separation", 12)
	for c in SWATCHES:
		grid.add_child(_swatch(c, 48))
	box.add_child(grid)
	box.add_child(_caption("Свій колір"))
	_picker = ColorPickerButton.new()
	_picker.custom_minimum_size = Vector2(0, 52)
	_picker.focus_mode = FOCUS_NONE
	_picker.color_changed.connect(func(c): view.color = c)
	_picker.popup_closed.connect(func(): _add_recent(view.color))
	box.add_child(_picker)
	box.add_child(_caption("Останні"))
	_recent_row = UI.hbox(8)
	_recent_row.custom_minimum_size.y = 34
	box.add_child(_recent_row)
	col.add_child(pal)
	return col


func _preview_3d() -> Control:
	var svc := SubViewportContainer.new()
	svc.stretch = true
	svc.custom_minimum_size = Vector2(0, 260)
	var vp := SubViewport.new()
	vp.own_world_3d = true
	vp.msaa_3d = Viewport.MSAA_4X
	svc.add_child(vp)
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = UI.NIGHT2
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.75, 0.7, 0.9)
	env.ambient_light_energy = 0.55
	var we := WorldEnvironment.new()
	we.environment = env
	vp.add_child(we)
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-40, 30, 0)
	vp.add_child(light)
	var cam := Camera3D.new()
	cam.fov = 40
	cam.position = Vector3(0, 1.1, 3.8)
	cam.rotation_degrees.x = -16
	vp.add_child(cam)
	# Toon shading + inverted-hull ink outline (a slightly bigger back-face-only copy).
	_mat = StandardMaterial3D.new()
	_mat.diffuse_mode = BaseMaterial3D.DIFFUSE_TOON
	_mat.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
	_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
	var ink := StandardMaterial3D.new()
	ink.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	ink.albedo_color = UI.INK
	ink.cull_mode = BaseMaterial3D.CULL_FRONT
	_mesh = MeshInstance3D.new()
	_mesh.material_override = _mat
	_outline = MeshInstance3D.new()
	_outline.material_override = ink
	_outline.scale = Vector3.ONE * 1.06
	_mesh.add_child(_outline)
	vp.add_child(_mesh)
	return svc


func _help_strip() -> Control:
	var p := UI.panel(Color(UI.INK, 0.85), 14, 0, 10, 0)
	var flow := HFlowContainer.new()
	flow.add_theme_constant_override("h_separation", 18)
	flow.add_theme_constant_override("v_separation", 6)
	for h in HELP:
		var pair := UI.hbox(6)
		pair.add_child(UI.chip(h[0], UI.PAPER, UI.INK, 15, 2))
		pair.add_child(UI.label(h[1], 16, UI.DIM, "body", 700))
		flow.add_child(pair)
	p.add_child(flow)
	return p


func _toggle(b: Button) -> Button:
	b.toggle_mode = true
	b.focus_mode = FOCUS_NONE
	var on := (b.get_theme_stylebox("normal") as StyleBoxFlat).duplicate() as StyleBoxFlat
	on.bg_color = UI.GOLD
	b.add_theme_stylebox_override("pressed", on)
	b.add_theme_stylebox_override("hover_pressed", on)
	return b


func _swatch(c: Color, s: int) -> Button:
	var b := Button.new()
	b.custom_minimum_size = Vector2(s, s)
	b.focus_mode = FOCUS_NONE
	b.tooltip_text = "#" + c.to_html(false)
	var st := UI.style(c, 12, 4, 0, UI.INK, 4)
	var hover := st.duplicate() as StyleBoxFlat
	hover.border_color = UI.ORANGE
	var down := st.duplicate() as StyleBoxFlat
	down.shadow_offset = Vector2(0, 1)
	b.add_theme_stylebox_override("normal", st)
	b.add_theme_stylebox_override("hover", hover)
	b.add_theme_stylebox_override("pressed", down)
	b.pressed.connect(_set_color.bind(c))
	return b


func _slider(box: Control, title_text: String, lo: float, hi: float, step: float, value: float, on_change: Callable) -> HSlider:
	var l := UI.label("", 17, UI.LABEL, "body", 900, true)
	box.add_child(l)
	var s := HSlider.new()
	s.min_value = lo
	s.max_value = hi
	s.step = step
	s.focus_mode = FOCUS_NONE
	s.value_changed.connect(func(v):
		l.text = "%s: %s" % [title_text, _num(v, step)]
		on_change.call(v))
	box.add_child(s)
	s.value = value
	l.text = "%s: %s" % [title_text, _num(value, step)]
	return s


func _num(v: float, step: float) -> String:
	return str(int(v)) if step >= 1.0 else str(snappedf(v, step))


func _caption(text: String) -> Label:
	return UI.label(text, 17, UI.LABEL, "body", 900, true)


func _wrap_label(text: String) -> Label:
	var l := UI.label(text, 22, UI.MUTED)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size.x = 500
	return l


func _file_list(files: Array) -> ItemList:
	var list := ItemList.new()
	list.custom_minimum_size = Vector2(500, 240)
	for f in files:
		list.add_item(f)
	return list


func _row(box: Control, buttons: Array) -> void:
	var row := UI.hbox(12)
	for b in buttons:
		var btn := UI.button(b[0], b[1], "", "", 22)
		btn.pressed.connect(b[2])
		row.add_child(btn)
	box.add_child(row)


func _theme() -> Theme:
	var t := Theme.new()
	t.default_font = UI.font("body", 800)
	t.default_font_size = 20
	var edit := UI.style(UI.PAPER, 12, 4)
	edit.set_content_margin_all(10)
	var edit_focus := edit.duplicate() as StyleBoxFlat
	edit_focus.border_color = UI.ORANGE
	t.set_stylebox("normal", "LineEdit", edit)
	t.set_stylebox("focus", "LineEdit", edit_focus)
	t.set_color("font_color", "LineEdit", UI.INK)
	t.set_color("font_placeholder_color", "LineEdit", UI.GREY.darkened(0.3))
	t.set_color("caret_color", "LineEdit", UI.INK)
	var list := UI.style(UI.PAPER, 14, 4)
	list.set_content_margin_all(8)
	t.set_stylebox("panel", "ItemList", list)
	t.set_stylebox("focus", "ItemList", StyleBoxEmpty.new())
	var sel := UI.style(UI.GOLD, 8, 3)
	for s in ["selected", "selected_focus"]:
		t.set_stylebox(s, "ItemList", sel)
	t.set_stylebox("hovered", "ItemList", UI.style(UI.LILAC, 8, 0))
	for c in ["font_color", "font_selected_color", "font_hovered_color"]:
		t.set_color(c, "ItemList", UI.INK)
	var track := UI.style(UI.LILAC, 6, 3)
	track.content_margin_top = 5
	track.content_margin_bottom = 5
	t.set_stylebox("slider", "HSlider", track)
	var filled := UI.style(UI.GOLD, 6, 3)
	t.set_stylebox("grabber_area", "HSlider", filled)
	t.set_stylebox("grabber_area_highlight", "HSlider", filled)
	for c in ["font_color", "font_hover_color", "font_pressed_color", "font_hover_pressed_color"]:
		t.set_color(c, "CheckBox", UI.INK)
	var swatch_box := UI.style(UI.PAPER, 12, 4)
	for s in ["normal", "hover", "pressed"]:
		t.set_stylebox(s, "ColorPickerButton", swatch_box)
	return t
