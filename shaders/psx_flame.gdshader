shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, shadows_disabled;

#include "res://shaders/psx.gdshaderinc"

uniform float brightness = 1.0;
uniform float fps = 10.0;

varying float seed;

void vertex() {
	seed = INSTANCE_CUSTOM.x;
	vec3 cam = (inverse(MODEL_MATRIX) * vec4(CAMERA_POSITION_WORLD, 1.0)).xyz;
	vec2 to_cam = normalize(cam.xz + vec2(0.0001));
	vec2 side = vec2(-to_cam.y, to_cam.x);
	VERTEX = vec3(side.x * VERTEX.x, VERTEX.y, side.y * VERTEX.x);
	POSITION = psx_snap(PROJECTION_MATRIX * MODELVIEW_MATRIX * vec4(VERTEX, 1.0));
}

float hash(float n) {
	return fract(sin(n) * 43758.5453);
}

void fragment() {
	float frame = floor(TIME * fps + seed * 7.0);
	float lean = (hash(frame + seed * 13.0) - 0.5) * 0.35;
	float tall = 0.85 + 0.25 * hash(frame * 1.7 + seed);
	vec2 cell = floor(UV * vec2(6.0, 12.0)) / vec2(6.0, 12.0) + vec2(1.0 / 12.0, 1.0 / 24.0);
	vec2 p = vec2(cell.x * 2.0 - 1.0, (1.0 - cell.y) / tall);
	p.x -= lean * p.y;
	float width = 0.9 * pow(max(1.0 - p.y, 0.0), 0.7) * step(0.04, p.y);
	float body = step(abs(p.x), width) * step(p.y, 1.0);
	float core = step(abs(p.x), width * 0.45) * step(p.y, 0.55);
	vec3 col = mix(vec3(1.0, 0.38, 0.06), vec3(1.0, 0.9, 0.55), core) * body;
	ALBEDO = psx_quantize(col * 2.2 * brightness, FRAGCOORD.xy);
}
