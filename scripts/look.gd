extends Node
## Visual looks to compare: Environment overrides + light tint + optional screen pass (look.gdshader).
## Node `Look`, added by game.gd. F2 cycles (debug); `current` is static, so the choice survives a restart.
## Look 0 is the scene as generated (no overrides). Nothing here touches the generated scene file.

const LOOKS := [
	{"name": "Як зараз"},
	{
		"name": "Теплі свічки",
		"env": {
			"background_color": Color(0.03, 0.015, 0.01),
			"ambient_light_color": Color(0.45, 0.3, 0.2), "ambient_light_energy": 0.35,
			"tonemap_mode": Environment.TONE_MAPPER_ACES,
			"fog_light_color": Color(0.2, 0.1, 0.04), "fog_density": 0.035,
			"glow_enabled": true, "glow_intensity": 0.9, "glow_bloom": 0.15, "glow_hdr_threshold": 0.8,
			"ssao_enabled": true, "ssao_intensity": 2.5,
			"adjustment_enabled": true, "adjustment_saturation": 1.15, "adjustment_contrast": 1.05,
		},
		"light": {"tint": Color(1.0, 0.85, 0.65), "energy": 1.2},
		"post": {"vignette": 0.45},
	},
	{
		"name": "Холодний туман",
		"env": {
			"background_color": Color(0.01, 0.02, 0.04),
			"ambient_light_color": Color(0.25, 0.35, 0.55), "ambient_light_energy": 0.5,
			"tonemap_mode": Environment.TONE_MAPPER_FILMIC,
			"fog_light_color": Color(0.1, 0.16, 0.26), "fog_density": 0.03,
			"volumetric_fog_enabled": true, "volumetric_fog_density": 0.06,
			"volumetric_fog_albedo": Color(0.7, 0.8, 1.0), "volumetric_fog_emission": Color(0.02, 0.03, 0.06),
			"glow_enabled": true, "glow_intensity": 0.7, "glow_bloom": 0.1,
			"adjustment_enabled": true, "adjustment_saturation": 0.7,
		},
		"light": {"tint": Color(0.75, 0.85, 1.0), "energy": 1.2},
		"post": {"vignette": 0.35},
	},
	{
		"name": "Темний хорор",
		"env": {
			"background_color": Color(0, 0, 0),
			"ambient_light_color": Color(0.2, 0.18, 0.25), "ambient_light_energy": 0.12,
			"tonemap_mode": Environment.TONE_MAPPER_ACES, "tonemap_exposure": 1.2,
			"fog_light_color": Color(0.02, 0.01, 0.02), "fog_density": 0.08,
			"ssao_enabled": true, "ssao_intensity": 3.0,
			"glow_enabled": true, "glow_intensity": 0.6,
			"adjustment_enabled": true, "adjustment_saturation": 0.55, "adjustment_contrast": 1.3,
		},
		"light": {"tint": Color(1.0, 0.75, 0.6), "energy": 1.8, "shadows": true},
		"post": {"vignette": 0.8, "grain": 0.08},
	},
	{
		"name": "Комікс",
		"env": {
			"background_color": Color(0.05, 0.04, 0.08),
			"ambient_light_color": Color(0.5, 0.45, 0.6), "ambient_light_energy": 0.6,
			"tonemap_mode": Environment.TONE_MAPPER_LINEAR,
			"fog_density": 0.015,
			"adjustment_enabled": true, "adjustment_saturation": 1.3, "adjustment_contrast": 1.2,
		},
		"light": {"tint": Color(1.0, 0.9, 0.75), "energy": 1.3},
		"post": {"ink": 1.0, "levels": 8.0},
	},
	{
		"name": "Зелений привид",
		"env": {
			"background_color": Color(0.0, 0.03, 0.02),
			"ambient_light_color": Color(0.2, 0.5, 0.35), "ambient_light_energy": 0.45,
			"tonemap_mode": Environment.TONE_MAPPER_FILMIC,
			"fog_light_color": Color(0.04, 0.14, 0.08), "fog_density": 0.03,
			"volumetric_fog_enabled": true, "volumetric_fog_density": 0.04,
			"volumetric_fog_albedo": Color(0.6, 1.0, 0.7), "volumetric_fog_emission": Color(0.0, 0.05, 0.02),
			"glow_enabled": true, "glow_intensity": 1.0, "glow_bloom": 0.2,
			"adjustment_enabled": true, "adjustment_saturation": 0.85,
		},
		"light": {"tint": Color(0.7, 1.0, 0.75), "energy": 1.2},
		"post": {"vignette": 0.4, "tint": Color(0.9, 1.05, 0.95)},
	},
]

static var current := 0

var _env: Environment
var _base := {}  ## Environment values before any look, for every key a look sets
var _post: ColorRect


func _ready() -> void:
	_env = get_parent().get_node("WorldEnvironment").environment
	for look in LOOKS:
		for k in look.get("env", {}):
			_base[k] = _env.get(k)
	var layer := CanvasLayer.new()
	layer.layer = -2  # under the wall veil (-1) and the HUD
	_post = ColorRect.new()
	_post.set_anchors_preset(Control.PRESET_FULL_RECT)
	_post.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_post.material = ShaderMaterial.new()
	_post.material.shader = preload("res://scripts/look.gdshader")
	layer.add_child(_post)
	add_child(layer)
	get_tree().node_added.connect(_on_node_added)
	apply.call_deferred(current)  # after decor / lanterns / stations add their lights


# shortcut: debug look switcher (F2 + name label), remove before release
func _unhandled_input(e: InputEvent) -> void:
	if e is InputEventKey and e.pressed and not e.echo and e.keycode == KEY_F2:
		apply((current + 1) % LOOKS.size())
		_flash("Вигляд %d/%d: %s" % [current + 1, LOOKS.size(), LOOKS[current].name])
		get_viewport().set_input_as_handled()


func _flash(text: String) -> void:
	var layer := CanvasLayer.new()
	layer.layer = 100  # over the HUD
	var label := Label.new()
	label.text = text
	label.position = Vector2(24, 24)
	label.add_theme_font_size_override("font_size", 28)
	label.add_theme_constant_override("outline_size", 8)
	label.add_theme_color_override("font_outline_color", Color.BLACK)
	layer.add_child(label)
	add_child(layer)
	get_tree().create_timer(2.0).timeout.connect(layer.queue_free)


func apply(i: int) -> void:
	current = i
	var look: Dictionary = LOOKS[i]
	for k in _base:
		_env.set(k, look.get("env", {}).get(k, _base[k]))
	var post: Dictionary = look.get("post", {})
	_post.visible = not post.is_empty()
	for u in ["ink", "levels", "vignette", "grain"]:
		_post.material.set_shader_parameter(u, post.get(u, 0.0))
	_post.material.set_shader_parameter("tint", post.get("tint", Color.WHITE))
	for l in get_parent().find_children("*", "OmniLight3D", true, false):
		_light(l)


## Energy goes into the colour (> 1 is fine): torches and lanterns rewrite light_energy every frame to flicker.
func _light(l: OmniLight3D) -> void:
	if not is_instance_valid(l):
		return
	if not l.has_meta("look_color"):
		l.set_meta("look_color", l.light_color)
		l.set_meta("look_shadow", l.shadow_enabled)
	var s: Dictionary = LOOKS[current].get("light", {})
	var c: Color = l.get_meta("look_color") * s.get("tint", Color.WHITE) * s.get("energy", 1.0)
	c.a = 1.0
	l.light_color = c
	l.shadow_enabled = s.get("shadows", l.get_meta("look_shadow"))


func _on_node_added(n: Node) -> void:
	if n is OmniLight3D and get_parent().is_ancestor_of(n):
		_light.call_deferred(n)  # its script sets light_color in _ready, after node_added
