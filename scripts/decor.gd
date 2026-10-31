extends Node3D
## Dressing for the corridors and passages, pure decoration: no collision, not in the navmesh.
## Models live in art/decor/ (not art/models/, nothing here replaces a box). Each one is measured and fitted when placed,
## so a list entry only says where it goes and how big its longest side is.
## Floor things stay within 0.45 m of a wall: visitors keep 0.5 m away from walls and walk through anything else.

const DIR := "res://art/decor/%s.glb"
const E := 90.0  ## on a wall facing +X
const W := -90.0  ## facing -X
const S := 0.0  ## facing +Z
const N := 180.0  ## facing -Z

## model, x, y of its lowest point, z of the wall surface point, the way the wall faces, longest side (m)
const ON_WALLS := [
	# main corridor, from the entrance up
	["torch_mounted", -1.25, 1.5, 10.0, E, 0.55],
	["vines", 1.25, 1.2, 11.2, W, 1.7],
	["banner_thin_red", 1.25, 0.9, 4.2, W, 1.7],
	["shelf_small_candles", -1.25, 1.2, 4.6, E, 0.7],
	["vines", -1.25, 1.1, 3.0, E, 1.8],
	["torch_mounted", 1.25, 1.5, 2.8, W, 0.55],
	["spider", -1.25, 1.75, 5.4, E, 0.25],
	["torch_mounted", -1.25, 1.5, -2.2, E, 0.55],
	["banner_patternA_brown", 1.25, 0.9, -3.0, W, 1.7],
	# cross corridor, west
	["keyring_hanging", -8.0, 1.0, -4.75, N, 0.7],
	["torch_mounted", -7.4, 1.5, -7.0, S, 0.55],
	["vines", -5.0, 1.2, -4.75, N, 1.8],
	["sword_shield_broken", -11.0, 1.0, -4.75, N, 0.9],
	# cross corridor, east
	["torch_mounted", 7.2, 1.5, -7.0, S, 0.55],
	["sword_shield_broken", 5.8, 1.0, -7.0, S, 0.9],
	["vines", 8.8, 1.1, -4.75, N, 1.8],
	["banner_thin_red", 6.0, 0.9, -4.75, N, 1.7],
	["torch_mounted", 11.0, 1.5, -4.75, N, 0.55],
	["spider", 9.6, 2.0, -7.0, S, 0.25],
]
## model, x, z, turn in degrees, longest side (m)
const ON_FLOOR := [
	["mushroom", -0.95, 11.5, 30.0, 0.35],
	["mushroom", -0.82, 11.15, 140.0, 0.2],
	["barrel_small", -0.95, 8.8, 20.0, 0.55],
	["bottle_B_brown", -0.9, 8.3, 0.0, 0.26],
	["skull", 0.95, 4.6, 200.0, 0.2],
	["mushroom", 0.9, 11.3, 30.0, 0.3],
	["rubble_half", 0.8, -2.6, 270.0, 0.65],
	["mushroom", -5.5, -5.1, 90.0, 0.26],
	["rubble_half", -0.85, 2.7, 90.0, 0.8],
	["candle_melted", 0.92, -3.4, 0.0, 0.2],
	["box_small", -0.95, -3.6, 15.0, 0.5],
	["mushroom", -0.92, -1.0, 75.0, 0.3],
	["skull_candle", -10.1, -5.05, 170.0, 0.22],
	["stool", -8.9, -5.1, 40.0, 0.5],
	["plate_small", -6.6, -5.05, 0.0, 0.22],
	["rubble_half", -4.5, -6.65, 0.0, 0.7],
	["skull", -1.8, -6.7, 150.0, 0.2],
	["trunk_small_A", 5.3, -5.1, 180.0, 0.55],
	["bottle_A_green", 6.6, -5.05, 0.0, 0.26],
	["barrel_small", 8.2, -6.65, 70.0, 0.55],
	["mushroom", 9.0, -6.72, 0.0, 0.32],
	["rubble_half", 12.0, -6.7, 180.0, 0.75],
	# behind the door
	["skull", 10.6, -9.5, 60.0, 0.2],
	["mushroom", 11.7, -10.3, 200.0, 0.3],
]
## cobwebs up in the corners: x, z, how it is turned so it spans that corner
const WEBS := [
	[-1.25, 12.0, 0.0], [1.25, 12.0, -90.0], [-1.25, -4.75, 90.0], [1.25, -4.75, 180.0],
	[-11.5, -7.0, 90.0], [12.5, -4.75, 180.0], [12.0, -11.75, 180.0],
]
const WEB_SIZE := 1.3
const CEILING := 3.0
const FLAME := Color(1.0, 0.55, 0.15)
const TORCH_LIGHT := 0.8
const TORCH_RANGE := 4.0

var _scenes := {}
var _flames: Array[Node3D] = []
var _t := 0.0


func _ready() -> void:
	for e in ON_WALLS:
		var n := _place(e[0], Vector3(e[1], e[2], e[3]), e[4], e[5], true)
		if e[0] == "torch_mounted":
			_light_torch(n)
	for e in ON_FLOOR:
		_place(e[0], Vector3(e[1], 0.0, e[2]), e[3], e[4], false)
	for e in WEBS:
		_place("cobweb", Vector3(e[0], CEILING - WEB_SIZE, e[1]), e[2], WEB_SIZE, true)


## A model on the wall sits with its back on the surface; on the floor, centred on the point. Its lowest point is at `at.y`.
func _place(model: String, at: Vector3, turn_deg: float, longest: float, on_wall: bool) -> Node3D:
	var holder := Node3D.new()
	holder.position = at
	holder.rotation.y = deg_to_rad(turn_deg)
	var n: Node3D = _scene(model).instantiate()
	var box := _bounds(n)
	var fit := longest / maxf(box.size.x, maxf(box.size.y, box.size.z))
	n.scale *= fit
	var c := box.get_center()
	n.position = Vector3(-c.x, -box.position.y, -box.position.z if on_wall else -c.z) * fit
	for m: MeshInstance3D in n.find_children("*", "MeshInstance3D", true, false):
		m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	holder.set_meta("size", box.size * fit)
	holder.add_child(n)
	add_child(holder)
	return holder


func _scene(model: String) -> PackedScene:
	if not _scenes.has(model):
		_scenes[model] = load(DIR % model)
	return _scenes[model]


## Bounds of all the meshes in the model's own space (works out of the tree).
func _bounds(root: Node3D) -> AABB:
	var box := AABB()
	var first := true
	for m: MeshInstance3D in root.find_children("*", "MeshInstance3D", true, false):
		var tr := m.transform
		var p := m.get_parent()
		while p != root and p is Node3D:
			tr = p.transform * tr
			p = p.get_parent()
		var a: AABB = tr * m.get_aabb()
		box = a if first else box.merge(a)
		first = false
	return box


## The torch model has no fire of its own: a little emissive flame and a warm light at its head.
func _light_torch(torch: Node3D) -> void:
	var size: Vector3 = torch.get_meta("size")
	var mat := StandardMaterial3D.new()
	mat.albedo_color = FLAME
	mat.emission_enabled = true
	mat.emission = FLAME
	mat.emission_energy_multiplier = 3.0
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	var mesh := SphereMesh.new()
	mesh.radius = 0.055
	mesh.height = 0.2
	mesh.radial_segments = 6
	mesh.rings = 3
	mesh.material = mat
	var flame := MeshInstance3D.new()
	flame.mesh = mesh
	flame.position = Vector3(0, size.y + 0.05, size.z * 0.7)
	var light := OmniLight3D.new()
	light.light_color = FLAME
	light.light_energy = TORCH_LIGHT
	light.omni_range = TORCH_RANGE
	flame.add_child(light)
	torch.add_child(flame)
	_flames.append(flame)


func _process(delta: float) -> void:
	_t += delta
	for i in _flames.size():
		var f := _flames[i]
		var beat := sin(_t * 11.0 + i * 2.1) * sin(_t * 6.3 + i)
		f.scale = Vector3(1.0 - beat * 0.12, 1.0 + beat * 0.2, 1.0 - beat * 0.12)
		(f.get_child(0) as OmniLight3D).light_energy = TORCH_LIGHT * (0.85 + 0.15 * beat)
