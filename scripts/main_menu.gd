extends Control

const UI = preload("res://scripts/ui.gd")
const Screens = preload("res://scripts/screens.gd")
const PROLOGUE := "res://art/comic/prologue/%s.png"
const PROLOGUE_LAYERS := ["A", "B", "C", "D", "E", "F", "frame"]
const PAGE_SIZE := Vector2(620, 862)

var _box: VBoxContainer
var _screen: Control


func _ready() -> void:
	add_child(UI.backdrop())
	add_child(UI.vignette(Color(UI.INK, 0.7)))

	var frame := UI.panel(UI.PAPER, 26, 0, 44, 0, UI.INK, "comic_frame")
	frame.add_child(_prologue_page())
	frame.rotation_degrees = 1.4
	Screens.place(self, frame, 1190, 46)
	var bubble := UI.panel(UI.PAPER, 20, 5, 14, 4)
	var bs = bubble.get_theme_stylebox("panel")
	bs.content_margin_left = 26
	bs.content_margin_right = 26
	bubble.add_child(UI.label("Випустіть мене…", 42, UI.GHOST_INK, "hand", 700))
	bubble.rotation_degrees = -4
	Screens.place(self, bubble, 1060, 790)

	var head := UI.vbox(4)
	head.add_child(UI.label("Ігровий хакатон 7.0 · Прозорий + Відпускати", 20, UI.DIM, "body", 600))
	var title := UI.painted_title("vidpusty", 270)
	title.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	head.add_child(title)
	head.add_child(UI.label("Підземелля старого міста", 50, UI.PAPER, "italic", 400))
	head.add_child(UI.label("Граф давно помер. А ти досі тут.", 44, UI.CYAN, "hand", 700))
	Screens.place(self, head, 80, 52)

	_box = UI.vbox(10)
	_box.name = "Box"
	var play := _nav(UI.button("Грати", "primary", "Enter", "play", 36), "Play")
	play.pressed.connect(get_tree().change_scene_to_file.bind("res://scenes/game.tscn"))
	var opts := _nav(UI.button("Налаштування", "secondary", "", "sliders", 30), "Settings")
	opts.pressed.connect(func() -> void: _open(Screens.settings(_close)))
	var quit := _nav(UI.button("Вихід", "ghost", "", "exit", 27), "Quit", "закрити гру", UI.MUTED)
	quit.pressed.connect(get_tree().quit)
	Screens.place(self, _box, 96, 610, 552)

	var hints := UI.hbox(26)
	hints.add_child(Screens.key_hint("↑↓", "обрати"))
	hints.add_child(Screens.key_hint("Enter", "підтвердити"))
	Screens.place(self, hints, 96, -34)
	var ver := UI.panel(UI.INK, 12, 0, 8, 0)
	var vs = ver.get_theme_stylebox("panel")
	vs.content_margin_left = 16
	vs.content_margin_right = 16
	ver.add_child(UI.label("v0.2 · Godot 4.7 · білд для хакатону", 17, UI.DIM, "body", 600))
	Screens.place(self, ver, -40, -24)

	play.grab_focus()


func _prologue_page() -> Control:
	var page := Control.new()
	page.custom_minimum_size = PAGE_SIZE
	page.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for layer in PROLOGUE_LAYERS:
		var t := TextureRect.new()
		t.texture = load(PROLOGUE % layer)
		t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		t.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		t.set_anchors_preset(Control.PRESET_FULL_RECT)
		t.mouse_filter = Control.MOUSE_FILTER_IGNORE
		if layer != "frame" and not GameState.intro_seen:
			t.modulate = Color.BLACK  # the story stays blacked out until the prologue was played
		page.add_child(t)
	return page


func _nav(b: Button, node_name: String, note := "", note_color := UI.INK) -> Button:
	b.name = node_name
	_box.add_child(b)
	if note != "":
		var l := UI.label(note, 28, note_color, "hand", 700)
		l.mouse_filter = Control.MOUSE_FILTER_IGNORE
		b.add_child(l)
		l.set_anchors_and_offsets_preset(Control.PRESET_CENTER_RIGHT, Control.PRESET_MODE_MINSIZE, 30)
	return b


func _open(screen: Control) -> void:
	_screen = screen
	_box.hide()
	add_child(screen)


func _close() -> void:
	_screen.queue_free()
	_box.show()
	$Box/Play.grab_focus()
