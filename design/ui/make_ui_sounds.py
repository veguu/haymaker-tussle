"""Renders the fight-poster mockup's soft UI sounds to WAV files.

The mockup (vault: UI Research/fight-poster-prototype.html) makes its sounds in the browser, in `sfx()`: sine and
triangle tones with a pitch slide, and lowpassed noise, all through one master gain (0.6) and one lowpass
(4600 Hz). This script does the same sums with the same numbers, so the files sound as the mockup does.

    python design/ui/make_ui_sounds.py            -> assets/sfx/ui/*.wav and a table of lengths and peaks

Only the sounds the GAME needs are rendered (see HANDOFF.md, ui-8b, for the map and for what was left out and why).
The mockup varies some pitches a little on each play (`v`); the files are rendered at v = 1 and the game varies the
playback speed instead. Every file is brought to the same peak (-6 dBFS): how loud each plays is set in
Shared/Config/SoundBank.luau, from the mockup's own levels (printed here as `mock peak`).

Nothing here uploads anything.
"""

import math
import os
import struct
import sys
import wave

import numpy as np

RATE = 44100
MASTER_GAIN = 0.6
MASTER_CUT = 4600.0
MASTER_Q_DB = 0.3
PEAK = 10 ** (-6 / 20)
TAIL = 0.03  # silence after the last sample that sounds, as the mockup's own stop time
RNG = np.random.default_rng(20261117)


def exp_ramp(v0, v1, n):
    """Web Audio's exponentialRampToValueAtTime over n samples (from v0, ending just short of v1)."""
    if n <= 0:
        return np.zeros(0)
    return v0 * (v1 / v0) ** (np.arange(n) / n)


def gain_curve(dur, vol, attack):
    up = int(round(attack * RATE))
    total = int(round(dur * RATE))
    return np.concatenate([exp_ramp(0.0001, vol, up), exp_ramp(vol, 0.0001, total - up)])


def osc(f1, f2, dur, kind="sine", vol=0.1, delay=0.0):
    n = int(round(dur * RATE))
    freq = exp_ramp(f1, f2, n) if (f2 and f2 != f1) else np.full(n, float(f1))
    phase = 2 * math.pi * np.cumsum(freq) / RATE
    if kind == "triangle":
        tone = 2 / math.pi * np.arcsin(np.sin(phase))
    else:
        tone = np.sin(phase)
    return delay, tone * gain_curve(dur, vol, min(0.012, dur * 0.25))


def lowpass_swept(x, cut, q_db):
    """A biquad lowpass (the Web Audio one: Q is in decibels) whose cutoff may change every sample."""
    y = np.zeros_like(x)
    q = 10 ** (q_db / 20)
    x1 = x2 = y1 = y2 = 0.0
    cut = np.broadcast_to(cut, x.shape)
    for i in range(len(x)):
        w0 = 2 * math.pi * min(cut[i], RATE * 0.49) / RATE
        cw, alpha = math.cos(w0), math.sin(w0) / (2 * q)
        b0 = (1 - cw) / 2
        b1 = 1 - cw
        a0, a1, a2 = 1 + alpha, -2 * cw, 1 - alpha
        out = (b0 * x[i] + b1 * x1 + b0 * x2 - a1 * y1 - a2 * y2) / a0
        x2, x1 = x1, x[i]
        y2, y1 = y1, out
        y[i] = out
    return y


def noise(dur, vol, f1, f2, delay=0.0):
    n = int(round(dur * RATE))
    raw = RNG.uniform(-1, 1, n)
    filtered = lowpass_swept(raw, exp_ramp(f1, f2, n), 1.0)  # a BiquadFilter's default Q is 1 (dB)
    return delay, filtered * gain_curve(dur, vol, min(0.03, dur * 0.3))


def mix(parts):
    length = max(int(round(d * RATE)) + len(s) for d, s in parts) + int(TAIL * RATE)
    out = np.zeros(length)
    for delay, samples in parts:
        at = int(round(delay * RATE))
        out[at : at + len(samples)] += samples
    return lowpass_swept(out * MASTER_GAIN, MASTER_CUT, MASTER_Q_DB)


def count(f, final):
    parts = [
        osc(110, 50, 0.42, "sine", 0.28),
        noise(0.22, 0.09, 900, 200),
        osc(f, f, 0.5, "triangle", 0.07, 0.02),
        osc(f * 1.5, f * 1.5, 0.5, "sine", 0.06, 0.02),
    ]
    if final:
        parts += [osc(f * 1.26, f * 1.26, 0.55, "triangle", 0.07, 0.24), osc(110, 50, 0.42, "sine", 0.22, 0.24)]
    return parts


# name -> the mockup's own recipe (its `case` in sfx(), at v = 1)
SOUNDS = {
    "ui_press": [osc(420, 300, 0.06, "triangle", 0.07)],  # 'pop'
    "ui_open": [noise(0.28, 0.07, 300, 1200), osc(150, 95, 0.2, "sine", 0.11, 0.14)],  # 'whoosh'
    "ui_close": [osc(340, 220, 0.11, "triangle", 0.07)],  # 'close'
    "ui_page": [osc(480, 360, 0.08, "triangle", 0.08), osc(720, 560, 0.07, "triangle", 0.035)],  # 'snap'
    "ui_equip": [osc(440, 440, 0.11, "triangle", 0.1), osc(587, 587, 0.2, "triangle", 0.1, 0.09)],  # 'equip'
    "ui_buy": [osc(880, 880, 0.09, "triangle", 0.08), osc(1175, 1175, 0.22, "triangle", 0.08, 0.08)],  # 'coin'
    "ui_deny": [osc(190, 140, 0.18, "triangle", 0.1)],  # 'nope'
    "skill_ready": [osc(659, 659, 0.08, "triangle", 0.09), osc(988, 988, 0.22, "triangle", 0.09, 0.08)],  # 'ready'
    "ring_out": [osc(300, 140, 0.15, "triangle", 0.09)],  # 'ko'
    "last_5": count(196, False),  # 'count', one per number as in the mockup
    "last_4": count(220, False),
    "last_3": count(262, False),
    "last_2": count(330, True),
    # NOT in the mockup (the owner, 2026-11-17: a hover sound that matches the rest): a soft sine that lifts a
    # little, where the press ('pop', 420 -> 300) falls; shorter attack-to-tail and about half the press's level
    "ui_hover": [osc(540, 630, 0.07, "sine", 0.04)],
}


def main():
    out_dir = os.path.join(os.path.dirname(__file__), "..", "..", "assets", "sfx", "ui")
    os.makedirs(out_dir, exist_ok=True)
    only = set(sys.argv[1:])
    print(f"{'file':<18}{'seconds':>8}{'mock peak':>11}{'gain':>7}")
    for name, parts in SOUNDS.items():
        if only and name not in only:
            continue
        samples = mix(parts)
        peak = float(np.max(np.abs(samples)))
        gain = PEAK / peak
        data = np.clip(samples * gain, -1, 1)
        path = os.path.join(out_dir, name + ".wav")
        with wave.open(path, "wb") as f:
            f.setnchannels(1)
            f.setsampwidth(2)
            f.setframerate(RATE)
            f.writeframes(struct.pack(f"<{len(data)}h", *(np.round(data * 32767).astype(int))))
        print(f"{name + '.wav':<18}{len(data) / RATE:>8.2f}{peak:>11.3f}{gain:>7.1f}")


if __name__ == "__main__":
    main()
