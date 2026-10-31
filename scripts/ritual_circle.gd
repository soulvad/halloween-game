@tool
extends Node3D

const CIRCLE_TEXTURE := preload("res://art/textures/holy_circle_psx.webp")
const CHALK_SHADER := preload("res://shaders/psx_chalk.gdshader")
const CONSECRATION_SHADER := preload("res://shaders/psx_consecration.gdshader")
const FLAME_SHADER := preload("res://shaders/psx_flame.gdshader")
const WAX_SHADER := preload("res://shaders/psx_wax.gdshader")
const SWIRL_SHADER := preload("res://shaders/psx_swirl.gdshader")
const RAYS_SHADER := preload("res://shaders/psx_rays.gdshader")
const CURTAIN_SHADER := preload("res://shaders/psx_curtain.gdshader")
const SPARKLE_SHADER := preload("res://shaders/psx_sparkle.gdshader")

const LAYER_WORLD_FX := 2
const PLANE_DIVISIONS := 8
const SWIRL_MARGIN := 1.3
const SWIRL_LAYERS := [
	{"height": 0.02, "ring": 0.99, "direction": 1.0, "speed": 0.45, "arcs": 6, "main": 1.0, "strength": 1.0},
	{"height": 0.09, "ring": 1.05, "direction": -1.0, "speed": 0.35, "arcs": 4, "main": 0.6, "strength": 0.75},
	{"height": 0.2, "ring": 0.93, "direction": 1.0, "speed": 0.6, "arcs": 3, "main": 0.0, "strength": 0.5},
]
const THIN_RAYS := 12
const WIDE_RAYS := 8
const RAY_RING := 0.99
const CURTAIN_HEIGHT := 1.9
const SPARKLES := 220
const CANDLE_COUNT := 8
const CANDLE_RADIUS := 0.024
const CANDLE_RING := 1.12
const FLAME_SIZE := Vector2(0.06, 0.13)
const WARM := Color(1.0, 0.66, 0.36)
const GOLD := Color(1.0, 0.72, 0.3)
const BRASS := Color(0.55, 0.4, 0.18)
const NO_GLOW := 2.0
const EFFECT_DITHER := 2.0
const CANDLE_LIGHT := 1.3
const GOLD_LIGHT := 2.6
const CALM_POWER := 0.35
const BLESSED_POWER := 1.0
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
var power := CALM_POWER
var _consecration: ShaderMaterial
var _effects: Array[ShaderMaterial] = []
var _swirl_strength: Array[float] = []
var _sparkles: GPUParticles3D
var _candle_light: OmniLight3D
var _gold_light: OmniLight3D
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
	var target := lerpf(lerpf(CALM_POWER, 1.0, progress), BLESSED_POWER, blessed)
	power = lerpf(power, target, k)
	_consecration.set_shader_parameter("progress", progress)
	_consecration.set_shader_parameter("blessed", blessed)
	for i in _effects.size():
		_effects[i].set_shader_parameter("power", power * _swirl_strength[i])
	_sparkles.amount_ratio = clampf(power, 0.0, 1.0)
	var frame := floorf(_time * LIGHT_FPS)
	var flicker := 0.88 + 0.12 * absf(sin(frame * 12.9898))
	_candle_light.light_energy = CANDLE_LIGHT * flicker
	_gold_light.light_energy = GOLD_LIGHT * power * (0.9 + 0.1 * sin(_time * 2.1))


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
	_effects.clear()
	_swirl_strength.clear()
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	var chalk := _material(CHALK_SHADER)
	chalk.set_shader_parameter("circle", CIRCLE_TEXTURE)
	add_child(_floor_plane(chalk, radius, 0.006, true))
	_consecration = _material(CONSECRATION_SHADER)
	_consecration.set_shader_parameter("circle", CIRCLE_TEXTURE)
	add_child(_floor_plane(_consecration, radius, 0.009, true))
	for i in SWIRL_LAYERS.size():
		add_child(_swirl(SWIRL_LAYERS[i], i))
	add_child(_rays(rng))
	add_child(_curtain())
	_sparkles = _sparkle_particles()
	add_child(_sparkles)
	var placements := _candle_placements(rng)
	add_child(_holders(placements))
	add_child(_candles(placements))
	add_child(_flames(placements))
	_candle_light = OmniLight3D.new()
	_candle_light.light_color = WARM
	_candle_light.omni_range = radius * 3.0
	_candle_light.omni_attenuation = 1.3
	_candle_light.light_energy = CANDLE_LIGHT
	_candle_light.position.y = 0.5
	add_child(_candle_light)
	_gold_light = OmniLight3D.new()
	_gold_light.light_color = GOLD
	_gold_light.omni_range = radius * 2.6
	_gold_light.omni_attenuation = 1.8
	_gold_light.light_energy = 0.0
	_gold_light.position.y = 0.25
	add_child(_gold_light)


func _material(shader: Shader) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = shader
	return m


func _effect(shader: Shader, strength: float) -> ShaderMaterial:
	var m := _material(shader)
	m.set_shader_parameter("psx_dither_pixel", EFFECT_DITHER)
	_effects.append(m)
	_swirl_strength.append(strength)
	return m


func _wax(albedo: Color, glow_from: float) -> ShaderMaterial:
	var m := _material(WAX_SHADER)
	m.set_shader_parameter("albedo", albedo)
	m.set_shader_parameter("glow_from", glow_from)
	return m


func _floor_plane(material: Material, half: float, height: float, subdivided: bool) -> MeshInstance3D:
	var plane := PlaneMesh.new()
	plane.size = Vector2(half * 2, half * 2)
	if subdivided:
		plane.subdivide_width = PLANE_DIVISIONS
		plane.subdivide_depth = PLANE_DIVISIONS
	plane.material = material
	var mi := MeshInstance3D.new()
	mi.mesh = plane
	mi.position.y = height
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return mi


func _swirl(layer: Dictionary, index: int) -> MeshInstance3D:
	var half := radius * SWIRL_MARGIN
	var m := _effect(SWIRL_SHADER, layer.strength)
	m.set_shader_parameter("ring", radius * layer.ring / half)
	m.set_shader_parameter("direction", layer.direction)
	m.set_shader_parameter("speed", layer.speed)
	m.set_shader_parameter("arc_count", float(layer.arcs))
	m.set_shader_parameter("main_line", layer.main)
	m.set_shader_parameter("seed", float(seed + index * 7))
	var mi := _floor_plane(m, half, layer.height, true)
	mi.layers = LAYER_WORLD_FX
	return mi


func _rays(rng: RandomNumberGenerator) -> MultiMeshInstance3D:
	var quad := QuadMesh.new()
	quad.size = Vector2(1, 1)
	quad.center_offset = Vector3(0, 0.5, 0)
	quad.material = _effect(RAYS_SHADER, 1.0)
	var transforms: Array[Transform3D] = []
	var customs: Array[Color] = []
	var total := THIN_RAYS + WIDE_RAYS
	for i in total:
		var wide := i >= THIN_RAYS
		var count := WIDE_RAYS if wide else THIN_RAYS
		var slot := (i - THIN_RAYS if wide else i) + (0.5 if wide else 0.0)
		var a := TAU * slot / count + rng.randf_range(-0.15, 0.15)
		var r := radius * RAY_RING + rng.randf_range(-0.04, 0.04)
		var w := rng.randf_range(0.35, 0.6) if wide else rng.randf_range(0.08, 0.16)
		var h := rng.randf_range(0.8, 1.5) if wide else rng.randf_range(0.6, 1.4)
		transforms.append(Transform3D(Basis.from_scale(Vector3(w, h, w)), Vector3(cos(a) * r, 0.01, sin(a) * r)))
		customs.append(Color(rng.randf(), 1.0 if wide else 0.0, 0, 0))
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_custom_data = true
	mm.mesh = quad
	mm.instance_count = total
	for i in total:
		mm.set_instance_transform(i, transforms[i])
		mm.set_instance_custom_data(i, customs[i])
	var mi := MultiMeshInstance3D.new()
	mi.multimesh = mm
	mi.layers = LAYER_WORLD_FX
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return mi


func _curtain() -> MeshInstance3D:
	var wall := CylinderMesh.new()
	wall.top_radius = radius * 1.03
	wall.bottom_radius = radius * 0.99
	wall.height = CURTAIN_HEIGHT
	wall.radial_segments = 24
	wall.rings = 0
	wall.cap_top = false
	wall.cap_bottom = false
	wall.material = _effect(CURTAIN_SHADER, 1.0)
	var mi := MeshInstance3D.new()
	mi.mesh = wall
	mi.position.y = CURTAIN_HEIGHT * 0.5
	mi.layers = LAYER_WORLD_FX
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return mi


func _sparkle_particles() -> GPUParticles3D:
	var process := ParticleProcessMaterial.new()
	process.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_RING
	process.emission_ring_axis = Vector3.UP
	process.emission_ring_radius = radius * 1.04
	process.emission_ring_inner_radius = radius * 0.88
	process.emission_ring_height = 0.04
	process.direction = Vector3.UP
	process.spread = 30.0
	process.initial_velocity_min = 0.03
	process.initial_velocity_max = 0.4
	process.radial_velocity_min = 0.02
	process.radial_velocity_max = 0.14
	process.gravity = Vector3(0, 0.04, 0)
	process.damping_min = 0.05
	process.damping_max = 0.2
	process.turbulence_enabled = true
	process.turbulence_noise_strength = 0.25
	process.turbulence_noise_scale = 2.0
	process.scale_min = 0.5
	process.scale_max = 1.6
	var fade := Gradient.new()
	fade.set_color(0, Color(1.0, 0.85, 0.5, 0.0))
	fade.add_point(0.12, Color(1.0, 0.82, 0.45, 1.0))
	fade.add_point(0.6, Color(1.0, 0.62, 0.2, 0.8))
	fade.set_color(fade.get_point_count() - 1, Color(1.0, 0.45, 0.1, 0.0))
	var ramp := GradientTexture1D.new()
	ramp.gradient = fade
	process.color_ramp = ramp
	var quad := QuadMesh.new()
	quad.size = Vector2(0.04, 0.04)
	quad.material = _effect(SPARKLE_SHADER, 1.0)
	var p := GPUParticles3D.new()
	p.amount = SPARKLES
	p.lifetime = 3.0
	p.preprocess = 3.0
	p.process_material = process
	p.draw_pass_1 = quad
	p.visibility_aabb = AABB(Vector3(-radius * 1.6, -0.2, -radius * 1.6), Vector3(radius * 3.2, 2.6, radius * 3.2))
	p.layers = LAYER_WORLD_FX
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	p.amount_ratio = CALM_POWER
	return p


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
