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

@export var bloqueado := false:
	set(v):
		bloqueado = v
		queue_redraw()


func _draw() -> void:
	var c: Vector2 = size / 2.0
	var r: float = min(size.x, size.y) * 0.5 * 0.6

	match forma:
		1:
			_draw_lobo(c, r)
		2:
			_draw_oso(c, r)
		3:
			_draw_murcielago(c, r)
		_:
			_draw_humano(c, r)

	if bloqueado:
		draw_circle(c, min(size.x, size.y) * 0.5, Color(0.03, 0.03, 0.04, 0.72))


func _draw_humano(c: Vector2, r: float) -> void:
	var cabeza: Vector2 = c + Vector2(0, -r * 0.55)
	draw_circle(cabeza, r * 0.28, color_icono)
	var cuerpo := PackedVector2Array([
		c + Vector2(-r * 0.32, -r * 0.15),
		c + Vector2(r * 0.32, -r * 0.15),
		c + Vector2(r * 0.22, r * 0.65),
		c + Vector2(-r * 0.22, r * 0.65),
	])
	draw_colored_polygon(cuerpo, color_icono)


func _draw_lobo(c: Vector2, r: float) -> void:
	var oreja_izq := PackedVector2Array([
		c + Vector2(-r * 0.34, -r * 0.08),
		c + Vector2(-r * 0.58, -r * 0.6),
		c + Vector2(-r * 0.08, -r * 0.28),
	])
	var oreja_der := PackedVector2Array([
		c + Vector2(r * 0.34, -r * 0.08),
		c + Vector2(r * 0.58, -r * 0.6),
		c + Vector2(r * 0.08, -r * 0.28),
	])
	draw_colored_polygon(oreja_izq, color_icono)
	draw_colored_polygon(oreja_der, color_icono)
	draw_circle(c, r * 0.42, color_icono)
	var hocico := PackedVector2Array([
		c + Vector2(-r * 0.16, r * 0.12),
		c + Vector2(r * 0.16, r * 0.12),
		c + Vector2(0, r * 0.6),
	])
	draw_colored_polygon(hocico, color_icono)


func _draw_oso(c: Vector2, r: float) -> void:
	draw_circle(c + Vector2(-r * 0.4, -r * 0.42), r * 0.18, color_icono)
	draw_circle(c + Vector2(r * 0.4, -r * 0.42), r * 0.18, color_icono)
	draw_circle(c, r * 0.5, color_icono)
	draw_circle(c + Vector2(0, r * 0.24), r * 0.24, color_icono)


func _draw_murcielago(c: Vector2, r: float) -> void:
	draw_circle(c, r * 0.2, color_icono)
	var ala_izq := PackedVector2Array([
		c + Vector2(-r * 0.06, -r * 0.12),
		c + Vector2(-r * 0.62, -r * 0.56),
		c + Vector2(-r * 0.36, -r * 0.05),
		c + Vector2(-r * 0.72, r * 0.16),
		c + Vector2(-r * 0.12, r * 0.24),
	])
	var ala_der := PackedVector2Array([
		c + Vector2(r * 0.06, -r * 0.12),
		c + Vector2(r * 0.62, -r * 0.56),
		c + Vector2(r * 0.36, -r * 0.05),
		c + Vector2(r * 0.72, r * 0.16),
		c + Vector2(r * 0.12, r * 0.24),
	])
	draw_colored_polygon(ala_izq, color_icono)
	draw_colored_polygon(ala_der, color_icono)
