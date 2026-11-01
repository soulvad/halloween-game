extends Node
## Headless: must print PAINTINGS OK; if it hangs, an assert failed.

const Paintings = preload("res://scripts/paintings.gd")
const LAYER_WALLS := 2
const LAYER_IN_THE_WAY := 2 | 4 | 8 | 64  ## walls, furniture, stations, rubble


func _frames(n: int) -> void:
	for i in n:
		await get_tree().physics_frame
		await get_tree().process_frame


## The eye at `d` metres straight out of the video painting.
func _eye_at(g: Node, a: Node, d: float) -> void:
	var cam: Camera3D = g.player.get_node("Head/Camera3D")
	var screen: Node3D = a._screen
	cam.global_position = screen.global_position + screen.global_basis.z * d
	await _frames(2)


func _ready() -> void:
	GameState.intro_seen = true
	var g = load("res://scenes/game.tscn").instantiate()
	g.comics_enabled = false
	add_child(g)
	await _frames(3)
	var a = g.get_node("Paintings")

	# all hung, nothing to bump into, the mask noticeably smaller than the rest
	assert(a.get_child_count() == Paintings.PICTURES.size() + 2)  # + the video player
	assert(a.find_children("*", "CollisionObject3D", true, false).is_empty())
	var heights: Array = Paintings.PICTURES.map(func(e): return e[3])
	assert(heights.min() < 0.5 * heights.max() and heights.min() < 0.5 * Paintings.VIDEO[3])

	# every one flat on a wall (not across a door gap), and no wall, furniture or station in its way
	var space: PhysicsDirectSpaceState3D = g.get_world_3d().direct_space_state
	for holder: Node3D in a.get_children().filter(func(n): return n is Node3D):
		var outer: Vector2 = holder.get_meta("size")
		var out := holder.global_basis.z
		for c: Vector2 in [outer / 2, -outer / 2, Vector2(outer.x, -outer.y) / 2, Vector2(-outer.x, outer.y) / 2]:
			var p := holder.global_position + holder.global_basis.x * c.x + holder.global_basis.y * c.y
			assert(p.y > 0.3 and p.y < 2.7)
			var q := PhysicsRayQueryParameters3D.create(p + out * 0.1, p - out * 0.05, LAYER_WALLS)
			assert(not space.intersect_ray(q).is_empty())
		var box := BoxShape3D.new()
		box.size = Vector3(outer.x, outer.y, 0.1)
		var shape := PhysicsShapeQueryParameters3D.new()
		shape.shape = box
		shape.transform = Transform3D(holder.global_basis, holder.global_position + out * 0.07)
		shape.collision_mask = LAYER_IN_THE_WAY
		assert(space.intersect_shape(shape).is_empty())

	# the falloff is cubic and over at HEAR_RANGE
	assert(is_equal_approx(Paintings.gain(0.0), 1.0))
	assert(is_equal_approx(Paintings.gain(Paintings.HEAR_RANGE / 2), 0.125))
	assert(Paintings.gain(Paintings.HEAR_RANGE) == 0.0 and Paintings.gain(100.0) == 0.0)

	# next to it: playing and audible; just past the range: silent, still playing; far off: paused
	assert(a._video.stream is VideoStreamTheora and a._video.loop and a._video.is_playing())
	await _eye_at(g, a, 0.6)
	assert(not a._video.paused and absf(a._video.volume - Paintings.gain(0.6)) < 0.001)
	await _eye_at(g, a, Paintings.HEAR_RANGE + 0.01)
	assert(not a._video.paused and a._video.volume == 0.0)
	await _eye_at(g, a, Paintings.PLAY_RANGE + 1.0)
	assert(a._video.paused and a._video.volume == 0.0)

	# frames really reach the screen, and it loops past its end
	await _eye_at(g, a, 1.0)
	var mat: StandardMaterial3D = a._screen.mesh.material
	assert(mat.albedo_texture != null)
	var length: float = a._video.get_stream_length()
	assert(length > 30.0)
	a._video.stream_position = length - 0.5
	var t0 := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < 2000:
		await _frames(1)
	assert(a._video.is_playing() and a._video.stream_position < 5.0)
	assert(mat.albedo_texture != null)

	print("PAINTINGS OK")
	get_tree().quit()
