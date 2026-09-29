@tool
extends Node2D
## Estalagmita alta de fondo (silueta plana). Origen = base sobre el piso. Se mueve como
## cualquier nodo; `alto`, `ancho_base` y `flip_h` se ajustan en el Inspector.

@export var alto := 420.0:
	set(v):
		alto = maxf(v, 20.0)
		queue_redraw()
@export var ancho_base := 90.0:
	set(v):
		ancho_base = maxf(v, 10.0)
		queue_redraw()
@export var color := Color(0.085, 0.133, 0.142, 1):
	set(v):
		color = v
		queue_redraw()
@export var color_luz := Color(0.17, 0.25, 0.27, 0.35):  ## brillo de la punta
	set(v):
		color_luz = v
		queue_redraw()
@export var flip_h := false:
	set(v):
		flip_h = v
		queue_redraw()


func _draw() -> void:
	var s := -1.0 if flip_h else 1.0
	var b := ancho_base
	var h := alto
	draw_colored_polygon(PackedVector2Array([
		Vector2(-b * 0.5 * s, 0), Vector2(-b * 0.34 * s, -h * 0.35),
		Vector2(-b * 0.14 * s, -h * 0.7), Vector2(0, -h),
		Vector2(b * 0.14 * s, -h * 0.7), Vector2(b * 0.34 * s, -h * 0.35),
		Vector2(b * 0.5 * s, 0)]), color)
	draw_polyline(PackedVector2Array([
		Vector2(-b * 0.3 * s, -h * 0.4), Vector2(0, -h), Vector2(b * 0.3 * s, -h * 0.4)]), color_luz, 1.5)
