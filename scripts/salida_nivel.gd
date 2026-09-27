extends Area2D
## Puerta de salida colocable: al tocarla, el jugador pasa a la siguiente escena.
## `siguiente_escena` es editable desde el Inspector (ninguna ruta hardcodeada en el nivel).

@export var siguiente_escena: String = ""
@export var color := Color(0.8, 0.7, 0.3)
@export var sonido_salida: AudioStream = preload("res://assets/audio/sfx/gen/zona_despejada.wav")
@export var volumen_salida_db := -8.0

var _usada := false

@onready var visual: Polygon2D = $Visual


func _ready() -> void:
	monitoring = true
	collision_layer = 0
	collision_mask = 4
	body_entered.connect(_on_body_entered)
	if visual != null:
		visual.color = color
	var luz := get_node_or_null("Luz") as PointLight2D
	if luz != null:
		luz.color = Color(color, 1.0)


func _on_body_entered(_body: Node2D) -> void:
	if _usada or siguiente_escena.is_empty():
		return
	_usada = true
	var audio := get_node_or_null("/root/AudioManager")
	if audio != null:
		audio.play_sfx(sonido_salida, volumen_salida_db)
	TransicionPantalla.de(get_tree()).cambiar_escena(siguiente_escena)
