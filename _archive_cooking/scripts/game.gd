extends Node3D
## Round flow: SHOP (60s, fill the cart) -> BREAK -> COOK (kitchen opens, serve orders) -> END.

const CAMERA_OFFSET := Vector3(0, 14, 9)
const ORDER_EVERY := 15.0
const MAX_ORDERS := 3

var time_left := GameState.SHOP_TIME
var order_timer := 0.0

@onready var player = $Player
@onready var camera: Camera3D = $Camera3D
@onready var timer_label: Label = $HUD/TimerLabel
@onready var info_label: Label = $HUD/InfoLabel
@onready var orders_label: Label = $HUD/OrdersLabel
@onready var prompt_label: Label = $HUD/PromptLabel
@onready var big_label: Label = $HUD/BigLabel
@onready var menu_button: Button = $HUD/MenuButton


func _ready() -> void:
	GameState.reset()
	menu_button.pressed.connect(_to_menu)
	menu_button.hide()
	_flash("Набери хавки за %d секунд! [E] біля полиці" % int(GameState.SHOP_TIME))


func _process(delta: float) -> void:
	camera.global_position = camera.global_position.lerp(player.global_position + CAMERA_OFFSET, 5 * delta)
	if GameState.phase in [GameState.Phase.SHOP, GameState.Phase.COOK]:
		time_left -= delta
		if time_left <= 0:
			_next_phase()
	if GameState.phase == GameState.Phase.COOK:
		order_timer -= delta
		if order_timer <= 0 and GameState.orders.size() < MAX_ORDERS:
			GameState.orders.append(GameState.RECIPES.keys().pick_random())
			order_timer = ORDER_EVERY
	_update_hud()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		_to_menu()


func _next_phase() -> void:
	match GameState.phase:
		GameState.Phase.SHOP:
			GameState.phase = GameState.Phase.BREAK
			_flash("Час вийшов! Кухня відкривається...")
			get_tree().create_timer(GameState.BREAK_TIME).timeout.connect(_open_kitchen)
		GameState.Phase.COOK:
			GameState.phase = GameState.Phase.END
			player.set_physics_process(false)
			player.set_process_unhandled_input(false)
			big_label.text = "Кінець зміни!\nРахунок: %d" % GameState.score
			big_label.show()
			menu_button.show()
			menu_button.grab_focus()


func _open_kitchen() -> void:
	$KitchenDoor.queue_free()
	player.cart.hide()
	GameState.phase = GameState.Phase.COOK
	time_left = GameState.COOK_TIME
	_flash("Готуй замовлення! Бери продукти з полиць")


func _update_hud() -> void:
	var timed := GameState.phase in [GameState.Phase.SHOP, GameState.Phase.COOK]
	timer_label.text = str(ceili(time_left)) if timed else ""

	var lines := PackedStringArray(["Візок:"])
	for item in GameState.cart:
		lines.append("  %s × %d" % [GameState.item_name(item), GameState.cart[item]])
	if GameState.phase == GameState.Phase.COOK:
		lines.append("\nУ руках: " + (GameState.describe(player.held, player.plate) if player.held else "нічого"))
	info_label.text = "\n".join(lines)

	if GameState.phase == GameState.Phase.COOK:
		var o := PackedStringArray(["Рахунок: %d" % GameState.score, "Замовлення:"])
		for r in GameState.orders:
			o.append("• %s: %s" % [r, ", ".join(GameState.RECIPES[r].map(GameState.item_name))])
		orders_label.text = "\n".join(o)
	else:
		orders_label.text = ""

	var s = player.target_station()
	prompt_label.text = "[E] " + s.title() if s else ""


func _flash(text: String) -> void:
	big_label.text = text
	big_label.show()
	get_tree().create_timer(2.5).timeout.connect(_hide_flash.bind(text))


func _hide_flash(text: String) -> void:
	if big_label.text == text:
		big_label.hide()


func _to_menu() -> void:
	get_tree().change_scene_to_file("res://scenes/main_menu.tscn")
