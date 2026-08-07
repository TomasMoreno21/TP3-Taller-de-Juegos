class_name Interactable
extends StaticBody2D

signal destroyed

@export var required_form: int = 1
@export var interact_range := 46.0

var broken := false


func _ready() -> void:
	add_to_group("interactable")


func can_interact(player: Node2D) -> bool:
	return not broken and player.current_form == required_form \
		and global_position.distance_to(player.global_position) <= interact_range


func break_interact() -> void:
	if broken:
		return
	broken = true
	destroyed.emit()
	var tween := create_tween()
	tween.tween_property(self, "modulate:a", 0.0, 0.25)
	tween.parallel().tween_property(self, "scale", Vector2(1.4, 1.4), 0.25)
	tween.tween_callback(queue_free)
