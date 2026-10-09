class_name Murcielago
extends Forma


func _init() -> void:
	form_name = "Murciélago"
	speed = 380.0
	jump_velocity = -400.0
	gravity_scale = 0.50
	max_health = 100
	melee_hit_delay = 0.06
	attack_damage = 9
	attack_range = 90.0
	attack_size = Vector2(110, 70)
	light_combo_steps = 3
	heavy_damage = 14
	heavy_range = 110.0
	heavy_size = Vector2(130, 85)
	heavy_combo_steps = 2
	special_damage = 15
	dano_recibido_mult = 1.1
	special_cost = 5.0
	flap_impulso = 330.0
	flap_costo = 4.0
	special_cooldown = 0.3
	special_cooldown_combate = 0.6
	color = Color(0.52, 0.4, 0.62)
	collider_size = Vector2(135, 133)
	flight_lift = 52.0
	camera_lookahead_mult = 1.0
	lean_angulo = 3.5
	accel = 3000.0
	friction = 2000.0
	accel_air_mult = 0.65
	coyote_time = 0.16
	jump_buffer_time = 0.18
	jump_cut_multiplier = 0.20
	camera_zoom = Vector2(0.88, 0.88)
	landing_squash = 0.06
	mult_recuperacion = 1.4
	recovery_early_fraccion = 0.4
	melee_sticky = 0.0
	step_up_max = 16.0   # sube escalones chicos (rampas suaves) pero no obstáculos
	combos = [
		{"nombre": "Ala Cortante", "secuencia": ["light", "heavy"], "dano": 32, "knockback": 240.0, "tamano": Vector2(192, 102), "rango": 114.0},
	]


const PICADA_VELOCIDAD := 760.0
const PICADA_ONDA_RADIO := 170.0
const PICADA_ONDA_DANO := 12
const PICADA_ONDA_KNOCKBACK := 260.0


## Picada: cae en vertical a toda velocidad; al tocar el suelo, onda corta alrededor.
func on_landing(player: CharacterBody2D, _fall_impact: float) -> void:
	if player.get("_picada"):
		player.set("_picada", false)
		player.onda_area(PICADA_ONDA_RADIO, PICADA_ONDA_DANO, PICADA_ONDA_KNOCKBACK, false)
		player.squash_y(0.4, 0.1)
		var cam := player.get_viewport().get_camera_2d()
		if cam != null and cam.has_method("shake"):
			cam.shake(7.0)


func is_gliding(player: CharacterBody2D) -> bool:
	return Input.is_action_pressed("jump") and not player.is_on_floor() and player.velocity.y > 0.0


func perform_special(player: CharacterBody2D) -> void:
	player.fire_projectile()