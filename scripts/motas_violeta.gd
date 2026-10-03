extends CPUParticles2D

## Motas violetas suaves que flotan por la cueva. Acompañan a la cámara y su opacidad sigue la
## intensidad del latido (latido_cueva.gd): arriba no hay, y aparecen más cerca del santuario.
## Las partículas viven en el mundo (local_coords = false), así que se quedan atrás al avanzar.

@export var latido: NodePath
@export var intensidad_min := 0.015     ## con menos latido que esto no hay motas
@export var intensidad_max := 0.07      ## con este latido, opacidad plena
@export var opacidad_max := 0.55
@export var margen := 200.0             ## px extra alrededor de la vista donde nacen
@export var suavizado := 2.0

var _latido: Node


func _ready() -> void:
	_latido = get_node_or_null(latido)
	modulate.a = 0.0
	emitting = false


func _process(delta: float) -> void:
	var cam := get_viewport().get_camera_2d()
	if cam == null:
		return
	global_position = cam.get_screen_center_position()
	emission_rect_extents = get_viewport_rect().size / cam.zoom * 0.5 + Vector2(margen, margen)
	var i: float = _latido.intensidad_actual() if _latido != null and _latido.has_method("intensidad_actual") else 0.0
	var k := clampf(inverse_lerp(intensidad_min, intensidad_max, i), 0.0, 1.0)
	modulate.a = lerpf(modulate.a, opacidad_max * k, 1.0 - exp(-suavizado * delta))
	emitting = modulate.a > 0.01
