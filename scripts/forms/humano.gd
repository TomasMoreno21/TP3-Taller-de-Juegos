class_name Humano
extends Forma


func _init() -> void:
	form_name = "Humano"
	speed = 600.0
	jump_velocity = -465.0
	gravity_scale = 1.0
	max_health = 100
	attack_damage = 10
	attack_range = 100.0
	attack_size = Vector2(110, 80)
	light_combo_steps = 3
	heavy_damage = 18
	heavy_range = 120.0
	heavy_size = Vector2(140, 100)
	heavy_combo_steps = 2
	special_damage = 22
	color = Color(0.42, 0.62, 0.36)
	collider_size = Vector2(175, 300)
	shake_strength = 5.0
	turn_tilt = 9.0
	hit_rotation = 7.0
	landing_squash = 0.12
	camera_zoom = Vector2.ONE
	accel = 2600.0
	friction = 2200.0
	combos = [
		{"nombre": "Remate", "secuencia": ["light", "heavy"], "dano": 38, "knockback": 260.0, "tamano": Vector2(162, 114), "rango": 126.0},
	]


func perform_special(player: CharacterBody2D) -> void:
	player.enable_melee(Vector2(198, 126), 156.0, special_damage, 260.0)
