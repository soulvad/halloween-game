shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, shadows_disabled;

#include "res://shaders/psx.gdshaderinc"

uniform vec3 color : source_color = vec3(1.0, 0.85, 0.55);
uniform float strength = 0.0;

void vertex() {
	POSITION = psx_snap(PROJECTION_MATRIX * MODELVIEW_MATRIX * vec4(VERTEX, 1.0));
}

void fragment() {
	float facing = abs(dot(NORMAL, VIEW));
	float edge = floor(pow(facing, 2.0) * 4.0) / 4.0;
	float down = UV.y;
	float fade = floor((smoothstep(0.0, 0.35, down) * (1.0 - smoothstep(0.45, 0.95, down))) * 4.0) / 4.0;
	float t = psx_step_time(TIME, 8.0);
	float rays = 0.6 + 0.4 * step(0.5, fract(UV.x * 14.0 + down * 0.5 - t * 0.15));
	vec3 col = color * edge * fade * rays * strength * 0.15;
	ALBEDO = psx_quantize(col, FRAGCOORD.xy);
}
