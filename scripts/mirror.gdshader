shader_type spatial;
render_mode unshaded, cull_back;
// The oval glass of the mirror model, showing the reflection camera's view. u is flipped: what that camera has on its
// left is on our right. Old, dusty glass: slightly dim, hazier towards the rim.

uniform sampler2D view : source_color, filter_linear;
uniform vec3 dust = vec3(0.5, 0.52, 0.55);

void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	float r = length(p);
	if (r > 1.0) {
		discard;
	}
	ALBEDO = mix(texture(view, vec2(1.0 - UV.x, UV.y)).rgb * 0.88, dust, 0.05 + 0.3 * r * r * r);
}
