shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, shadows_disabled;

#include "res://shaders/psx.gdshaderinc"

uniform sampler2D circle : source_color, filter_nearest, repeat_disable;
uniform vec3 gold : source_color = vec3(1.0, 0.7, 0.3);
uniform float progress = 0.0;
uniform float blessed = 0.0;
uniform float idle = 0.06;
uniform float segments = 24.0;

varying vec3 affine_uv;

void vertex() {
	vec4 clip = psx_snap(PROJECTION_MATRIX * MODELVIEW_MATRIX * vec4(VERTEX, 1.0));
	POSITION = clip;
	affine_uv = vec3(UV * clip.w, clip.w);
}

void fragment() {
	vec2 uv = affine_uv.xy / affine_uv.z;
	vec2 p = uv * 2.0 - 1.0;
	vec2 m = texture(circle, uv).rg;
	float t = psx_step_time(TIME, 12.0);
	float turn = fract(atan(p.x, -p.y) / 6.2831853 + 1.0);
	float seg = floor(turn * segments);
	float done = floor(progress * segments);
	float traced = step(seg + 1.0, done + 0.001);
	float front = (seg == done && progress > 0.001 && progress < 0.999) ? (0.6 + 0.4 * step(0.5, fract(t * 3.0))) : 0.0;
	float centre = step(length(p), 0.42) * floor(progress * 4.0) / 4.0;
	float breath = 0.85 + 0.15 * step(0.5, fract(t * 0.6));
	float lit = max(max(traced, centre), blessed) * breath + front * 2.0;
	vec3 col = gold * (m.r * (idle + lit * 1.5) + m.g * (idle * 0.3 + lit * 0.5));
	ALBEDO = psx_quantize(col, FRAGCOORD.xy);
}
