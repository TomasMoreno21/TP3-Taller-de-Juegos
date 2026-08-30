class_name Lobo
extends Forma


func _init() -> void:
	form_name = "Lobo"
	speed = 690.0
	jump_velocity = -540.0
	gravity_scale = 0.9
	jumps = 2
	max_health = 100
	attack_damage = 6
	attack_range = 110.0
	attack_size = Vector2(140, 85)
	light_combo_steps = 3
	heavy_damage = 10
	heavy_range = 105.0
	heavy_size = Vector2(150, 95)
	heavy_combo_steps = 2
	special_damage = 14
	color = Color(0.58, 0.64, 0.75)
	collider_size = Vector2(210, 160)
	camera_lookahead_mult = 1.15
	shake_strength = 4.0
	transform_duration = 8.0
	turn_tilt = 9.0
	lean_angulo = 4.5
	hit_zoom = 1.015
	accel = 4200.0
	friction = 3600.0
	camera_zoom = Vector2(0.94, 0.94)
	sprint_zoom_out = 0.04
	sprint_min_speed = 420.0
	turn_tilt_cam = 0.06
	landing_squash = 0.08
	mult_recuperacion = 0.85
	lunge_light = 110.0
	combos = [
		{"nombre": "Mordida", "secuencia": ["light", "heavy"], "dano": 26, "knockback": 240.0, "tamano": Vector2(180, 102), "rango": 102.0},
	]


const DOUBLE_JUMP_ZIP := 320.0
const DOUBLE_JUMP_STRETCH := 0.28
const DOUBLE_JUMP_STRETCH_DURATION := 0.35


func on_second_jump(player: CharacterBody2D) -> void:
	player.apply_zip(DOUBLE_JUMP_ZIP)
	player.stretch_y(DOUBLE_JUMP_STRETCH, DOUBLE_JUMP_STRETCH_DURATION)


func perform_light(player: CharacterBody2D, step: int) -> void:
	player.enable_melee(attack_size, attack_range, light_damage_at(step), light_knockback)


func perform_special(player: CharacterBody2D) -> void:
	player.enable_melee(Vector2(210, 120), 180.0, special_damage, 220.0)
