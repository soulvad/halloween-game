shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, shadows_disabled;

#include "res://shaders/psx.gdshaderinc"

uniform float power = 1.0;
uniform vec3 gold : source_color = vec3(1.0, 0.6, 0.14);

void vertex() {
	POSITION = psx_snap(PROJECTION_MATRIX * MODELVIEW_MATRIX * vec4(VERTEX, 1.0));
}

void fragment() {
	float edge = pow(1.0 - abs(dot(NORMAL, VIEW)), 1.6);
	float rise = 1.0 - UV.y;
	float reach = mix(0.35, 1.0, clamp(power, 0.0, 1.0));
	float vertical = pow(max(1.0 - rise / reach, 0.0), 2.2) * smoothstep(0.0, 0.03, rise);
	float a = UV.x * 6.2831853;
	float streak = 0.5 + 0.5 * sin(a * 23.0 + sin(a * 7.0 + TIME * 0.35) * 2.0 - TIME * 0.2);
	streak = pow(streak, 3.0);
	float k = vertical * (edge * 0.9 + 0.12) * (0.35 + streak * 0.9) * power * 0.75;
	ALBEDO = psx_quantize(gold * k, FRAGCOORD.xy);
}
