extends RefCounted
## Easter egg sounds: `audio/eggs/<name>.ogg|wav|mp3` if the team dropped one in, else a small synthesized placeholder.

const RATE := 22050
const DIR := "res://audio/eggs/"
const LOOPED := ["skeleton"]  ## the cat's track plays once: it spins for exactly as long
const REST := 0.0
## Original tune, not any existing song: [Hz, beats]. A minor march for the dancing skeleton.
const TUNE := [[440.0, 1], [523.25, 1], [659.25, 1], [523.25, 1], [587.33, 1], [698.46, 1], [659.25, 2],
	[440.0, 1], [392.0, 1], [440.0, 1], [523.25, 1], [493.88, 2], [329.63, 2]]
const BEAT := 0.2


static func stream(sound: String) -> AudioStream:
	for ext in ["ogg", "wav", "mp3"]:
		var path := "%s%s.%s" % [DIR, sound, ext]
		if ResourceLoader.exists(path):
			var s: AudioStream = load(path)
			if sound in LOOPED and "loop" in s:
				s.loop = true
			elif sound in LOOPED and s is AudioStreamWAV:
				s.loop_mode = AudioStreamWAV.LOOP_FORWARD
			return s
	var samples: PackedFloat32Array
	match sound:
		"cat":
			samples = _cat()
		"skeleton":
			samples = _xylophone()
		"rat":
			samples = _glide(2200, 3100, 0.09, 0.35) + _silence(0.05) + _glide(2500, 3400, 0.07, 0.3)
		_:  # phone
			samples = _beep(880, 0.12) + _silence(0.06) + _beep(1320, 0.18)
	return _wav(samples, sound in LOOPED)


## «у і а і у і а»: a nasal voice gliding between the vowels' pitches.
static func _cat() -> PackedFloat32Array:
	var out := PackedFloat32Array()
	var pitch := {"у": 330.0, "і": 780.0, "а": 520.0}
	var prev := 330.0
	for i in 4:
		for v in ["у", "і", "а", "і", "у", "і", "а"]:
			out += _glide(prev, pitch[v], 0.2, 0.5, true)
			prev = pitch[v]
		out += _silence(0.3)
	return out


static func _xylophone() -> PackedFloat32Array:
	var out := PackedFloat32Array()
	for note in TUNE:
		var n := int(note[1] * BEAT * RATE)
		for i in n:
			var t := float(i) / RATE
			var hit := exp(-t * 11.0) * (sin(TAU * note[0] * t) + 0.35 * sin(TAU * note[0] * 3.0 * t))
			out.append(0.45 * hit + 0.14 * sign(sin(TAU * note[0] * 0.25 * t)) * exp(-t * 5.0))
	return out


static func _glide(from: float, to: float, dur: float, vol: float, nasal := false) -> PackedFloat32Array:
	var out := PackedFloat32Array()
	var ph := 0.0
	var n := int(dur * RATE)
	for i in n:
		var k := float(i) / n
		var eased := minf(k * 3.0, 1.0)  # reach the pitch early, then hold
		ph += TAU * lerpf(from, to, eased) / RATE
		var wave := sin(ph)
		if nasal:
			wave = 0.6 * wave + 0.3 * sin(ph * 2.0) + 0.2 * sin(ph * 3.0)
		out.append(wave * vol * minf(minf(k, 1.0 - k) * 12.0, 1.0))
	return out


static func _beep(hz: float, dur: float) -> PackedFloat32Array:
	return _glide(hz, hz, dur, 0.4)


static func _silence(dur: float) -> PackedFloat32Array:
	var out := PackedFloat32Array()
	out.resize(int(dur * RATE))
	return out


static func _wav(samples: PackedFloat32Array, loop: bool) -> AudioStreamWAV:
	var data := PackedByteArray()
	data.resize(samples.size() * 2)
	for i in samples.size():
		data.encode_s16(i * 2, int(clampf(samples[i], -1, 1) * 32767))
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = RATE
	w.data = data
	if loop:
		w.loop_mode = AudioStreamWAV.LOOP_FORWARD
		w.loop_end = samples.size()
	return w
