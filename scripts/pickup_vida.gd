extends Area2D

## Orbe rojo de vida: soltado por enemigos con 55% de chance al morir.
## Visualmente igual que el orbe de energía (rombo) pero en rojo.

@export var curacion := 30

@onready var visual: Polygon2D = $Visual


func _ready() -> void:
	monitoring = true
	collision_mask = 4
	body_entered.connect(_on_body_entered)


func _on_body_entered(body: Node2D) -> void:
	if body.has_method("curar"):
		body.curar(curacion)
		queue_free()