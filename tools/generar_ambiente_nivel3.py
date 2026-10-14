"""Sintetiza los sonidos ambientales del nivel 3 ("El corazón late") en assets/audio/ambiente_nivel3/*.wav.

Uso (desde la raíz del proyecto):  python tools/generar_ambiente_nivel3.py
Necesita numpy. Determinista (semilla fija). Reutiliza las utilidades de generar_ambiente_cueva.py.
  - latido_pum1 / latido_pum2: los dos golpes del corazón (los dispara latido_sonoro.gd con el latido de la cueva).
  - cueva_pulso_loop: zumbido grave en bucle que crece cerca del sello (volumen según la intensidad del latido).
  - canto_lejano: voces graves de los cultistas, muy lejos (acento aleatorio).
  - piedra_cruje: la roca cediendo bajo el peso de algo enorme (acento aleatorio).
Cada archivo se puede reemplazar por audio definitivo.
"""
import os
import sys

import numpy as np

sys.path.insert(0, os.path.dirname(__file__))
import generar_ambiente_cueva as base  # noqa: E402

base.SALIDA = os.path.join(os.path.dirname(__file__), "..", "assets", "audio", "ambiente_nivel3")
SR = base.SR


def caida(n, tau):
    return np.exp(-np.arange(n) / (tau * SR))


def pum(rng, f0, f1, dur, cuerpo=1.0, golpe=0.5):
    n = int(dur * SR)
    t = np.arange(n) / SR
    barrido = f1 + (f0 - f1) * np.exp(-t / 0.045)
    fase = 2 * np.pi * np.cumsum(barrido) / SR
    tono = np.sin(fase) * caida(n, 0.11 * cuerpo)
    ruido = base.ruido_filtrado(dur, rng, lambda f: 1.0 / (1.0 + (f / 150.0) ** 4))
    ruido = ruido / max(np.std(ruido), 1e-9) * caida(n, 0.03) * golpe * 0.5
    ataque = np.minimum(t / 0.004, 1.0)
    return (tono + ruido) * ataque


def pulso_loop(rng):
    seg = 16.0
    n = int(seg * SR)
    t = np.arange(n) / SR
    grave = base.ruido_filtrado(seg, rng, lambda f: 1.0 / (1.0 + (f / 90.0) ** 4) / (1.0 + (25.0 / np.maximum(f, 1.0)) ** 2))
    grave /= np.std(grave)
    # dos tonos casi iguales (batido lento, como un órgano muy lejano) con frecuencias que dan un número entero de ciclos
    f1 = round(41.0 * seg) / seg
    f2 = round(42.5 * seg) / seg
    tonos = 0.6 * np.sin(2 * np.pi * f1 * t) + 0.5 * np.sin(2 * np.pi * f2 * t + 0.7)
    mod = 0.65 + 0.35 * np.sin(2 * np.pi * 1 * t / seg + 0.4)
    return (0.8 * grave + tonos) * mod


def canto(rng):
    seg = 11.0
    n = int(seg * SR)
    t = np.arange(n) / SR
    voces = np.zeros(n)
    # acorde menor muy grave (La, Do, Mi) con vibrato lento; cada voz entra y sale a su tiempo
    for f0, ini, dur in ((55.0, 0.4, 9.0), (65.4, 1.4, 8.0), (82.4, 2.4, 6.5), (110.0, 3.4, 5.0)):
        vib = 1.0 + 0.012 * np.sin(2 * np.pi * (4.6 + rng.random()) * t + rng.random() * 6.28)
        fase = 2 * np.pi * np.cumsum(f0 * vib) / SR
        voz = np.zeros(n)
        for h in range(1, 14):
            # formantes aproximados de una vocal "o" cerrada (≈ 450 y 800 Hz) sobre los armónicos
            fh = f0 * h
            ganancia = np.exp(-((fh - 450.0) / 220.0) ** 2) + 0.55 * np.exp(-((fh - 800.0) / 260.0) ** 2) + 0.2 / h
            voz += ganancia * np.sin(h * fase + rng.random() * 6.28)
        env = np.clip((t - ini) / 2.0, 0.0, 1.0) * np.clip((ini + dur - t) / 2.5, 0.0, 1.0)
        voces += voz * env ** 1.5
    voces *= 0.7 + 0.3 * np.sin(2 * np.pi * 0.35 * t)
    return base.reverb(voces, rng, cola=2.6, brillo=1400.0)


def cruje(rng):
    seg = 3.2
    n = int(seg * SR)
    t = np.arange(n) / SR
    f = 62.0 - 14.0 * (t / seg) + 3.0 * np.sin(2 * np.pi * 7.0 * t)
    fase = 2 * np.pi * np.cumsum(f) / SR
    diente = 2.0 * ((fase / (2 * np.pi)) % 1.0) - 1.0
    # el diente de sierra pasa por un pasabajos que se cierra: gruñido sordo
    gru = base.ruido_filtrado(seg, rng, lambda fr: 1.0 / (1.0 + (fr / 220.0) ** 3))
    gru = gru / max(np.std(gru), 1e-9)
    cuerpo = (0.7 * diente + 0.5 * gru) * np.sin(np.pi * np.clip(t / seg, 0, 1)) ** 1.2
    chasquidos = np.zeros(n)
    for _ in range(14):
        i = int(rng.random() * (n - 800))
        dur = int(SR * (0.006 + rng.random() * 0.02))
        chasquidos[i:i + dur] += rng.standard_normal(dur) * np.exp(-np.arange(dur) / (dur * 0.3)) * (0.3 + rng.random() * 0.5)
    chasquidos = base.ruido_filtrado(seg, rng, lambda fr: 1.0) * 0 + chasquidos
    return base.reverb(cuerpo + 0.4 * chasquidos, rng, cola=1.4, brillo=2200.0)


def generar():
    rng = np.random.default_rng(303)
    base.guardar_wav("latido_pum1.wav", pum(rng, 95.0, 42.0, 0.9, cuerpo=1.0, golpe=0.6), 0.92)
    base.guardar_wav("latido_pum2.wav", pum(rng, 80.0, 38.0, 0.7, cuerpo=0.8, golpe=0.35), 0.72)
    base.guardar_wav("cueva_pulso_loop.wav", pulso_loop(rng), 0.85, loop=True)
    base.guardar_wav("canto_lejano.wav", canto(rng), 0.45)
    base.guardar_wav("piedra_cruje.wav", cruje(rng), 0.55)


if __name__ == "__main__":
    generar()
