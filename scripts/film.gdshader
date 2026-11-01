shader_type canvas_item;
// Old film reel over the time-lapse (timelapse.gd): sepia, flicker, gate weave, grain, scratches, dust,
// and a perforated film strip down both sides. TIME keeps running while the tree is paused.

uniform sampler2D screen : hint_screen_texture, filter_linear_mipmap;
uniform float fps = 12.0;  // the jitter, scratches and dust change this often
uniform float strip = 0.075;  // width of each side strip, share of the screen width

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

void fragment() {
	float frame = floor(TIME * fps);
	float aspect = SCREEN_PIXEL_SIZE.y / SCREEN_PIXEL_SIZE.x;  // width / height
	vec2 uv = SCREEN_UV;
	uv.y += (hash(vec2(frame, 1.0)) - 0.5) * 0.006;  // gate weave
	uv.x += (hash(vec2(frame, 2.0)) - 0.5) * 0.002;
	vec3 c = textureLod(screen, uv, 0.0).rgb;
	float l = dot(c, vec3(0.3, 0.59, 0.11));
	l = smoothstep(0.02, 0.9, l);
	vec3 col = l * vec3(1.08, 0.93, 0.7) + vec3(0.03, 0.02, 0.0);  // sepia
	col *= 0.88 + 0.12 * hash(vec2(frame, 3.0));  // flicker
	col += (hash(UV * 731.0 + fract(TIME)) - 0.5) * 0.12;  // grain
	for (int i = 0; i < 2; i++) {  // vertical scratches, a new place every frame, sometimes none
		float h = hash(vec2(frame, 10.0 + float(i)));
		if (h > 0.45) {
			float x = hash(vec2(frame, 20.0 + float(i)));
			float d = abs(SCREEN_UV.x - x) / SCREEN_PIXEL_SIZE.x;
			col = mix(col, vec3(0.95, 0.9, 0.78), (1.0 - smoothstep(0.5, 1.5, d)) * 0.5);
		}
	}
	for (int i = 0; i < 4; i++) {  // dark dust specks
		vec2 p = vec2(hash(vec2(frame, 30.0 + float(i))), hash(vec2(frame, 40.0 + float(i))));
		vec2 d = (SCREEN_UV - p) * vec2(aspect, 1.0);
		float r = 0.002 + 0.004 * hash(vec2(frame, 50.0 + float(i)));
		col *= mix(1.0, 0.25, 1.0 - smoothstep(r * 0.5, r, length(d)));
	}
	float v = distance(SCREEN_UV, vec2(0.5));
	col *= 1.0 - smoothstep(0.35, 0.8, v) * 0.75;  // vignette
	// side strips: black film with light sprocket holes rolling down
	float sx = min(SCREEN_UV.x, 1.0 - SCREEN_UV.x);
	if (sx < strip) {
		col = vec3(0.04, 0.03, 0.025);
		float pitch = 0.11;  // hole spacing, share of the screen height
		float y = fract(SCREEN_UV.y / pitch + TIME * 2.0);
		vec2 q = vec2((sx - strip * 0.5) * aspect / pitch, y - 0.5);
		vec2 hole = vec2(0.22, 0.28);
		vec2 dd = abs(q) - hole + 0.08;
		float box = length(max(dd, 0.0)) + min(max(dd.x, dd.y), 0.0) - 0.08;
		col = mix(col, vec3(0.85, 0.8, 0.68), 1.0 - smoothstep(-0.01, 0.01, box));
	} else if (sx < strip + 0.004) {
		col *= 0.3;  // the frame edge
	}
	COLOR = vec4(col, 1.0);
}
