extends Node3D
## The phone lying on the archaeologists' table: a dark slab with the air-raid notifications on its screen.
## easter_eggs.gd decides when the alert goes off and calls alert(). Purely a thing to look at: no collision, no story.
## The screen sleeps dim, wakes when the ghost comes close, pulses and throws a light on the table during the alert.
## At its real size the small print is too fine to read, so looking straight at it from close by fades in a close-up
## on the side of the screen (it never blocks the crosshair or E, the plan lies right next to it).

const Wall = preload("res://scripts/wall.gd")
const SCREEN_TEX := preload("res://art/textures/air_raid_phone.jpg")

const SPOT := Vector2(-0.72, 0.2)  ## (x, z) from the table's centre: beside the plan, on the side people stand at
const TURN := 0.2  ## a bit askew, somebody put it down; the top of the screen points away from the room
const BODY := Vector3(0.122, 0.012, 0.25)
const SCREEN_W := 0.11  ## its height follows the picture
const SCREEN_LIFT := 0.002  ## over the body, enough not to flicker from across the room

const WAKE_NEAR := 3.0
const LEVEL_ASLEEP := 0.1
const LEVEL_AWAKE := 0.8
const LEVEL_FADE := 4.0  ## level per second
const ALERT_TIME := 30.0
const PULSE := 5.0
const LIGHT_COLOR := Color(1, 0.6, 0.5)
const LIGHT_ENERGY := 1.4
const LIGHT_RANGE := 2.5
const CLOSE_RANGE := 1.8  ## camera to screen
const CLOSE_AIM := 0.93  ## cosine of the angle off the view's centre (about 21 degrees)
const CLOSE_FADE := 5.0

var alert_left := 0.0  ## seconds of the alert left
var level := LEVEL_ASLEEP  ## current screen brightness
var closeup := 0.0  ## close-up opacity, 0..1

var _screen_mat: StandardMaterial3D
var _light: OmniLight3D
var _overlay: CanvasLayer
var _overlay_root: Control
var _t := 0.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS  # to drop the close-up the moment the game pauses
	_build_body()
	_build_overlay()


## Lie flat on the table's top. Wall boxes have their origin at half height, and models fit the box (docs/assets.md).
func lay_on(table: Node3D) -> void:
	position = table.global_position + Vector3(SPOT.x, table.size.y / 2.0, SPOT.y)
	rotation.y = TURN


func alert() -> void:
	alert_left = ALERT_TIME


## The screen's size in metres, keeping the picture's proportions.
func screen_size() -> Vector2:
	return Vector2(SCREEN_W, SCREEN_W * SCREEN_TEX.get_height() / SCREEN_TEX.get_width())


func _build_body() -> void:
	var body := Wall.box(BODY, Color(0.04, 0.04, 0.05))
	body.position.y = BODY.y / 2.0
	add_child(body)
	_screen_mat = StandardMaterial3D.new()
	_screen_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED  # it gives light, the dungeon's dark doesn't touch it
	_screen_mat.albedo_texture = SCREEN_TEX
	_screen_mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	var quad := QuadMesh.new()
	quad.size = screen_size()
	quad.material = _screen_mat
	var screen := MeshInstance3D.new()
	screen.name = "Screen"
	screen.mesh = quad
	screen.rotation.x = -PI / 2.0  # faces up, the picture's top towards -Z
	screen.position.y = BODY.y + SCREEN_LIFT
	screen.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(screen)
	_light = OmniLight3D.new()
	_light.light_color = LIGHT_COLOR
	_light.omni_range = LIGHT_RANGE
	_light.light_energy = 0.0
	_light.position.y = 0.25
	add_child(_light)
	_apply_level()


func _build_overlay() -> void:
	_overlay = CanvasLayer.new()
	_overlay.visible = false
	add_child(_overlay)
	var box := AspectRatioContainer.new()
	box.ratio = BODY.x / BODY.z
	box.alignment_horizontal = AspectRatioContainer.ALIGNMENT_END
	box.anchor_left = 0.5  # left of the minimap column, right of the crosshair
	box.anchor_right = 0.81
	box.anchor_top = 0.14
	box.anchor_bottom = 0.86
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_overlay.add_child(box)
	_overlay_root = box
	var bezel := ColorRect.new()
	bezel.color = Color(0.04, 0.04, 0.05)
	bezel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(bezel)
	var pic := TextureRect.new()
	pic.texture = SCREEN_TEX
	pic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	pic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	pic.set_anchors_preset(Control.PRESET_FULL_RECT)
	pic.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bezel.add_child(pic)


func _process(delta: float) -> void:
	if get_tree().paused:
		_overlay.visible = false
		return
	_t += delta
	alert_left = maxf(alert_left - delta, 0.0)
	var pulse := 0.5 + 0.5 * sin(_t * PULSE)
	var target := LEVEL_ASLEEP
	if alert_left > 0:
		target = lerpf(LEVEL_AWAKE, 1.0, pulse)
	elif _ghost_near():
		target = LEVEL_AWAKE
	level = move_toward(level, target, LEVEL_FADE * delta)
	_apply_level()
	_light.light_energy = LIGHT_ENERGY * pulse if alert_left > 0 else 0.0
	closeup = move_toward(closeup, 1.0 if _looked_at() else 0.0, CLOSE_FADE * delta)
	_overlay.visible = closeup > 0
	_overlay_root.modulate.a = closeup


func _apply_level() -> void:
	_screen_mat.albedo_color = Color(level, level, level)


func _ghost_near() -> bool:
	var ghost := GameState.player
	return ghost != null and GameState.phase == GameState.Phase.PLAY and ghost.global_position.distance_to(global_position) < WAKE_NEAR


## The ghost's own camera (not the guide's), close, with the phone near the middle of the view.
func _looked_at() -> bool:
	var ghost := GameState.player
	if ghost == null or GameState.phase != GameState.Phase.PLAY or not ghost.camera.current:
		return false
	var cam: Camera3D = ghost.camera
	var to_phone := global_position - cam.global_position
	return to_phone.length() < CLOSE_RANGE and -cam.global_basis.z.dot(to_phone.normalized()) > CLOSE_AIM
