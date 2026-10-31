shader_type canvas_item;

uniform vec4 top : source_color = vec4(0.07, 0.04, 0.16, 1.0);
uniform vec4 mid : source_color = vec4(0.1, 0.055, 0.21, 1.0);
uniform vec4 horizon : source_color = vec4(0.62, 0.16, 0.62, 1.0);
uniform vec4 far_hills : source_color = vec4(0.16, 0.07, 0.28, 1.0);
uniform vec4 near_hills : source_color = vec4(0.09, 0.04, 0.17, 1.0);
uniform float alpha = 1.0;
uniform float star_density = 0.985;
uniform float horizon_glow = 0.55;
uniform vec2 moon = vec2(0.8, 0.2);
uniform float moon_size = 0.0;
uniform float hills = 0.0;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float ridge(float x, float seed, float cells, float base, float amp) {
	float c = x * cells;
	float i = floor(c);
	return mix(base + amp * hash(vec2(i, seed)), base + amp * hash(vec2(i + 1.0, seed)), fract(c));
}

void fragment() {
	vec2 uv = UV;
	float aspect = SCREEN_PIXEL_SIZE.y / SCREEN_PIXEL_SIZE.x;
	vec3 col = mix(top.rgb, mid.rgb, smoothstep(0.0, 0.6, uv.y));
	col = mix(col, horizon.rgb, smoothstep(0.45, 1.0, uv.y) * horizon_glow);

	vec2 grid = vec2(uv.x * aspect, uv.y) * 90.0;
	vec2 cell = floor(grid);
	float h = hash(cell);
	float star = step(star_density, h) * smoothstep(0.14, 0.0, length(fract(grid) - 0.5));
	star *= (0.55 + 0.45 * sin(TIME * 1.7 + h * 50.0)) * (1.0 - smoothstep(0.4, 0.85, uv.y));
	col += vec3(1.0, 0.92, 1.0) * star;

	if (moon_size > 0.0) {
		float r = length(vec2((uv.x - moon.x) * aspect, uv.y - moon.y));
		col += vec3(1.0, 0.55, 0.95) * 0.32 * smoothstep(moon_size * 4.5, 0.0, r);
		col = mix(col, vec3(1.0, 0.95, 0.86), smoothstep(moon_size, moon_size * 0.94, r));
	}
	if (hills > 0.0) {
		col = mix(col, far_hills.rgb, step(ridge(uv.x, 1.0, 7.0, 0.68, 0.12), uv.y) * hills);
		col = mix(col, near_hills.rgb, step(ridge(uv.x + 0.37, 2.0, 11.0, 0.8, 0.1), uv.y) * hills);
	}
	COLOR = vec4(col, alpha);
}
