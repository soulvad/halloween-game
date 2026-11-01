"""The release music, made of knocks: python tools/make_end_music.py

Takes the game's own knock (audio/sfx/knock.ogg), pitches it by resampling and lays it out on a grid: a low knock as
the kick, mid knocks for the groove, high knocks playing a short tune in A minor pentatonic (an original line), with
a soft plucked bass under it. Needs ffmpeg on PATH. Writes:
  audio/music/end_buildup.ogg — BUILD s of knocks speeding up and climbing, played while E is held in the circle
                                (game.gd; the hold is RELEASE_TIME long)
  audio/music/end_knocks.ogg  — the climax for the end screen: one bar of a big hit, then the loop (hud.gd loops it
                                from CLIMAX_BAR s on)
"""
import os
import subprocess
import tempfile
import wave

import numpy as np

SRC = "audio/sfx/knock.ogg"
OUT = "audio/music/end_knocks.ogg"
BUILD_OUT = "audio/music/end_buildup.ogg"
BUILD = 2.5  # s, = game.gd RELEASE_TIME
SR = 44100
BPM = 100
STEP = 60 / BPM / 4  # a 16th note, s
BARS = 4
A = 220.0
SCALE = [0, 3, 5, 7, 10, 12, 15]  # A minor pentatonic, semitones from A3

tmp = os.path.join(tempfile.mkdtemp(), "knock.wav")
subprocess.run(["ffmpeg", "-v", "error", "-y", "-i", SRC, "-ac", "1", "-ar", str(SR), tmp], check=True)
with wave.open(tmp) as w:
    knock = np.frombuffer(w.readframes(w.getnframes()), np.int16).astype(np.float32) / 32768
knock /= np.abs(knock).max()

length = int(BARS * 16 * STEP * SR)
mix = np.zeros(length + SR, np.float32)  # a tail, folded back onto the start so the loop is seamless


def put(sound, at_step, gain):
    i = int(at_step * STEP * SR)
    mix[i:i + len(sound)] += sound * gain


def pitched(ratio):
    """The knock played faster (higher) or slower (lower)."""
    idx = np.arange(0, len(knock) - 1, ratio)
    return np.interp(idx, np.arange(len(knock)), knock).astype(np.float32)


def pluck(freq, dur=0.45):
    t = np.arange(int(dur * SR)) / SR
    tone = np.sin(2 * np.pi * freq * t) + 0.3 * np.sin(4 * np.pi * freq * t)
    return (tone * np.exp(-t * 7.0) * np.minimum(t * 200, 1)).astype(np.float32)


low, mid = pitched(0.62), pitched(1.0)
for bar in range(BARS):
    b = bar * 16
    for s in (0, 7, 10):  # the kick: a knock-knock… knock that never sits square
        put(low, b + s, 0.9)
    for s in (4, 12):
        put(mid, b + s, 0.55)
    for s in (2, 6, 14):
        put(pitched(1.35), b + s, 0.18)  # ghost knocks
    bass = [A / 2, A / 2, A / 2 * 2 ** (5 / 12), A / 2 * 2 ** (3 / 12)][bar]
    for s in (0, 3, 8, 11):
        put(pluck(bass), b + s, 0.35)

# the tune: (step, scale degree), high knocks tuned so their thump lands on the note's pitch
TUNE = [(0, 4), (3, 3), (6, 2), (8, 4), (12, 5), (16, 3), (19, 2), (22, 0), (26, 1),
        (32, 4), (35, 5), (38, 6), (40, 5), (44, 4), (48, 2), (51, 3), (54, 1), (58, 0)]
for s, deg in TUNE:
    put(pitched(1.6 * 2 ** (SCALE[deg] / 12)), s, 0.42)
    put(pluck(A * 2 * 2 ** (SCALE[deg] / 12), 0.3), s, 0.12)  # a faint tone so the knock has a note

loop = mix[:length].copy()
loop[:SR] += mix[length:length + SR]

# the climax: one bar opening on a big hit (stacked low knocks + the bass an octave apart), the tune's first notes
bar = int(16 * STEP * SR)
mix = np.zeros(bar + SR, np.float32)
for r, g in ((0.5, 1.0), (0.62, 0.9), (0.8, 0.6)):
    put(pitched(r), 0, g)
put(pluck(A / 2, 1.6), 0, 0.6)
put(pluck(A, 1.6), 0, 0.4)
for s in (4, 6, 8, 10, 12, 13, 14, 15):  # a roll of knocks into the loop
    put(mid, s, 0.3 + 0.03 * s)
hit = mix[:bar]  # the roll runs straight into the loop's first beat
climax = np.concatenate([hit, loop])

# the build-up: knocks closer and closer, each a step higher, a rising tone under them
mix = np.zeros(int((BUILD + 1.0) * SR), np.float32)
t, gap, n = 0.0, 0.42, 0
while t < BUILD:
    i = int(t * SR)
    k = pitched(0.8 * 2 ** (n / 24))
    mix[i:i + len(k)] += k * (0.35 + 0.4 * t / BUILD)
    t += gap
    gap = max(0.07, gap * 0.86)
    n += 1
tt = np.arange(int(BUILD * SR)) / SR
rise = np.sin(2 * np.pi * np.cumsum(A / 2 * 2 ** (tt / BUILD * 1.0)) / SR) * (tt / BUILD) ** 2 * 0.25
mix[:len(rise)] += rise.astype(np.float32)
build = mix


def write(sig, path, peak):
    sig = sig * (peak / np.abs(sig).max())
    pcm = os.path.join(tempfile.mkdtemp(), "out.wav")
    with wave.open(pcm, "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes((sig * 32767).astype(np.int16).tobytes())
    os.makedirs(os.path.dirname(path), exist_ok=True)
    subprocess.run(["ffmpeg", "-v", "error", "-y", "-i", pcm, "-c:a", "libvorbis", "-q:a", "5", path], check=True)
    print("wrote", path, "%.2f s" % (len(sig) / SR))


write(climax, OUT, 0.5)  # quiet masters; the game turns them down further
write(build, BUILD_OUT, 0.5)
print("climax bar: %.3f s" % (bar / SR))
