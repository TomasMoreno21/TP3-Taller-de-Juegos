@tool
extends Node2D
## Marca de garra: tres zarpazos de piedra que laten sobre lo que solo rompe el Oso (nudo del tallo,
## ojo acorazado, ojo cerrado del jefe). La señal sale del objeto mismo; `destello()` al rebotar.

@export var encendida := false:
	set(v):
		if v == encendida:
			return
		encendida = v
		visible = v
		queue_redraw()
@export var tamano := 70.0:                       ## alto de los zarpazos (px)
	set(v):
		tamano = v
		queue_redraw()
@export var color := Color(0.86, 0.8, 0.68)       ## hueso / piedra clara
@export var color_brillo := Color(1.0, 0.72, 0.38)   ## luz cálida del Oso
@export var latido := 2.2                         ## latidos por segundo
@export var grosor := 0.22                        ## ancho de cada zarpazo (× tamano)

var _t := 0.0
var _destello := 0.0


func _ready() -> void:
	visible = encendida


func _process(delta: float) -> void:
	if not visible:
		return
	_t += delta
	_destello = maxf(_destello - delta * 3.0, 0.0)
	queue_redraw()


## Golpe que no alcanzó (otra forma): la marca destella para recordar que hace falta el Oso.
func destello() -> void:
	_destello = 1.0
	queue_redraw()


func _draw() -> void:
	if not encendida:
		return
	var pulso := 0.5 + 0.5 * sin(_t * TAU * latido)
	var k := 1.0 + 0.08 * pulso + 0.25 * _destello
	var brillo := Color(color_brillo.r, color_brillo.g, color_brillo.b, 0.25 + 0.35 * pulso + 0.4 * _destello)
	for i in 3:
		var dx := (float(i) - 1.0) * tamano * 0.42 * k
		var zarpazo := _zarpazo(Vector2(dx, -float(abs(i - 1)) * tamano * 0.08), tamano * k * (1.0 if i == 1 else 0.85))
		draw_colored_polygon(_engordar(zarpazo, 1.35), brillo)   # halo
		draw_colored_polygon(zarpazo, color.lerp(Color.WHITE, 0.4 * _destello))


## Media luna fina e inclinada (arriba-derecha → abajo-izquierda), centrada en `c`.
func _zarpazo(c: Vector2, alto: float) -> PackedVector2Array:
	var pts := PackedVector2Array()
	var pasos := 10
	var ancho := alto * grosor
	for j in pasos + 1:
		var t := float(j) / pasos
		var p := Vector2(lerpf(alto * 0.22, -alto * 0.22, t) + sin(t * PI) * alto * 0.12, lerpf(-alto * 0.5, alto * 0.5, t))
		pts.append(c + p + Vector2(sin(t * PI) * ancho * 0.5, 0))
	for j in range(pasos - 1, 0, -1):   # sin repetir las puntas (polígono válido)
		var t := float(j) / pasos
		var p := Vector2(lerpf(alto * 0.22, -alto * 0.22, t) + sin(t * PI) * alto * 0.12, lerpf(-alto * 0.5, alto * 0.5, t))
		pts.append(c + p - Vector2(sin(t * PI) * ancho * 0.5, 0))
	return pts


func _engordar(pts: PackedVector2Array, f: float) -> PackedVector2Array:
	var c := Vector2.ZERO
	for p in pts:
		c += p
	c /= maxf(float(pts.size()), 1.0)
	var out := PackedVector2Array()
	for p in pts:
		out.append(c + (p - c) * f)
	return out
