extends StaticBody3D
## Any interactive object: shelf, counter, cutting board, stove, plate stack, serve window, trash.
## The player calls interact(player) when pressing E next to it.

enum Kind { SHELF, COUNTER, BOARD, STOVE, PLATES, SERVE, TRASH }

const KIND_NAMES := ["", "Стіл", "Дошка", "Плита", "Тарілки", "Видача", "Смітник"]
const CHOPS_NEEDED := 5
const COOK_TIME := 4.0
const BURN_TIME := 12.0

@export var kind := Kind.COUNTER
@export var item_type := "tomato"  ## SHELF only
@export var size := Vector3(1.4, 1, 1.4)  ## used to place content on top

var content := ""  ## item lying on the station ("plate" for a plate)
var plate: Array = []  ## ingredients when content == "plate"
var progress := 0.0  ## chops on BOARD, seconds on STOVE
var _visual: Node3D

@onready var label: Label3D = $Label


func _ready() -> void:
	if kind == Kind.SHELF:  # decorative stock on top
		for i in int(size.x / 0.6):
			var v := GameState.make_visual(item_type)
			v.position = Vector3(-size.x / 2 + 0.3 + i * 0.6, size.y / 2 + 0.18, 0)
			add_child(v)
	_refresh()


func _process(delta: float) -> void:
	label.text = _label_text()
	if kind != Kind.STOVE or content == "":
		return
	progress += delta
	if GameState.COOK.has(content) and progress >= COOK_TIME:
		content = GameState.COOK[content]
		_refresh()
	elif content.ends_with("_cooked") and progress >= BURN_TIME:
		content = "burnt"
		_refresh()


func title() -> String:
	if kind == Kind.SHELF:
		return GameState.item_name(item_type)
	return KIND_NAMES[kind] + ("" if content == "" else ": " + GameState.describe(content, plate))


func interact(p) -> void:
	match kind:
		Kind.SHELF:
			if GameState.phase == GameState.Phase.SHOP:
				GameState.add_to_cart(item_type)
			elif GameState.phase == GameState.Phase.COOK and p.held == "" and GameState.cart.get(item_type, 0) > 0:
				GameState.cart[item_type] -= 1
				p.set_held(item_type)
		Kind.PLATES:
			if p.held == "":
				p.set_held("plate")
		Kind.TRASH:
			p.set_held("plate" if p.held == "plate" else "")  # keeps the plate, drops the food
		Kind.SERVE:
			if p.held == "plate" and not p.plate.is_empty():
				GameState.serve(p.plate)
				p.set_held("")
		_:
			_swap(p)
	_refresh()


## COUNTER / BOARD / STOVE: chop, take, put, or combine with a plate.
func _swap(p) -> void:
	if kind == Kind.BOARD and p.held == "" and GameState.CHOP.has(content):
		progress += 1
		if progress >= CHOPS_NEEDED:
			content = GameState.CHOP[content]
			progress = 0
	elif p.held == "":
		if content != "":
			p.set_held(content, plate)
			_clear()
	elif content == "":
		if _accepts(p.held):
			content = p.held
			plate = p.plate.duplicate()
			progress = 0
			p.set_held("")
	elif content == "plate" and p.held in GameState.PLATEABLE:
		plate.append(p.held)
		p.set_held("")
	elif p.held == "plate" and content in GameState.PLATEABLE:
		p.plate.append(content)
		p.set_held("plate", p.plate)
		_clear()


func _accepts(item: String) -> bool:
	match kind:
		Kind.BOARD: return GameState.CHOP.has(item)
		Kind.STOVE: return GameState.COOK.has(item)
	return true


func _clear() -> void:
	content = ""
	plate = []
	progress = 0


func _refresh() -> void:
	if _visual:
		_visual.queue_free()
	_visual = GameState.make_visual(content, plate)
	_visual.position.y = size.y / 2 + 0.05
	add_child(_visual)
	label.text = _label_text()


func _label_text() -> String:
	match kind:
		Kind.SHELF:
			var n := GameState.item_name(item_type)
			if GameState.phase == GameState.Phase.SHOP:
				return n
			return "%s (у візку: %d)" % [n, GameState.cart.get(item_type, 0)]
		Kind.BOARD:
			if GameState.CHOP.has(content):
				return "Ріжемо %d/%d" % [progress, CHOPS_NEEDED]
		Kind.STOVE:
			if GameState.COOK.has(content):
				return "Готується %d%%" % int(progress / COOK_TIME * 100)
			if content.ends_with("_cooked") and progress > COOK_TIME + 3:
				return "ГОРИТЬ!"
	return KIND_NAMES[kind] if content == "" else ""
