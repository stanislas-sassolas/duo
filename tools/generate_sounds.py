"""Génère les sons de Duo (originaux, créés pour l'app : aucun droit tiers).

Clin d'œil à Miraculous sans reprendre la musique de la série :
- send_yoyo.wav       : petit « fwip » de yoyo qui s'envole (envoi)
- receive_sparkle.wav : tintement magique très court (réception)
- music_box.wav       : boucle de boîte à musique, valse originale en do majeur

Usage : python tools/generate_sounds.py
Écrit dans assets/sounds/ et copie le son de réception dans
android/app/src/main/res/raw/ (son de la notification).
"""

import shutil
import wave
from pathlib import Path

import numpy as np

ROOT = Path(__file__).resolve().parent.parent
OUT = ROOT / "assets" / "sounds"
RAW = ROOT / "android" / "app" / "src" / "main" / "res" / "raw"


def write_wav(path: Path, samples: np.ndarray, rate: int, peak: float) -> None:
    samples = samples / (np.max(np.abs(samples)) or 1.0) * peak
    data = (samples * 32767).astype("<i2").tobytes()
    path.parent.mkdir(parents=True, exist_ok=True)
    with wave.open(str(path), "wb") as f:
        f.setnchannels(1)
        f.setsampwidth(2)
        f.setframerate(rate)
        f.writeframes(data)


def fade(samples: np.ndarray, rate: int, ms_in: float = 4, ms_out: float = 30) -> np.ndarray:
    n_in, n_out = int(rate * ms_in / 1000), int(rate * ms_out / 1000)
    env = np.ones_like(samples)
    env[:n_in] = np.linspace(0, 1, n_in)
    env[-n_out:] = np.linspace(1, 0, n_out)
    return samples * env


def bell(freq: float, dur: float, rate: int, decay: float) -> np.ndarray:
    """Timbre de clochette / boîte à musique : partiels légèrement inharmoniques."""
    t = np.arange(int(dur * rate)) / rate
    tone = (
        np.sin(2 * np.pi * freq * t)
        + 0.35 * np.sin(2 * np.pi * freq * 2.01 * t) * np.exp(-t / (decay * 0.5))
        + 0.12 * np.sin(2 * np.pi * freq * 3.98 * t) * np.exp(-t / (decay * 0.25))
    )
    attack = np.minimum(1, t / 0.004)
    return tone * attack * np.exp(-t / decay)


def send_yoyo(rate: int = 44100) -> np.ndarray:
    dur = 0.22
    t = np.arange(int(dur * rate)) / rate
    # Glissando montant 420 → 1500 Hz : le yoyo qui part.
    freq = 420 * (1500 / 420) ** (t / dur)
    phase = 2 * np.pi * np.cumsum(freq) / rate
    env = np.sin(np.pi * np.minimum(t / dur, 1)) ** 1.5
    tone = np.sin(phase) * env
    # Léger souffle de fil.
    noise = np.random.default_rng(7).normal(0, 1, len(t))
    noise = np.convolve(noise, np.ones(12) / 12, mode="same") * env * 0.15
    return fade(tone + noise, rate)


def receive_sparkle(rate: int = 44100) -> np.ndarray:
    dur = 0.75
    out = np.zeros(int(dur * rate))
    # Mi6 – Si6 – Mi7, décalés de 55 ms : une petite étincelle.
    for i, f in enumerate([1318.5, 1975.5, 2637.0]):
        start = int(i * 0.055 * rate)
        note = bell(f, dur - i * 0.055, rate, decay=0.22) * (1 - 0.15 * i)
        out[start:start + len(note)] += note
    return fade(out, rate, ms_out=80)


NOTES = {
    "G3": 196.00, "C4": 261.63, "D4": 293.66, "E4": 329.63, "F4": 349.23,
    "G4": 392.00, "A4": 440.00, "B4": 493.88, "C5": 523.25, "D5": 587.33,
    "E5": 659.25, "F5": 698.46, "G5": 783.99, "A5": 880.00, "B5": 987.77,
    "C6": 1046.50, "D6": 1174.66,
}

# Valse originale (3 temps par mesure). (note, durée en temps)
MELODY = [
    ("E5", 1), ("G5", 1), ("C6", 1),
    ("B5", 1), ("G5", 1), ("E5", 1),
    ("F5", 1), ("A5", 1), ("D6", 1),
    ("C6", 3),
    ("A5", 1), ("F5", 1), ("D5", 1),
    ("G5", 1), ("E5", 1), ("C5", 1),
    ("D5", 1), ("F5", 1), ("B5", 1),
    ("C6", 2), ("G5", 1),
]
BASS = ["C4", "E4", "F4", "C4", "F4", "C4", "G3", "C4"]  # 1er temps de chaque mesure


def music_box(rate: int = 22050, bpm: float = 96) -> np.ndarray:
    beat = 60 / bpm
    bars = len(BASS)
    length = int(bars * 3 * beat * rate)
    out = np.zeros(length + rate * 3)  # marge pour les résonances

    pos = 0.0
    for name, beats in MELODY:
        note = bell(NOTES[name], 2.2, rate, decay=0.7)
        i = int(pos * beat * rate)
        out[i:i + len(note)] += note
        pos += beats
    for bar, name in enumerate(BASS):
        note = bell(NOTES[name], 2.6, rate, decay=0.9) * 0.45
        i = int(bar * 3 * beat * rate)
        out[i:i + len(note)] += note
        # Deux accords légers sur les temps 2 et 3 (tierce au-dessus).
        for b in (1, 2):
            chord = bell(NOTES[name] * 2 * 1.26, 1.2, rate, decay=0.35) * 0.12
            j = int((bar * 3 + b) * beat * rate)
            out[j:j + len(chord)] += chord

    # Petite réverbération (échos décroissants).
    wet = out.copy()
    for k, gain in [(0.061, 0.35), (0.113, 0.22), (0.197, 0.12)]:
        d = int(k * rate)
        wet[d:] += out[:-d] * gain
    # Boucle sans coupure : la résonance qui dépasse revient au début.
    loop = wet[:length].copy()
    tail = wet[length:]
    loop[:len(tail)] += tail[:length]
    return loop


def main() -> None:
    write_wav(OUT / "send_yoyo.wav", send_yoyo(), 44100, peak=0.35)
    write_wav(OUT / "receive_sparkle.wav", receive_sparkle(), 44100, peak=0.35)
    write_wav(OUT / "music_box.wav", music_box(), 22050, peak=0.5)
    RAW.mkdir(parents=True, exist_ok=True)
    shutil.copy(OUT / "receive_sparkle.wav", RAW / "receive_sparkle.wav")
    for f in sorted(OUT.glob("*.wav")):
        print(f"{f.name}: {f.stat().st_size // 1024} Ko")


if __name__ == "__main__":
    main()
