@tool
extends StaticBody3D
## Box wall / furniture built from `size`. Collision layer = solid_from: layer 1 (outer walls) blocks the ghost,
## layers 2–3 (inner walls, furniture) only block people and shape the navmesh; the ghost floats through them.

@export var size := Vector3(4, 1.6, 0.3):
	set(v):
		size = v
		_build()
@export_range(1, 3) var solid_from := 3:
	set(v):
		solid_from = v
		_build()
@export var color := Color(0.45, 0.42, 0.5)
@export var people_only := false  ## blocks only people (layer 7) — e.g. rubble the ghost floats through

const LAYER_PEOPLE_ONLY := 64
## Final art drops in here, no code changes (see docs/assets.md): a model named after the node replaces its box,
## `wall.png` textures every wall box, `floor.png` / `ceiling.png` the floor and ceiling (game.gd).
const MODEL_DIR := "res://art/models/"
const TEXTURE_DIR := "res://art/textures/"

var _mesh: Node3D


func _ready() -> void:
	_build()


func _build() -> void:
	if not is_inside_tree():
		return
	for c in get_children():
		if not c.owner:  # only what we built, not children saved in the scene
			c.free()
	_mesh = visual(name, size, color)
	if _mesh is MeshInstance3D and solid_from < 3:
		textured(_mesh.mesh.material, "wall")
	add_child(_mesh)
	var shape := CollisionShape3D.new()
	shape.shape = BoxShape3D.new()
	shape.shape.size = size
	add_child(shape)
	collision_layer = LAYER_PEOPLE_ONLY if people_only else 1 << (solid_from - 1)
	collision_mask = 0


## `art/models/<node_name>.glb|.gltf|.tscn`, else the name's first word (CandleHall → Candle, CrateR1L → Crate,
## Memory3 → Memory), else null.
static func model(node_name: String) -> PackedScene:
	var first := RegEx.create_from_string("^[A-Z][a-z]+").search(node_name)
	for n in [node_name, first.get_string() if first else node_name]:
		for ext in ["glb", "gltf", "tscn"]:
			var path := "%s%s.%s" % [MODEL_DIR, n, ext]
			if ResourceLoader.exists(path):
				return load(path)
	return null


## The node's final model (origin at the bottom centre, real size in metres) or a placeholder box of `s`,
## both centred like the box on a body whose origin is at half height.
static func visual(node_name: String, s: Vector3, c: Color) -> Node3D:
	var ps := model(node_name)
	if ps == null:
		return box(s, c)
	var n: Node3D = ps.instantiate()
	n.position.y = -s.y / 2
	return n


## Put `art/textures/<tex>.png` on a material (triplanar, so any box size tiles), if the file exists.
static func textured(mat: StandardMaterial3D, tex: String, tiles := 0.5) -> void:
	var path := "%s%s.png" % [TEXTURE_DIR, tex]
	if mat == null or not ResourceLoader.exists(path):
		return
	mat.albedo_texture = load(path)
	mat.albedo_color = Color.WHITE
	mat.uv1_triplanar = true
	mat.uv1_scale = Vector3.ONE * tiles


static func box(s: Vector3, c: Color) -> MeshInstance3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = c
	var mesh := BoxMesh.new()
	mesh.size = s
	mesh.material = mat
	var m := MeshInstance3D.new()
	m.mesh = mesh
	return m


## Glowing floor circle + warm light marking holy ground (lit candle, priest).
static func holy_glow(radius: float) -> Node3D:
	var root := Node3D.new()
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color = Color(1, 0.85, 0.35, 0.3)
	var disc := CylinderMesh.new()
	disc.top_radius = radius
	disc.bottom_radius = radius
	disc.height = 0.02
	disc.material = mat
	var m := MeshInstance3D.new()
	m.mesh = disc
	m.position.y = 0.02
	root.add_child(m)
	var light := OmniLight3D.new()
	light.light_color = Color(1, 0.8, 0.45)
	light.omni_range = radius * 1.6
	light.light_energy = 1.5
	light.position.y = 1.2
	root.add_child(light)
	return root
