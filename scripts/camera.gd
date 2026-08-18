extends Camera2D

signal modo_cambio(modo: String)

var _shake_timer := 0.0
var _shake_strength := 0.0
var _modo := "seguir"
var _fija_pos := Vector2.ZERO

@export var suavizado := 6.0
@export var desplazamiento := Vector2(0, -210)
@export var limite_min := Vector2(-400, -800)
@export var limite_max := Vector2(3400, 1080)


func _ready() -> void:
	_modo = "seguir"


func _process(delta: float) -> void:
	if _shake_timer > 0.0:
		_shake_timer -= delta
		offset = Vector2(randf_range(-1, 1), randf_range(-1, 1)) * _shake_strength
		if _shake_timer <= 0.0:
			offset = Vector2.ZERO

	if _modo == "fija":
		global_position = global_position.lerp(_fija_pos, minf(suavizado * delta, 1.0))
		return

	var player := get_tree().get_first_node_in_group("player")
	if player == null:
		return
	var destino := (player as Node2D).global_position + desplazamiento
	destino.x = clampf(destino.x, limite_min.x, limite_max.x)
	destino.y = clampf(destino.y, limite_min.y, limite_max.y)
	global_position = global_position.lerp(destino, minf(suavizado * delta, 1.0))


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
