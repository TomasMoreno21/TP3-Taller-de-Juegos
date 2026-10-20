"""Sintetiza la vibración macabra de la aparición del Arzobispo: assets/audio/sfx/gen/jefe_vibracion.wav (6 s, mono).

Uso (desde la raíz del proyecto):  python tools/generar_vibracion_jefe.py     Necesita numpy. Determinista.
Dura lo que el zoom lento de la aparición (temblor 2.8 + calma 1.3 + acecho 1.9). Zumbido grave en batido con
temblor de amplitud (~24 Hz) que crece; en la calma queda un hilo agudo desafinado; en el acecho vuelve a hincharse
y se corta en seco justo antes del rugido.
"""
import os
import wave

import numpy as np

SR = 44100
DUR = 6.0
rng = np.random.default_rng(13)
n = int(DUR * SR)
t = np.arange(n) / SR

# envolvente: sube (0-2.8) -> casi nada (2.8-4.1) -> se hincha despacio (4.1-6.0) -> corte seco
env = np.interp(t, [0.0, 0.6, 2.8, 3.1, 4.1, 5.9, 5.97], [0.0, 0.25, 1.0, 0.1, 0.1, 0.65, 0.0])

# zumbido grave en batido (41 y 43.5 Hz), saturado
grave = np.tanh(2.2 * (np.sin(2 * np.pi * 41 * t) + 0.9 * np.sin(2 * np.pi * 43.5 * t + 0.6)))

# temblor de amplitud irregular: 18-30 Hz, más profundo con el tiempo
frec_am = 24 + 6 * np.sin(2 * np.pi * 0.7 * t) + rng.normal(0, 0.8, n).cumsum() / SR * 40
am = 0.55 + 0.45 * np.sin(2 * np.pi * np.cumsum(frec_am) / SR)
prof = np.interp(t, [0, 2.8, 4.1, 6.0], [0.3, 1.0, 1.0, 1.0])
grave *= 1.0 - prof * (1.0 - am)

# hilo agudo desafinado (segunda menor) con vibrato nervioso
vib = 1 + 0.012 * np.sin(2 * np.pi * 6.5 * t)
agudo = 0.5 * np.sin(2 * np.pi * np.cumsum(740 * vib) / SR) + 0.5 * np.sin(2 * np.pi * np.cumsum(784 * vib) / SR)
agudo *= (0.04 + 0.2 * np.interp(t, [0, 2.8, 3.1, 4.1, 6.0], [0.1, 0.5, 1.0, 1.0, 0.8])) * (0.6 + 0.4 * am)

# ruido grave de roca
ruido = rng.normal(0, 1, n)
for _ in range(3):
    ruido = np.convolve(ruido, np.ones(40) / 40, mode="same")
ruido = ruido / np.max(np.abs(ruido)) * 0.5 * (0.4 + 0.6 * am)

x = (0.8 * grave + ruido) * env + agudo * np.minimum((DUR - t) / 0.05, 1.0)
x = x / np.max(np.abs(x)) * 0.75

ruta = os.path.join(os.path.dirname(__file__), "..", "assets", "audio", "sfx", "gen", "jefe_vibracion.wav")
with wave.open(ruta, "wb") as w:
    w.setnchannels(1)
    w.setsampwidth(2)
    w.setframerate(SR)
    w.writeframes((x * 32767).astype("<i2").tobytes())
print("escrito", ruta)
