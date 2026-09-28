"""Sintetiza los efectos de sonido del juego en assets/audio/sfx/gen/*.wav.

Uso (desde la raíz del proyecto):  python tools/generar_sfx.py
Solo usa la biblioteca estándar (math/random/wave). Es determinista (semilla fija):
volver a correrlo regenera exactamente los mismos archivos. Cada sonido se puede
reemplazar desde el Inspector de Godot por audio definitivo.
"""
import math
import os
import random
import struct
import wave

SR = 44100
SALIDA = os.path.join(os.path.dirname(__file__), "..", "assets", "audio", "sfx", "gen")


# ---------------------------------------------------------------- primitivas
def n(seg):
    return int(seg * SR)


def ruido(seg, rng):
    return [rng.uniform(-1.0, 1.0) for _ in range(n(seg))]


def pasabajos(x, corte):
    a = math.exp(-2.0 * math.pi * corte / SR)
    y, prev = [], 0.0
    for v in x:
        prev = (1 - a) * v + a * prev
        y.append(prev)
    return y


def pasaaltos(x, corte):
    lp = pasabajos(x, corte)
    return [v - l for v, l in zip(x, lp)]


def banda(x, lo, hi):
    return pasabajos(pasaaltos(x, lo), hi)


def pasabajos_var(x, cortes):
    """Pasabajos con frecuencia de corte variable por muestra (barridos)."""
    y, prev = [], 0.0
    for v, c in zip(x, cortes):
        a = math.exp(-2.0 * math.pi * max(c, 20.0) / SR)
        prev = (1 - a) * v + a * prev
        y.append(prev)
    return y


def env(largo, ataque, caida, curva=1.0):
    """Envolvente: sube en `ataque` s y cae exponencialmente con constante `caida` s."""
    out = []
    na = max(1, n(ataque))
    for i in range(largo):
        t = i / SR
        if i < na:
            out.append((i / na) ** curva)
        else:
            out.append(math.exp(-(t - ataque) / max(caida, 1e-4)))
    return out


def tono(seg, f0, f1=None, forma="seno", fase=0.0):
    """Oscilador con glissando exponencial f0→f1."""
    f1 = f0 if f1 is None else f1
    largo = n(seg)
    out, ph = [], fase
    for i in range(largo):
        t = i / max(largo - 1, 1)
        f = f0 * (f1 / f0) ** t
        ph += 2 * math.pi * f / SR
        if forma == "seno":
            out.append(math.sin(ph))
        elif forma == "tri":
            out.append(2 / math.pi * math.asin(math.sin(ph)))
        elif forma == "cuadrada":
            out.append(1.0 if math.sin(ph) >= 0 else -1.0)
    return out


def cuerda(seg, f, rng, brillo=0.5):
    """Karplus-Strong: cuerda pulsada (arco del arquero)."""
    periodo = max(2, int(SR / f))
    buf = [rng.uniform(-1, 1) for _ in range(periodo)]
    out = []
    for i in range(n(seg)):
        v = buf[i % periodo]
        nxt = buf[(i + 1) % periodo]
        buf[i % periodo] = (v * brillo + nxt * (1 - brillo)) * 0.996
        out.append(v)
    return out


def mul(a, b):
    return [x * y for x, y in zip(a, b)]


def mezclar(*capas):
    largo = max(len(c) for c, _ in capas)
    out = [0.0] * largo
    for c, g in capas:
        for i, v in enumerate(c):
            out[i] += v * g
    return out


def desplazar(x, seg):
    return [0.0] * n(seg) + x


def fade(x, fin=0.01):
    k = min(len(x), n(fin))
    for i in range(k):
        x[len(x) - 1 - i] *= i / k
    return x


def normalizar(x, pico=0.89):
    m = max((abs(v) for v in x), default=1.0) or 1.0
    return [v / m * pico for v in x]


def guardar(nombre, x, pico=0.89):
    x = normalizar(fade(list(x)), pico)
    ruta = os.path.join(SALIDA, nombre + ".wav")
    with wave.open(ruta, "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes(b"".join(struct.pack("<h", int(max(-1, min(1, v)) * 32767)) for v in x))
    print("  ", nombre)


# ---------------------------------------------------------------- recetas
def golpe_seco(seg, f0, f1, caida, rng, cuerpo=1.0, crujido=0.0, crujido_banda=(1800, 6000)):
    largo = n(seg)
    thump = mul(tono(seg, f0, f1), env(largo, 0.002, caida))
    capas = [(thump, cuerpo)]
    if crujido > 0:
        cr = mul(banda(ruido(seg, rng), *crujido_banda), env(largo, 0.001, caida * 0.6))
        capas.append((cr, crujido))
    return mezclar(*capas)


def whoosh(seg, f_ini, f_fin, rng, pico_en=0.4):
    largo = n(seg)
    cortes = [f_ini * (f_fin / f_ini) ** (i / largo) for i in range(largo)]
    base = pasabajos_var(pasaaltos(ruido(seg, rng), 150), cortes)
    forma = [math.sin(math.pi * min(1.0, (i / largo) / pico_en) * 0.5) ** 2 * (1 - i / largo) ** 1.5
             for i in range(largo)]
    return mul(base, forma)


def hojas(seg, rng, densidad=0.004, brillo=2600):
    """Crujido de hojas/pasto: ráfaga de microclicks filtrados."""
    largo = n(seg)
    x = [0.0] * largo
    i = 0
    while i < largo:
        i += int(rng.expovariate(1.0 / (densidad * SR))) + 1
        k = n(rng.uniform(0.002, 0.008))
        amp = rng.uniform(0.3, 1.0)
        for j in range(k):
            if i + j < largo:
                x[i + j] += rng.uniform(-1, 1) * amp * (1 - j / k)
    return banda(x, brillo * 0.6, brillo * 2.4)


def acorde(seg, frecs, ataque, caida, rng=None, brillo=0.0):
    largo = n(seg)
    capas = []
    for k, f in enumerate(frecs):
        t = mezclar((tono(seg, f), 1.0), (tono(seg, f * 2.0), 0.25), (tono(seg, f * 3.0), 0.08))
        capas.append((mul(t, env(largo, ataque, caida)), 1.0 / len(frecs)))
    return mezclar(*capas)


def arpegio(frecs, paso, nota, caida):
    capas = []
    for k, f in enumerate(frecs):
        t = mezclar((tono(nota, f), 1.0), (tono(nota, f * 2.01), 0.3))
        capas.append((desplazar(mul(t, env(n(nota), 0.003, caida)), paso * k), 1.0))
    return mezclar(*capas)


def generar():
    os.makedirs(SALIDA, exist_ok=True)
    rng = random.Random(20260927)
    print("Generando SFX en", os.path.abspath(SALIDA))

    # --- Pasos (4 variantes por forma; el juego elige al azar y varía el tono)
    for v in range(4):
        r = random.Random(100 + v)
        guardar("paso_humano_%d" % (v + 1), mezclar(
            (golpe_seco(0.14, 115 + v * 6, 60, 0.035, r, crujido=0.0), 1.0),
            (mul(hojas(0.12, r, 0.0035, 2400 + v * 150), env(n(0.12), 0.002, 0.04)), 0.9)))
        guardar("paso_lobo_%d" % (v + 1), mezclar(
            (golpe_seco(0.09, 170 + v * 8, 95, 0.02, r), 0.8),
            (mul(hojas(0.08, r, 0.005, 3200 + v * 200), env(n(0.08), 0.001, 0.025)), 0.55)))
        guardar("paso_oso_%d" % (v + 1), mezclar(
            (golpe_seco(0.38, 68 + v * 4, 34, 0.11, r), 1.0),
            (mul(pasabajos(ruido(0.3, r), 380), env(n(0.3), 0.004, 0.08)), 0.7),
            (mul(hojas(0.18, r, 0.003, 1800), env(n(0.18), 0.002, 0.06)), 0.45)))
    for v in range(3):
        r = random.Random(200 + v)
        a = mul(banda(ruido(0.22, r), 250, 1400 + v * 120), env(n(0.22), 0.025, 0.05, 0.6))
        b = mul(banda(ruido(0.16, r), 300, 1600), env(n(0.16), 0.02, 0.04, 0.6))
        guardar("aleteo_%d" % (v + 1), mezclar((a, 1.0), (desplazar(b, 0.11), 0.6)))

    # --- Saltos y aterrizajes
    guardar("salto_humano", mezclar((whoosh(0.22, 600, 2600, rng, 0.25), 1.0),
                                    (golpe_seco(0.08, 140, 80, 0.02, rng), 0.35)))
    guardar("salto_lobo", mezclar((whoosh(0.16, 900, 3600, rng, 0.2), 1.0),
                                  (golpe_seco(0.06, 190, 110, 0.015, rng), 0.3)))
    guardar("salto_oso", mezclar((whoosh(0.3, 300, 1400, rng, 0.3), 1.0),
                                 (golpe_seco(0.16, 80, 45, 0.05, rng), 0.6)))
    guardar("doble_salto", mezclar((whoosh(0.28, 1200, 5200, rng, 0.2), 0.9),
                                   (mul(tono(0.28, 520, 1040, "tri"), env(n(0.28), 0.01, 0.09)), 0.35),
                                   (mul(tono(0.28, 780, 1560), env(n(0.28), 0.02, 0.08)), 0.2)))
    guardar("aterrizaje_suave", mezclar((golpe_seco(0.2, 110, 50, 0.05, rng), 1.0),
                                        (mul(hojas(0.18, rng, 0.0025, 2000), env(n(0.18), 0.002, 0.06)), 0.8)))
    guardar("aterrizaje_fuerte", mezclar((golpe_seco(0.5, 85, 32, 0.14, rng), 1.0),
                                         (mul(pasabajos(ruido(0.45, rng), 500), env(n(0.45), 0.003, 0.12)), 0.8),
                                         (mul(hojas(0.3, rng, 0.0018, 1700), env(n(0.3), 0.002, 0.09)), 0.6)))
    guardar("derrape", mul(mezclar((pasabajos(pasaaltos(ruido(0.35, rng), 300), 2200), 1.0),
                                   (hojas(0.35, rng, 0.002, 2000), 0.6)),
                           env(n(0.35), 0.03, 0.12, 0.7)))

    # --- Liana
    guardar("liana_agarrar", mezclar((mul(hojas(0.25, rng, 0.0015, 2600), env(n(0.25), 0.002, 0.08)), 1.0),
                                     (golpe_seco(0.12, 160, 90, 0.03, rng), 0.5)))
    for v in range(3):
        r = random.Random(300 + v)
        guardar("liana_trepar_%d" % (v + 1), mul(hojas(0.14, r, 0.003, 2300 + v * 200), env(n(0.14), 0.004, 0.05)))
    # Loop continuo (1.2 s): fricción de hojas/soga, sin fundidos para que empalme.
    r = random.Random(400)
    base = mezclar((banda(ruido(1.2, r), 700, 3200), 0.7), (hojas(1.2, r, 0.0012, 2500), 0.8))
    mod = [0.75 + 0.25 * math.sin(2 * math.pi * 3.0 * i / SR) for i in range(len(base))]
    loop = normalizar(mul(base, mod), 0.7)
    cruce = n(0.08)  # fundido cruzado del final con el principio → loop sin click
    for i in range(cruce):
        t = i / cruce
        loop[i] = loop[i] * t + loop[len(loop) - cruce + i] * (1 - t)
    loop = loop[:len(loop) - cruce]
    ruta = os.path.join(SALIDA, "liana_deslizar_loop.wav")
    with wave.open(ruta, "wb") as w:
        w.setnchannels(1); w.setsampwidth(2); w.setframerate(SR)
        w.writeframes(b"".join(struct.pack("<h", int(v * 32767)) for v in loop))
    print("   liana_deslizar_loop")
    guardar("liana_soltar", mezclar((mul(hojas(0.2, rng, 0.002, 2800), env(n(0.2), 0.002, 0.06)), 0.9),
                                    (whoosh(0.2, 800, 3000, rng, 0.2), 0.6)))

    # --- Combate
    for v in range(3):
        r = random.Random(500 + v)
        guardar("swing_%d" % (v + 1), whoosh(0.17, 700 + v * 150, 4200 + v * 300, r, 0.35))
    guardar("swing_pesado", mezclar((whoosh(0.3, 350, 2600, rng, 0.4), 1.0),
                                    (mul(pasabajos(ruido(0.3, rng), 300), env(n(0.3), 0.08, 0.1)), 0.5)))
    guardar("dano_jugador", mezclar((golpe_seco(0.25, 150, 60, 0.06, rng, crujido=0.5, crujido_banda=(900, 3500)), 1.0),
                                    (mul(tono(0.22, 330, 190, "tri"), env(n(0.22), 0.005, 0.07)), 0.4)))
    guardar("bloqueo", mezclar((mul(mezclar((tono(0.3, 820), 1.0), (tono(0.3, 1370), 0.6), (tono(0.3, 2260), 0.3)),
                                    env(n(0.3), 0.001, 0.07)), 0.7),
                               (mul(pasaaltos(ruido(0.05, rng), 2500), env(n(0.05), 0.0005, 0.01)), 0.8),
                               (golpe_seco(0.12, 200, 120, 0.03, rng), 0.5)))
    guardar("proyectil_disparo", mezclar((mul(tono(0.2, 620, 1500, "tri"), env(n(0.2), 0.004, 0.06)), 0.8),
                                         (mul(tono(0.2, 1240, 3000), env(n(0.2), 0.004, 0.04)), 0.3),
                                         (whoosh(0.2, 1500, 5000, rng, 0.15), 0.5)))
    guardar("proyectil_impacto", mezclar((mul(tono(0.14, 900, 180), env(n(0.14), 0.001, 0.035)), 0.8),
                                         (mul(banda(ruido(0.12, rng), 800, 5000), env(n(0.12), 0.001, 0.03)), 0.7)))
    guardar("enemigo_muerte", mezclar((mul(tono(0.6, 420, 70, "tri"), env(n(0.6), 0.005, 0.2)), 0.7),
                                      (mul(banda(ruido(0.6, rng), 300, 2400), env(n(0.6), 0.03, 0.18)), 0.6),
                                      (golpe_seco(0.25, 120, 50, 0.08, rng), 0.6)))
    guardar("arquero_disparo", mezclar((mul(cuerda(0.35, 196, rng, 0.45), env(n(0.35), 0.001, 0.09)), 0.8),
                                       (desplazar(whoosh(0.2, 1500, 5000, rng, 0.15), 0.02), 0.6)))
    guardar("muerte_jugador", mezclar((golpe_seco(0.9, 70, 28, 0.3, rng), 1.0),
                                      (mul(tono(0.9, 520, 110, "tri"), env(n(0.9), 0.01, 0.3)), 0.45),
                                      (mul(banda(ruido(0.9, rng), 200, 1500), env(n(0.9), 0.05, 0.3)), 0.4)))

    # --- Formas / energía
    guardar("transformacion_bloqueada", mezclar(
        (mul(pasabajos(tono(0.12, 190, 170, "cuadrada"), 1400), env(n(0.12), 0.003, 0.04)), 1.0),
        (desplazar(mul(pasabajos(tono(0.14, 150, 130, "cuadrada"), 1200), env(n(0.14), 0.003, 0.05)), 0.12), 1.0)), 0.6)
    guardar("energia_agotada", arpegio([587, 440, 294], 0.13, 0.35, 0.12), 0.7)
    guardar("energia_baja", mezclar((mul(tono(0.1, 880), env(n(0.1), 0.004, 0.03)), 1.0),
                                    (desplazar(mul(tono(0.1, 880), env(n(0.1), 0.004, 0.03)), 0.16), 1.0)), 0.45)

    # --- Mundo
    # Estilo "místico grave" (pedido del usuario: nada de tintineos alegres, seco y
    # tenso): soplos/respiraciones, zumbido grave del espíritu con batido y notas
    # menores apagadas con cola corta, todo por debajo de ~1 kHz.
    ruido(0.3, rng)  # conserva el estado del rng compartido (la receta vieja lo consumía)
    r = random.Random(701)
    inhala = mul(banda(ruido(0.42, r), 300, 1500), env(n(0.42), 0.26, 0.06, 2.0))
    zumbido = mul(mezclar((tono(0.24, 110.0), 1.0), (tono(0.24, 112.5), 0.9), (tono(0.24, 155.6, None, "tri"), 0.35)),
                  env(n(0.24), 0.012, 0.07))
    guardar("pickup", pasabajos(mezclar((inhala, 0.7), (desplazar(zumbido, 0.2), 1.0)), 900), 0.7)
    r = random.Random(702)
    L = n(1.2)
    zumbido = mul(mezclar((tono(1.2, 73.4), 1.0), (tono(1.2, 74.2), 0.8), (tono(1.2, 110.0), 0.6), (tono(1.2, 110.9), 0.5)),
                  env(L, 0.35, 0.3, 1.5))
    soplo = mul(banda(ruido(1.2, r), 250, 1200), env(L, 0.4, 0.35, 1.5))
    diada = mul(mezclar((tono(1.2, 146.8, None, "tri"), 1.0), (tono(1.2, 174.6, None, "tri"), 0.8)), env(L, 0.25, 0.35, 1.5))
    guardar("checkpoint", pasabajos(mezclar((zumbido, 1.0), (soplo, 0.35), (diada, 0.45)), 1100), 0.75)
    guardar("rompible_golpe", mezclar((mul(mezclar((tono(0.2, 230), 1.0), (tono(0.2, 370), 0.6), (tono(0.2, 610), 0.3)),
                                           env(n(0.2), 0.001, 0.045)), 1.0),
                                      (mul(banda(ruido(0.05, rng), 1500, 6000), env(n(0.05), 0.0005, 0.01)), 0.6)))
    crash = [0.0] * n(0.55)
    for k in range(7):
        r = random.Random(600 + k)
        f = r.uniform(180, 520)
        g = mul(mezclar((tono(0.2, f), 1.0), (tono(0.2, f * 1.6), 0.5)), env(n(0.2), 0.001, 0.04))
        crash = mezclar((crash, 1.0), (desplazar(g, r.uniform(0.0, 0.18)), r.uniform(0.3, 0.8)))
    guardar("rompible_romper", mezclar((crash, 1.0),
                                       (mul(banda(ruido(0.55, rng), 400, 5000), env(n(0.55), 0.002, 0.12)), 0.8)))
    chirrido = mul(banda(ruido(0.5, rng), 500, 900), [0.5 + 0.5 * math.sin(2 * math.pi * 23 * i / SR) for i in range(n(0.5))])
    guardar("fragil_crujir", mul(chirrido, env(n(0.5), 0.05, 0.2, 0.7)), 0.6)
    grava = hojas(0.7, rng, 0.0015, 900)
    guardar("fragil_romper", mezclar((mul(grava, env(n(0.7), 0.003, 0.2)), 1.0),
                                     (golpe_seco(0.4, 90, 40, 0.12, rng), 0.8),
                                     (mul(pasabajos(ruido(0.6, rng), 600), env(n(0.6), 0.005, 0.18)), 0.6)))
    guardar("pinchos", mezclar((mul(pasaaltos(ruido(0.06, rng), 3000), env(n(0.06), 0.0005, 0.012)), 1.0),
                               (mul(mezclar((tono(0.18, 1850), 1.0), (tono(0.18, 2930), 0.5)), env(n(0.18), 0.001, 0.05)), 0.4)))
    guardar("arena_inicio", mezclar((golpe_seco(0.7, 75, 40, 0.2, rng), 1.0),
                                    (mul(tono(0.7, 110, 220, "tri"), env(n(0.7), 0.25, 0.2, 2.0)), 0.5),
                                    (mul(pasabajos(ruido(0.7, rng), 250), env(n(0.7), 0.3, 0.2, 2.0)), 0.4)))
    r = random.Random(703)
    L = n(0.9)
    exhala = mul(pasabajos_var(pasaaltos(ruido(0.9, r), 120), [1800.0 * (250.0 / 1800.0) ** (i / L) for i in range(L)]),
                 env(L, 0.04, 0.3))
    diada = mul(mezclar((tono(0.9, 110.0, None, "tri"), 1.0), (tono(0.9, 130.8, None, "tri"), 0.8), (tono(0.9, 111.0), 0.4)),
                env(L, 0.08, 0.28))
    guardar("zona_despejada", pasabajos(mezclar((exhala, 0.5), (golpe_seco(0.5, 70, 38, 0.12, r), 0.9), (diada, 0.55)), 1000), 0.75)
    r = random.Random(704)
    L = n(1.3)
    respira = mul(pasabajos_var(banda(ruido(1.3, r), 200, 2000), [300.0 * (1400.0 / 300.0) ** (i / L) for i in range(L)]),
                  env(L, 0.5, 0.35, 1.6))
    triada = mul(mezclar((tono(1.3, 110.0, None, "tri"), 1.0), (tono(1.3, 130.8, None, "tri"), 0.8), (tono(1.3, 164.8, None, "tri"), 0.7)),
                 env(L, 0.4, 0.4, 1.8))
    brillo = mul(mezclar((tono(1.3, 440.0), 1.0), (tono(1.3, 443.5), 1.0)), env(L, 0.5, 0.3, 2.0))
    grave = mul(mezclar((tono(1.3, 55.0), 1.0), (tono(1.3, 55.6), 0.8)), env(L, 0.4, 0.4, 1.5))
    guardar("nivel_subido", pasabajos(mezclar((respira, 0.4), (triada, 0.6), (brillo, 0.06), (grave, 0.6)), 1300), 0.8)

    # --- Interfaz
    guardar("ui_mover", mul(tono(0.05, 1500, 1400), env(n(0.05), 0.001, 0.012)), 0.4)
    guardar("ui_confirmar", arpegio([880, 1320], 0.06, 0.18, 0.05), 0.55)
    guardar("ui_pausa", mezclar((mul(tono(0.35, 440, 330, "tri"), env(n(0.35), 0.01, 0.1)), 1.0),
                                (whoosh(0.3, 400, 1600, rng, 0.3), 0.4)), 0.5)
    # Tecla del diálogo: mismo "blip" triangular, más presente y con un poco de cuerpo.
    guardar("dialogo_tecla", mul(mezclar((tono(0.045, 1100, 950, "tri"), 1.0), (tono(0.045, 560, 520), 0.5)),
                                 env(n(0.045), 0.001, 0.012)), 0.75)


if __name__ == "__main__":
    generar()
