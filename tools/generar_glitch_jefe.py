"""Sintetiza el glitch de la muerte del Arzobispo: assets/audio/sfx/gen/jefe_glitch.wav (2.4 s, mono).

Uso (desde la raíz del proyecto):  python tools/generar_glitch_jefe.py     Necesita numpy. Determinista.
Capas: retumbo sub que cae, coro grave desafinado (segunda menor) que se traba y repite en bucles
cortos, ráfagas de ruido digital (muestreo escalonado), chillido de saltos de tono y bitcrush que crece.
"""
import os
import wave

import numpy as np

SR = 44100
DUR = 2.4
rng = np.random.default_rng(666)
n = int(DUR * SR)
t = np.arange(n) / SR
k = t / DUR

# retumbo sub: barrido 62 -> 26 Hz saturado, con temblor irregular
f = 26 + 36 * np.exp(-t / 0.9)
sub = np.tanh(2.5 * np.sin(2 * np.pi * np.cumsum(f) / SR)) * (0.5 + 0.5 * k) * (0.7 + 0.3 * np.sin(2 * np.pi * 7 * t) * np.sin(2 * np.pi * 2.3 * t))

# coro grave desafinado (La - La# - Mi) con formante de "o"
coro = np.zeros(n)
for f0 in (55.0, 58.3, 82.4, 110.0, 116.5):
    vib = 1 + 0.02 * np.sin(2 * np.pi * (3 + 3 * rng.random()) * t)
    fase = 2 * np.pi * np.cumsum(f0 * vib) / SR
    for h in range(1, 16):
        fh = f0 * h
        g = np.exp(-((fh - 450) / 220) ** 2) + 0.5 * np.exp(-((fh - 800) / 260) ** 2) + 0.15 / h
        coro += g * np.sin(h * fase + rng.random() * 6.28)
coro /= np.max(np.abs(coro))

# trabado: segmentos cortos que se repiten, caen en silencio o saltan de tono; más densos hacia el final
i = 0
while i < n:
    i += int(SR * rng.uniform(0.15, 0.45) * (1.0 - 0.75 * (i / n)))
    L = int(SR * rng.uniform(0.02, 0.13))
    if i + L * 3 >= n:
        break
    seg = coro[i:i + L].copy()
    r = rng.random()
    if r < 0.2:
        seg[:] = 0.0
    elif r < 0.5:
        seg = np.interp(np.linspace(0, L - 1, int(L / rng.choice([0.5, 0.7, 1.5, 2.0]))), np.arange(L), seg)
    reps = int(rng.integers(2, 7))
    rep = np.tile(seg, reps)[: n - i]
    coro[i:i + len(rep)] = rep

# ruido digital escalonado (ráfagas)
ruido = np.zeros(n)
for _ in range(14):
    ini = int(n * rng.random() ** 1.3)
    L = int(SR * rng.uniform(0.01, 0.09))
    paso = int(rng.choice([4, 12, 30, 70]))
    bloque = np.repeat(rng.uniform(-1, 1, L // paso + 2), paso)[:L]
    bloque *= np.linspace(1, 0, len(bloque)) ** 0.5
    ruido[ini:ini + len(bloque)] += bloque[: n - ini] * (0.1 + 0.25 * ini / n)

# chillido: tono que salta al azar de frecuencia, modulado en anillo
chill = np.zeros(n)
j = int(n * 0.35)
while j < n:
    L = int(SR * rng.uniform(0.03, 0.09))
    fr = rng.choice([220, 330, 1700, 2400, 3100]) * rng.uniform(0.9, 1.1)
    tt = np.arange(min(L, n - j)) / SR
    chill[j:j + len(tt)] = np.sin(2 * np.pi * fr * tt) * np.sign(np.sin(2 * np.pi * 70 * tt)) * 0.05
    j += L + int(SR * rng.uniform(0.0, 0.08))

x = 0.9 * sub + 0.55 * coro * (0.4 + 0.6 * k) + ruido + chill * k
# bitcrush creciente: baja la resolución y repite muestras
x = x / np.max(np.abs(x))
bits = 9
x = np.round(x * 2 ** bits) / 2 ** bits
dec = np.where(k > 0.7, 3, 1)
idx = (np.arange(n) // dec) * dec
x = np.tanh(1.1 * x[idx])
x *= np.minimum(t / 0.02, 1.0) * np.minimum((DUR - t) / 0.12, 1.0)
x = x / np.max(np.abs(x)) * 0.6

ruta = os.path.join(os.path.dirname(__file__), "..", "assets", "audio", "sfx", "gen", "jefe_glitch.wav")
with wave.open(ruta, "wb") as w:
    w.setnchannels(1)
    w.setsampwidth(2)
    w.setframerate(SR)
    w.writeframes((x * 32767).astype("<i2").tobytes())
print("escrito", ruta)
