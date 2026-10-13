"""Sintetiza el ambiente sonoro de cueva (nivel 2) en assets/audio/ambiente_nivel2/*.wav.

Uso (desde la raíz del proyecto):  python tools/generar_ambiente_cueva.py
Necesita numpy. Es determinista (semilla fija). Las capas en loop se generan en el dominio de la
frecuencia, así que son periódicas y empalman sin cortes; además llevan un bloque `smpl` con el loop
completo para que Godot las importe en bucle. Cada archivo se puede reemplazar por audio definitivo.
"""
import os
import struct

import numpy as np

SR = 22050
SALIDA = os.path.join(os.path.dirname(__file__), "..", "assets", "audio", "ambiente_nivel2")


def guardar_wav(nombre, x, pico, loop=False):
    x = x / max(np.max(np.abs(x)), 1e-9) * pico
    datos = (np.clip(x, -1.0, 1.0) * 32767.0).astype("<i2").tobytes()
    fmt = struct.pack("<HHIIHH", 1, 1, SR, SR * 2, 2, 16)
    cuerpo = b"WAVE" + b"fmt " + struct.pack("<I", len(fmt)) + fmt + b"data" + struct.pack("<I", len(datos)) + datos
    if loop:
        smpl = struct.pack("<IIIIIIIII", 0, 0, int(1e9 / SR), 60, 0, 0, 0, 1, 0)
        smpl += struct.pack("<IIIIII", 0, 0, 0, len(x) - 1, 0, 0)
        cuerpo += b"smpl" + struct.pack("<I", len(smpl)) + smpl
    os.makedirs(SALIDA, exist_ok=True)
    with open(os.path.join(SALIDA, nombre), "wb") as f:
        f.write(b"RIFF" + struct.pack("<I", len(cuerpo)) + cuerpo)
    print("escrito", nombre)


def ruido_filtrado(seg, rng, respuesta):
    """Ruido blanco con la respuesta en frecuencia dada: periódico (empalma consigo mismo)."""
    n = int(seg * SR)
    f = np.fft.rfftfreq(n, 1.0 / SR)
    espectro = np.fft.rfft(rng.standard_normal(n)) * respuesta(f)
    return np.fft.irfft(espectro, n)


def reverb(x, rng, cola=1.6, brillo=2500.0):
    """Reverberación circular (la cola de lo último vuelve a empezar el loop)."""
    n = len(x)
    t = np.arange(int(cola * SR)) / SR
    ir = rng.standard_normal(len(t)) * np.exp(-t / (cola * 0.28))
    ir = np.fft.irfft(np.fft.rfft(ir, n) / (1.0 + (np.fft.rfftfreq(n, 1.0 / SR) / brillo) ** 2), n)
    ir /= np.sqrt(np.sum(ir ** 2))
    return np.fft.irfft(np.fft.rfft(x) * np.fft.rfft(ir), n)


def viento_cueva(rng):
    seg = 30.0
    n = int(seg * SR)
    t = np.arange(n) / SR
    grave = ruido_filtrado(seg, rng, lambda f: 1.0 / (1.0 + (f / 160.0) ** 4) / (1.0 + (40.0 / np.maximum(f, 1.0)) ** 2))
    aire = ruido_filtrado(seg, rng, lambda f: np.exp(-((np.log(np.maximum(f, 1.0) / 650.0)) ** 2) / 0.5))
    mod_g = 0.7 + 0.3 * np.sin(2 * np.pi * 3 * t / seg + 0.6)
    mod_a = 0.15 + 0.85 * (0.5 + 0.5 * np.sin(2 * np.pi * 2 * t / seg + 2.1)) ** 2
    return grave / np.std(grave) * mod_g + 0.22 * aire / np.std(aire) * mod_a


def goteo(rng):
    seg = 40.0
    n = int(seg * SR)
    seco = np.zeros(n)
    tiempos = []
    t = rng.uniform(0.5, 2.0)
    while t < seg - 1.0:
        tiempos.append(t)
        t += rng.uniform(1.4, 6.0) if rng.random() > 0.3 else rng.uniform(0.25, 0.6)   # a veces caen en racimo
    for t0 in tiempos:
        dur = 0.18
        tt = np.arange(int(dur * SR)) / SR
        f = rng.uniform(900.0, 1700.0)
        fase = 2 * np.pi * np.cumsum(f * (1.0 + 0.9 * np.exp(-tt * 40.0))) / SR
        gota = np.sin(fase) * np.exp(-tt / 0.035) * rng.uniform(0.25, 1.0)
        i = int(t0 * SR)
        seco[i:i + len(gota)] += gota[: n - i]
    return 0.6 * seco + 0.9 * reverb(seco, rng, cola=2.2, brillo=3000.0)


def rumor_lejano(rng):
    seg = 7.0
    n = int(seg * SR)
    t = np.arange(n) / SR
    base = ruido_filtrado(seg, rng, lambda f: 1.0 / (1.0 + (f / 85.0) ** 4))
    env = np.minimum(t / 0.8, 1.0) * np.exp(-np.maximum(t - 0.8, 0.0) / 1.6)
    return reverb(base * env, rng, cola=2.0, brillo=700.0)


def gota_lejana(rng):
    seg = 5.0
    n = int(seg * SR)
    seco = np.zeros(n)
    tt = np.arange(int(0.2 * SR)) / SR
    fase = 2 * np.pi * np.cumsum(1100.0 * (1.0 + 0.9 * np.exp(-tt * 40.0))) / SR
    seco[int(0.2 * SR):int(0.2 * SR) + len(tt)] = np.sin(fase) * np.exp(-tt / 0.04)
    return 0.3 * seco + 1.2 * reverb(seco, rng, cola=3.2, brillo=2200.0)


if __name__ == "__main__":
    guardar_wav("cueva_viento_loop.wav", viento_cueva(np.random.default_rng(11)), 0.5, loop=True)
    guardar_wav("cueva_goteo_loop.wav", goteo(np.random.default_rng(12)), 0.45, loop=True)
    guardar_wav("cueva_rumor.wav", rumor_lejano(np.random.default_rng(13)), 0.55)
    guardar_wav("cueva_gota_lejana.wav", gota_lejana(np.random.default_rng(14)), 0.4)
