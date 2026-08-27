extends Area2D

@export var climb_speed: float = 200.0
@export var ancho: float = 32.0
@export var alto: float = 400.0
@export var required_form: int = 0

@onready var collision_shape: CollisionShape2D = $Collision
@onready var visual_poly: Polygon2D = $Visual/Poly

func _ready() -> void:
	add_to_group("enredadera")
	collision_layer = 0
	collision_mask = 4
	monitoring = true
	monitorable = true
	if collision_shape and collision_shape.shape is RectangleShape2D:
		(collision_shape.shape as RectangleShape2D).size = Vector2(ancho, alto)
	if visual_poly:
		var w := ancho * 0.5
		var h := alto * 0.5
		visual_poly.polygon = PackedVector2Array([Vector2(-w, -h), Vector2(w, -h), Vector2(w, h), Vector2(-w, h)])
