class_name Murcielago
extends Forma


func _init() -> void:
	form_name = "Murciélago"
	speed = 215.0
	jump_velocity = -420.0
	gravity_scale = 0.8
	max_health = 100
	attack_damage = 8
	attack_range = 66.0
	attack_size = Vector2(78, 60)
	light_combo_steps = 3
	heavy_damage = 14
	heavy_range = 90.0
	heavy_size = Vector2(114, 78)
	heavy_combo_steps = 2
	special_damage = 15
	color = Color(0.52, 0.4, 0.62)
	collider_size = Vector2(84, 90)
	transform_duration = 9.0
	combos = [
		{"nombre": "Ala Cortante", "secuencia": ["light", "heavy"], "dano": 28, "knockback": 240.0, "tamano": Vector2(192, 102), "rango": 114.0},
	]


func is_gliding(player: CharacterBody2D) -> bool:
	return Input.is_action_pressed("jump") and not player.is_on_floor() and player.velocity.y > 0.0


func perform_special(player: CharacterBody2D) -> void:
	player.fire_projectile()