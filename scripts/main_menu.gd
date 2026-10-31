extends Control
## Board 01 «Головне меню». Built in code; nav buttons live in `Box` (smoke test checks `Box/Play`).

const UI = preload("res://scripts/ui.gd")
const Screens = preload("res://scripts/screens.gd")

var _box: VBoxContainer
var _screen: Control


func _ready() -> void:
	add_child(UI.backdrop())
	add_child(UI.vignette(Color(UI.INK, 0.7)))

	var ghost := UI.icon("ghost", 420, UI.PAPER)
	ghost.modulate.a = 0.85
	Screens.place(self, ghost, 1180, 540)
	var bubble := UI.panel(UI.PAPER, 20, 5, 0, 4)
	(bubble.get_theme_stylebox("panel") as StyleBoxFlat).content_margin_left = 18
	(bubble.get_theme_stylebox("panel") as StyleBoxFlat).content_margin_right = 18
	bubble.add_child(UI.label("Випустіть мене…", 32, UI.INK, "hand", 700))
	bubble.rotation_degrees = 3
	Screens.place(self, bubble, 1300, 440)

	var head := UI.vbox(10)
	var badge := UI.pill("Ігровий хакатон 7.0 · Прозорий + Відпускати", UI.ORANGE, 19)
	badge.rotation_degrees = -2
	badge.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	head.add_child(badge)
	head.add_child(UI.title("Відпусти", 170))
	head.add_child(UI.title("Підземелля старого міста", 64, UI.GOLD))
	head.add_child(UI.label("Граф давно помер. А ти досі тут.", 40, UI.CYAN, "hand", 700))
	Screens.place(self, head, 96, 60)

	_box = UI.vbox(14)
	_box.name = "Box"
	var play := _nav(UI.button("Грати", "primary", "Enter", "play", 32), "Play")
	play.pressed.connect(get_tree().change_scene_to_file.bind("res://scenes/game.tscn"))
	var opts := _nav(UI.button("Налаштування", "secondary", "", "sliders", 28), "Settings")
	opts.pressed.connect(func() -> void: _open(Screens.settings(_close)))
	var quit := _nav(UI.button("Вихід", "ghost", "", "exit", 24), "Quit", "закрити гру", UI.DIM)
	quit.pressed.connect(get_tree().quit)
	Screens.place(self, _box, 96, 570, 500)

	var hints := UI.hbox(22)
	hints.add_child(Screens.key_hint("↑↓", "обрати"))
	hints.add_child(Screens.key_hint("Enter", "підтвердити"))
	Screens.place(self, hints, 96, -34)
	var ver := UI.panel(UI.INK, 12, 0, 8, 0)
	(ver.get_theme_stylebox("panel") as StyleBoxFlat).content_margin_left = 16
	(ver.get_theme_stylebox("panel") as StyleBoxFlat).content_margin_right = 16
	ver.add_child(UI.label("v0.2 · Godot 4.7 · білд для хакатону", 16, UI.DIM, "body", 600))
	Screens.place(self, ver, -40, -30)

	play.grab_focus()


## Adds a nav button to Box, with an optional note on its right edge.
func _nav(b: Button, node_name: String, note := "", note_color := UI.INK) -> Button:
	b.name = node_name
	_box.add_child(b)
	if note != "":
		var l := UI.label(note, 16, note_color, "body", 700)
		l.mouse_filter = Control.MOUSE_FILTER_IGNORE
		b.add_child(l)
		l.set_anchors_and_offsets_preset(Control.PRESET_CENTER_RIGHT, Control.PRESET_MODE_MINSIZE, 24)
	return b


func _open(screen: Control) -> void:
	_screen = screen
	_box.hide()  # keeps focus from wandering to the menu behind the screen
	add_child(screen)


func _close() -> void:
	_screen.queue_free()
	_box.show()
	$Box/Play.grab_focus()
