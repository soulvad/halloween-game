@tool
extends Node3D

const CIRCLE_TEXTURE := preload("res://art/textures/holy_circle_psx.webp")
const CHALK_SHADER := preload("res://shaders/psx_chalk.gdshader")
const CONSECRATION_SHADER := preload("res://shaders/psx_consecration.gdshader")
const FLAME_SHADER := preload("res://shaders/psx_flame.gdshader")
const WAX_SHADER := preload("res://shaders/psx_wax.gdshader")
const SHAFT_SHADER := preload("res://shaders/psx_shaft.gdshader")

const LAYER_WORLD_FX := 2
const PLANE_DIVISIONS := 8
const CANDLE_COUNT := 8
const CANDLE_RADIUS := 0.024
const CANDLE_RING := 1.08
const FLAME_SIZE := Vector2(0.06, 0.13)
const CEILING := 2.98
const WARM := Color(1.0, 0.66, 0.36)
const HEAVENLY := Color(1.0, 0.88, 0.66)
const BRASS := Color(0.55, 0.4, 0.18)
const NO_GLOW := 2.0
const CANDLE_LIGHT := 1.4
const BLESSED_LIGHT := 2.3
const SHAFT_LIGHT := 3.0
const RITUAL_SHAFT := 0.25
const LIGHT_FPS := 12.0
const EASE := 1.2

@export var radius := 1.4:
	set(v):
		radius = v
		_build()
@export var seed := 5:
	set(v):
		seed = v
		_build()

var progress := 0.0
var blessed := 0.0
var shaft := 0.0
var _consecration: ShaderMaterial
var _shaft_material: ShaderMaterial
var _dust: GPUParticles3D
var _candle_light: OmniLight3D
var _heaven_light: SpotLight3D
var _time := 0.0


func _ready() -> void:
	_build()


func _process(delta: float) -> void:
	if not _candle_light:
		return
	_time += delta
	var k := 1.0 - exp(-delta * EASE)
	progress = lerpf(progress, _target_progress(), k)
	blessed = lerpf(blessed, _target_blessed(), k)
	shaft = lerpf(shaft, maxf(blessed, progress * RITUAL_SHAFT), k)
	_consecration.set_shader_parameter("progress", progress)
	_consecration.set_shader_parameter("blessed", blessed)
	_shaft_material.set_shader_parameter("strength", shaft)
	_dust.amount_ratio = shaft
	_dust.emitting = shaft > 0.02
	var frame := floorf(_time * LIGHT_FPS)
	var flicker := 0.88 + 0.12 * absf(sin(frame * 12.9898))
	_candle_light.light_energy = lerpf(CANDLE_LIGHT, BLESSED_LIGHT, blessed) * flicker
	_heaven_light.light_energy = SHAFT_LIGHT * shaft
	_heaven_light.visible = shaft > 0.01


func _target_progress() -> float:
	if Engine.is_editor_hint() or GameState.stage != GameState.Stage.RITUAL:
		return 0.0
	return GameState.ritual


func _target_blessed() -> float:
	if Engine.is_editor_hint():
		return 0.0
	return 1.0 if GameState.release_ready() else 0.0


func _build() -> void:
	if not is_inside_tree():
		return
	for c in get_children():
		if not c.owner:
			c.free()
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	var chalk := _material(CHALK_SHADER)
	chalk.set_shader_parameter("circle", CIRCLE_TEXTURE)
	add_child(_floor_plane(chalk, 0.006))
	_consecration = _material(CONSECRATION_SHADER)
	_consecration.set_shader_parameter("circle", CIRCLE_TEXTURE)
	add_child(_floor_plane(_consecration, 0.009))
	var placements := _candle_placements(rng)
	add_child(_holders(placements))
	add_child(_candles(placements))
	add_child(_flames(placements))
	add_child(_shaft())
	_dust = _dust_motes()
	add_child(_dust)
	_candle_light = OmniLight3D.new()
	_candle_light.light_color = WARM
	_candle_light.omni_range = radius * 3.0
	_candle_light.omni_attenuation = 1.3
	_candle_light.light_energy = CANDLE_LIGHT
	_candle_light.position.y = 0.5
	add_child(_candle_light)
	_heaven_light = SpotLight3D.new()
	_heaven_light.light_color = HEAVENLY
	_heaven_light.spot_range = CEILING + 0.5
	_heaven_light.spot_angle = rad_to_deg(atan(radius * 0.9 / CEILING))
	_heaven_light.spot_angle_attenuation = 1.4
	_heaven_light.position.y = CEILING - 0.05
	_heaven_light.rotation.x = -PI / 2
	_heaven_light.light_energy = 0.0
	_heaven_light.visible = false
	add_child(_heaven_light)


func _material(shader: Shader) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = shader
	return m


func _wax(albedo: Color, glow_from: float) -> ShaderMaterial:
	var m := _material(WAX_SHADER)
	m.set_shader_parameter("albedo", albedo)
	m.set_shader_parameter("glow_from", glow_from)
	return m


func _floor_plane(material: Material, height: float) -> MeshInstance3D:
	var plane := PlaneMesh.new()
	plane.size = Vector2(radius * 2, radius * 2)
	plane.subdivide_width = PLANE_DIVISIONS
	plane.subdivide_depth = PLANE_DIVISIONS
	plane.material = material
	var mi := MeshInstance3D.new()
	mi.mesh = plane
	mi.position.y = height
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return mi


func _candle_placements(rng: RandomNumberGenerator) -> Array[Transform3D]:
	var out: Array[Transform3D] = []
	for i in CANDLE_COUNT:
		var a := TAU * (i + 0.5) / CANDLE_COUNT + rng.randf_range(-0.05, 0.05)
		var r := radius * CANDLE_RING + rng.randf_range(-0.03, 0.03)
		var h := rng.randf_range(0.22, 0.4)
		var axis := Vector3(rng.randf_range(-1, 1), 0, rng.randf_range(-1, 1)).normalized()
		var lean := Basis(axis, rng.randf_range(0.0, 0.04))
		out.append(Transform3D(lean.scaled(Vector3(1, h, 1)), Vector3(cos(a) * r, 0, sin(a) * r)))
	return out


func _multimesh(mesh: Mesh, transforms: Array[Transform3D], custom := false) -> MultiMeshInstance3D:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_custom_data = custom
	mm.mesh = mesh
	mm.instance_count = transforms.size()
	for i in transforms.size():
		mm.set_instance_transform(i, transforms[i])
		if custom:
			mm.set_instance_custom_data(i, Color(float(i) / transforms.size() + 0.37, 0, 0, 0))
	var mi := MultiMeshInstance3D.new()
	mi.multimesh = mm
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return mi


func _holders(placements: Array[Transform3D]) -> MultiMeshInstance3D:
	var dish := CylinderMesh.new()
	dish.top_radius = 0.055
	dish.bottom_radius = 0.045
	dish.height = 0.018
	dish.radial_segments = 6
	dish.rings = 0
	dish.material = _wax(BRASS, NO_GLOW)
	var transforms: Array[Transform3D] = []
	for t in placements:
		transforms.append(Transform3D(Basis(), t.origin + Vector3(0, 0.009, 0)))
	return _multimesh(dish, transforms)


func _candles(placements: Array[Transform3D]) -> MultiMeshInstance3D:
	var body := CylinderMesh.new()
	body.top_radius = CANDLE_RADIUS * 0.9
	body.bottom_radius = CANDLE_RADIUS
	body.height = 1.0
	body.radial_segments = 6
	body.rings = 0
	body.material = _wax(Color(0.9, 0.8, 0.58), 0.93)
	var transforms: Array[Transform3D] = []
	for t in placements:
		transforms.append(Transform3D(t.basis, t.origin + t.basis.y * 0.5 + Vector3(0, 0.018, 0)))
	return _multimesh(body, transforms)


func _flames(placements: Array[Transform3D]) -> MultiMeshInstance3D:
	var quad := QuadMesh.new()
	quad.size = FLAME_SIZE
	quad.center_offset = Vector3(0, FLAME_SIZE.y * 0.5, 0)
	quad.material = _material(FLAME_SHADER)
	var transforms: Array[Transform3D] = []
	for t in placements:
		transforms.append(Transform3D(Basis(), t.origin + t.basis.y + Vector3(0, 0.014, 0)))
	var mi := _multimesh(quad, transforms, true)
	mi.layers = LAYER_WORLD_FX
	return mi


func _shaft() -> MeshInstance3D:
	var cone := CylinderMesh.new()
	cone.top_radius = radius * 0.45
	cone.bottom_radius = radius * 0.85
	cone.height = CEILING
	cone.radial_segments = 12
	cone.rings = 0
	cone.cap_top = false
	cone.cap_bottom = false
	_shaft_material = _material(SHAFT_SHADER)
	cone.material = _shaft_material
	var mi := MeshInstance3D.new()
	mi.mesh = cone
	mi.position.y = CEILING * 0.5
	mi.layers = LAYER_WORLD_FX
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return mi


func _dust_motes() -> GPUParticles3D:
	var process := ParticleProcessMaterial.new()
	process.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	process.emission_box_extents = Vector3(radius * 0.55, CEILING * 0.4, radius * 0.55)
	process.direction = Vector3.DOWN
	process.spread = 180.0
	process.initial_velocity_min = 0.0
	process.initial_velocity_max = 0.03
	process.gravity = Vector3(0, -0.015, 0)
	process.turbulence_enabled = true
	process.turbulence_noise_strength = 0.15
	process.turbulence_noise_scale = 1.5
	var draw := StandardMaterial3D.new()
	draw.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	draw.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	draw.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	draw.albedo_color = Color(0.75, 0.62, 0.4)
	var quad := QuadMesh.new()
	quad.size = Vector2(0.018, 0.018)
	quad.material = draw
	var p := GPUParticles3D.new()
	p.amount = 90
	p.lifetime = 7.0
	p.preprocess = 7.0
	p.fixed_fps = 12
	p.interpolate = false
	p.process_material = process
	p.draw_pass_1 = quad
	p.position.y = CEILING * 0.5
	p.visibility_aabb = AABB(Vector3(-radius, -CEILING * 0.5, -radius), Vector3(radius * 2, CEILING, radius * 2))
	p.layers = LAYER_WORLD_FX
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	p.emitting = false
	p.amount_ratio = 0.0
	return p
