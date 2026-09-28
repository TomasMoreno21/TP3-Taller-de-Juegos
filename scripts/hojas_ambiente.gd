extends CPUParticles2D
## Hojas que caen DELANTE de todo (primer plano), siguiendo la vista de la cámara.
## Las partículas viven en el mundo (local_coords = false): el emisor acompaña a la
## cámara por arriba de la pantalla y las hojas caen lento con ráfagas de viento.
## Bajo tierra (cámara por debajo de y_max) dejan de emitir.

@export var y_max := 1300.0               ## más abajo que esto (cuevas) no caen hojas
@export var margen_arriba := 160.0        ## px por encima del borde superior de la vista
@export var viento_fuerza := 26.0         ## empuje lateral de las ráfagas
@export var viento_periodo := 7.0         ## s por ciclo de ráfaga

var _t := 0.0


func _process(delta: float) -> void:
	var cam := get_viewport().get_camera_2d()
	if cam == null:
		return
	_t += delta
	var tam := get_viewport_rect().size / cam.zoom
	var c := cam.get_screen_center_position()
	global_position = Vector2(c.x, c.y - tam.y * 0.5 - margen_arriba)
	emission_rect_extents = Vector2(tam.x * 0.5 + 240.0, 10.0)
	emitting = c.y < y_max
	gravity.x = sin(_t * TAU / maxf(viento_periodo, 0.1)) * viento_fuerza + viento_fuerza * 0.4
