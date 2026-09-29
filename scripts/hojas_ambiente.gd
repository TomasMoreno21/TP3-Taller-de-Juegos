extends CPUParticles2D
## Hojas que caen DELANTE de todo (primer plano), siguiendo la vista de la cámara.
## Las partículas viven en el mundo (local_coords = false): el emisor acompaña a la
## cámara por arriba de la pantalla y las hojas caen lento con ráfagas de viento.
## Bajo tierra (cámara por debajo de y_max) dejan de emitir.

@export var y_max := 1300.0               ## más abajo que esto (cuevas) no caen hojas
@export var margen_arriba := 160.0        ## px por encima del borde superior de la vista
@export var viento_fuerza := 26.0         ## empuje lateral de las ráfagas
@export var viento_periodo := 7.0         ## s por ciclo de ráfaga

@export var tension_viento := 1.2         ## cuánto más nervioso sopla con tensión máxima (peleas, poca vida)
@export var tension_velocidad := 0.5      ## cuánto más rápido caen con tensión máxima
@export var polvo_color := Color(0.55, 0.57, 0.6, 0.55)   ## polvo fino que cae del techo en la cueva con shakes fuertes

var _t := 0.0
var _racha := 0.0
var _amb: Node


func _ready() -> void:
	add_to_group("reactivo")
	var amb := get_node_or_null("/root/Ambiente")
	if amb != null:
		amb.sacudida_fuerte.connect(_polvo_techo)


## Golpe fuerte cerca: ráfaga de viento que se apaga sola (lo llama Ambiente).
func empujar(pos: Vector2, fuerza: float) -> void:
	var cam := get_viewport().get_camera_2d()
	var lado := 1.0
	if cam != null:
		lado = 1.0 if cam.get_screen_center_position().x <= pos.x else -1.0
	_racha += fuerza * viento_fuerza * 4.0 * lado


## En la cueva no caen hojas, pero un shake fuerte desprende polvo del techo.
func _polvo_techo(fuerza: float) -> void:
	var cam := get_viewport().get_camera_2d()
	if cam == null or DisplayServer.get_name() == "headless" or cam.get_screen_center_position().y < y_max:
		return
	var tam := get_viewport_rect().size / cam.zoom
	var c := cam.get_screen_center_position()
	var p := CPUParticles2D.new()
	p.one_shot = true
	p.explosiveness = 0.35
	p.amount = int(clampf(fuerza * 4.0, 16.0, 60.0))
	p.lifetime = 1.8
	p.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	p.emission_rect_extents = Vector2(tam.x * 0.5, 8.0)
	p.direction = Vector2.DOWN
	p.spread = 12.0
	p.gravity = Vector2(0.0, 140.0)
	p.initial_velocity_min = 10.0
	p.initial_velocity_max = 40.0
	p.scale_amount_min = 1.5
	p.scale_amount_max = 3.5
	p.color = polvo_color
	p.z_index = 4
	p.global_position = Vector2(c.x, c.y - tam.y * 0.5)
	get_tree().current_scene.add_child(p)
	p.emitting = true
	get_tree().create_timer(3.5).timeout.connect(p.queue_free)


func _process(delta: float) -> void:
	var cam := get_viewport().get_camera_2d()
	if cam == null:
		return
	_t += delta
	_racha = move_toward(_racha, 0.0, delta * viento_fuerza * 3.0)
	if _amb == null:
		_amb = get_node_or_null("/root/Ambiente")
	var tension: float = _amb.tension if _amb != null else 0.0
	speed_scale = 1.0 + tension * tension_velocidad
	var tam := get_viewport_rect().size / cam.zoom
	var c := cam.get_screen_center_position()
	global_position = Vector2(c.x, c.y - tam.y * 0.5 - margen_arriba)
	emission_rect_extents = Vector2(tam.x * 0.5 + 240.0, 10.0)
	emitting = c.y < y_max
	gravity.x = (sin(_t * TAU / maxf(viento_periodo, 0.1)) * viento_fuerza + viento_fuerza * 0.4) * (1.0 + tension * tension_viento) + _racha
