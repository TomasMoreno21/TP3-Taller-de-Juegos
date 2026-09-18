# -*- coding: utf-8 -*-
"""Inserta un test Flip (facing+scale.x en el mismo frame) en tests/autotest.gd
tras la linea de ancla: 	Input.action_release("block")  del test imbloqueable.
Ancla exacta unica: la primer action_release("block") que aparece seguida de
una linea con "imbloqueable" cercana NO existe; ancla real usada: la linea
'	Input.action_release("block")' que va seguida (dentro de +/-3) de la cadena
'# Murcielago: special dispa'  (ancla del test imbloqueable -> siguiente bloque real).
"""
import io

f = "C:/Users/Usuario/Documents/proyecto--ben-10/tests/autotest.gd"

def read():
    with io.open(f, "r", encoding="utf-8", newline="") as h:
        return h.read()

def write(s):
    with io.open(f, "w", encoding="utf-8", newline="") as h:
        h.write(s)

p = read()
lines = p.split("\n")

ANCLA = '\tInput.action_release("block")'
idx = None
for i in range(len(lines)):
    if lines[i].strip() == ANCLA:
        # esta linea es el release del test imbloqueable si las 2-4 lineas
        # siguientes (no vacias) contienen el header del bloque Murcielago
        window = "\n".join(x.strip() for x in lines[i + 1 : i + 6])
        if "Murcielago" in window and ("special" in window or "s.p" in window.lower()):
            idx = i
            break

assert idx is not None, "ancla imbloqueable-release + header Murcielago no encontrada"

bloque = [
    "\tawait physics_frame",
    "",
    "\t# --- Flip: facing y sprite cambian en el mismo frame al invertir direccion ---",
    "\tInput.action_press(\"move_right\")",
    "\tawait physics_frame",
    "\tInput.action_release(\"move_right\")",
    "\tawait physics_frame",
    "\tvar facing_a: int = _player.facing",
    "\tvar flip_a: float = _player.visual.scale.x",
    "\tInput.action_press(\"move_left\")",
    "\tawait physics_frame",
    "\tvar facing_b: int = _player.facing",
    "\tvar flip_b: float = _player.visual.scale.x",
    "\t_check(facing_b == -1, \"Flip: facing=-1 tras mover izquierda (era %d)\" % facing_b)",
    "\t_check(flip_b < 0.0 and flip_a > 0.0, \"Flip: sprite invertido mismo frame (scale.x %.1f -> %.1f)\" % [flip_a, flip_b])",
    "\tInput.action_release(\"move_left\")",
    "\tawait physics_frame",
    "",
]

insert_at = idx + 1
for off, l in enumerate(bloque):
    lines.insert(insert_at + off, l)

write("\n".join(lines))
print("OK test Flip insertado (posts L%d)" % (insert_at + 1))
