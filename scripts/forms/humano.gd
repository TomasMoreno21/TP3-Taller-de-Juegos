class_name Humano
extends Forma


func _init() -> void:
	form_name = "Guardabosques"
	speed = 200.0
	jump_velocity = -420.0
	gravity_scale = 1.0
	max_health = 100
	attack_damage = 10
	attack_range = 26.0
	attack_size = Vector2(30, 24)
	color = Color(0.42, 0.62, 0.36)
	collider_size = Vector2(16, 40)
	shake_strength = 5.0
	hit_rotation = 7.0
