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
	Burst.emitir(self, global_position, Color(0.55, 0.4, 0.26), 16)
	var cam := get_viewport().get_camera_2d()
	if cam != null and cam.has_method("shake"):
		cam.shake(4.0, 0.12)
	queue_free()
	return true
