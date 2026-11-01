shader_type canvas_item;
// Ghost passing through a wall (player.gd): `amount` 0 = clear, 1 = deep inside; `edge` = pressing against an outer wall;
// `travel` = metres moved inside (the stone drifts past). Inside: soft dark stone haze, the room beyond faint and
// blurred through it, a cold rim; crossing the wall's face sends one gentle ripple.

uniform sampler2D screen : hint_screen_texture, filter_linear_mipmap;
uniform float amount : hint_range(0.0, 1.0) = 0.0;
uniform float edge : hint_range(0.0, 1.0) = 0.0;
uniform float travel = 0.0;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1, 0)), u.x), mix(hash(i + vec2(0, 1)), hash(i + vec2(1, 1)), u.x), u.y);
}

void fragment() {
	float k = amount * amount * (3.0 - 2.0 * amount);  // soft approach, firm inside
	float surface = clamp(amount * (1.0 - amount) * 4.0, 0.0, 1.0);  // peaks while crossing the wall's face
	vec2 p = (SCREEN_UV - 0.5) * vec2(SCREEN_PIXEL_SIZE.y / SCREEN_PIXEL_SIZE.x, 1.0);
	float r = length(p);

	vec2 uv = SCREEN_UV + p / max(r, 1e-3) * sin(r * 30.0 - TIME * 6.0) * 0.006 * surface;  // the ripple
	vec3 seen = textureLod(screen, uv, 2.5 * k).rgb;  // the room beyond, blurred
	vec3 ghost = vec3(0.45, 0.85, 1.0);
	vec3 beyond = mix(seen, ghost * dot(seen, vec3(0.3, 0.59, 0.11)), k * 0.8);

	vec2 q = p * 3.0 + vec2(travel * 0.35, TIME * 0.05);  // haze drifting past as you move
	float haze = noise(q) * 0.6 + noise(q * 2.3 + 5.0) * 0.4;
	vec3 stone = mix(vec3(0.04, 0.035, 0.05), vec3(0.13, 0.12, 0.14), haze);
	vec3 c = mix(beyond, stone, k * (0.6 + 0.25 * haze));
	c += ghost * smoothstep(0.4, 0.95, r) * 0.3 * k;  // cold rim: you are the ghost, this is a wall
	c *= 1.0 - smoothstep(0.5, 1.0, r) * 0.5 * k;

	float rim = smoothstep(0.45, 0.95, r) * edge;  // cold blue frost: the dungeon ends here
	c = mix(c, vec3(0.6, 0.8, 1.0), rim * 0.6 * (1.0 - k));
	COLOR = vec4(mix(textureLod(screen, SCREEN_UV, 0.0).rgb, c, clamp(max(k * 1.3, rim) + surface * 0.3, 0.0, 1.0)), 1.0);
}
