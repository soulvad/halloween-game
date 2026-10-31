shader_type canvas_item;
// Screen post pass for the visual looks (look.gd): ink outlines, posterize, vignette, grain. All 0 = untouched.

uniform sampler2D screen : hint_screen_texture, filter_linear;
uniform float ink : hint_range(0.0, 4.0) = 0.0;  // comic outline strength (colour edges)
uniform float levels = 0.0;  // brightness bands (cel shading), 0 = off
uniform float vignette : hint_range(0.0, 1.0) = 0.0;
uniform float grain : hint_range(0.0, 0.3) = 0.0;
uniform vec3 tint = vec3(1.0);

float luma(vec2 uv) {
	return dot(texture(screen, uv).rgb, vec3(0.3, 0.59, 0.11));
}

void fragment() {
	vec3 c = texture(screen, SCREEN_UV).rgb;
	if (levels > 0.0) {
		float l = dot(c, vec3(0.3, 0.59, 0.11));  // flat bands of brightness, hue kept
		c *= (floor(l * levels + 0.5) / levels + 0.02) / max(l, 0.001);
	}
	if (ink > 0.0) {
		vec2 px = SCREEN_PIXEL_SIZE * 1.5;
		float gx = luma(SCREEN_UV + vec2(px.x, 0.0)) - luma(SCREEN_UV - vec2(px.x, 0.0));
		float gy = luma(SCREEN_UV + vec2(0.0, px.y)) - luma(SCREEN_UV - vec2(0.0, px.y));
		float e = smoothstep(0.18, 0.35, length(vec2(gx, gy)) * ink);
		c = mix(c, vec3(0.03, 0.02, 0.05), e);
	}
	c *= tint;
	vec2 d = SCREEN_UV - 0.5;
	c *= 1.0 - vignette * smoothstep(0.25, 0.75, length(d * vec2(1.4, 1.0)));
	if (grain > 0.0) {
		float n = fract(sin(dot(SCREEN_UV * 900.0 + TIME * 37.0, vec2(12.9898, 78.233))) * 43758.5453);
		c += (n - 0.5) * grain;
	}
	COLOR = vec4(c, 1.0);
}
