shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, shadows_disabled;

#include "res://shaders/psx.gdshaderinc"

uniform float power = 1.0;

varying float phase;

void vertex() {
	mat4 facing = mat4(INV_VIEW_MATRIX[0], INV_VIEW_MATRIX[1], INV_VIEW_MATRIX[2], MODEL_MATRIX[3]);
	float s = length(MODEL_MATRIX[0].xyz);
	MODELVIEW_MATRIX = VIEW_MATRIX * facing * mat4(vec4(s, 0, 0, 0), vec4(0, s, 0, 0), vec4(0, 0, s, 0), vec4(0, 0, 0, 1));
	phase = float(INSTANCE_ID) * 1.618;
	POSITION = psx_snap(PROJECTION_MATRIX * MODELVIEW_MATRIX * vec4(VERTEX, 1.0));
}

void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	float dot_ = exp(-dot(p, p) * 7.0);
	float star = exp(-abs(p.x) * 16.0) * exp(-abs(p.y) * 3.0) + exp(-abs(p.y) * 16.0) * exp(-abs(p.x) * 3.0);
	float twinkle = 0.35 + 0.65 * abs(sin(TIME * 5.0 + phase));
	vec3 col = COLOR.rgb * (dot_ * 1.3 + star * 0.7) * twinkle * COLOR.a * 3.0 * power;
	ALBEDO = psx_quantize(col, FRAGCOORD.xy);
}
