shader_type canvas_item;
// Ghost passing through a wall (player.gd): `amount` 0 = clear, 1 = deep inside; `edge` = pressing against an outer wall.

uniform float amount : hint_range(0.0, 1.0) = 0.0;
uniform float edge : hint_range(0.0, 1.0) = 0.0;

void fragment() {
	vec2 uv = (UV - 0.5) * vec2(1.6, 1.0);
	float r = length(uv);
	float swirl = sin(atan(uv.y, uv.x) * 5.0 + r * 16.0 - TIME * 1.2) * 0.5 + 0.5;
	float n = sin(uv.x * 13.0 + TIME * 1.9) * sin(uv.y * 9.0 - TIME * 1.4) * 0.5 + 0.5;
	float k = amount * amount * (3.0 - 2.0 * amount);  // soft approach, firm inside
	vec3 deep = vec3(0.025, 0.02, 0.06);
	vec3 glow = vec3(0.45, 0.85, 1.0);
	float streak = smoothstep(0.82, 1.0, swirl) * n;  // thin ectoplasm streaks
	vec3 c = deep + glow * (0.04 + 0.16 * streak) * k;
	c += glow * smoothstep(0.45, 0.95, r) * 0.3 * k;  // cyan rim: you are the ghost, this is a wall
	float a = k * mix(0.86, 0.98, smoothstep(0.0, 0.7, r));
	float rim = smoothstep(0.45, 0.95, r) * edge;  // cold blue frost: the dungeon ends here
	c = mix(c, vec3(0.6, 0.8, 1.0), rim * (1.0 - k));
	COLOR = vec4(c, clamp(max(a, rim * 0.5), 0.0, 0.97));
}
