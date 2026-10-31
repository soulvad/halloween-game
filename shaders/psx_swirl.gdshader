shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, shadows_disabled;

#include "res://shaders/psx.gdshaderinc"

uniform float power = 1.0;
uniform float ring = 0.77;
uniform float direction = 1.0;
uniform float speed = 0.5;
uniform float seed = 0.0;
uniform float main_line = 1.0;
uniform float arc_count = 5.0;
uniform vec3 core : source_color = vec3(1.0, 0.93, 0.66);
uniform vec3 gold : source_color = vec3(1.0, 0.56, 0.1);

void vertex() {
	POSITION = psx_snap(PROJECTION_MATRIX * MODELVIEW_MATRIX * vec4(VERTEX, 1.0));
}

float band(float r, float r0, float w) {
	float d = (r - r0) / w;
	return exp(-d * d);
}

float hash(float n) {
	return fract(sin(n * 91.7 + seed * 13.1) * 43758.5453);
}

void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	float r = length(p);
	float angle = atan(p.y, p.x) * direction;
	float t = TIME * speed;
	float glow = main_line * (band(r, ring, 0.005) * 1.7 + band(r, ring, 0.025) * 0.35 + band(r, ring, 0.1) * 0.1);
	for (int i = 0; i < 8; i++) {
		float fi = float(i);
		if (fi >= arc_count) {
			break;
		}
		float h1 = hash(fi);
		float h2 = hash(fi + 17.0);
		float h3 = hash(fi + 41.0);
		float head = t * (0.5 + h1 * 1.1) + h2 * 6.2831853;
		float behind = fract((head - angle) / 6.2831853);
		float length_ = 0.12 + h3 * 0.38;
		float tail = 1.0 - smoothstep(0.0, length_, behind);
		tail *= tail;
		float r0 = ring + (h1 - 0.5) * 0.14 + behind * (h2 - 0.5) * 0.08;
		float w = 0.0035 + h3 * 0.004;
		glow += (band(r, r0, w) * (1.1 + h2) + band(r, r0, w * 7.0) * 0.22) * tail;
	}
	float k = glow * power;
	vec3 col = mix(gold, core, clamp(k * 0.55, 0.0, 1.0)) * k * 2.2;
	ALBEDO = psx_quantize(col, FRAGCOORD.xy);
}
