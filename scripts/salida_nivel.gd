extends Area2D
## Puerta de salida colocable: al tocarla, el jugador pasa a la siguiente escena.
## `siguiente_escena` es editable desde el Inspector (ninguna ruta hardcodeada en el nivel).

@export var siguiente_escena: String = ""
@export var color := Color(0.8, 0.7, 0.3)

var _usada := false

@onready var visual: Polygon2D = $Visual


func _ready() -> void:
	monitoring = true
	collision_layer = 0
	collision_mask = 4
	body_entered.connect(_on_body_entered)
	if visual != null:
		visual.color = color


func _on_body_entered(_body: Node2D) -> void:
	if _usada or siguiente_escena.is_empty():
		return
	_usada = true
	get_tree().change_scene_to_file(siguiente_escena)
