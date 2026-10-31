shader_type spatial;
render_mode unshaded, depth_draw_never, cull_back;
// The ghost's cloud in the guide: soft puffs, thick in the middle and fading at the rim. Runs on TIME, so it keeps
// drifting while the guide has the tree paused.

uniform vec3 tint = vec3(0.58, 0.67, 0.8);

void vertex() {
	vec3 w = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	VERTEX += NORMAL * 0.03 * sin(TIME * 1.3 + w.y * 7.0 + w.x * 5.0 + w.z * 3.0);
}

void fragment() {
	ALBEDO = tint;
	ALPHA = 0.42 * pow(clamp(dot(NORMAL, VIEW), 0.0, 1.0), 3.0);
}
