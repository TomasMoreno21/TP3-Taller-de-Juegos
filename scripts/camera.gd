extends Camera2D

signal modo_cambio(modo: String)

var _shake_timer := 0.0
var _shake_strength := 0.0
var _modo := "seguir"
var _fija_pos := Vector2.ZERO
var _zoom_objetivo := Vector2.ONE
var _punch_scale := 1.0
var _tilt := 0.0
var _lookahead_actual := 0.0

@export var suavizado := 6.0
@export var desplazamiento := Vector2(0, -310)
@export var suavizado_zoom := 5.0
@export var lookahead := 0.28    # anticipación de cámara según velocidad horizontal
@export var lookahead_umbral := 80.0    # velocidad (px/s) recién pasada la cual empieza el adelanto
@export var suavizado_lookahead := 3.0  # qué tan suave entra y sale el adelanto
@export var deadzone_horizontal := 12.0  # zona muerta en X (evita temblor al estar quieto)
@export var deadzone_vertical := 150.0  # salto dentro de este rango casi no mueve la cámara al subir
@export var seguimiento_vertical_leve := 0.15  # cuánto sí se mueve dentro de la deadzone al subir
@export var suavizado_subida := 1.8  # al subir: lento
@export var suavizado_bajada := 7.0  # al bajar: brusco y rápido


func _ready() -> void:
	_modo = "seguir"
	_zoom_objetivo = zoom


func _process(delta: float) -> void:
	if _shake_timer > 0.0:
		_shake_timer -= delta
		var t := clampf(_shake_timer / 0.15, 0.0, 1.0)
		var cur_strength := _shake_strength * (t * t)
		offset = Vector2(randf_range(-1, 1), randf_range(-1, 1)) * cur_strength
		if _shake_timer <= 0.0:
			offset = Vector2.ZERO

	# Zoom suave hacia el objetivo (por transformación / sprint de forma).
	var objetivo := _zoom_objetivo * _punch_scale
	if zoom.distance_to(objetivo) > 0.0001:
		zoom = zoom.lerp(objetivo, minf(suavizado_zoom * delta, 1.0))
	else:
		zoom = objetivo

	# El punch de zoom recupera con curva suave (ease out).
	if _punch_scale > 1.0:
		_punch_scale = lerpf(_punch_scale, 1.0, minf(4.0 * delta, 1.0))

	# Tilt de cámara transitorio (giro de Lobo) -> recupera a 0.
	if absf(_tilt) > 0.01:
		rotation = lerpf(rotation, 0.0, minf(suavizado * 0.5 * delta, 1.0))
		if absf(rotation) < 0.01:
			_tilt = 0.0
			rotation = 0.0


func _physics_process(delta: float) -> void:
	if _modo == "fija":
		global_position = global_position.lerp(_fija_pos, minf(suavizado * delta, 1.0))
		return

	var player := get_tree().get_first_node_in_group("player")
	if player == null:
		return
	var destino := (player as Node2D).global_position + desplazamiento
	# Lookahead progresivo por forma: cada transformación ve más/menos adelante
	var vel_x: float = (player as Node2D).velocity.x
	var look_mult := 1.0
	if "forms" in player and "current_form" in player:
		var f = (player as Node).get("forms")[(player as Node).get("current_form")]
		if f != null and "camera_lookahead_mult" in f:
			look_mult = f.get("camera_lookahead_mult")
	var objetivo_la := clampf(maxf(absf(vel_x) - lookahead_umbral, 0.0) * lookahead * look_mult * signf(vel_x), -160.0, 160.0)
	_lookahead_actual = lerpf(_lookahead_actual, objetivo_la, minf(suavizado_lookahead * delta, 1.0))
	destino.x += _lookahead_actual
	if absf(destino.x - global_position.x) < deadzone_horizontal:
		destino.x = global_position.x
	# Vertical asimétrico: subir lento (deadzone + suavizado bajo), bajar brusco.
	var dy = destino.y - global_position.y
	var suavizado_y: float
	if dy < 0:
		if absf(dy) < deadzone_vertical:
			destino.y = global_position.y + dy * seguimiento_vertical_leve
		suavizado_y = suavizado_subida
	else:
		suavizado_y = suavizado_bajada
	global_position.x = lerpf(global_position.x, destino.x, minf(suavizado * delta, 1.0))
	global_position.y = lerpf(global_position.y, destino.y, minf(suavizado_y * delta, 1.0))


func fijar_zoom(objetivo: Vector2) -> void:
	_zoom_objetivo = objetivo


func punch(escala: float = 1.03) -> void:
	_punch_scale = maxf(_punch_scale, escala)


func tilt(angulo: float) -> void:
	_tilt = angulo
	rotation = angulo


func modo_arena(centro: Vector2) -> void:
	_modo = "fija"
	_fija_pos = centro
	global_position = centro
	modo_cambio.emit("arena")


func modo_normal() -> void:
	_modo = "seguir"
	modo_cambio.emit("seguir")


func shake(strength: float = 8.0, duration: float = 0.15) -> void:
	_shake_timer = duration
	_shake_strength = strength
