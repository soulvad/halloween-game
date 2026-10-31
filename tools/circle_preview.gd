extends SceneTree

const CENTRE := Vector3(20.5, 0.0, -10.0)
const ORBIT_RADIUS := 2.2
const ORBIT_HEIGHT := 1.5
const ORBIT_SPEED := 0.12
const CALM_TIME := 5.0
const PRAYER_TIME := 14.0
const BLESSED_TIME := 9.0
const CYCLE := CALM_TIME + PRAYER_TIME + BLESSED_TIME
const SHOT_TIMES := [3.0, 12.0, 24.0]

var _game: Node
var _gs: Node
var _cam: Camera3D
var _caption: Label
var _start := 0
var _shots_dir := ""
var _shot := 0


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() >= 2 and args[0] == "shots":
		_shots_dir = args[1]
	_gs = root.get_node("GameState")
	_gs.intro_seen = true
	_gs.show_labels = false
	_game = load("res://scenes/game.tscn").instantiate()
	_game.comics_enabled = false
	root.add_child(_game)
	_setup.call_deferred()


func _setup() -> void:
	_game.set_process(false)
	_game.get_node("HUD").visible = false
	var player := _game.get_node_or_null("Player")
	if player:
		player.process_mode = Node.PROCESS_MODE_DISABLED
		player.visible = false
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_cam = Camera3D.new()
	_cam.fov = 68
	_game.add_child(_cam)
	_cam.current = true
	var layer := CanvasLayer.new()
	_caption = Label.new()
	_caption.position = Vector2(40, 30)
	_caption.add_theme_font_size_override("font_size", 34)
	_caption.add_theme_color_override("font_color", Color.WHITE)
	_caption.add_theme_color_override("font_outline_color", Color.BLACK)
	_caption.add_theme_constant_override("outline_size", 10)
	_caption.visible = _shots_dir.is_empty()
	layer.add_child(_caption)
	_game.add_child(layer)
	_start = Time.get_ticks_msec()
	process_frame.connect(_tick)


func _tick() -> void:
	var elapsed := (Time.get_ticks_msec() - _start) / 1000.0
	var a := elapsed * ORBIT_SPEED
	_cam.global_position = CENTRE + Vector3(cos(a) * ORBIT_RADIUS, ORBIT_HEIGHT, sin(a) * ORBIT_RADIUS)
	_cam.look_at(CENTRE + Vector3(0, 0.3, 0))
	var t := fmod(elapsed, CYCLE)
	if t < CALM_TIME:
		_set_state(0, 0.0)
		_caption.text = "Спокій: крейдяне коло і свічки"
	elif t < CALM_TIME + PRAYER_TIME:
		_set_state(_gs.Stage.RITUAL, minf((t - CALM_TIME) / PRAYER_TIME, 0.99))
		_caption.text = "Священник молиться: %d%%" % int(_gs.ritual * 100)
	else:
		_set_state(_gs.Stage.RITUAL, 1.0)
		_caption.text = "Коло освячене: можна піти"
	if not _shots_dir.is_empty() and _shot < SHOT_TIMES.size() and elapsed >= SHOT_TIMES[_shot]:
		root.get_viewport().get_texture().get_image().save_png("%s/circle_%d.png" % [_shots_dir, _shot])
		_shot += 1
		if _shot == SHOT_TIMES.size():
			quit()


func _set_state(stage: int, ritual: float) -> void:
	_gs.stage = stage
	_gs.ritual = ritual
