from PIL import Image, ImageDraw, ImageFont
import math, os, sys
R = "C:/Users/Usuario/Documents/proyecto--ben-10/"
OUT = os.path.dirname(os.path.abspath(__file__)) + "/"
T = "C:/Windows/Fonts/times.ttf"; TB = "C:/Windows/Fonts/timesbd.ttf"
BROWN = (139, 69, 19)
GREEN = (112, 173, 71); RED = (192, 80, 77)

def font(p, s): return ImageFont.truetype(p, s)

def trim(im):
    im = im.convert("RGBA"); bb = im.getbbox()
    return im.crop(bb) if bb else im

# ---- sprites recortados (fondo transparente)
SP = R + "Sprites/"
def sprite(path, name, h):
    im = trim(Image.open(path)); s = h / im.height
    im.resize((max(1, int(im.width * s)), h), Image.LANCZOS).save(OUT + name)
sprite(SP + "Jugador y Transformaciones/ccorrer1.png", "s_humano.png", 300)
sprite(SP + "Jugador y Transformaciones/1lobo quieto.png", "s_lobo.png", 200)
sprite(SP + "Jugador y Transformaciones/1oso quieto.png", "s_oso.png", 230)
sprite(SP + "Jugador y Transformaciones/1murci volar.png", "s_murci.png", 200)
sprite(SP + "Enemigos/enemigo gordo1.png", "s_cultista.png", 300)
sprite(SP + "Enemigos/enemigo flaco1.png", "s_arquero.png", 300)

# ---- fondos (miniaturas)
def thumb(path, name, w=564, h=318):
    im = Image.open(path).convert("RGB")
    s = max(w / im.width, h / im.height); im = im.resize((int(im.width * s), int(im.height * s)), Image.LANCZOS)
    l = (im.width - w) // 2; t = (im.height - h) // 2
    im.crop((l, t, l + w, t + h)).save(OUT + name)
thumb(SP + "Fondos/Bosque/1par. bosque.png", "f_bosque.png")
thumb(SP + "Fondos/Cueva2/cercanas.png", "f_cueva.png")
thumb(SP + "Fondos/Cueva2/pared.png", "f_pared.png")

# ---- banner de portada
W, H = 1600, 360
im = Image.new("RGBA", (W, H), (255, 255, 255, 0)); d = ImageDraw.Draw(im)
fo = font(TB, 150)
txt = "SPIRIT KEEPER"
tw = d.textlength(txt, font=fo)
d.text(((W - tw) / 2 + 6, 110 + 6), txt, font=fo, fill=(60, 30, 10))
d.text(((W - tw) / 2, 110), txt, font=fo, fill=BROWN)
lobo = Image.open(OUT + "s_lobo.png"); lobo = lobo.resize((int(lobo.width * 0.55), int(lobo.height * 0.55)))
mur = Image.open(OUT + "s_murci.png"); mur = mur.resize((int(mur.width * 0.7), int(mur.height * 0.7)))
im.paste(lobo, (20, 110), lobo)
mr = Image.open(OUT + "s_oso.png"); mr = mr.resize((int(mr.width * 0.5), int(mr.height * 0.5)))
im.paste(mur, (W - mur.width - 40, 110), mur)
im.save(OUT + "banner.png")

# ---- diagrama de flujo (estilo del GDD original: cajas negras, flechas verde=ir / roja=volver)
W, H = 1400, 1500
im = Image.new("RGB", (W, H), "white"); d = ImageDraw.Draw(im)
f1 = font(T, 40); f2 = font(T, 34); f3 = font(TB, 46)
def tcenter(x, y, w, h, t, f):
    lines = t.split("\n"); lh = f.size + 8; yy = y + (h - lh * len(lines)) / 2
    for l in lines:
        d.text((x + (w - d.textlength(l, font=f)) / 2, yy), l, font=f, fill="black"); yy += lh
def rect(x, y, w, h, t, f=f1):
    d.rectangle([x, y, x + w, y + h], outline="black", width=3); tcenter(x, y, w, h, t, f)
def arrow(pts, col, w=5):
    d.line(pts, fill=col, width=w, joint="curve")
    (x0, y0), (x1, y1) = pts[-2], pts[-1]; a = math.atan2(y1 - y0, x1 - x0)
    for s in (-0.5, 0.5):
        d.line([(x1, y1), (x1 - 26 * math.cos(a + s), y1 - 26 * math.sin(a + s))], fill=col, width=w)
tw = d.textlength("Diagrama de Flujo", font=f3)
d.text(((W - tw) / 2, 30), "Diagrama de Flujo", font=f3, fill="black")
# menu central
mx, my, mw, mh = 520, 150, 360, 330
d.rectangle([mx, my, mx + mw, my + mh], outline="black", width=3)
d.text((mx + (mw - d.textlength("MENÚ PRINCIPAL", font=f2)) / 2, my + 20), "MENÚ PRINCIPAL", font=f2, fill="black")
for i, l in enumerate(["-Jugar", "-Controles", "-Opciones", "-Créditos", "-Salir"]):
    d.text((mx + 80, my + 85 + i * 44), l, font=f2, fill="black")
# cajas laterales
rect(60, 140, 300, 230, "Controles\n\nBack")
rect(60, 460, 300, 230, "Opciones\n\nBack")
rect(1040, 140, 300, 230, "Créditos\n\nBack")
# partida
rect(500, 700, 400, 150, "Cómic de inicio")
rect(500, 910, 400, 150, "Nivel 1  →  Nivel 2\n→  Nivel 3  →  Jefe")
rect(1000, 700, 340, 150, "Pausa\n(Reanudar / Back)")
rect(1000, 910, 340, 150, "Derrota\n(reaparece en\ncheckpoint)")
rect(60, 910, 340, 150, "Victoria\nFinal del juego")
# flechas menu <-> cajas
arrow([(mx, 250), (360, 250)], GREEN); arrow([(360, 290), (mx, 290)], RED)
arrow([(mx, 400), (440, 400), (440, 520), (360, 520)], GREEN); arrow([(360, 600), (470, 600), (470, 440), (mx, 440)], RED)
arrow([(mx + mw, 250), (1040, 250)], GREEN); arrow([(1040, 300), (mx + mw, 300)], RED)
# menu -> partida
arrow([(700, my + mh), (700, 700)], GREEN)
arrow([(700, 850), (700, 910)], GREEN)
# partida <-> pausa
arrow([(900, 760), (1000, 760)], GREEN); arrow([(1000, 810), (900, 810)], RED)
# partida -> derrota / victoria
arrow([(900, 1000), (1000, 1000)], RED); arrow([(1000, 1040), (900, 1040)], GREEN)
arrow([(500, 985), (400, 985)], GREEN)
# volver al menú
arrow([(230, 910), (230, 780), (420, 780), (420, 330), (mx, 330)], RED)
# leyenda
d.line([(80, 1200), (180, 1200)], fill=GREEN, width=5); d.text((200, 1178), "ir a la pantalla", font=f2, fill="black")
d.line([(80, 1260), (180, 1260)], fill=RED, width=5); d.text((200, 1238), "volver (Back)", font=f2, fill="black")
im.save(OUT + "flujo.png")

# ---- core loop (estilo del original: cajas redondeadas negras y flechas curvas)
W, H = 1300, 1300
im = Image.new("RGB", (W, H), "white"); d = ImageDraw.Draw(im)
f = font(TB, 38)
boxes = [("EXPLORAR Y\nCOMBATIR", 650, 190), ("ELEGIR LA\nFORMA CORRECTA", 1010, 520), ("RECOGER FRAGMENTOS\nY ENERGÍA", 980, 1000), ("SUBIR DE NIVEL\nY ELEGIR COMBO", 420, 1000), ("AVANZAR AL\nSIGUIENTE TRAMO", 290, 520)]
bw, bh = 500, 150
def rbox(cx, cy, t):
    d.rounded_rectangle([cx - bw / 2, cy - bh / 2, cx + bw / 2, cy + bh / 2], radius=28, outline="black", width=5)
    lines = t.split("\n"); lh = 46; yy = cy - lh * len(lines) / 2
    for l in lines:
        d.text((cx - d.textlength(l, font=f) / 2, yy), l, font=f, fill="black"); yy += lh
for t, x, y in boxes: rbox(x, y, t)
cx0, cy0 = 650, 640; rx, ry = 480, 470
def arc(a0, a1):
    pts = []
    for i in range(0, 41):
        a = a0 + (a1 - a0) * i / 40
        pts.append((cx0 + rx * math.cos(a), cy0 + ry * math.sin(a)))
    d.line(pts, fill="black", width=6)
    (x0, y0), (x1, y1) = pts[-2], pts[-1]; a = math.atan2(y1 - y0, x1 - x0)
    for s in (-0.5, 0.5):
        d.line([(x1, y1), (x1 - 34 * math.cos(a + s), y1 - 34 * math.sin(a + s))], fill="black", width=6)
n = len(boxes)
angs = [math.atan2((y - cy0) / ry, (x - cx0) / rx) for _, x, y in boxes]
for i in range(n):
    a0 = angs[i]; a1 = angs[(i + 1) % n]
    if a1 <= a0: a1 += 2 * math.pi
    pad = 0.40
    arc(a0 + pad, a1 - pad)
im.save(OUT + "coreloop.png")
print("ok")
