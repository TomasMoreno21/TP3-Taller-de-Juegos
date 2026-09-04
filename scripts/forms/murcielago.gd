class_name Murcielago
extends Forma


func _init() -> void:
	form_name = "Murciélago"
	speed = 380.0
	jump_velocity = -350.0
	gravity_scale = 0.65
	max_health = 100
	attack_damage = 8
	attack_range = 90.0
	attack_size = Vector2(110, 70)
	light_combo_steps = 3
	heavy_damage = 14
	heavy_range = 110.0
	heavy_size = Vector2(130, 85)
	heavy_combo_steps = 2
	special_damage = 15
	special_cooldown = 0.8
	special_cooldown_combate = 2.0
	color = Color(0.52, 0.4, 0.62)
	collider_size = Vector2(160, 286)
	camera_lookahead_mult = 1.0
	transform_duration = 9.0
	turn_tilt = 9.0
	lean_angulo = 3.5
	accel = 2400.0
	friction = 2000.0
	accel_air_mult = 0.65
	coyote_time = 0.14
	jump_buffer_time = 0.18
	camera_zoom = Vector2(0.95, 0.95)
	landing_squash = 0.06
	mult_recuperacion = 1.8
	melee_sticky = 550.0
	combos = [
		{"nombre": "Ala Cortante", "secuencia": ["light", "heavy"], "dano": 32, "knockback": 240.0, "tamano": Vector2(192, 102), "rango": 114.0},
	]


func is_gliding(player: CharacterBody2D) -> bool:
	return Input.is_action_pressed("jump") and not player.is_on_floor() and player.velocity.y > 0.0


func perform_special(player: CharacterBody2D) -> void:
	player.fire_projectile()