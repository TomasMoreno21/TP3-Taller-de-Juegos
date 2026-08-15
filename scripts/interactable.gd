extends StaticBody2D

@export var required_form: int = 2
@export var interact_range := 220.0

var destroyed := false


func _ready() -> void:
	add_to_group("interactable")


func try_interact(player: Node2D) -> bool:
	if destroyed:
		return false
	if player.current_form != required_form:
		return false
	if player.global_position.distance_to(global_position) > interact_range:
		return false
	destroyed = true
	queue_free()
	return true
