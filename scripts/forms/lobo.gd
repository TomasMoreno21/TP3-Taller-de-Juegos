class_name Lobo
extends Forma


func _init() -> void:
	form_name = "Lobo"
	speed = 340.0
	jump_velocity = -500.0
	gravity_scale = 0.9
	jumps = 2
	max_health = 100
	attack_damage = 5
	attack_range = 60.0
	attack_size = Vector2(126, 78)
	light_combo_steps = 3
	heavy_damage = 8
	heavy_range = 78.0
	heavy_size = Vector2(138, 90)
	heavy_combo_steps = 2
	special_damage = 12
	color = Color(0.58, 0.64, 0.75)
	collider_size = Vector2(102, 84)
	shake_strength = 4.0
	transform_duration = 8.0
	combos = [
		{"nombre": "Mordida", "secuencia": ["light", "heavy"], "dano": 22, "knockback": 240.0, "tamano": Vector2(180, 102), "rango": 102.0},
	]


func perform_light(player: CharacterBody2D, step: int) -> void:
	player.enable_melee(attack_size, attack_range, light_damage_at(step), light_knockback)


func perform_special(player: CharacterBody2D) -> void:
	player.enable_melee(Vector2(210, 120), 180.0, special_damage, 220.0)
