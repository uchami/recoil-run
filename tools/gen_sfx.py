#!/usr/bin/env python3
"""Genera los efectos de sonido del juego (síntesis simple, sin dependencias).

    python3 tools/gen_sfx.py   ->  game/assets/sfx/*.wav

Retocar acá y volver a correr; después `godot --headless --path game --import`.
"""
import math
import os
import random
import struct
import wave

SR = 22050
OUT = os.path.join(os.path.dirname(__file__), "..", "game", "assets", "sfx")
random.seed(7)


def env(t, attack, decay):
    if t < attack:
        return t / attack
    return math.exp(-(t - attack) / decay)


def sweep_phase(f0, f1, dur):
    """Fase acumulada para un barrido exponencial de frecuencia f0->f1."""
    phase = 0.0
    out = []
    n = int(dur * SR)
    for i in range(n):
        k = i / max(n - 1, 1)
        f = f0 * (f1 / f0) ** k
        phase += 2 * math.pi * f / SR
        out.append(phase)
    return out


class Noise:
    def __init__(self, cutoff=1.0):
        self.y = 0.0
        self.a = cutoff  # 1 = blanco, menor = más grave

    def __call__(self):
        self.y += self.a * (random.uniform(-1, 1) - self.y)
        return self.y


def write(name, samples, gain=0.9):
    peak = max(1e-6, max(abs(s) for s in samples))
    os.makedirs(OUT, exist_ok=True)
    with wave.open(os.path.join(OUT, name + ".wav"), "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes(b"".join(struct.pack("<h", int(max(-1, min(1, s / peak * gain)) * 32767)) for s in samples))


def render(dur, fn):
    return [fn(i / SR) for i in range(int(dur * SR))]


def shot():
    nz = Noise(0.6)
    ph = sweep_phase(160, 45, 0.28)
    return render(0.28, lambda t: nz() * env(t, 0.001, 0.035) * 1.2
                  + math.sin(ph[int(t * SR)]) * env(t, 0.002, 0.07))


def empty():
    nz = Noise(1.0)
    return render(0.08, lambda t: (nz() * 0.6 + math.sin(2 * math.pi * 2400 * t) * 0.4) * env(t, 0.0005, 0.008))


def kill():
    nz = Noise(0.25)
    ph = sweep_phase(220, 60, 0.25)
    return render(0.25, lambda t: math.sin(ph[int(t * SR)]) * env(t, 0.002, 0.06) + nz() * env(t, 0.001, 0.05) * 0.8)


def headshot():
    def f(t):
        bell = sum(math.sin(2 * math.pi * fr * t) * a for fr, a in ((1320, 1), (1980, 0.5), (2640, 0.25)))
        return bell * env(t, 0.002, 0.18) * 0.7
    base = kill()
    ding = render(0.5, f)
    return [(base[i] if i < len(base) else 0) * 0.8 + ding[i] for i in range(len(ding))]


def clank():
    def f(t):
        s = sum(math.sin(2 * math.pi * fr * t) * a for fr, a in ((870, 1), (1430, 0.7), (2210, 0.5), (3170, 0.3)))
        return s * env(t, 0.0005, 0.07)
    nz = Noise(1.0)
    return render(0.35, lambda t: f(t) + nz() * env(t, 0.0005, 0.006))


def hurt():
    ph = sweep_phase(330, 110, 0.3)
    return render(0.3, lambda t: (1 if math.sin(ph[int(t * SR)]) > 0 else -1) * 0.5 * env(t, 0.003, 0.12))


def boing():
    n = int(0.55 * SR)
    phase = 0.0
    out = []
    for i in range(n):
        t = i / SR
        f = 140 + 420 * (1 - math.exp(-t * 9)) + 30 * math.sin(2 * math.pi * 18 * t)
        phase += 2 * math.pi * f / SR
        out.append(math.sin(phase) * env(t, 0.003, 0.22))
    return out


def chest_hit():
    nz = Noise(0.35)
    return render(0.18, lambda t: (math.sin(2 * math.pi * 190 * t) + 0.5 * math.sin(2 * math.pi * 410 * t)) * env(t, 0.001, 0.04)
                  + nz() * env(t, 0.0005, 0.02))


def chest_open():
    nz = Noise(0.15)
    out = render(0.7, lambda t: nz() * 0.5 * env(t, 0.05, 0.2) * (1 + math.sin(2 * math.pi * 23 * t)))
    for k, fr in enumerate((1570, 1870, 2350, 2790)):
        start = int((0.12 + k * 0.07) * SR)
        for i in range(int(0.25 * SR)):
            if start + i < len(out):
                t = i / SR
                out[start + i] += math.sin(2 * math.pi * fr * t) * env(t, 0.001, 0.06) * 0.6
    return out


def pickup():
    def f(t):
        fr = 1320 if t < 0.06 else 1760
        return math.sin(2 * math.pi * fr * t) * env(t % 0.06 if t < 0.06 else t - 0.06, 0.002, 0.07)
    return render(0.2, f)


def powerup():
    notes = (523, 659, 784, 1047, 1319)
    out = []
    for fr in notes:
        out += render(0.075, lambda t, fr=fr: (math.sin(2 * math.pi * fr * t) + 0.4 * math.sin(4 * math.pi * fr * t)) * env(t, 0.003, 0.08))
    out += render(0.3, lambda t: math.sin(2 * math.pi * 1568 * t) * env(t, 0.003, 0.12))
    return out


def screech():
    n = int(0.6 * SR)
    phase = 0.0
    nz = Noise(0.8)
    out = []
    for i in range(n):
        t = i / SR
        f = 2600 - 1400 * t / 0.6 + 120 * math.sin(2 * math.pi * 31 * t)
        phase += 2 * math.pi * f / SR
        out.append((math.sin(phase) * 0.7 + nz() * 0.3) * env(t, 0.02, 0.25))
    return out


def squeak():
    out = []
    for k in range(3):
        ph = sweep_phase(3800, 5200, 0.035)
        out += [math.sin(p) * env(i / SR, 0.002, 0.012) for i, p in enumerate(ph)]
        out += [0.0] * int(0.03 * SR)
    return out


def chomp():
    nz = Noise(0.3)
    out = []
    for _ in range(2):
        out += render(0.09, lambda t: (nz() + math.sin(2 * math.pi * 140 * t)) * env(t, 0.001, 0.025))
        out += [0.0] * int(0.04 * SR)
    return out


def game_over():
    out = []
    for fr in (392, 330, 262):
        out += render(0.2, lambda t, fr=fr: (1 if math.sin(2 * math.pi * fr * t) > 0 else -1) * 0.4 * env(t, 0.005, 0.15))
    return out


def land():
    nz = Noise(0.12)
    return render(0.12, lambda t: (nz() * 1.5 + math.sin(2 * math.pi * 90 * t)) * env(t, 0.001, 0.025))


def slowmo():
    ph = sweep_phase(600, 90, 0.7)
    nz = Noise(0.1)
    return [(math.sin(p) * 0.4 + nz() * 0.6) * env(i / SR, 0.08, 0.25) for i, p in enumerate(ph)]


def flap():
    nz = Noise(0.2)
    return render(0.1, lambda t: nz() * env(t, 0.01, 0.025))


def explosion():
    nz = Noise(0.08)
    nz2 = Noise(0.5)
    ph = sweep_phase(90, 30, 0.9)
    return [nz() * 2.5 * env(i / SR, 0.002, 0.3) + nz2() * env(i / SR, 0.001, 0.04)
            + math.sin(p) * env(i / SR, 0.003, 0.25) for i, p in enumerate(ph)]


def engine():
    ph = sweep_phase(70, 85, 0.8)
    nz = Noise(0.05)
    return [((1 if math.sin(p) > 0 else -1) * 0.4 + nz() * 0.8) * env(i / SR, 0.15, 0.4) for i, p in enumerate(ph)]


def fanfare():
    out = []
    for fr, d in ((523, 0.1), (659, 0.1), (784, 0.1), (1047, 0.35)):
        out += render(d, lambda t, fr=fr: (math.sin(2 * math.pi * fr * t) + 0.5 * math.sin(4 * math.pi * fr * t)
                                           + 0.25 * math.sin(6 * math.pi * fr * t)) * env(t, 0.004, d * 0.9))
    # "wichi wow": barrido con vibrato
    n = int(0.6 * SR)
    phase = 0.0
    for i in range(n):
        t = i / SR
        f = 500 + 700 * math.sin(math.pi * t / 0.6) + 40 * math.sin(2 * math.pi * 12 * t)
        phase += 2 * math.pi * f / SR
        out.append(math.sin(phase) * 0.6 * env(t, 0.02, 0.3))
    return out


def laser():
    ph = sweep_phase(2400, 300, 0.35)
    return [((1 if math.sin(p) > 0 else -1) * 0.5 + math.sin(p * 0.5) * 0.5) * env(i / SR, 0.002, 0.12) for i, p in enumerate(ph)]


def lock():
    out = render(0.06, lambda t: math.sin(2 * math.pi * 1800 * t) * env(t, 0.0005, 0.01))
    out += [0.0] * int(0.05 * SR)
    nz = Noise(0.4)
    out += render(0.15, lambda t: (nz() + math.sin(2 * math.pi * 300 * t)) * env(t, 0.0005, 0.03))
    return out


def combo(notes, tail):
    """Combo: campanitas que suben (x2 dos notas, x3 tres más agudas y con brillo)."""
    out = []
    for fr in notes:
        out += render(0.07, lambda t, fr=fr: (math.sin(2 * math.pi * fr * t) + 0.35 * math.sin(6 * math.pi * fr * t)) * env(t, 0.002, 0.06))
    fr = notes[-1] * 2
    out += render(tail, lambda t: (math.sin(2 * math.pi * fr * t) + 0.5 * math.sin(2 * math.pi * fr * 1.5 * t))
                  * env(t, 0.002, tail * 0.45) * (1 + 0.3 * math.sin(2 * math.pi * 18 * t)))
    return out


def combo2():
    return combo((784, 1047), 0.18)


def combo3():
    return combo((880, 1175, 1568), 0.32)


SOUNDS = {
    "shot": (shot, 0.95), "empty": (empty, 0.6), "kill": (kill, 0.8), "headshot": (headshot, 0.9),
    "clank": (clank, 0.75), "hurt": (hurt, 0.7), "boing": (boing, 0.8), "chest_hit": (chest_hit, 0.8),
    "chest_open": (chest_open, 0.7), "pickup": (pickup, 0.55), "powerup": (powerup, 0.75),
    "screech": (screech, 0.5), "squeak": (squeak, 0.5), "chomp": (chomp, 0.85), "game_over": (game_over, 0.6),
    "land": (land, 0.6), "slowmo": (slowmo, 0.6), "flap": (flap, 0.4),
    "explosion": (explosion, 0.95), "engine": (engine, 0.5), "fanfare": (fanfare, 0.8),
    "laser": (laser, 0.6), "lock": (lock, 0.8), "combo2": (combo2, 0.7), "combo3": (combo3, 0.8),
}

if __name__ == "__main__":
    for name, (fn, gain) in SOUNDS.items():
        write(name, fn(), gain)
    print("ok:", ", ".join(SOUNDS))
