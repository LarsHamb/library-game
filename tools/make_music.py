"""Erzeugt die ruhige Hintergrundmusik der Bibliothek (game/library/audio/musik.ogg).

Alles synthetisch: weiche Flächen, Bass und eine Spieluhr-Melodie mit Hall.
Aufruf: python3 tools/make_music.py   (braucht numpy und ffmpeg)
Die Datei loopt nahtlos: der Hall-Ausklang wird auf den Anfang gelegt.
"""
import subprocess
import sys
from pathlib import Path

import numpy as np

RATE = 44100
BPM = 66
BEAT = 60.0 / BPM
BAR = BEAT * 4
rng = np.random.default_rng(1907)

NOTE = {"C": 0, "C#": 1, "D": 2, "D#": 3, "E": 4, "F": 5, "F#": 6, "G": 7, "G#": 8, "A": 9, "A#": 10, "B": 11}


def midi(name, octave):
    return 12 * (octave + 1) + NOTE[name]


def hz(m):
    return 440.0 * 2 ** ((m - 69) / 12)


# Akkorde: (Grundton, Intervalle). Jeder Akkord dauert zwei Takte.
CHORDS = {
    "Dmaj7": ("D", [0, 4, 7, 11]),
    "Bm7": ("B", [0, 3, 7, 10]),
    "Gmaj7": ("G", [0, 4, 7, 11]),
    "Asus": ("A", [0, 5, 7, 10]),
    "Em7": ("E", [0, 3, 7, 10]),
    "F#m7": ("F#", [0, 3, 7, 10]),
    "Gadd9": ("G", [0, 4, 7, 14]),
    "A": ("A", [0, 4, 7, 10]),
}
SECTION_A = ["Dmaj7", "Bm7", "Gmaj7", "Asus"]
SECTION_B = ["Em7", "F#m7", "Gadd9", "A"]
SONG = SECTION_A + SECTION_B + SECTION_A + ["Em7", "Gmaj7", "Asus", "Dmaj7"]
SCALE = [NOTE[n] for n in ["D", "E", "F#", "A", "B"]]   # D-Dur-Pentatonik für die Melodie

LENGTH = len(SONG) * 2 * BAR
N = int(LENGTH * RATE)
TAIL = int(6.0 * RATE)


def env_adsr(n, attack, release):
    e = np.ones(n)
    a = min(int(attack * RATE), n)
    r = min(int(release * RATE), n - a)
    e[:a] = np.linspace(0, 1, a) ** 2
    if r > 0:
        e[n - r:] *= np.linspace(1, 0, r) ** 2
    return e


def tone(freq, dur, harmonics, detune_cents=0.0):
    t = np.arange(int(dur * RATE)) / RATE
    out = np.zeros_like(t)
    for k, amp in harmonics:
        f = freq * k * 2 ** (detune_cents / 1200)
        out += amp * np.sin(2 * np.pi * f * t + rng.uniform(0, 2 * np.pi))
    return out


def add(buf, start, sig, gain=1.0, pan=0.0):
    i = int(start * RATE)
    j = min(i + len(sig), buf.shape[1])
    left = np.cos((pan + 1) * np.pi / 4)
    right = np.sin((pan + 1) * np.pi / 4)
    buf[0, i:j] += sig[: j - i] * gain * left
    buf[1, i:j] += sig[: j - i] * gain * right


pad = np.zeros((2, N + TAIL))
bass = np.zeros((2, N + TAIL))
bells = np.zeros((2, N + TAIL))

PAD_HARM = [(1, 1.0), (2, 0.35), (3, 0.18), (4, 0.08), (5, 0.04)]
BELL_HARM = [(1, 1.0), (2.0, 0.25), (3.0, 0.08), (4.07, 0.12)]

for idx, name in enumerate(SONG):
    root, ivs = CHORDS[name]
    start = idx * 2 * BAR
    dur = 2 * BAR + 1.6   # überlappt in den nächsten Akkord
    base = midi(root, 3)
    if base > midi("F#", 3):
        base -= 12
    for iv in ivs:
        f = hz(base + iv + 12)
        e = env_adsr(int(dur * RATE), 1.8, 1.8)
        for cents, pan in [(-4, -0.5), (4, 0.5)]:
            add(pad, start, tone(f, dur, PAD_HARM, cents) * e, 0.05, pan)
    # Bass: Grundton, je Takt einmal weich angeschlagen
    for bar in range(2):
        bdur = BAR + 0.5
        t = np.arange(int(bdur * RATE)) / RATE
        e = np.exp(-t / 2.2) * np.minimum(1, t * 30) * env_adsr(len(t), 0.0, 0.5)
        add(bass, start + bar * BAR, tone(hz(base - 12 + 12 * (base < midi("C", 3))), bdur, [(1, 1.0), (2, 0.3)]) * e, 0.16)

    # Melodie: Spieluhr, nicht in jedem Takt, Töne aus der Pentatonik nahe den Akkordtönen
    if idx % 4 == 0 and idx in (0, 12):
        continue   # die erste und die Rückkehr der A-Teile beginnen ohne Melodie
    pos = 0.0
    last = midi("A", 5)
    while pos < 2 * BAR - BEAT * 0.5:
        step = rng.choice([0.5, 1.0, 1.0, 1.5, 2.0]) * BEAT
        if rng.random() < 0.78:
            chord_pcs = [(NOTE[root] + iv) % 12 for iv in ivs]
            pool = [m for m in range(midi("D", 5), midi("E", 6) + 1) if m % 12 in SCALE or m % 12 in chord_pcs]
            weights = np.array([1.0 / (1 + abs(m - last)) * (2.0 if m % 12 in chord_pcs else 1.0) for m in pool])
            m = rng.choice(pool, p=weights / weights.sum())
            last = m
            ndur = 2.6
            t = np.arange(int(ndur * RATE)) / RATE
            e = np.exp(-t / 0.75) * np.minimum(1, t * 600)
            vel = rng.uniform(0.6, 1.0)
            add(bells, start + pos, tone(hz(m), ndur, BELL_HARM) * e, 0.075 * vel, rng.uniform(-0.4, 0.4))
        pos += step


def ping_pong(buf, delay_s, feedback, mix):
    out = buf.copy()
    d = int(delay_s * RATE)
    echo = buf.mean(axis=0)
    gain = mix
    for k in range(1, 6):
        ch = k % 2
        shifted = np.zeros(buf.shape[1])
        shifted[d * k:] = echo[: buf.shape[1] - d * k]
        out[ch] += shifted * gain
        gain *= feedback
    return out


def reverb(buf, seconds, mix):
    n = int(seconds * RATE)
    t = np.arange(n) / RATE
    out = np.zeros_like(buf)
    size = 1 << int(np.ceil(np.log2(buf.shape[1] + n)))
    for ch in range(2):
        ir = rng.normal(0, 1, n) * np.exp(-t * 6.9 / seconds)
        ir[: int(0.012 * RATE)] = 0     # kurzer Vorlauf
        ir /= np.sqrt(np.sum(ir ** 2))
        wet = np.fft.irfft(np.fft.rfft(buf[ch], size) * np.fft.rfft(ir, size), size)[: buf.shape[1]]
        out[ch] = buf[ch] + wet * mix
    return out


bells = ping_pong(bells, BEAT * 0.75, 0.4, 0.35)
mix = reverb(pad + bells, 4.0, 0.9) + reverb(bass, 1.5, 0.25)

# Sanfter Tiefpass auf alles (einfacher Ein-Pol-Filter, vektorisiert über die FFT wäre übertrieben)
alpha = 0.55
for ch in range(2):
    from itertools import accumulate  # noqa: E402
    mix[ch] = np.array(list(accumulate(mix[ch], lambda y, x: y + alpha * (x - y))))

# Nahtlos: Ausklang auf den Anfang legen
song = mix[:, :N].copy()
song[:, :TAIL] += mix[:, N:N + TAIL]
song /= np.max(np.abs(song)) / 0.7

out_dir = Path(__file__).resolve().parent.parent / "game" / "library" / "audio"
out_dir.mkdir(parents=True, exist_ok=True)
pcm = (np.clip(song.T, -1, 1) * 32767).astype("<i2").tobytes()
subprocess.run(
    ["ffmpeg", "-y", "-loglevel", "error", "-f", "s16le", "-ar", str(RATE), "-ac", "2", "-i", "-",
     "-c:a", "libvorbis", "-q:a", "4", str(out_dir / "musik.ogg")],
    input=pcm, check=True)
print(f"musik.ogg: {LENGTH:.1f} s", file=sys.stderr)
