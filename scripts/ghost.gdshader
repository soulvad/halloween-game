shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_back;
// Over the ghost model (player.gd, material_overlay): a cold blue glow, strong at the rim, faint over the face.

uniform vec3 tint = vec3(0.45, 0.65, 1.0);

void fragment() {
	float rim = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 2.0);
	ALBEDO = tint * (0.18 + 1.1 * rim) * (0.85 + 0.15 * sin(TIME * 2.0));
}
