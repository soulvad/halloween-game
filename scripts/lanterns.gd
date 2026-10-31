extends Node3D
## Small jack-o'-lanterns drifting around the dungeon, pure decoration: no collision, nobody reacts to them.
## Routes come from the visitors' navmesh, so they follow rooms and corridors instead of cutting through walls.
## A lantern shut in by a closed door or the bricked wall just wanders on its side. Pauses with the tree (comics, menu).

const Wall = preload("res://scripts/wall.gd")

const COUNT := 9
const SPAWN_TRIES := 40
const NEAR_START := 3.5  ## the first one floats this far in front of the ghost, so the player meets it right away
const MODEL_SIZE := Vector3(1.5, 1.3, 1.5)  ## art/models/Lantern.glb as authored, also the box if it's missing
const SCALE := 0.2  ## about 30 cm wide
const GLOW := Color(1.0, 0.5, 0.12)
const LAYER_HIDDEN_ON_MAP := 2  ## visual layer 2: the minimap culls it


func _ready() -> void:
	var map := get_world_3d().navigation_map
	while NavigationServer3D.map_get_random_point(map, 1, true) == Vector3.ZERO:  # the navmesh reaches the map a few physics frames in
		await get_tree().physics_frame
	var player: Node3D = GameState.player
	for i in COUNT:
		var from := _spawn_point(map)
		if i == 0 and player:
			from = NavigationServer3D.map_get_closest_point(map, player.global_position - player.global_basis.z * NEAR_START)
		add_child(Lantern.new(map, from))


## A random point in the dungeon. The navmesh also covers the rock around the rooms, so keep only what the entrance reaches.
func _spawn_point(map: RID) -> Vector3:
	var entrance: Vector3 = get_parent().get_node("Markers/Entrance").global_position
	for i in SPAWN_TRIES:
		var p := NavigationServer3D.map_get_random_point(map, 1, true)
		if in_dungeon(map, entrance, p):
			return p
	return NavigationServer3D.map_get_closest_point(map, entrance)


static func in_dungeon(map: RID, entrance: Vector3, p: Vector3) -> bool:
	var path := NavigationServer3D.map_get_path(map, entrance, p, true)
	return path.size() > 0 and path[-1].distance_to(p) < 0.5


class Lantern extends Node3D:
	const TURN := 2.5
	const STEER := 1.5  ## how quickly the course bends towards the next path point
	const BOB := 0.14  ## m
	const WOBBLE := 0.22  ## rad
	const LIGHT := 0.5
	const LIGHT_RANGE := 2.6
	const WANDER := 12.0  ## m, how far the next destination can be

	var _map: RID
	var _path := PackedVector3Array()
	var _next := 0
	var _flat := Vector3.ZERO  ## current position on the floor plane
	var _vel := Vector3.ZERO
	var _speed := randf_range(0.7, 1.5)
	var _height := randf_range(1.5, 2.3)
	var _t := randf() * TAU  ## each one on its own beat
	var _light := OmniLight3D.new()

	func _init(map: RID, from: Vector3) -> void:
		_map = map
		_flat = from
		name = "Lantern"
		position = from + Vector3.UP * _height
		var pivot := Node3D.new()
		pivot.scale = Vector3.ONE * SCALE
		pivot.rotation.y = PI  # the model's face looks along +Z, we fly along -Z
		var v := Wall.visual("Lantern", MODEL_SIZE, GLOW)
		pivot.add_child(v)
		add_child(pivot)
		_glow(v)
		_light.light_color = GLOW
		_light.omni_range = LIGHT_RANGE
		add_child(_light)

	## The pumpkin glows from within: tinted orange and emissive, off the minimap.
	func _glow(root: Node3D) -> void:
		var meshes: Array = root.find_children("*", "MeshInstance3D", true, false)
		if root is MeshInstance3D:
			meshes.append(root)
		for m: MeshInstance3D in meshes:
			m.layers = LAYER_HIDDEN_ON_MAP
			var mat := m.mesh.surface_get_material(0).duplicate() as StandardMaterial3D
			mat.albedo_color = Color(1.0, 0.62, 0.3)
			mat.emission_enabled = true
			mat.emission = GLOW
			mat.emission_energy_multiplier = 0.55
			m.material_override = mat

	func _process(delta: float) -> void:
		_t += delta
		if _next >= _path.size():
			var offset := Vector3(randf_range(-WANDER, WANDER), 0, randf_range(-WANDER, WANDER))
			_path = NavigationServer3D.map_get_path(_map, _flat, _flat + offset, true)  # stops at the end of its own part of the dungeon
			_next = 0
		elif _flat.distance_to(_path[_next]) < 0.4:
			_next += 1
		else:
			_vel = _vel.lerp((_path[_next] - _flat).normalized() * _speed, minf(STEER * delta, 1))
		_flat += _vel * delta
		position = _flat + Vector3.UP * (_height + sin(_t * 1.3) * BOB)
		if Vector2(_vel.x, _vel.z).length() > 0.05:
			rotation.y = lerp_angle(rotation.y, atan2(-_vel.x, -_vel.z), minf(TURN * delta, 1))
		rotation.z = sin(_t * 0.9) * WOBBLE
		rotation.x = sin(_t * 0.7 + 1.0) * WOBBLE * 0.5
		_light.light_energy = LIGHT * (0.8 + 0.2 * sin(_t * 9.0) * sin(_t * 4.3))
