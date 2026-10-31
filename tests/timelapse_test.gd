extends Node
## Headless: must print TIMELAPSE OK; if it hangs, an assert failed.

const Timelapse = preload("res://scripts/timelapse.gd")


func _frames(n: int) -> void:
	for i in n:
		await get_tree().physics_frame
		await get_tree().process_frame


func _game() -> Node3D:
	var g = load("res://scenes/game.tscn").instantiate()
	g.comics_enabled = false
	g.process_mode = Node.PROCESS_MODE_PAUSABLE  # this test node runs always: the game must still pause
	add_child(g)
	await _frames(3)
	return g


## The end state, after a skip or the full run.
func _check(g: Node3D) -> void:
	assert(g.get_node_or_null("Level/Rubble") == null)
	assert(g.get_node("Player").camera.current)
	assert(not get_tree().paused)
	assert(g.get_node("HUD").visible)
	for v in get_tree().get_nodes_in_group("visitor"):
		assert(v.visible and v.global_position.distance_to(Vector3(14.75, v.global_position.y, -10.875)) < 4.0)


func _ready() -> void:
	GameState.intro_seen = true
	# skip: Space / Esc lands on the end state at once
	var g := await _game()
	var lines := []
	GameState.said.connect(func(who, _t, _c): lines.append(who))
	var t = Timelapse.new()
	g.add_child(t)
	t.play(g)
	await _frames(2)
	assert(get_tree().paused and not g.get_node("Player").camera.current)
	assert(t._legs.size() == 4)  # two rooms, the plan, the wall
	var done := [false]
	t.finished.connect(func(): done[0] = true)
	t.skip()
	assert(done[0])
	_check(g)
	g.free()
	await _frames(2)

	# full run, sped up: all subtitle lines, then the same end state
	g = await _game()
	lines.clear()
	t = Timelapse.new()
	g.add_child(t)
	t.play(g)
	assert(t._total > 15.0 and t._total < 30.0)
	Engine.time_scale = 10.0
	done[0] = false
	t.finished.connect(func(): done[0] = true; Engine.time_scale = 1.0)  # before the next physics frame moves people on
	var waited := 0.0
	while not done[0] and waited < 40.0:
		await get_tree().process_frame
		waited += get_process_delta_time()
	Engine.time_scale = 1.0
	assert(done[0])
	assert(lines.size() == 4 and "Отець Василь" in lines)
	_check(g)
	print("TIMELAPSE OK")
	get_tree().quit()
