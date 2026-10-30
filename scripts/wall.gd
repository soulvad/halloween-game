@tool
extends StaticBody3D
## Box wall / furniture built from `size`. The ghost passes through it while its level < solid_from.
## Collision layer = solid_from (layer 1 always blocks, 2 from level 2, 3 from level 3).

@export var size := Vector3(4, 1.6, 0.3):
	set(v):
		size = v
		_build()
@export_range(1, 3) var solid_from := 3:
	set(v):
		solid_from = v
		_build()
@export var color := Color(0.45, 0.42, 0.5)

var _mesh: MeshInstance3D


func _ready() -> void:
	_build()
	if Engine.is_editor_hint():
		return
	GameState.visibility_changed.connect(_on_visibility_changed)
	_on_visibility_changed()


func _build() -> void:
	if not is_inside_tree():
		return
	for c in get_children():
		if not c.owner:  # only what we built, not children saved in the scene
			c.free()
	_mesh = box(size, color)
	add_child(_mesh)
	var shape := CollisionShape3D.new()
	shape.shape = BoxShape3D.new()
	shape.shape.size = size
	add_child(shape)
	collision_layer = 1 << (solid_from - 1)
	collision_mask = 0


## Walls the ghost can pass right now look see-through.
func _on_visibility_changed() -> void:
	var passable := GameState.is_fading() and solid_from > 1 or GameState.level < solid_from
	_mesh.transparency = 0.65 if passable else 0.0


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
