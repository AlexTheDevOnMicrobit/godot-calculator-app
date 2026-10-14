#!/usr/bin/env python3
"""Generates the UI sound effects in assets/sounds (16-bit mono WAV).

Run from the project root:  python3 tools/generate_sounds.py
"""
import math
import random
import struct
import wave
from pathlib import Path

RATE = 44100
OUT = Path(__file__).resolve().parent.parent / "assets" / "sounds"


def envelope(i, n, attack=0.004):
    t = i / RATE
    a = min(1.0, t / attack)
    return a * (1.0 - i / n) ** 3


def tone(freqs, duration, volume=0.5, noise=0.0, square=False):
    n = int(RATE * duration)
    rnd = random.Random(42)
    samples = []
    for i in range(n):
        t = i / RATE
        v = 0.0
        for f in freqs:
            s = math.sin(2 * math.pi * f * t)
            if square:
                s = math.copysign(min(1.0, abs(s) * 3), s) * 0.6
            v += s / len(freqs)
        v += noise * (rnd.random() * 2 - 1)
        samples.append(v * envelope(i, n) * volume)
    return samples


def save(name, samples):
    OUT.mkdir(parents=True, exist_ok=True)
    with wave.open(str(OUT / name), "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(RATE)
        w.writeframes(b"".join(struct.pack("<h", int(max(-1, min(1, s)) * 32767)) for s in samples))
    print("wrote", OUT / name)


save("click.wav", tone([1900, 2600], 0.035, volume=0.45, noise=0.15))
save("result.wav", tone([880], 0.07, 0.4) + tone([1320], 0.12, 0.4))
save("error.wav", tone([170, 180], 0.16, volume=0.5, square=True))
