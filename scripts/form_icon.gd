extends Control

## Silueta vectorial placeholder por forma (reemplazar por arte final cuando exista).
## forma sigue el enum Form de player.gd: HUMAN=0, LOBO=1, OSO=2, MURCIELAGO=3.

@export var forma: int = 0:
	set(v):
		forma = v
		queue_redraw()

@export var color_icono := Color(0.9, 0.9, 0.9):
	set(v):
		color_icono = v
		queue_redraw()

## Color de los detalles (ojos, nariz) recortados sobre la silueta.
@export var color_detalle := Color(0.05, 0.05, 0.07):
	set(v):
		color_detalle = v
		queue_redraw()

## Disco de fondo (alfa 0 = sin disco), como el dial del HUD.
@export var color_disco := Color(0, 0, 0, 0):
	set(v):
		color_disco = v
		queue_redraw()

@export var bloqueado := false:
	set(v):
		bloqueado = v
		queue_redraw()


func _draw() -> void:
	var c: Vector2 = size / 2.0
	var r: float = min(size.x, size.y) * 0.5 * 0.45
	if color_disco.a > 0.0:
		draw_circle(c, min(size.x, size.y) * 0.5, color_disco)

	match forma:
		1:
			_draw_lobo(c + Vector2(0, r * 0.11), r)
		2:
			_draw_oso(c, r)
		3:
			_draw_murcielago(c + Vector2(0, r * 0.07), r)
		_:
			_draw_humano(c - Vector2(0, r * 0.08), r)

	if bloqueado:
		draw_circle(c, min(size.x, size.y) * 0.5, Color(0.03, 0.03, 0.04, 0.72))


## Convierte puntos en unidades de r (relativos al centro) a coordenadas locales.
func _pts(c: Vector2, r: float, u: Array, espejo := false) -> PackedVector2Array:
	var out := PackedVector2Array()
	for p in u:
		out.append(c + Vector2(-p.x if espejo else p.x, p.y) * r)
	return out


func _elipse(c: Vector2, rx: float, ry: float, desde := 0.0, hasta := TAU) -> PackedVector2Array:
	var out := PackedVector2Array()
	for i in 25:
		var a := lerpf(desde, hasta, i / 24.0)
		out.append(c + Vector2(cos(a) * rx, sin(a) * ry))
	return out


func _par(c: Vector2, r: float, u: Array, col: Color) -> void:
	draw_colored_polygon(_pts(c, r, u), col)
	draw_colored_polygon(_pts(c, r, u, true), col)


func _draw_humano(c: Vector2, r: float) -> void:
	draw_colored_polygon(_elipse(c + Vector2(0, r * 0.95), r * 0.72, r * 0.8, PI, TAU), color_icono)
	draw_colored_polygon(_elipse(c + Vector2(0, -r * 0.42), r * 0.34, r * 0.38), color_icono)
	# cuello oscuro para separar cabeza y hombros
	draw_colored_polygon(_elipse(c + Vector2(0, r * 0.2), r * 0.3, r * 0.07), color_detalle)


func _draw_lobo(c: Vector2, r: float) -> void:
	_par(c, r, [Vector2(-0.12, -0.3), Vector2(-0.34, -0.92), Vector2(-0.62, -0.1)], color_icono)
	draw_colored_polygon(_pts(c, r, [Vector2(-0.5, -0.1), Vector2(-0.45, 0.3), Vector2(-0.16, 0.58), Vector2(0, 0.7),
		Vector2(0.16, 0.58), Vector2(0.45, 0.3), Vector2(0.5, -0.1), Vector2(0.3, -0.34), Vector2(-0.3, -0.34)]), color_icono)
	_par(c, r, [Vector2(-0.14, -0.16), Vector2(-0.34, -0.06), Vector2(-0.12, 0.0)], color_detalle)
	draw_colored_polygon(_pts(c, r, [Vector2(-0.1, 0.5), Vector2(0.1, 0.5), Vector2(0, 0.62)]), color_detalle)


func _draw_oso(c: Vector2, r: float) -> void:
	for x in [-1.0, 1.0]:
		draw_circle(c + Vector2(x * r * 0.5, -r * 0.46), r * 0.24, color_icono)
		draw_circle(c + Vector2(x * r * 0.5, -r * 0.46), r * 0.11, color_detalle)
	draw_colored_polygon(_elipse(c + Vector2(0, r * 0.04), r * 0.66, r * 0.6), color_icono)
	for x in [-1.0, 1.0]:
		draw_circle(c + Vector2(x * r * 0.26, -r * 0.1), r * 0.08, color_detalle)
	draw_colored_polygon(_elipse(c + Vector2(0, r * 0.3), r * 0.28, r * 0.2), color_detalle)
	draw_colored_polygon(_elipse(c + Vector2(0, r * 0.22), r * 0.1, r * 0.07), color_icono)


func _draw_murcielago(c: Vector2, r: float) -> void:
	_par(c, r, [Vector2(0.06, -0.12), Vector2(0.88, -0.5), Vector2(0.82, -0.05), Vector2(0.64, 0.12),
		Vector2(0.56, 0.4), Vector2(0.36, 0.2), Vector2(0.18, 0.46), Vector2(0.1, 0.2)], color_icono)
	_par(c, r, [Vector2(0.04, -0.22), Vector2(0.2, -0.6), Vector2(0.24, -0.18)], color_icono)
	draw_colored_polygon(_elipse(c + Vector2(0, r * 0.02), r * 0.24, r * 0.34), color_icono)
	for x in [-1.0, 1.0]:
		draw_circle(c + Vector2(x * r * 0.09, -r * 0.08), r * 0.05, color_detalle)
