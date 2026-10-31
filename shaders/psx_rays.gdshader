shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, shadows_disabled;

#include "res://shaders/psx.gdshaderinc"

uniform float power = 1.0;
uniform vec3 core : source_color = vec3(1.0, 0.9, 0.6);
uniform vec3 gold : source_color = vec3(1.0, 0.55, 0.1);

varying float seed;
varying float wide;

void vertex() {
	seed = INSTANCE_CUSTOM.x;
	wide = INSTANCE_CUSTOM.y;
	vec3 cam = (inverse(MODEL_MATRIX) * vec4(CAMERA_POSITION_WORLD, 1.0)).xyz;
	vec2 to_cam = normalize(cam.xz + vec2(0.0001));
	vec2 side = vec2(-to_cam.y, to_cam.x);
	float grow = mix(0.3, 1.0, clamp(power, 0.0, 1.0));
	VERTEX = vec3(side.x * VERTEX.x, VERTEX.y * grow, side.y * VERTEX.x);
	POSITION = psx_snap(PROJECTION_MATRIX * MODELVIEW_MATRIX * vec4(VERTEX, 1.0));
}

void fragment() {
	float across = abs(UV.x * 2.0 - 1.0);
	float rise = 1.0 - UV.y;
	float thin = exp(-across * across * 9.0) * 0.8 + exp(-across * across * 2.5) * 0.3;
	float soft = exp(-across * across * 2.8);
	float profile = mix(thin, soft * 0.75, wide);
	float vertical = pow(1.0 - rise, 2.2) * smoothstep(0.0, 0.06, rise);
	float flicker = 0.7 + 0.3 * sin(TIME * (1.1 + seed * 1.7) + seed * 40.0);
	float k = profile * vertical * flicker * power;
	vec3 col = mix(gold, core, clamp(k, 0.0, 1.0)) * k * 2.0;
	ALBEDO = psx_quantize(col, FRAGCOORD.xy);
}
