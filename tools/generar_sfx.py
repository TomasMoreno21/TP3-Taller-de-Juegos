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
    # Capa de impacto del jugador (se suma al mp3): liviano = seco y crujiente, pesado = sub grave + crujido + cola.
    # RNG propio para no mover el resto de sonidos.
    for v in range(3):
        r = random.Random(600 + v)
        guardar("impacto_liviano_%d" % (v + 1), mezclar(
            (golpe_seco(0.16, 210 + v * 15, 95, 0.04, r, crujido=0.8, crujido_banda=(1500, 5500)), 1.0),
            (mul(pasaaltos(ruido(0.03, r), 3000), env(n(0.03), 0.0005, 0.008)), 0.6)))
    for v in range(2):
        r = random.Random(700 + v)
        guardar("impacto_pesado_%d" % (v + 1), mezclar(
            (golpe_seco(0.5, 100 + v * 8, 36, 0.15, r), 1.0),
            (mul(banda(ruido(0.25, r), 250, 2800), env(n(0.25), 0.001, 0.07)), 0.9),
            (mul(pasaaltos(ruido(0.04, r), 2500), env(n(0.04), 0.0005, 0.01)), 0.7),
            (mul(pasabajos(ruido(0.45, r), 420), env(n(0.45), 0.005, 0.14)), 0.6)))
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
    # Atmósfera (la maneja Ambiente.gd): latido lub/dub con poca vida y drone de tensión en loop.
    r = random.Random(810)
    guardar("latido_lub", mezclar((golpe_seco(0.22, 70, 38, 0.07, r), 1.0),
                                  (mul(pasabajos(ruido(0.12, r), 220), env(n(0.12), 0.003, 0.03)), 0.5)), 0.9)
    guardar("latido_dub", mezclar((golpe_seco(0.18, 58, 34, 0.06, r), 1.0),
                                  (mul(pasabajos(ruido(0.1, r), 180), env(n(0.1), 0.003, 0.025)), 0.4)), 0.7)
    r = random.Random(811)
    L = n(6.0)
    # Frecuencias con ciclos enteros en 6 s y modulación lenta → empalma sin click; roce de viento grave encima.
    drone = mezclar((tono(6.0, 55.0), 1.0), (tono(6.0, 55.5), 0.8), (tono(6.0, 82.5, None, "tri"), 0.35),
                    (tono(6.0, 116.5, None, "tri"), 0.18))   # 116.5 ≈ tritono sobre 82.5: inquieta
    moda = [0.7 + 0.3 * math.sin(2 * math.pi * i / L) for i in range(L)]
    viento = pasabajos_var(banda(ruido(6.0, r), 80, 900), [250.0 + 200.0 * math.sin(2 * math.pi * i / L) for i in range(L)])
    loop = normalizar(mul(mezclar((drone, 0.8), (viento, 0.5)), moda), 0.7)
    cruce = n(0.25)
    for i in range(cruce):
        t = i / cruce
        loop[i] = loop[i] * t + loop[len(loop) - cruce + i] * (1 - t)
    loop = loop[:len(loop) - cruce]
    with wave.open(os.path.join(SALIDA, "tension_loop.wav"), "wb") as w:
        w.setnchannels(1); w.setsampwidth(2); w.setframerate(SR)
        w.writeframes(b"".join(struct.pack("<h", int(v * 32767)) for v in loop))
    print("   tension_loop")
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
    guardar("ui_mover", mul(mezclar((tono(0.11, 380, 300, "tri"), 1.0), (tono(0.11, 760, 600), 0.4)), env(n(0.11), 0.001, 0.035)), 0.8)
    guardar("ui_confirmar", arpegio([880, 1320], 0.06, 0.18, 0.05), 0.55)
    guardar("ui_pausa", mezclar((mul(tono(0.35, 440, 330, "tri"), env(n(0.35), 0.01, 0.1)), 1.0),
                                (whoosh(0.3, 400, 1600, rng, 0.3), 0.4)), 0.5)
    # Tecla del diálogo: mismo "blip" triangular, más presente y con un poco de cuerpo.
    guardar("dialogo_tecla", mul(mezclar((tono(0.045, 1100, 950, "tri"), 1.0), (tono(0.045, 560, 520), 0.5)),
                                 env(n(0.045), 0.001, 0.012)), 0.75)

    generar_jefe()


def generar_jefe():
    """Jefe final: grito de aparición y rebote de coraza (golpe que no es del Oso). Semilla propia."""
    r = random.Random(4242)
    largo = 2.6
    # Rugido grave: armónicos de una fundamental que baja 72→52 Hz, con aspereza (AM por ruido lento).
    base = [0.0] * n(largo)
    for k in range(1, 9):
        for i, v in enumerate(tono(largo, 72 * k, 52 * k, "tri" if k == 1 else "seno")):
            base[i] += v / k
    aspereza = [0.55 + 0.45 * abs(v) * 6 for v in pasabajos(ruido(largo, r), 35)]
    rugido = mul(mul(base, aspereza), env(n(largo), 0.15, 0.9))
    # Chillido: dos voces que suben (formantes ásperos), desde 0.25 s, con ruido de garganta.
    voz = mezclar((tono(1.9, 520, 900, "tri"), 1.0), (tono(1.9, 790, 1380), 0.6))
    garganta = banda(ruido(1.9, r), 900, 2600)
    chillido = pasabajos(mul(mezclar((voz, 1.0), (garganta, 0.5)), env(n(1.9), 0.3, 0.45, 1.5)), 3000)
    retumbe = mul(pasabajos(ruido(largo, r), 120), env(n(largo), 0.4, 1.0, 2.0))
    guardar("jefe_grito", mezclar((golpe_seco(1.2, 60, 28, 0.35, r), 1.0),
                                  (rugido, 0.9),
                                  (desplazar(chillido, 0.25), 0.45),
                                  (retumbe, 0.8)), 0.9)
    # Rebote de coraza: "clonk" seco de piedra.
    guardar("rebote_coraza", mezclar((golpe_seco(0.25, 260, 140, 0.05, r, crujido=0.6, crujido_banda=(1500, 4000)), 1.0),
                                     (mul(tono(0.2, 410), env(n(0.2), 0.001, 0.04)), 0.4)), 0.7)


def crujido_piedra(seg, rng, densidad=0.006, lo=500, hi=2600):
    """Crujido de piedra: ráfaga irregular de chasquidos graves filtrados."""
    largo = n(seg)
    x = [0.0] * largo
    i = 0
    while i < largo:
        if rng.random() < densidad:
            amp = rng.uniform(0.3, 1.0)
            for k in range(min(n(0.012), largo - i)):
                x[i + k] += amp * rng.uniform(-1, 1) * math.exp(-k / n(0.003))
        i += 1
    return banda(x, lo, hi)


def guardar_jefe(nombre, x, _pico=None, rms_obj=-15.0, pico_max=0.7):
    """Como `guardar`, pero iguala la sonoridad (RMS de la ventana de 100 ms más fuerte) con el resto
    de los SFX del juego y corta el subgrave (< 40 Hz): antes saturaban al superponerse."""
    x = pasaaltos(fade(list(x)), 40)
    v = 4410
    mejor = max((sum(a * a for a in x[k:k + v]) / v for k in range(0, max(len(x) - v, 1), v // 2)), default=1e-9)
    rms = math.sqrt(mejor) or 1e-9
    g = (10 ** (rms_obj / 20.0)) / rms
    pico = max(abs(a) for a in x) * g
    if pico > pico_max:
        g *= pico_max / pico
    x = [a * g for a in x]
    ruta = os.path.join(SALIDA, nombre + ".wav")
    with wave.open(ruta, "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes(b"".join(struct.pack("<h", int(max(-1, min(1, a)) * 32767)) for a in x))
    print("  ", nombre)


def chisporroteo(seg, rng, d0, d1, lo, hi):
    """Chispas eléctricas: chasquidos muy cortos cuya densidad crece de `d0` a `d1` (prob. por muestra)."""
    largo = n(seg)
    x = [0.0] * largo
    for i in range(largo):
        if rng.random() < d0 + (d1 - d0) * (i / largo) ** 2:
            amp = rng.uniform(0.4, 1.0)
            for k in range(min(n(0.004), largo - i)):
                x[i + k] += amp * rng.uniform(-1, 1) * math.exp(-k / n(0.0008))
    return banda(x, lo, hi)


def trueno(seg, rng, retumbe=0.3, chispas=0.3, rodar=False):
    """Rayo de tormenta: chasquido de banda ancha (5 ms) + cola de chispas + retumbe grave."""
    largo = n(seg)
    chasquido = mul(pasaaltos(ruido(seg, rng), 300), env(largo, 0.0005, 0.004))
    cola = mul(chisporroteo(seg, rng, 0.008, 0.0, 1500, 7000), env(largo, 0.001, chispas))
    grave = pasabajos(ruido(seg, rng), 150)
    if rodar:   # el trueno "rueda": ondulación lenta de la intensidad
        grave = mul(grave, [0.55 + 0.45 * math.sin(2 * math.pi * 3.2 * k / SR + 1.0) for k in range(largo)])
    grave = mul(grave, env(largo, 0.02, retumbe))
    return mezclar((chasquido, 1.0), (cola, 0.6), (grave, 1.6))


def generar_jefe_ataques():
    """Ataques del jefe final (secos y tensos, nada brillante). Semilla propia: no altera el resto.
    Uso suelto:  python tools/generar_sfx.py jefe_ataques"""
    r = random.Random(7310)
    # (consume el azar de las recetas viejas del rayo: así los demás sonidos quedan idénticos)
    for seg in (0.9, 0.35, 0.35, 1.4, 0.9, 0.9):
        ruido(seg, r)
    rr = random.Random(7311)
    # Rayo de los ojos: como un rayo de tormenta, no un láser (nada de tonos que suben).
    # Carga: chisporroteo eléctrico cada vez más denso sobre un zumbido grave fijo con trémolo.
    carga = mezclar((chisporroteo(0.9, rr, 0.0004, 0.006, 1800, 7000), 1.0),
                    (mul(mul(tono(0.9, 55, None, "tri"), [0.6 + 0.4 * math.sin(2 * math.pi * 11 * k / SR) for k in range(n(0.9))]),
                         env(n(0.9), 0.7, 0.1, 2.0)), 0.35))
    guardar_jefe("jefe_rayo_carga", carga)
    # Disparo: trueno seco (chasquido de banda ancha + chispas + retumbe grave corto).
    guardar_jefe("jefe_rayo_disparo", trueno(0.6, rr, retumbe=0.25, chispas=0.25))
    # Rayo grueso: misma familia, más larga, y un trueno que rueda.
    carga_g = mezclar((chisporroteo(1.4, rr, 0.0003, 0.008, 900, 6000), 1.0),
                      (mul(mul(tono(1.4, 42, None, "tri"), [0.55 + 0.45 * math.sin(2 * math.pi * 7 * k / SR) for k in range(n(1.4))]),
                           env(n(1.4), 1.2, 0.1, 2.2)), 0.5))
    guardar_jefe("jefe_rayo_grueso_carga", carga_g)
    guardar_jefe("jefe_rayo_grueso", trueno(1.4, rr, retumbe=0.8, chispas=0.5, rodar=True))
    # Lanza: silbido grave que cae y estaca que se clava en piedra.
    guardar_jefe("jefe_lanza_aviso", whoosh(0.6, 400, 1800, r, pico_en=0.9), 0.4)
    guardar_jefe("jefe_lanza_impacto", mezclar((golpe_seco(0.45, 140, 50, 0.1, r, crujido=0.8, crujido_banda=(900, 3500)), 1.0),
                                          (crujido_piedra(0.4, r, 0.004), 0.5)), 0.75)
    # Golpe al ojo: carnoso y apagado; el fuerte (cierra la ventana) más grave y largo.
    guardar_jefe("jefe_ojo_golpe", mezclar((golpe_seco(0.25, 170, 70, 0.06, r, crujido=0.35, crujido_banda=(400, 1500)), 1.0),
                                      (mul(pasabajos(ruido(0.25, r), 900), env(n(0.25), 0.001, 0.04)), 0.5)), 0.75)
    guardar_jefe("jefe_ojo_golpe_fuerte", mezclar((golpe_seco(0.7, 120, 38, 0.22, r, crujido=0.5, crujido_banda=(300, 1400)), 1.0),
                                             (mul(pasabajos(ruido(0.7, r), 400), env(n(0.7), 0.002, 0.25)), 0.7)), 0.85)
    # Cambio de fase: estallido grave + grieta de piedra + retumbe que se apaga.
    fase = mezclar((golpe_seco(2.2, 70, 26, 0.6, r), 1.0),
                   (crujido_piedra(1.4, r, 0.01, 300, 2200), 0.7),
                   (mul(pasabajos(ruido(2.2, r), 140), env(n(2.2), 0.05, 0.9)), 0.9))
    guardar_jefe("jefe_fase", fase, 0.9)
    # Embestida: carga (rumor que sube) y paso (soplo grave y pesado).
    guardar_jefe("jefe_embestida_carga", mul(mezclar((tono(0.9, 45, 110, "tri"), 1.0), (pasabajos(ruido(0.9, r), 300), 0.8)),
                                        env(n(0.9), 0.8, 0.08, 2.0)), 0.7)
    guardar_jefe("jefe_embestida", mezclar((whoosh(0.8, 200, 900, r, pico_en=0.3), 1.0),
                                      (mul(tono(0.8, 70, 40, "tri"), env(n(0.8), 0.05, 0.3)), 0.6)), 0.8)
    # Picada: impacto muy pesado contra el piso con escombros.
    guardar_jefe("jefe_picada_impacto", mezclar((golpe_seco(1.2, 85, 28, 0.35, r, crujido=0.6, crujido_banda=(600, 2500)), 1.0),
                                           (desplazar(crujido_piedra(0.8, r, 0.008), 0.05), 0.6),
                                           (mul(pasabajos(ruido(1.2, r), 160), env(n(1.2), 0.01, 0.5)), 0.7)), 0.9)
    # Estalactitas: crujido en el techo (aviso) y rotura al caer.
    guardar_jefe("jefe_estalactita_crujido", mul(crujido_piedra(1.2, r, 0.003, 400, 2000), env(n(1.2), 0.9, 0.15, 1.5)), 0.6)
    guardar_jefe("jefe_estalactita_caida", mezclar((golpe_seco(0.5, 200, 70, 0.08, r, crujido=1.0, crujido_banda=(1200, 5000)), 1.0),
                                              (crujido_piedra(0.45, r, 0.012, 800, 4000), 0.6)), 0.75)
    # Rocas que se arrancan del piso y giran: rumor de piedra.
    guardar_jefe("jefe_rocas", mezclar((crujido_piedra(0.9, r, 0.008, 300, 1800), 0.8),
                                  (mul(pasabajos(ruido(0.9, r), 200), env(n(0.9), 0.3, 0.3)), 1.0)), 0.7)
    # Ojo verde que aparece: "plop" seco y apagado (sin brillo).
    guardar_jefe("ojo_aparecer", mezclar((golpe_seco(0.18, 320, 160, 0.04, r), 1.0),
                                    (mul(pasabajos(ruido(0.18, r), 1200), env(n(0.18), 0.002, 0.03)), 0.3)), 0.5)
    # Muerte: grieta larga, estallido y derrumbe que se apaga.
    muerte = mezclar((crujido_piedra(1.0, r, 0.012, 300, 2400), 0.7),
                     (desplazar(golpe_seco(2.8, 60, 22, 0.9, r, crujido=0.4, crujido_banda=(400, 1800)), 0.8), 1.0),
                     (desplazar(mul(pasabajos(ruido(3.0, r), 180), env(n(3.0), 0.1, 1.2)), 0.8), 0.9),
                     (desplazar(crujido_piedra(2.0, r, 0.004, 500, 2600), 1.2), 0.4))
    guardar_jefe("jefe_muerte", muerte, 0.9)


if __name__ == "__main__":
    import sys
    if len(sys.argv) > 1 and sys.argv[1] == "jefe_ataques":
        generar_jefe_ataques()
    else:
        generar()
        generar_jefe_ataques()
