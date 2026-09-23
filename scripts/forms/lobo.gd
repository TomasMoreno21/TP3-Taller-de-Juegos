class_name Lobo
extends Forma


func _init() -> void:
	form_name = "Lobo"
	speed = 690.0
	jump_velocity = -660.0
	gravity_scale = 1.22
	jumps = 2
	max_health = 100
	attack_damage = 6
	attack_range = 205.0
	attack_size = Vector2(140, 85)
	light_combo_steps = 3
	heavy_damage = 10
	heavy_range = 105.0
	heavy_size = Vector2(150, 95)
	heavy_combo_steps = 2
	special_damage = 14
	special_size = Vector2(210, 120)
	special_range = 180.0
	special_knockback = 220.0
	color = Color(0.58, 0.64, 0.75)
	collider_size = Vector2(360, 160)
	# Las patas de los PNG del lobo caen unos px por debajo de la base del collider;
	# flight_lift eleva el sprite (todas las anims: idle/AFK, run, attack) a la misma
	# altura, dejando al lobo siempre por encima del piso. Ajustable en el Inspector.
	flight_lift = 8.0
	camera_lookahead_mult = 0.9
	shake_strength = 4.0
	transform_duration = 8.0
	turn_tilt = 9.0
	lean_angulo = 4.5
	hit_zoom = 1.025
	accel = 5200.0
	friction = 5200.0
	accel_air_mult = 0.85
	coyote_time = 0.18
	jump_buffer_time = 0.20
	coyote_time = 0.18
	jump_buffer_time = 0.20
	jump_cut_multiplier = 0.35
	step_up_max = 48.0
	camera_zoom = Vector2(0.94, 0.94)
	sprint_zoom_out = 0.3
	sprint_min_speed = 300.0
	turn_tilt_cam = 0.06
	landing_squash = 0.14
	mult_recuperacion = 0.85
	recovery_early_fraccion = 0.35
	lunge_light = 110.0
	melee_sticky = 0.0
	combos = [
		{"nombre": "Mordida", "secuencia": ["light", "heavy"], "dano": 26, "knockback": 240.0, "tamano": Vector2(180, 102), "rango": 102.0},
	]


const DOUBLE_JUMP_ZIP := 320.0
const DOUBLE_JUMP_STRETCH := 0.28
const DOUBLE_JUMP_STRETCH_DURATION := 0.35


func on_second_jump(player: CharacterBody2D) -> void:
	player.apply_zip(DOUBLE_JUMP_ZIP)
	player.stretch_y(DOUBLE_JUMP_STRETCH, DOUBLE_JUMP_STRETCH_DURATION)
	var cam := player.get_viewport().get_camera_2d()
	if cam != null and cam.has_method("punch"):
		cam.punch(1.03)
	if cam != null and cam.has_method("shake"):
		cam.shake(3.0, 0.1)
	if player.has_method("_emitir_polvo"):
		player._emitir_polvo(0.7)


func perform_light(player: CharacterBody2D, step: int) -> void:
	player.enable_melee(attack_size, attack_range, light_damage_at(step), light_knockback)


func perform_special(player: CharacterBody2D) -> void:
	player.enable_melee(special_size, special_range, special_damage, special_knockback)
