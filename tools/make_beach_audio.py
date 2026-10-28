"""Erzeugt Musik und Meeresrauschen für den Strand (game/beach/audio/musik.ogg und meer.ogg).

Musik: gezupfte Ukulele-Akkorde, Marimba-Melodie, weicher Bass und Shaker, sommerlich-entspannt.
Meer: Brandung aus gefiltertem Rauschen in langsamen Wellen, dazu ab und zu ferne Möwen.
Alles synthetisch. Aufruf: python3 tools/make_beach_audio.py   (braucht numpy und ffmpeg)
Beide Dateien loopen nahtlos.
"""
import subprocess
import sys
from pathlib import Path

import numpy as np

RATE = 44100
BPM = 92
BEAT = 60.0 / BPM
BAR = BEAT * 4
rng = np.random.default_rng(2026)

NOTE = {"C": 0, "C#": 1, "D": 2, "D#": 3, "E": 4, "F": 5, "F#": 6, "G": 7, "G#": 8, "A": 9, "A#": 10, "B": 11}


def midi(name, octave):
    return 12 * (octave + 1) + NOTE[name]


def hz(m):
    return 440.0 * 2 ** ((m - 69) / 12)


CHORDS = {
    "C": ("C", [0, 4, 7]), "Am": ("A", [0, 3, 7]), "F": ("F", [0, 4, 7]), "G": ("G", [0, 4, 7]),
    "Em": ("E", [0, 3, 7]), "Dm": ("D", [0, 3, 7]), "Fmaj7": ("F", [0, 4, 7, 11]), "G7": ("G", [0, 4, 7, 10]),
}
SONG = ["C", "Am", "F", "G", "C", "Em", "Fmaj7", "G7",
        "Am", "Em", "F", "C", "Dm", "G", "C", "G7"]
SCALE = [NOTE[n] for n in ["C", "D", "E", "G", "A"]]

LENGTH = len(SONG) * BAR
N = int(LENGTH * RATE)
TAIL = int(4.0 * RATE)


def add(buf, start, sig, gain=1.0, pan=0.0):
    i = int(start * RATE)
    if i >= buf.shape[1]:
        return
    j = min(i + len(sig), buf.shape[1])
    left = np.cos((pan + 1) * np.pi / 4)
    right = np.sin((pan + 1) * np.pi / 4)
    buf[0, i:j] += sig[: j - i] * gain * left
    buf[1, i:j] += sig[: j - i] * gain * right


def pluck(freq, dur, brightness=1.0):
    """Gezupfte Saite: Obertöne, die höheren klingen schneller ab."""
    t = np.arange(int(dur * RATE)) / RATE
    out = np.zeros_like(t)
    for k in range(1, 9):
        amp = (1.0 / k ** 1.2) * (1.0 if k == 1 else brightness)
        out += amp * np.sin(2 * np.pi * freq * k * t + rng.uniform(0, 6.3)) * np.exp(-t * (2.2 + 1.6 * k))
    return out * np.minimum(1, t * 900)


def marimba(freq, dur):
    t = np.arange(int(dur * RATE)) / RATE
    out = np.sin(2 * np.pi * freq * t) * np.exp(-t * 3.2)
    out += 0.35 * np.sin(2 * np.pi * freq * 4.0 * t) * np.exp(-t * 14)
    out += 0.12 * np.sin(2 * np.pi * freq * 9.9 * t) * np.exp(-t * 30)
    return out * np.minimum(1, t * 1500)


def lowpass(x, alpha):
    """Ein-Pol-Tiefpass, vektorisiert über scipy-freie Rekursion in Blöcken."""
    y = np.empty_like(x)
    acc = 0.0
    for i in range(0, len(x), 4096):
        block = x[i:i + 4096]
        out = np.empty_like(block)
        for j, v in enumerate(block):
            acc += alpha * (v - acc)
            out[j] = acc
        y[i:i + 4096] = out
    return y


def reverb(buf, seconds, mix):
    n = int(seconds * RATE)
    t = np.arange(n) / RATE
    out = np.zeros_like(buf)
    size = 1 << int(np.ceil(np.log2(buf.shape[1] + n)))
    for ch in range(2):
        ir = rng.normal(0, 1, n) * np.exp(-t * 6.9 / seconds)
        ir[: int(0.01 * RATE)] = 0
        ir /= np.sqrt(np.sum(ir ** 2))
        wet = np.fft.irfft(np.fft.rfft(buf[ch], size) * np.fft.rfft(ir, size), size)[: buf.shape[1]]
        out[ch] = buf[ch] + wet * mix
    return out


def seamless(mix, n, tail):
    song = mix[:, :n].copy()
    song[:, :tail] += mix[:, n:n + tail]
    return song


def write_ogg(song, name, peak):
    song = song / (np.max(np.abs(song)) / peak)
    out_dir = Path(__file__).resolve().parent.parent / "game" / "beach" / "audio"
    out_dir.mkdir(parents=True, exist_ok=True)
    pcm = (np.clip(song.T, -1, 1) * 32767).astype("<i2").tobytes()
    subprocess.run(
        ["ffmpeg", "-y", "-loglevel", "error", "-f", "s16le", "-ar", str(RATE), "-ac", "2", "-i", "-",
         "-c:a", "libvorbis", "-q:a", "4", str(out_dir / name)],
        input=pcm, check=True)
    print(f"{name}: {song.shape[1] / RATE:.1f} s", file=sys.stderr)


# ================================================================ Musik

uke = np.zeros((2, N + TAIL))
mel = np.zeros((2, N + TAIL))
bass = np.zeros((2, N + TAIL))
perc = np.zeros((2, N + TAIL))

# Ukulele-Schlagmuster (Achtel): runter, runter-hoch, hoch-runter-hoch
STRUM = [(0.0, 1.0), (1.0, 0.8), (1.5, 0.55), (2.5, 0.6), (3.0, 0.8), (3.5, 0.55)]
for idx, name in enumerate(SONG):
    root, ivs = CHORDS[name]
    start = idx * BAR
    base = midi(root, 4)
    if base > midi("E", 4):
        base -= 12
    voicing = [base + iv for iv in ivs]
    for beat, vel in STRUM:
        order = voicing if beat % 1 == 0 else voicing[::-1]
        for k, m in enumerate(order):
            t0 = start + beat * BEAT + k * 0.012 + rng.uniform(0, 0.006)
            add(uke, t0, pluck(hz(m + 12), 1.2, 0.7), 0.05 * vel, -0.25)
    # Bass: Grundton und Quinte
    for beat, off in [(0, 0), (2, 7), (3.5, 0)]:
        t = np.arange(int(BEAT * 1.6 * RATE)) / RATE
        f = hz(midi(root, 2) + off)
        sig = (np.sin(2 * np.pi * f * t) + 0.25 * np.sin(4 * np.pi * f * t)) * np.exp(-t * 2.5) * np.minimum(1, t * 200)
        add(bass, start + beat * BEAT, sig, 0.2)
    # Shaker auf allen Achteln, leise Kick auf 1 und 3
    for e in range(8):
        n = int(0.06 * RATE)
        t = np.arange(n) / RATE
        noise = rng.normal(0, 1, n) * np.exp(-t * (60 if e % 2 else 40))
        noise = np.diff(noise, prepend=0)   # hell
        add(perc, start + e * BEAT * 0.5 + rng.uniform(0, 0.01), noise, 0.012 * (1.3 if e % 2 else 0.8), 0.35)
    for beat in (0, 2):
        t = np.arange(int(0.3 * RATE)) / RATE
        kick = np.sin(2 * np.pi * (50 + 60 * np.exp(-t * 30)) * t) * np.exp(-t * 12)
        add(perc, start + beat * BEAT, kick, 0.18)
    # Marimba-Melodie, ab dem dritten Takt
    if idx < 2:
        continue
    pos = 0.0
    last = midi("E", 5)
    while pos < BAR - 0.01:
        step = rng.choice([0.5, 0.5, 1.0, 1.0, 1.5]) * BEAT
        if rng.random() < 0.72:
            chord_pcs = [(NOTE[root] + iv) % 12 for iv in ivs]
            pool = [m for m in range(midi("C", 5), midi("A", 6) + 1) if m % 12 in SCALE]
            weights = np.array([1.0 / (1 + abs(m - last)) ** 1.3 * (2.5 if m % 12 in chord_pcs else 1.0) for m in pool])
            m = rng.choice(pool, p=weights / weights.sum())
            last = m
            add(mel, start + pos, marimba(hz(m), 1.5), 0.1 * rng.uniform(0.7, 1.0), rng.uniform(-0.3, 0.4))
        pos += step

music = reverb(uke + mel, 1.8, 0.35) + bass + reverb(perc, 0.8, 0.2)
write_ogg(seamless(music, N, TAIL), "musik.ogg", 0.75)

# ================================================================ Meer

SEA_LEN = 48.0
SN = int(SEA_LEN * RATE)
STAIL = int(6.0 * RATE)
total = SN + STAIL
sea = np.zeros((2, total))
noise = rng.normal(0, 1, (2, total))
# brauner Rausch-Grund (tief, weich) und heller Rausch für Gischt
brown = np.cumsum(noise, axis=1)
brown -= np.array([lowpass(b, 0.0008) for b in brown])
brown /= np.max(np.abs(brown))
hiss = np.array([lowpass(n, 0.25) for n in noise])
hiss /= np.max(np.abs(hiss))
t = np.arange(total) / RATE
# Wellen: unregelmäßige Abstände, jede Welle schwillt an, bricht (Gischt) und zieht sich zurück
env_low = np.full(total, 0.25)
env_hi = np.zeros(total)
pos = 0.0
while pos < SEA_LEN + 4:
    length = rng.uniform(5.5, 8.5)
    i0 = int(pos * RATE)
    n = int(length * RATE)
    tt = np.arange(n) / RATE
    swell = np.exp(-((tt - 1.6) / 1.0) ** 2)
    crash = np.exp(-((tt - 2.2) / 0.5) ** 2) + 0.5 * np.exp(-np.maximum(tt - 2.2, 0) / 1.6) * (tt > 2.2)
    j = min(i0 + n, total)
    env_low[i0:j] += swell[: j - i0] * rng.uniform(0.6, 1.0)
    env_hi[i0:j] += crash[: j - i0] * rng.uniform(0.5, 1.0)
    pos += length * rng.uniform(0.75, 1.0)
for ch in range(2):
    sea[ch] = brown[ch] * env_low * 0.9 + hiss[ch] * env_hi * 0.22
# Möwen: kurze, abfallende Rufe, weit weg
for _ in range(7):
    start = rng.uniform(1, SEA_LEN - 3)
    pan = rng.uniform(-0.8, 0.8)
    for k in range(rng.integers(2, 5)):
        d = rng.uniform(0.25, 0.4)
        tt = np.arange(int(d * RATE)) / RATE
        f = 1500 + 600 * np.exp(-tt * 8) - 400 * tt / d
        phase = 2 * np.pi * np.cumsum(f) / RATE
        call = (np.sin(phase) + 0.4 * np.sin(2 * phase) + 0.2 * np.sin(3 * phase)) * np.sin(np.pi * tt / d) ** 1.5
        add(sea, start + k * rng.uniform(0.32, 0.45), call, 0.035, pan)
sea = reverb(sea, 1.2, 0.3)
write_ogg(seamless(sea, SN, STAIL), "meer.ogg", 0.6)
