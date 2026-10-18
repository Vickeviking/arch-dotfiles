#!/usr/bin/env python3
"""Desk sound theme: small, soft, one family (sine bells with a quick decay).
Regenerate with `python3 make-sounds.py`; files land in ./stereo/."""
import math, os, random, struct, wave

RATE = 48000
OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "stereo")


def bell(freq, dur, gain=0.32, delay=0.0):
    """One soft bell note: sine + quiet octave, fast attack, exponential decay."""
    n = int(RATE * (dur + delay))
    out = [0.0] * n
    start = int(RATE * delay)
    for i in range(start, n):
        t = (i - start) / RATE
        env = min(1.0, t / 0.004) * math.exp(-t * 7.5 / dur)
        out[i] = gain * env * (math.sin(2 * math.pi * freq * t) + 0.18 * math.sin(4 * math.pi * freq * t))
    return out


def mixdown(*parts):
    n = max(len(p) for p in parts)
    return [sum(p[i] for p in parts if i < len(p)) for i in range(n)]


def save(name, samples):
    peak = max(1e-9, max(abs(s) for s in samples))
    scale = min(1.0, 0.85 / peak)
    tail = int(RATE * 0.02)
    samples = samples + [0.0] * tail
    with wave.open(os.path.join(OUT, name + ".wav"), "wb") as w:
        w.setnchannels(2)
        w.setsampwidth(2)
        w.setframerate(RATE)
        w.writeframes(b"".join(struct.pack("<hh", int(s * scale * 32767), int(s * scale * 32767)) for s in samples))


def click(dur=0.05, gain=0.25):
    rnd = random.Random(7)
    n = int(RATE * dur)
    return [gain * rnd.uniform(-1, 1) * math.exp(-i / RATE * 90) for i in range(n)]


os.makedirs(OUT, exist_ok=True)
E6, A6, C5, G5, A5, C6, A3, E5 = 1318.5, 1760.0, 523.3, 784.0, 880.0, 1046.5, 220.0, 659.3
save("message-new-instant", mixdown(bell(E6, .22, .22), bell(A6, .30, .18, .07)))
save("device-added", mixdown(bell(C5, .20), bell(G5, .28, .3, .09)))
save("device-removed", mixdown(bell(G5, .20), bell(C5, .30, .3, .09)))
save("audio-volume-change", bell(A5, .06, .25))
save("screen-capture", mixdown(click(), bell(C6, .14, .14, .02)))
save("dialog-error", mixdown(bell(A3 * 2, .16, .3), bell(A3 * 2, .2, .3, .14)))
save("power-plug", mixdown(bell(C5, .14), bell(E5, .14, .3, .06), bell(G5, .24, .3, .12)))
save("power-unplug", mixdown(bell(G5, .14), bell(E5, .14, .3, .06), bell(C5, .24, .3, .12)))
save("bell", bell(A5, .3))
# pomodoro: a bright rising pling when focus ends, a softer two-note one when the break ends
G6 = 1568.0
save("pomodoro-done", mixdown(bell(C6, .5, .3), bell(E6, .5, .28, .11), bell(G6, .9, .26, .22)))
save("break-done", mixdown(bell(G5, .35, .3), bell(C6, .6, .3, .14)))

# Sam's purr: soft low rumble, about 26 pulses a second, swelling in and out over 2.4 s
def purr(dur=2.4, gain=0.5):
    rnd = random.Random(3)
    n = int(RATE * dur)
    out, lp = [], 0.0
    for i in range(n):
        t = i / RATE
        lp += 0.035 * (rnd.uniform(-1, 1) - lp)          # low-passed noise
        pulse = 0.5 + 0.5 * math.sin(2 * math.pi * 26 * t)
        swell = math.sin(math.pi * t / dur) ** 0.8
        tone = math.sin(2 * math.pi * 52 * t) * 0.35
        out.append(gain * swell * pulse * (lp * 6 + tone))
    return out


save("purr", purr())
print("desk sounds →", OUT)
