shader_type spatial;
// Finger paint on the mirror (station.gd MIRROR, art/textures/help_writing.png): wet and glossy, smeared on left to
// right as `reveal` goes 0 → 1, the front ragged like a finger's stroke.

uniform sampler2D tex : source_color, filter_linear_mipmap;
instance uniform float reveal = 1.0;

float hash(float y) {
	return fract(sin(y * 91.7) * 4375.85);
}

void fragment() {
	vec4 c = texture(tex, UV);
	float edge = reveal * 1.1 - 0.05 + (hash(floor(UV.y * 24.0)) - 0.5) * 0.06;
	ALBEDO = c.rgb;
	ALPHA = c.a * (1.0 - smoothstep(edge - 0.02, edge, UV.x));
	EMISSION = c.rgb * 0.35;  // reads in the dark room and against the red light
	ROUGHNESS = 0.25;
	SPECULAR = 0.7;
}
