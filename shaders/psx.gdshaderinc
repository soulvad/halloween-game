uniform vec2 psx_grid = vec2(426.0, 240.0);
uniform float psx_colors = 31.0;
uniform float psx_dither_pixel = 3.0;

vec4 psx_snap(vec4 clip) {
	vec2 ndc = clip.xy / clip.w;
	ndc = floor(ndc * psx_grid * 0.5 + 0.5) / (psx_grid * 0.5);
	return vec4(ndc * clip.w, clip.z, clip.w);
}

float psx_bayer(vec2 frag) {
	ivec2 p = ivec2(mod(floor(frag / psx_dither_pixel), 4.0));
	int i = p.x + p.y * 4;
	float m[16] = float[](0.0, 8.0, 2.0, 10.0, 12.0, 4.0, 14.0, 6.0, 3.0, 11.0, 1.0, 9.0, 15.0, 7.0, 13.0, 5.0);
	return (m[i] + 0.5) / 16.0;
}

vec3 psx_quantize(vec3 c, vec2 frag) {
	float d = psx_bayer(frag) - 0.5;
	return max(floor(c * psx_colors + d + 0.5) / psx_colors, vec3(0.0));
}

float psx_step_time(float t, float fps) {
	return floor(t * fps) / fps;
}
