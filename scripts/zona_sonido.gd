@tool
extends Node2D

## Zona de sonido de la cueva (ver ambiente_zonas.gd): un rectángulo centrado en este nodo.
## Mientras el jugador esté dentro, el ambiente toma esta reverberación, este filtro y, si hay, una capa propia.
## Se mueve y se estira desde el editor (cambiá `tamano` y la posición).

@export var tamano := Vector2(1600, 1000):
	set(v):
		tamano = v
		queue_redraw()
@export var capa: AudioStream                              ## loop propio de esta zona (opcional): se mezcla al entrar y se apaga al salir
@export var capa_db := -14.0
@export_range(0.0, 1.0, 0.01) var reverb_mezcla := 0.2     ## cuánta cola de eco tiene el ambiente aquí
@export_range(0.0, 1.0, 0.01) var reverb_sala := 0.5       ## tamaño de la sala (más = eco más largo)
@export_range(200.0, 20500.0, 10.0) var filtro_hz := 20500.0   ## paso bajo: más bajo = ambiente más sordo/lejano
@export var volumen_db := 0.0                              ## ajuste del volumen de las capas de ambiente en esta zona
@export var color_editor := Color(0.55, 0.75, 1.0)


func contiene(p: Vector2) -> bool:
	return Rect2(global_position - tamano * 0.5, tamano).has_point(p)


func _draw() -> void:
	if Engine.is_editor_hint():
		draw_rect(Rect2(-tamano * 0.5, tamano), Color(color_editor, 0.1), true)
		draw_rect(Rect2(-tamano * 0.5, tamano), Color(color_editor, 0.7), false, 6.0)
