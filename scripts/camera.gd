extends Camera2D

signal modo_cambio(modo: String)

var _shake_timer := 0.0
var _shake_strength := 0.0
var _modo := "seguir"
var _fija_pos := Vector2.ZERO
var _zoom_objetivo := Vector2.ONE
var _punch_scale := 1.0
var _tilt := 0.0

@export var suavizado := 6.0
@export var desplazamiento := Vector2(0, -210)
@export var suavizado_zoom := 5.0
@export var lookahead := 0.006   # anticipación de cámara según velocidad horizontal


func _ready() -> void:
	_modo = "seguir"
	_zoom_objetivo = zoom


func _process(delta: float) -> void:
	if _shake_timer > 0.0:
		_shake_timer -= delta
		offset = Vector2(randf_range(-1, 1), randf_range(-1, 1)) * _shake_strength
		if _shake_timer <= 0.0:
			offset = Vector2.ZERO

	# Zoom suave hacia el objetivo (por transformación / sprint de forma).
	var objetivo := _zoom_objetivo * _punch_scale
	if zoom.distance_to(objetivo) > 0.0001:
		zoom = zoom.lerp(objetivo, minf(suavizado_zoom * delta, 1.0))
	else:
		zoom = objetivo

	# El punch de zoom recupera solo hacia 1.0 (landing más suave).
	if _punch_scale > 1.0:
		_punch_scale = maxf(1.0, _punch_scale - 3.0 * delta)

	# Tilt de cámara transitorio (giro de Lobo) -> recupera a 0.
	if absf(_tilt) > 0.01:
		rotation = lerpf(rotation, 0.0, minf(suavizado * 0.5 * delta, 1.0))
		if absf(rotation) < 0.01:
			_tilt = 0.0
			rotation = 0.0

	if _modo == "fija":
		global_position = global_position.lerp(_fija_pos, minf(suavizado * delta, 1.0))
		return

	var player := get_tree().get_first_node_in_group("player")
	if player == null:
		return
	var destino := (player as Node2D).global_position + desplazamiento
	# Lookahead: anticipa hacia dónde se mueve el player (solo horizontal, clampado).
	destino.x += clampf((player as Node2D).velocity.x * lookahead, -120.0, 120.0)
	global_position = global_position.lerp(destino, minf(suavizado * delta, 1.0))


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
