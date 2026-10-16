@tool
extends Node2D
## Ojo central de la Estrella (dibujo). `apertura` 0 = cerrado, 1 = abierto. Adentro se ve
## la silueta del niño (placeholder hasta tener el arte). Todo editable en el Inspector.

@export_range(0.0, 1.0, 0.01) var apertura := 0.0:
	set(v):
		apertura = v
		queue_redraw()
@export var radio := 95.0:
	set(v):
		radio = v
		queue_redraw()
@export var textura_cerrado: Texture2D:
	set(v):
		textura_cerrado = v
		queue_redraw()
@export var cerrado_escala := Vector2.ONE:
	set(v):
		cerrado_escala = v
		queue_redraw()
@export var cerrado_offset := Vector2.ZERO:
	set(v):
		cerrado_offset = v
		queue_redraw()
@export var color_esclera := Color(0.85, 0.9, 1.0):
	set(v):
		color_esclera = v
		queue_redraw()
@export var color_iris := Color(0.15, 0.45, 0.85):
	set(v):
		color_iris = v
		queue_redraw()
@export var color_parpado := Color(0.78, 0.22, 0.72):
	set(v):
		color_parpado = v
		queue_redraw()
@export var mostrar_nino := true
@export var color_nino := Color(1.0, 0.95, 0.8, 0.55):
	set(v):
		color_nino = v
		queue_redraw()

var mirada := Vector2.ZERO   # la mueve el jefe (hacia el jugador)


func _draw() -> void:
	if apertura <= 0.02 and textura_cerrado != null:
		var ts := textura_cerrado.get_size() * cerrado_escala
		draw_texture_rect(textura_cerrado, Rect2(cerrado_offset - ts * 0.5, ts), false)
		return
	var w := radio * 1.45
	var h := radio * 0.85
	var almendra := _almendra(w, h)
	draw_colored_polygon(almendra, color_parpado.darkened(0.35))
	if apertura > 0.02:
		var hh := h * apertura
		draw_colored_polygon(_almendra(w * (0.6 + 0.4 * apertura), hh), color_esclera)
		var r_iris := minf(radio * 0.55, hh * 0.95)
		var c := mirada * apertura
		draw_circle(c, r_iris, color_iris)
		draw_circle(c, r_iris * 0.55, Color(0.03, 0.03, 0.08))
		if mostrar_nino and apertura > 0.4:
			_dibujar_nino(c, r_iris * 0.5)
	# Contorno con trazos (como el boceto).
	var borde := almendra.duplicate()
	borde.append(almendra[0])
	draw_polyline(borde, color_iris, 5.0, true)
	for i in 5:
		var a := -PI * 0.85 + PI * 0.7 * float(i) / 4.0
		var p := Vector2(cos(a) * w * 1.05, sin(a) * h * 1.15)
		draw_line(p, p * 1.18, color_iris, 4.0, true)


## Silueta del niño encogido dentro de la pupila (cabeza + cuerpo).
func _dibujar_nino(c: Vector2, r: float) -> void:
	draw_circle(c + Vector2(0, -r * 0.45), r * 0.32, color_nino)
	draw_colored_polygon(PackedVector2Array([
		c + Vector2(-r * 0.35, -r * 0.1), c + Vector2(r * 0.35, -r * 0.1),
		c + Vector2(r * 0.45, r * 0.7), c + Vector2(-r * 0.45, r * 0.7)]), color_nino)


func _almendra(w: float, h: float) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in 32:
		var a := TAU * float(i) / 32.0
		pts.append(Vector2(cos(a) * w, sin(a) * h * (1.0 - 0.4 * absf(cos(a)))))
	return pts
