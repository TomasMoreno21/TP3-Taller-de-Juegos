extends StaticBody2D

@onready var visual: Polygon2D = $Visual
@onready var collision: CollisionShape2D = $Collision
@onready var label: Label = $Label


func set_closed(closed: bool) -> void:
	visual.visible = closed
	collision.disabled = not closed
	label.visible = closed
