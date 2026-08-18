extends Control

## Retrato vectorial placeholder del amuleto (reemplazar por sprite final cuando exista).

@export var color_gema := Color(0.25, 0.55, 0.48)
@export var color_borde := Color(0.95, 0.85, 0.4)
@export var color_brillo := Color(0.95, 0.85, 0.4, 0.35)
@export var color_ojo := Color(1, 0.97, 0.85)

var _t := 0.0
var _hablando := false


func set_hablando(activo: bool) -> void:
	_hablando = activo


func _process(delta: float) -> void:
	_t += delta
	queue_redraw()


func _draw() -> void:
	var c: Vector2 = size / 2.0
	var w: float = min(size.x, size.y) * 0.42
	var pulso := 1.0
	if _hablando:
		pulso = 1.0 + sin(_t * 8.0) * 0.12

	var pts := PackedVector2Array([
		c + Vector2(0, -w),
		c + Vector2(w * 0.62, -w * 0.35),
		c + Vector2(w * 0.62, w * 0.5),
		c + Vector2(0, w),
		c + Vector2(-w * 0.62, w * 0.5),
		c + Vector2(-w * 0.62, -w * 0.35),
	])
	draw_colored_polygon(pts, color_gema)
	draw_polyline(PackedVector2Array([pts[0], pts[1], pts[2], pts[3], pts[4], pts[5], pts[0]]), color_borde, 3.0, true)
	for p in pts:
		draw_line(p, c, color_borde, 1.5)

	draw_circle(c, w * 0.22 * pulso, color_brillo)
	draw_circle(c, w * 0.1 * pulso, color_ojo)
