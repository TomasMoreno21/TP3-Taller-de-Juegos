"""Genera las capas PNG del fondo del nivel 2 (cueva natural).

Mismo lenguaje que Sprites/Fondos/Bosque: siluetas GRANDES y PLANAS de 2-3 tonos de gris
(luz / sombra / filo), sin ruido. El color lo pone la "Noche" del nivel (CanvasModulate) y el
modulate por acto (scripts/fondo_actos.gd), igual que el bosque.

Cada capa mide 3840x1600 y repite sin costura en horizontal (motion_mirroring).
Se dibuja a 2x y se reduce para suavizar los bordes.

Uso:  python tools/generar_fondo_cueva.py          (escribe en Sprites/Fondos/Cueva2/)
"""
import math
import os
import random

import numpy as np
from PIL import Image, ImageChops, ImageDraw, ImageOps

W, H, S = 3840, 1600, 2   # alto 1600: el fondo se escala con el zoom de la cámara (hasta ~0.7) y no puede dejar franja negra abajo
SALIDA = os.path.join(os.path.dirname(__file__), "..", "Sprites", "Fondos", "Cueva2")


# ---------------------------------------------------------------- utilidades
def gris(v, a=255):
    v = max(0.0, min(1.0, v))
    c = int(round(v * 255))
    return (c, c, c, a)


class Lienzo:
    def __init__(self, fondo=(0, 0, 0, 0)):
        self.img = Image.new("RGBA", (W * S, H * S), fondo)

    def capa(self):
        return Image.new("RGBA", (W * S, H * S), (0, 0, 0, 0))

    def pegar(self, capa):
        self.img = Image.alpha_composite(self.img, capa)

    def guardar(self, nombre):
        os.makedirs(SALIDA, exist_ok=True)
        out = self.img.resize((W, H), Image.LANCZOS)
        out.save(os.path.join(SALIDA, nombre), optimize=True)
        print("ok", nombre)


def ruido(rng, n=3):
    """Función suave 1D en [-1, 1] (suma de senos con fases al azar)."""
    comp = [(rng.uniform(0.6, 3.2) * (i + 1), rng.uniform(0, math.tau), 1.0 / (i + 1)) for i in range(n)]
    norm = sum(c[2] for c in comp)

    def f(t):
        return sum(math.sin(t * fr + ph) * am for fr, ph, am in comp) / norm

    return f


def envolver(dibujar):
    """Ejecuta `dibujar(dx)` 3 veces (-W, 0, +W) para que el borde cierre sin costura."""
    for dx in (-W, 0, W):
        dibujar(dx)


def P(x, y):
    return (x * S, y * S)


def poligono(d, pts, color):
    d.polygon([P(x, y) for x, y in pts], fill=color)


def linea(d, pts, color, ancho):
    d.line([P(x, y) for x, y in pts], fill=color, width=int(ancho * S), joint="curve")


def recortar_mitad(capa, x_corte, lado_derecho=True):
    """Deja solo un lado (derecho o izquierdo) de la capa respecto a x_corte (px 1x)."""
    m = Image.new("L", capa.size, 0)
    dm = ImageDraw.Draw(m)
    if lado_derecho:
        dm.rectangle([x_corte * S, 0, W * S * 2, H * S], fill=255)
    else:
        dm.rectangle([-W * S, 0, x_corte * S, H * S], fill=255)
    out = capa.copy()
    out.putalpha(ImageChops.multiply(capa.getchannel("A"), m))
    return out



def resplandor(lienzo, cx, cy, r, v=0.6, a=0.7):
    """Mancha de luz suave (radial) de valor `v` y opacidad máxima `a`. Se repite en los bordes."""
    for dx in (-W, 0, W):
        x0, x1 = int((cx + dx - r) * S), int((cx + dx + r) * S)
        y0, y1 = int((cy - r) * S), int((cy + r) * S)
        cx0, cx1 = max(x0, 0), min(x1, W * S)
        cy0, cy1 = max(y0, 0), min(y1, H * S)
        if cx0 >= cx1 or cy0 >= cy1:
            continue
        ys, xs = np.mgrid[cy0:cy1, cx0:cx1]
        d = np.sqrt((xs - (cx + dx) * S) ** 2 + (ys - cy * S) ** 2) / (r * S)
        alfa = np.clip(1.0 - d, 0.0, 1.0) ** 2 * a
        parche = np.zeros((cy1 - cy0, cx1 - cx0, 4), dtype=np.uint8)
        parche[..., :3] = int(v * 255)
        parche[..., 3] = (alfa * 255).astype(np.uint8)
        capa = lienzo.capa()
        capa.paste(Image.fromarray(parche, "RGBA"), (cx0, cy0))
        lienzo.pegar(capa)


# ---------------------------------------------------------------- formas
def contorno_vertical(rng, x, y0, y1, ancho_fn, deriva=0.0, n=40):
    """Lista de puntos (izq, der) de una forma vertical: ancho_fn(t) -> medio ancho."""
    izq, der = [], []
    for i in range(n + 1):
        t = i / n
        y = y0 + (y1 - y0) * t
        cx = x + deriva * t
        hw = ancho_fn(t)
        izq.append((cx - hw, y))
        der.append((cx + hw, y))
    return izq, der


def estalactita(lienzo, rng, x, largo, ancho, tonos, y_techo=-40):
    claro, medio, oscuro = tonos
    n1, n2 = ruido(rng), ruido(rng)
    deriva = rng.uniform(-0.06, 0.06) * largo
    punta = rng.uniform(0.85, 1.25)

    def ancho_fn(t):
        base = ancho * 0.5 * (1.0 - t) ** punta
        return max(1.0, base * (1.0 + 0.10 * n1(t * 6.0)) * (1.0 + 0.55 * math.exp(-t * 9.0)))

    def forma(d, color, dx=0):
        izq, der = contorno_vertical(rng_fijo(x, largo), x + dx, y_techo, y_techo + largo, ancho_fn, deriva)
        poligono(d, izq + der[::-1], color)

    def un_dibujo(dx):
        con_sombra_x(lienzo, forma, dx, x + dx + deriva * 0.5, claro, medio, oscuro)

    envolver(un_dibujo)
    # gota brillante en la punta
    return


def rng_fijo(*vals):
    return random.Random(hash(tuple(round(v) for v in vals)) & 0xFFFFFFFF)


def con_sombra_x(lienzo, forma, dx, x_corte, claro, medio, oscuro):
    base = lienzo.capa()
    forma(ImageDraw.Draw(base), medio, dx)
    lienzo.pegar(base)
    if oscuro is not None:
        s = lienzo.capa()
        forma(ImageDraw.Draw(s), oscuro, dx)
        lienzo.pegar(recortar_mitad(s, x_corte, True))
    if claro is not None:
        l = lienzo.capa()
        forma(ImageDraw.Draw(l), claro, dx)
        # filo: solo una franja estrecha a la izquierda del eje
        franja = l.copy()
        m = Image.new("L", l.size, 0)
        dm = ImageDraw.Draw(m)
        dm.rectangle([(x_corte - 70) * S, 0, (x_corte - 38) * S, H * S], fill=255)
        franja.putalpha(ImageChops.multiply(l.getchannel("A"), m))
        lienzo.pegar(franja)


def columna_natural(lienzo, rng, x, y_techo, y_piso, ancho, tonos, ensancha=1.0):
    """Columna de roca (estalactita + estalagmita fusionadas): cintura fina, bases anchas."""
    claro, medio, oscuro = tonos
    n1 = ruido(rng)
    deriva = rng.uniform(-30, 30)

    def ancho_fn(t):
        cintura = 1.0 - 0.38 * math.sin(math.pi * t)
        flare = 1.0 + 0.9 * math.exp(-t * 10.0) + 1.3 * math.exp(-(1.0 - t) * 9.0)
        return ancho * 0.5 * cintura * flare * ensancha * (1.0 + 0.07 * n1(t * 7.0))

    def forma(d, color, dx=0):
        izq, der = contorno_vertical(None, x + dx, y_techo, y_piso, ancho_fn, deriva)
        poligono(d, izq + der[::-1], color)

    envolver(lambda dx: con_sombra_x(lienzo, forma, dx, x + dx + deriva * 0.5, claro, medio, oscuro))











# ---------------------------------------------------------------- capas
def tonos_lejanos(v):
    return (gris(v + 0.09), gris(v), gris(v - 0.09))


def capa_pared():
    rng = random.Random(11)
    L = Lienzo((0, 0, 0, 255))
    px = L.img.load()
    # degradé vertical: techo oscuro, resplandor al medio, piso oscuro
    base = Image.new("RGBA", (W * S, H * S))
    d = ImageDraw.Draw(base)
    for y in range(0, H * S, 2):
        t = y / (H * S)
        v = 0.19 + 0.20 * math.exp(-((t - 0.5) / 0.28) ** 2) - 0.06 * (t > 0.9)
        d.line([(0, y), (W * S, y)], fill=gris(v), width=2)
    L.img = base
    # manchas grandes de roca (2 tonos): periodo entero en W
    for i in range(46):
        cx = rng.uniform(0, W)
        cy = rng.uniform(0.12, 0.92) * H
        rx, ry = rng.uniform(260, 700), rng.uniform(90, 260)
        capa = L.capa()
        dc = ImageDraw.Draw(capa)
        v = rng.choice([0.17, 0.2, 0.28, 0.33])

        def uno(dx, cx=cx, cy=cy, rx=rx, ry=ry, v=v):
            pts = []
            f = ruido(rng_fijo(cx, cy))
            for k in range(36):
                a = math.tau * k / 36
                r = 1.0 + 0.16 * f(a * 2.0)
                pts.append((cx + dx + math.cos(a) * rx * r, cy + math.sin(a) * ry * r))
            poligono(dc, pts, gris(v, 150))

        envolver(uno)
        L.pegar(capa)
    # estratos horizontales finos
    for i in range(0):
        y = rng.uniform(0.1, 0.9) * H
        capa = L.capa()
        dc = ImageDraw.Draw(capa)
        k = rng.choice([2, 3, 4])
        pts = [(x, y + 24 * math.sin(x / W * math.tau * k + i)) for x in range(0, W + 80, 80)]
        linea(dc, pts, gris(0.10, 110), rng.uniform(5, 12))
        L.pegar(capa)
    for cx, cy, r in ((500, 520, 700), (1700, 620, 620), (2900, 500, 760), (3500, 700, 520)):
        resplandor(L, cx, cy, r, 0.55, 0.30)
    return L


def capa_estalactitas_lejanas(v=0.36, n=17, semilla=21, largo=(330, 640), ancho=(120, 240)):
    rng = random.Random(semilla)
    L = Lienzo()
    xs = [(i + rng.uniform(0.15, 0.85)) * W / n for i in range(n)]
    for x in xs:
        estalactita(L, rng, x, rng.uniform(*largo), rng.uniform(*ancho), tonos_lejanos(v))
    return L


def capa_columnas_naturales(v=0.30, n=7, semilla=31):
    rng = random.Random(semilla)
    L = Lienzo()
    for i in range(n):
        x = (i + rng.uniform(0.2, 0.8)) * W / n
        columna_natural(L, rng, x, -60, H + 60, rng.uniform(170, 260), tonos_lejanos(v))
    return L


def capa_estalactitas_cercanas(v=0.17, semilla=41):
    rng = random.Random(semilla)
    L = Lienzo()
    n = 10
    for i in range(n):
        x = (i + rng.uniform(0.2, 0.8)) * W / n
        estalactita(L, rng, x, rng.uniform(280, 560), rng.uniform(140, 260), tonos_lejanos(v))
    # estalagmitas: se dibujan como estalactitas y se voltean
    inv = Lienzo()
    for i in range(9):
        x = (i + rng.uniform(0.2, 0.8)) * W / 9
        estalactita(inv, rng, x, rng.uniform(520, 820), rng.uniform(150, 260), tonos_lejanos(v))
    L.img = Image.alpha_composite(L.img, ImageOps.flip(inv.img))
    return L







def capa_estalagmitas_lejanas(v=0.34, n=11, semilla=27):
    """Estalagmitas lejanas: estalactitas dibujadas al revés."""
    rng = random.Random(semilla)
    inv = Lienzo()
    for i in range(n):
        x = (i + rng.uniform(0.2, 0.8)) * W / n
        estalactita(inv, rng, x, rng.uniform(560, 1000), rng.uniform(170, 300), tonos_lejanos(v))
    L = Lienzo()
    L.img = ImageOps.flip(inv.img)
    return L


def main():
    capa_pared().guardar("pared.png")
    capa_estalactitas_lejanas(0.42, 17, 21).guardar("lejanas.png")
    capa_estalagmitas_lejanas().guardar("lejanas_piso.png")
    capa_columnas_naturales(0.31, 7, 31).guardar("columnas_a.png")
    capa_estalactitas_lejanas(0.25, 11, 23, (420, 760), (170, 300)).guardar("medias.png")
    capa_columnas_naturales(0.21, 5, 33).guardar("columnas_b.png")
    capa_estalactitas_cercanas(0.15, 41).guardar("cercanas.png")


if __name__ == "__main__":
    main()
