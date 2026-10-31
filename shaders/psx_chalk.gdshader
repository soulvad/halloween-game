shader_type spatial;
render_mode vertex_lighting, cull_disabled, depth_draw_opaque;

#include "res://shaders/psx.gdshaderinc"

uniform sampler2D circle : source_color, filter_nearest, repeat_disable;
uniform vec3 chalk_color : source_color = vec3(0.82, 0.8, 0.74);

varying vec3 affine_uv;

void vertex() {
	vec4 clip = psx_snap(PROJECTION_MATRIX * MODELVIEW_MATRIX * vec4(VERTEX, 1.0));
	POSITION = clip;
	affine_uv = vec3(UV * clip.w, clip.w);
}

void fragment() {
	vec2 uv = affine_uv.xy / affine_uv.z;
	float line = pow(texture(circle, uv).r, 0.55);
	if (line < psx_bayer(FRAGCOORD.xy) * 0.9 + 0.05) {
		discard;
	}
	ALBEDO = floor(chalk_color * line * 15.0 + 0.5) / 15.0;
	ROUGHNESS = 1.0;
	SPECULAR = 0.0;
}
