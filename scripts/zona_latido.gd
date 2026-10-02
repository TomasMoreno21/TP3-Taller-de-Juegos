@tool
extends Node2D

## Zona de ambiente del "latido" de la cueva (ver latido_cueva.gd): un rectángulo centrado en este nodo.
## Mientras el jugador esté dentro, la cueva toma este color y late a esta frecuencia/intensidad.
## Se mueve y se estira desde el editor (cambiá `tamano` y la posición).

@export var tamano := Vector2(1000, 800):
	set(v):
		tamano = v
		queue_redraw()
@export var color_ambiente := Color(0.66, 0.84, 0.96)   ## tinte de la cueva en esta zona (multiplica el mundo)
@export_range(0.05, 3.0, 0.05) var frecuencia := 0.5   ## latidos por segundo
@export_range(0.0, 0.3, 0.005) var intensidad := 0.03   ## cuánto sube el brillo en cada latido


func contiene(p: Vector2) -> bool:
	return Rect2(global_position - tamano * 0.5, tamano).has_point(p)


func _draw() -> void:
	if Engine.is_editor_hint():
		draw_rect(Rect2(-tamano * 0.5, tamano), Color(color_ambiente.r, color_ambiente.g, color_ambiente.b, 0.12), true)
		draw_rect(Rect2(-tamano * 0.5, tamano), Color(color_ambiente.r, color_ambiente.g, color_ambiente.b, 0.7), false, 6.0)
