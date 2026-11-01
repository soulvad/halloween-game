extends Node
## The game's look («Комікс»): Environment overrides + light tint + screen pass (look.gdshader: ink outlines, cel bands).
## Node `Look`, added by game.gd. Nothing here touches the generated scene file.

const ENV := {
	"background_color": Color.BLACK,
	"fog_sky_affect": 0.0,
	"ambient_light_color": Color(0.5, 0.45, 0.6), "ambient_light_energy": 0.6,
	"tonemap_mode": Environment.TONE_MAPPER_LINEAR,
	"fog_density": 0.015,
	"adjustment_enabled": true, "adjustment_saturation": 1.3, "adjustment_contrast": 1.2,
}
const LIGHT_TINT := Color(1.0, 0.9, 0.75)
const LIGHT_ENERGY := 1.3
const POST := {"ink": 1.0, "levels": 8.0}


func _ready() -> void:
	var env: Environment = get_parent().get_node("WorldEnvironment").environment
	for k in ENV:
		env.set(k, ENV[k])
	var layer := CanvasLayer.new()
	layer.layer = -2  # under the wall veil (-1) and the HUD
	var post := ColorRect.new()
	post.set_anchors_preset(Control.PRESET_FULL_RECT)
	post.mouse_filter = Control.MOUSE_FILTER_IGNORE
	post.material = ShaderMaterial.new()
	post.material.shader = preload("res://scripts/look.gdshader")
	for u in POST:
		post.material.set_shader_parameter(u, POST[u])
	layer.add_child(post)
	add_child(layer)
	get_tree().node_added.connect(_on_node_added)
	_tint_all.call_deferred()  # after decor / lanterns / stations add their lights


func _tint_all() -> void:
	for l in get_parent().find_children("*", "OmniLight3D", true, false):
		_light(l)


## Energy goes into the colour (> 1 is fine): torches and lanterns rewrite light_energy every frame to flicker.
func _light(l: OmniLight3D) -> void:
	if not is_instance_valid(l) or l.has_meta("look_color"):
		return
	l.set_meta("look_color", l.light_color)
	var c: Color = l.light_color * LIGHT_TINT * LIGHT_ENERGY
	c.a = 1.0
	l.light_color = c


func _on_node_added(n: Node) -> void:
	if n is OmniLight3D and get_parent().is_ancestor_of(n):
		_light.call_deferred(n)  # its script sets light_color in _ready, after node_added
