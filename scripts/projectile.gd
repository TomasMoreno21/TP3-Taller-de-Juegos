extends Area2D

var direction := Vector2.RIGHT
var speed := 700.0
var damage := 15
var enemy_shot := false
var _life := 2.5

@onready var visual: Polygon2D = $Visual
@onready var hitbox: CollisionShape2D = $Hitbox


func _ready() -> void:
	collision_mask = 4 if enemy_shot else 3
	body_entered.connect(_on_body_entered)
	monitoring = true


func _physics_process(delta: float) -> void:
	global_position += direction * speed * delta
	_life -= delta
	if _life <= 0.0:
		queue_free()


func _on_body_entered(body: Node2D) -> void:
	if body.has_method("take_damage"):
		body.take_damage(damage, 120.0, int(direction.x))
	queue_free()
