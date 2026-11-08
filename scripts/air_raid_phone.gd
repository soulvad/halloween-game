extends Node3D
## The phone lying on the archaeologists' table: a no-name book-style foldable, half-open (the left half flat on the
## table, the right one sprung up FOLD from the hinge), with the air-raid alerts app on its nearly square inner screen.
## easter_eggs.gd decides when the alert goes off and calls alert(). Purely a thing to look at: no collision, no story.
## The screen sleeps dim, wakes when the ghost comes close, pulses and throws a light on the table during the alert.
## At its real size the small print is too fine to read, so looking straight at it from close by fades in a close-up
## on the side of the screen (it never blocks the crosshair or E, the plan lies right next to it).
## Generic on purpose: plain grey frame, black glass, a crease down the middle, one round camera dot in the bezel.

const SCREEN_TEX := preload("res://art/textures/air_raid_phone.jpg")

const SPOT := Vector2(-0.72, 0.2)  ## (x, z) from the table's centre: beside the plan, on the side people stand at
const TURN := 0.2  ## a bit askew, somebody put it down; the top of the screen points away from the room
const BODY := Vector3(0.137, 0.0065, 0.172)  ## opened out: width across both halves, thickness, height
const SCREEN_W := 0.128  ## across both halves; its height follows the picture
const FOLD := deg_to_rad(10.0)  ## the right half's tilt up from the hinge: not quite flat, so it reads as a foldable
const RIM := 0.0012  ## the metal frame showing around the glass
const GLASS := 0.0004  ## glass plate thickness
const SCREEN_LIFT := 0.0003  ## over the glass, enough not to flicker from across the room
const CREASE := 0.003  ## shaded strip either side of the fold
const CREASE_DARK := 0.6
const CREASE_LINE := Color(0.14, 0.14, 0.16)  ## added over the picture
const CREASE_LINE_W := 0.0009
const CAMERA_R := 0.0011
const FRAME_COLOR := Color(0.36, 0.36, 0.39)  ## light enough to outline the black glass and picture
const GLASS_COLOR := Color(0.015, 0.015, 0.02)

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


## Lie on the table's top, the flat half and the hinge touching it. Wall boxes have their origin at half height (docs/assets.md).
func lay_on(table: Node3D) -> void:
	position = table.global_position + Vector3(SPOT.x, table.size.y / 2.0, SPOT.y)
	rotation.y = TURN


func alert() -> void:
	alert_left = ALERT_TIME


## The screen's size in metres (unfolded), keeping the picture's proportions.
func screen_size() -> Vector2:
	return Vector2(SCREEN_W, SCREEN_W * SCREEN_TEX.get_height() / SCREEN_TEX.get_width())


func _build_body() -> void:
	var frame := _material(FRAME_COLOR, 0.3, 0.4)
	var glass := _material(GLASS_COLOR, 0.0, 0.12)
	var half := BODY.x / 2.0
	for side: int in [-1, 1]:
		var pivot := Node3D.new()  # the hinge line on the table; the half lies flat in it, then tips up
		pivot.name = "Half%s" % ("L" if side < 0 else "R")
		pivot.rotation.z = _tilt(side)
		add_child(pivot)
		_part(pivot, BoxMesh.new(), Vector3(half, BODY.y, BODY.z), Vector3(side * half / 2.0, BODY.y / 2.0, 0), frame)
		var gw := half - RIM  # the glass runs into the hinge, the frame shows on the other three sides
		_part(pivot, BoxMesh.new(), Vector3(gw, GLASS, BODY.z - 2 * RIM), Vector3(side * gw / 2.0, BODY.y + GLASS / 2.0, 0), glass)
	# the camera: one round dot in the top bezel of the right half, over a lighter ring
	var right := get_node("HalfR")
	var bezel := (BODY.z - screen_size().y) / 2.0
	var cam_at := Vector3(half / 2.0, BODY.y + GLASS, -BODY.z / 2.0 + bezel / 2.0)
	_disc(right, CAMERA_R * 1.45, 0.0001, cam_at, _material(Color(0.5, 0.5, 0.53), 0.5, 0.3))
	_disc(right, CAMERA_R, 0.0002, cam_at, _material(Color(0.02, 0.03, 0.06), 0.3, 0.05))
	# the hinge's spine, its ends just showing past the halves
	var spine := CylinderMesh.new()
	spine.top_radius = BODY.y * 0.42
	spine.bottom_radius = spine.top_radius
	spine.height = BODY.z + 0.001
	spine.radial_segments = 12
	var hinge := _part(self, spine, Vector3.ZERO, Vector3(0, spine.top_radius, 0), frame)
	hinge.rotation.x = PI / 2.0
	_build_screen()
	_light = OmniLight3D.new()
	_light.light_color = LIGHT_COLOR
	_light.omni_range = LIGHT_RANGE
	_light.light_energy = 0.0
	_light.position.y = 0.25
	add_child(_light)
	_apply_level()


## The inner screen as one mesh bent along the fold: from the crease (where both halves' top planes meet, over the
## hinge) out to each edge, the picture's halves left and right, a soft shade on the crease.
func _build_screen() -> void:
	_screen_mat = StandardMaterial3D.new()
	_screen_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED  # it gives light, the dungeon's dark doesn't touch it
	_screen_mat.albedo_texture = SCREEN_TEX
	_screen_mat.vertex_color_use_as_albedo = true
	_screen_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	_screen_mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	var size := screen_size()
	var crease := _crease(BODY.y + GLASS + SCREEN_LIFT)
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for side: int in [-1, 1]:
		var dir := Vector3(side * cos(_tilt(side)), side * sin(_tilt(side)), 0)
		var stops := [0.0, CREASE, size.x / 2.0]  # distance from the crease
		for i in 2:
			var a: float = stops[i]
			var b: float = stops[i + 1]
			var pa := crease + dir * a
			var pb := crease + dir * b
			var ua: float = 0.5 + side * a / size.x
			var ub: float = 0.5 + side * b / size.x
			var ca := Color.WHITE * (CREASE_DARK if i == 0 else 1.0)
			ca.a = 1.0
			var corners := [  # top (-Z, v 0) and bottom of both edges
				[pa + Vector3(0, 0, -size.y / 2), Vector2(ua, 0), ca], [pb + Vector3(0, 0, -size.y / 2), Vector2(ub, 0), Color.WHITE],
				[pb + Vector3(0, 0, size.y / 2), Vector2(ub, 1), Color.WHITE], [pa + Vector3(0, 0, size.y / 2), Vector2(ua, 1), ca],
			]
			for k in [0, 1, 2, 0, 2, 3]:
				st.set_color(corners[k][2])
				st.set_uv(corners[k][1])
				st.add_vertex(corners[k][0])
	var screen := MeshInstance3D.new()
	screen.name = "Screen"
	screen.mesh = st.commit()
	screen.material_override = _screen_mat
	screen.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(screen)
	# the fold catches a little light: a faint line over the crease, seen even where the picture is black
	var line_mat := StandardMaterial3D.new()
	line_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	line_mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	line_mat.albedo_color = CREASE_LINE
	var line_mesh := QuadMesh.new()
	line_mesh.size = Vector2(CREASE_LINE_W, size.y)
	line_mesh.material = line_mat
	var line := MeshInstance3D.new()
	line.name = "Crease"
	line.mesh = line_mesh
	line.rotation.x = -PI / 2.0
	line.position = crease + Vector3(0, 0.0002, 0)
	line.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	screen.add_child(line)


## A half's turn about the hinge (z): the right one tips up, the left lies flat.
func _tilt(side: int) -> float:
	return FOLD if side > 0 else 0.0


## Where the two halves' planes at height h (in their own frames) cross over the hinge.
func _crease(h: float) -> Vector3:
	var a1 := -sin(_tilt(-1))
	var b1 := cos(_tilt(-1))
	var a2 := -sin(_tilt(1))
	var b2 := cos(_tilt(1))
	var det := a1 * b2 - a2 * b1
	if absf(det) < 1e-6:
		return Vector3(0, h, 0)
	return Vector3(h * (b2 - b1) / det, h * (a1 - a2) / det, 0)


func _material(c: Color, metal: float, rough: float) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.metallic = metal
	m.roughness = rough
	return m


func _part(parent: Node, mesh: PrimitiveMesh, size: Vector3, at: Vector3, mat: Material) -> MeshInstance3D:
	if mesh is BoxMesh:
		(mesh as BoxMesh).size = size
	mesh.material = mat
	var m := MeshInstance3D.new()
	m.mesh = mesh
	m.position = at
	parent.add_child(m)
	return m


func _disc(parent: Node, r: float, h: float, at: Vector3, mat: Material) -> void:
	var c := CylinderMesh.new()
	c.top_radius = r
	c.bottom_radius = r
	c.height = h
	c.radial_segments = 16
	_part(parent, c, Vector3.ZERO, at + Vector3(0, h / 2.0, 0), mat).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


## The close-up: the same phone seen from above, flat, its picture at full sharpness.
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
	var body := _panel(box, FRAME_COLOR, 14)
	var glass := _panel(body, GLASS_COLOR, 12)
	glass.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT, Control.PRESET_MODE_MINSIZE, 3)
	var size := screen_size()
	var mx := (1.0 - size.x / BODY.x) / 2.0
	var my := (1.0 - size.y / BODY.z) / 2.0
	var pic := TextureRect.new()
	pic.texture = SCREEN_TEX
	pic.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS  # shown at about half size: keep the print clean
	pic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	pic.stretch_mode = TextureRect.STRETCH_SCALE
	pic.anchor_left = mx
	pic.anchor_right = 1.0 - mx
	pic.anchor_top = my
	pic.anchor_bottom = 1.0 - my
	pic.mouse_filter = Control.MOUSE_FILTER_IGNORE
	body.add_child(pic)
	var crease := ColorRect.new()  # the fold down the middle
	crease.color = Color(0, 0, 0, 0.3)
	crease.anchor_left = 0.5
	crease.anchor_right = 0.5
	crease.anchor_bottom = 1.0
	crease.offset_left = -1.5
	crease.offset_right = 1.5
	crease.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pic.add_child(crease)
	var cam := _panel(body, Color(0.02, 0.03, 0.06), 5)
	cam.get_theme_stylebox("panel").border_color = Color(0.2, 0.2, 0.22)
	cam.get_theme_stylebox("panel").set_border_width_all(1)
	cam.anchor_left = 0.75
	cam.anchor_right = 0.75
	cam.anchor_top = my / 2.0
	cam.anchor_bottom = my / 2.0
	cam.offset_left = -5
	cam.offset_right = 5
	cam.offset_top = -5
	cam.offset_bottom = 5


func _panel(parent: Control, c: Color, radius: int) -> Panel:
	var style := StyleBoxFlat.new()
	style.bg_color = c
	style.set_corner_radius_all(radius)
	style.anti_aliasing = true
	var p := Panel.new()
	p.add_theme_stylebox_override("panel", style)
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(p)
	return p


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
