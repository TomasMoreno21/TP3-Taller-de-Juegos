class_name Lobo
extends Forma


func _init() -> void:
	form_name = "Lobo"
	speed = 690.0
	jump_velocity = -660.0
	gravity_scale = 1.22
	jumps = 2
	max_health = 100
	melee_hit_delay = 0.04
	attack_damage = 8
	attack_range = 205.0
	attack_size = Vector2(140, 85)
	light_combo_steps = 3
	heavy_damage = 13
	heavy_range = 105.0
	heavy_size = Vector2(150, 95)
	heavy_combo_steps = 2
	special_damage = 18
	special_size = Vector2(210, 120)
	special_range = 180.0
	special_knockback = 220.0
	special_cost = 4.0
	color = Color(0.58, 0.64, 0.75)
	collider_size = Vector2(360, 160)
	# Las patas de los PNG del lobo caen unos px por debajo de la base del collider;
	# flight_lift eleva el sprite (todas las anims: idle/AFK, run, attack) a la misma
	# altura, dejando al lobo siempre por encima del piso. Ajustable en el Inspector.
	flight_lift = 8.0
	camera_lookahead_mult = 1.1
	lean_angulo = 4.5
	salto_rot_grados = 7.0   # inclinación leve al subir/caer
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
	camera_zoom = Vector2(0.87, 0.87)
	sprint_zoom_out = 0.16
	sprint_min_speed = 300.0
	turn_tilt_cam = 0.06
	landing_squash = 0.14
	mult_recuperacion = 0.85
	recovery_early_fraccion = 0.35
	lunge_light = 40.0
	lunge_heavy = 80.0
	lunge_combo = 130.0
	melee_sticky = 0.0
	combos = [
		{"nombre": "Mordida", "secuencia": ["light", "heavy"], "dano": 40, "knockback": 240.0, "tamano": Vector2(180, 102), "rango": 102.0},
	]


const DOUBLE_JUMP_ZIP := 320.0
const DOUBLE_JUMP_STRETCH := 0.28
const DOUBLE_JUMP_STRETCH_DURATION := 0.35


func on_second_jump(player: CharacterBody2D) -> void:
	player.apply_zip(DOUBLE_JUMP_ZIP)
	var cam := player.get_viewport().get_camera_2d()
	if cam != null and cam.has_method("punch"):
		cam.punch(1.03)
	if cam != null and cam.has_method("shake"):
		cam.shake(3.0, 0.1)
	if player.has_method("_emitir_polvo"):
		player._emitir_polvo(0.7)


## Cadena de mordidas: 1.º salto corto, 2.º ya en carrera (más avance, sin preparación),
## 3.º remate largo con más pausa. Cada golpe cambia pose, avance, impacto y recuperación.
func lunge_para(tipo: String, step: int) -> float:
	var base := super.lunge_para(tipo, step)
	if tipo == "light":
		return base * (1.0 if step <= 1 else (1.35 if step == 2 else 2.0))
	if tipo == "heavy" and step >= 2:
		return base * 1.4
	return base


func hit_delay_para(tipo: String, step: int) -> float:
	match tipo:
		"light":
			return 0.06 if step != 2 else 0.03   # el 2.º ya viene lanzado: muerde antes
		"heavy":
			return 0.07 if step <= 1 else 0.05
		"combo":
			return 0.06
	return melee_hit_delay


func mult_recuperacion_para(tipo: String, step: int) -> float:
	if tipo == "light" and step >= light_combo_steps:
		return 1.3   # el cierre de la cadena se toma su tiempo: ritmo rápido-rápido-mordida
	return mult_recuperacion


func anim_frame_inicio(tipo: String, step: int) -> int:
	if (tipo == "light" or tipo == "heavy") and step == 2:
		return 1     # saltea el agazapado: ya está en pleno salto
	return 0


func pose_ataque(player: CharacterBody2D, tipo: String, step: int) -> void:
	match tipo:
		"light":
			player.pose_ataque([3.0, 6.0, 10.0][clampi(step - 1, 0, 2)], [0.05, 0.08, 0.14][clampi(step - 1, 0, 2)])
		"heavy":
			player.pose_ataque(8.0 + 4.0 * float(step - 1), 0.12 + 0.04 * float(step - 1))
		"combo":
			player.pose_ataque(14.0, 0.18)


func perform_light(player: CharacterBody2D, step: int) -> void:
	player.enable_melee(attack_size, attack_range, light_damage_at(step), light_knockback)


func perform_special(player: CharacterBody2D) -> void:
	player.enable_melee(special_size, special_range, special_damage, special_knockback)
