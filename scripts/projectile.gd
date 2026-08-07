extends Area2D

var direction := 1
var damage := 10
var speed := 480.0

var _life := 0.0

@onready var visual: Polygon2D = $Visual
@onready var hitbox: CollisionShape2D = $Hitbox


func setup(dir: int, dmg: int) -> void:
	direction = dir
	damage = dmg


func _physics_process(delta: float) -> void:
	_life += delta
	position.x += direction * speed * delta
	for body in get_overlapping_bodies():
		if body.is_in_group("enemy"):
			body.take_damage(damage)
			queue_free()
			return
		elif body is StaticBody2D:
			queue_free()
			return
	if _life > 3.0:
		queue_free()
