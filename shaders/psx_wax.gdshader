shader_type spatial;
render_mode vertex_lighting;

#include "res://shaders/psx.gdshaderinc"

uniform vec3 albedo : source_color = vec3(0.9, 0.8, 0.58);
uniform vec3 glow : source_color = vec3(1.0, 0.5, 0.15);
uniform float glow_from = 1.0;
uniform float part_height = 1.0;

varying float height01;

void vertex() {
	height01 = clamp(VERTEX.y / part_height + 0.5, 0.0, 1.0);
	POSITION = psx_snap(PROJECTION_MATRIX * MODELVIEW_MATRIX * vec4(VERTEX, 1.0));
}

void fragment() {
	ALBEDO = floor(albedo * 15.0 + 0.5) / 15.0;
	ROUGHNESS = 1.0;
	SPECULAR = 0.0;
	EMISSION = glow * step(glow_from, height01) * 0.5;
}
