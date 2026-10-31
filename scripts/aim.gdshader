shader_type spatial;
// Overlay on the station under the ghost's aim (player.gd): a soft glowing rim, brightest where the surface turns
// away from the eye, breathing slowly. Added on top of any mesh, box or imported model.
render_mode unshaded, blend_add, depth_draw_never, cull_back, shadows_disabled;

uniform vec4 color : source_color = vec4(0.66, 0.86, 0.85, 1.0);

void fragment() {
	float rim = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 2.2);
	float breathe = 0.8 + 0.2 * sin(TIME * 4.0);
	ALBEDO = color.rgb * (0.12 + rim) * breathe * color.a;
}
