extends Node3D
## Round: charge at spirit items, raise visibility at the altar, bring the memento
## to the loved one at level 3 and let go, before midnight.

const CAMERA_OFFSET := Vector3(0, 14, 9)

var time_left := GameState.ROUND_TIME
var _last_level := 1

@onready var player = $Player
@onready var camera: Camera3D = $Camera3D
@onready var timer_label: Label = $HUD/TimerLabel
@onready var info_label: Label = $HUD/InfoLabel
@onready var prompt_label: Label = $HUD/PromptLabel
@onready var big_label: Label = $HUD/BigLabel
@onready var menu_button: Button = $HUD/MenuButton


func _ready() -> void:
	GameState.reset()
	GameState.visibility_changed.connect(_on_visibility_changed)
	GameState.finished.connect(_on_finished)
	menu_button.pressed.connect(_to_menu)
	menu_button.hide()
	_flash("Ти привид. Заряджайся біля спіритичних речей [E]\nі підніми видимість біля вівтаря")


func _process(delta: float) -> void:
	camera.global_position = camera.global_position.lerp(player.global_position + CAMERA_OFFSET, 5 * delta)
	if GameState.phase == GameState.Phase.PLAY:
		time_left -= delta
		if time_left <= 0:
			GameState.finish(false)
	_update_hud()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		_to_menu()


func _on_visibility_changed() -> void:
	var l: int = GameState.level
	if l > _last_level:
		_flash("Рівень %d: %s\n%s" % [l, GameState.LEVEL_NAMES[l], "Тебе почали помічати" if l == 2 else "Тебе бачать усі. Стіни більше не пускають"])
	elif l < _last_level:
		_flash("Мисливець ослабив тебе! Рівень %d" % l)
	_last_level = l


func _on_finished(won: bool) -> void:
	player.set_physics_process(false)
	player.set_process_unhandled_input(false)
	big_label.text = "Вона нарешті відпустила тебе.\nТи вільний." if won else "Північ...\nТи лишився тут назавжди."
	big_label.show()
	menu_button.show()
	menu_button.grab_focus()


func _update_hud() -> void:
	var t := maxi(ceili(time_left), 0)
	timer_label.text = "До півночі %d:%02d" % [t / 60, t % 60]

	var l: int = GameState.level
	var lines := PackedStringArray([
		"Видимість: %d — %s" % [l, GameState.LEVEL_NAMES[l]],
		"Заряд: %.1f / %d" % [GameState.charge, GameState.MAX_CHARGE],
	])
	if l < GameState.MAX_LEVEL:
		lines.append("Наступний рівень: %d заряду (вівтар)" % GameState.LEVEL_COST[l + 1])
	if GameState.is_fading():
		lines.append("Невидимий: %.1f с" % GameState.fade_left)
	else:
		lines.append("[Q] Сховатися: %d заряду" % GameState.FADE_COST)
	if player.held != "":
		lines.append("У руках: " + player.held)
	info_label.text = "\n".join(lines)

	var s = player.target_station()
	prompt_label.text = "[E] " + s.title() if s else ""


func _flash(text: String) -> void:
	big_label.text = text
	big_label.show()
	get_tree().create_timer(3.0).timeout.connect(_hide_flash.bind(text))


func _hide_flash(text: String) -> void:
	if big_label.text == text and GameState.phase == GameState.Phase.PLAY:
		big_label.hide()


func _to_menu() -> void:
	get_tree().change_scene_to_file("res://scenes/main_menu.tscn")
