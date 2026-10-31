extends MeshInstance3D
## The glass of the MIRROR station: a planar reflection. A second camera at the eye's image behind the glass looks at the
## room through it. It doesn't see the ghost's body: ghosts have no reflection. Renders only while someone is close.

const FACE_X := -1.0  ## the station's -X side faces the room
const GLASS := Vector2(0.8, 1.26)  ## the oval inside the model's frame
const RESOLUTION := 720  ## px, height
const RANGE := 11.0
const FAR := 40.0
const LAYER_GLASS := 16  ## visual layer 5: so the mirror doesn't see itself
const CULL := 0xFFFFF & ~4 & ~2 & ~LAYER_GLASS  ## no own body (3), no world labels (2)

var _glass := GLASS  ## the model's own pane (a box named Glass, Ostap's mirror) replaces the oval
var _view := SubViewport.new()
var _cam := Camera3D.new()


func _init(station_size: Vector3) -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS  # the guide flies past it with the tree paused
	var quad := QuadMesh.new()
	quad.size = GLASS
	mesh = quad
	layers = LAYER_GLASS
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	position = Vector3(FACE_X * (station_size.x / 2 + 0.012), 0, 0)
	rotation.y = FACE_X * PI / 2
	_view.size = Vector2i(roundi(RESOLUTION * GLASS.x / GLASS.y), RESOLUTION)
	_view.render_target_update_mode = SubViewport.UPDATE_DISABLED
	_cam.cull_mask = CULL
	_view.add_child(_cam)
	add_child(_view)


func _ready() -> void:
	var mat := ShaderMaterial.new()
	mat.shader = load("res://scripts/mirror.gdshader")
	var pane := get_parent().find_child("Glass", true, false) as MeshInstance3D
	if pane and pane.mesh is BoxMesh:
		var box: Vector3 = pane.mesh.size
		var t: Transform3D = get_parent().global_transform.affine_inverse() * pane.global_transform
		_glass = Vector2(box.z * t.basis.get_scale().z, box.y * t.basis.get_scale().y)
		position = t.origin + Vector3(FACE_X * (box.x * t.basis.get_scale().x / 2 + 0.004), 0, 0)
		mesh.size = _glass
		_view.size = Vector2i(roundi(RESOLUTION * _glass.x / _glass.y), RESOLUTION)
		pane.visible = false
		mat.set_shader_parameter("oval", false)
	mat.set_shader_parameter("view", _view.get_texture())
	material_override = mat


func _process(_delta: float) -> void:
	var eye := get_viewport().get_camera_3d()
	var glass := global_transform.orthonormalized()
	var normal := glass.basis.z
	var away := eye.global_position - glass.origin if eye else Vector3.ZERO
	var d := away.dot(normal)
	if eye == null or d < 0.02 or away.length() > RANGE:
		_view.render_target_update_mode = SubViewport.UPDATE_DISABLED
		return
	_view.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	var image := eye.global_position - normal * d * 2.0
	_cam.global_transform = Transform3D(Basis(-glass.basis.x, glass.basis.y, -normal), image)
	var to_glass := glass.origin - image
	_cam.set_frustum(_glass.y, Vector2(to_glass.dot(-glass.basis.x), to_glass.dot(glass.basis.y)), d, FAR)
