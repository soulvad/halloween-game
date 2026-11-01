"""A quiet loop made of knocks for the end screen: python tools/make_end_music.py

Takes the game's own knock (audio/sfx/knock.ogg), pitches it by resampling and lays it out on a grid: a low knock as
the kick, mid knocks for the groove, high knocks playing a short tune in A minor pentatonic (an original line), with
a soft plucked bass under it. Writes audio/music/end_knocks.ogg, seamless when looped. Needs ffmpeg on PATH.
"""
import os
import subprocess
import tempfile
import wave

import numpy as np

SRC = "audio/sfx/knock.ogg"
OUT = "audio/music/end_knocks.ogg"
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

out = mix[:length].copy()
out[:SR] += mix[length:length + SR]
out *= 0.5 / np.abs(out).max()  # quiet master; the game turns it down further
pcm = os.path.join(tempfile.mkdtemp(), "loop.wav")
with wave.open(pcm, "wb") as w:
    w.setnchannels(1)
    w.setsampwidth(2)
    w.setframerate(SR)
    w.writeframes((out * 32767).astype(np.int16).tobytes())
os.makedirs(os.path.dirname(OUT), exist_ok=True)
subprocess.run(["ffmpeg", "-v", "error", "-y", "-i", pcm, "-c:a", "libvorbis", "-q:a", "5", OUT], check=True)
print("wrote", OUT, "%.1f s" % (length / SR))
