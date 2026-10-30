extends Node3D
## Round: charge at spirit items, raise visibility at the altar, carry 3 memories to the loved one,
## then let go at level 3. The priest lights the candles; all lit = the house is consecrated, you lose.

const CAMERA_OFFSET := Vector3(0, 14, 9)

var _last_level := 1
var _spawn: Vector3

@onready var player = $Player
@onready var camera: Camera3D = $Camera3D
@onready var timer_label: Label = $HUD/TimerLabel
@onready var info_label: Label = $HUD/InfoLabel
@onready var prompt_label: Label = $HUD/PromptLabel
@onready var big_label: Label = $HUD/BigLabel
@onready var menu_button: Button = $HUD/MenuButton


func _ready() -> void:
	GameState.reset()
	_spawn = player.global_position
	GameState.visibility_changed.connect(_on_visibility_changed)
	GameState.banished.connect(_on_banished)
	GameState.finished.connect(_on_finished)
	menu_button.pressed.connect(_to_menu)
	menu_button.hide()
	_flash("Ти привид. Заряджайся біля спіритичних речей [E]\nСвященник запалює свічки: коли згорять усі — тебе вигнано")


func _process(delta: float) -> void:
	camera.global_position = camera.global_position.lerp(player.global_position + CAMERA_OFFSET, 5 * delta)
	var candles := get_tree().get_nodes_in_group("holy_candle")
	var lit := candles.filter(func(c): return c.lit).size()
	if GameState.phase == GameState.Phase.PLAY and lit == candles.size():
		GameState.finish(false)
	timer_label.text = "Святі свічки: %d / %d" % [lit, candles.size()]
	_update_hud()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		_to_menu()


func _on_visibility_changed() -> void:
	var l: int = GameState.level
	if l > _last_level:
		_flash("Рівень %d: %s\n%s" % [l, GameState.LEVEL_NAMES[l], "Тебе помічають. Стіни кімнат більше не пускають" if l == 2 else "Тебе бачать усі. Мама почує"])
	elif l < _last_level:
		_flash("Ти слабшаєш... Рівень %d" % l)
	_last_level = l


func _on_banished() -> void:
	player.global_position = _spawn
	_flash("Святе світло відкинуло тебе назад")


func _on_finished(won: bool) -> void:
	player.set_physics_process(false)
	player.set_process_unhandled_input(false)
	big_label.text = "Мама нарешті відпустила тебе.\nТи вільний." if won else "Священник освятив будинок.\nТебе вигнано у порожнечу."
	big_label.show()
	menu_button.show()
	menu_button.grab_focus()


func _update_hud() -> void:
	var l: int = GameState.level
	var lines := PackedStringArray([
		"Видимість: %d — %s" % [l, GameState.LEVEL_NAMES[l]],
		"Заряд: %.1f / %d%s" % [GameState.charge, GameState.MAX_CHARGE, "  (тане -%.2f/с)" % GameState.UPKEEP[l] if l > 1 else ""],
		"Спогади для мами: %d / %d" % [GameState.memories, GameState.MEMORIES_NEEDED],
	])
	if l < GameState.MAX_LEVEL:
		lines.append("Вівтар: рівень %d при %d заряду" % [l + 1, GameState.LEVEL_REQ[l + 1]])
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
	get_tree().create_timer(3.5).timeout.connect(_hide_flash.bind(text))


func _hide_flash(text: String) -> void:
	if big_label.text == text and GameState.phase == GameState.Phase.PLAY:
		big_label.hide()


func _to_menu() -> void:
	get_tree().change_scene_to_file("res://scenes/main_menu.tscn")
