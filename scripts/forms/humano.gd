class_name Humano
extends Forma


func _init() -> void:
	form_name = "Humano"
	speed = 200.0
	jump_velocity = -420.0
	gravity_scale = 1.0
	max_health = 100
	attack_damage = 10
	attack_range = 78.0
	attack_size = Vector2(90, 72)
	light_combo_steps = 3
	heavy_damage = 18
	heavy_range = 102.0
	heavy_size = Vector2(126, 96)
	heavy_combo_steps = 2
	special_damage = 22
	color = Color(0.42, 0.62, 0.36)
	collider_size = Vector2(48, 120)
	shake_strength = 5.0
	hit_rotation = 7.0
	combos = [
		{"nombre": "Remate", "secuencia": ["light", "heavy"], "dano": 42, "knockback": 260.0, "tamano": Vector2(162, 114), "rango": 126.0},
	]


func perform_special(player: CharacterBody2D) -> void:
	player.enable_melee(Vector2(198, 126), 156.0, special_damage, 260.0)
