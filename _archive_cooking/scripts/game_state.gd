extends Node
## Autoload: shared game data (phase, cart, orders, score) + item/recipe tables.

signal cart_changed(item: String)

enum Phase { SHOP, BREAK, COOK, END }

const SHOP_TIME := 60.0
const BREAK_TIME := 3.0
const COOK_TIME := 150.0

## raw -> processed
const CHOP := { "tomato": "tomato_chopped", "lettuce": "lettuce_chopped" }
const COOK := { "meat": "meat_cooked" }
## only these can go on a plate
const PLATEABLE := ["tomato_chopped", "lettuce_chopped", "meat_cooked", "bread"]

const RECIPES := {
	"Овочевий салат": ["tomato_chopped", "lettuce_chopped"],
	"Бургер": ["bread", "meat_cooked"],
	"Бургер делюкс": ["bread", "meat_cooked", "tomato_chopped", "lettuce_chopped"],
}

const NAMES := {
	"tomato": "Помідор", "tomato_chopped": "Нарізаний помідор",
	"lettuce": "Латук", "lettuce_chopped": "Нарізаний латук",
	"meat": "Сира котлета", "meat_cooked": "Смажена котлета", "burnt": "Вуглинка",
	"bread": "Булка", "plate": "Тарілка",
}

const COLORS := {
	"tomato": Color(0.9, 0.12, 0.1), "tomato_chopped": Color(1, 0.4, 0.3),
	"lettuce": Color(0.3, 0.75, 0.2), "lettuce_chopped": Color(0.55, 1, 0.4),
	"meat": Color(0.9, 0.4, 0.45), "meat_cooked": Color(0.45, 0.25, 0.1), "burnt": Color(0.05, 0.05, 0.05),
	"bread": Color(0.95, 0.75, 0.4), "plate": Color(0.95, 0.95, 0.95),
}

const SCORE_PER_INGREDIENT := 10

var phase := Phase.SHOP
var cart := {}  ## item -> count
var orders: Array[String] = []
var score := 0


func reset() -> void:
	phase = Phase.SHOP
	cart.clear()
	orders.clear()
	score = 0


func add_to_cart(item: String) -> void:
	cart[item] = cart.get(item, 0) + 1
	cart_changed.emit(item)


func item_name(item: String) -> String:
	return NAMES.get(item, item)


func describe(item: String, plate: Array = []) -> String:
	if item != "plate" or plate.is_empty():
		return item_name(item)
	return "Тарілка (%s)" % ", ".join(plate.map(item_name))


## Returns true if the plate matched an open order.
func serve(plate: Array) -> bool:
	var got := plate.duplicate()
	got.sort()
	for i in orders.size():
		var want: Array = RECIPES[orders[i]].duplicate()
		want.sort()
		if want == got:
			orders.remove_at(i)
			score += SCORE_PER_INGREDIENT * want.size()
			return true
	return false


## Simple placeholder visual: colored box (flat when chopped), plate = disc + stacked cubes.
func make_visual(item: String, plate: Array = []) -> Node3D:
	var root := Node3D.new()
	if item == "plate":
		root.add_child(_box(Vector3(0.6, 0.05, 0.6), COLORS.plate))
		for i in plate.size():
			var b := _box(Vector3(0.22, 0.12, 0.22), COLORS[plate[i]])
			b.position = Vector3((i % 2 - 0.5) * 0.24, 0.09 + floori(i / 2.0) * 0.12, 0)
			root.add_child(b)
	elif item != "":
		var flat := item.ends_with("_chopped")
		root.add_child(_box(Vector3(0.4, 0.12, 0.4) if flat else Vector3(0.35, 0.35, 0.35), COLORS.get(item, Color.MAGENTA)))
	return root


func _box(size: Vector3, color: Color) -> MeshInstance3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	var mesh := BoxMesh.new()
	mesh.size = size
	mesh.material = mat
	var m := MeshInstance3D.new()
	m.mesh = mesh
	return m
