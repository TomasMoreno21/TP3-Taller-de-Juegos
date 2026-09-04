class_name Forma
extends Resource

@export var form_name: String = "Forma"
@export var speed: float = 200.0
@export var jump_velocity: float = -420.0
@export var gravity_scale: float = 1.0
@export var max_health: int = 100
@export var jumps: int = 1

var _jumps_usados := 0

# Combo ligero (repetición de J)
@export var attack_damage: int = 10
@export var attack_range: float = 26.0
@export var attack_size: Vector2 = Vector2(30, 24)
@export var light_combo_steps: int = 3
@export var light_knockback: float = 150.0

# Combo fuerte (repetición de K)
@export var heavy_damage: int = 20
@export var heavy_range: float = 36.0
@export var heavy_size: Vector2 = Vector2(44, 34)
@export var heavy_combo_steps: int = 2

# Ataque especial (L)
@export var special_damage: int = 25
@export var special_cooldown: float = 0.0        # espera entre especiales fuera de combate (0 = sin límite)
@export var special_cooldown_combate: float = 0.0  # espera entre especiales en combate (0 = sin límite)

# Combos por secuencia (desbloqueables al subir de nivel)
# Cada entry: {"nombre", "secuencia" (Array de "light"/"heavy"/"special"), "dano", "knockback", "tamano", "rango"}
@export var combos: Array[Dictionary] = []

@export var color: Color = Color(1, 1, 1)
@export var collider_size: Vector2 = Vector2(16, 40)
@export var shake_strength: float = 8.0
@export var shake_duration: float = 0.15
@export var hit_rotation: float = 14.0
@export var hit_zoom: float = 1.02
@export var shake_golpe_ligero: float = 7.5
@export var shake_golpe_pesado: float = 12.0
@export var shake_golpe_combo: float = 15.0
@export var transform_duration: float = 14.0
@export var turn_tilt: float = 0.0
@export var lean_angulo: float = 3.0   # inclinación leve del sprite según velocidad (grados)

# Inercia de movimiento (Ítem 5): aceleración al arrancar (más alto = más ágil)
# y rozamiento al soltar el input (más alto = frena más seco, bajo = derrapa).
@export var accel: float = 2400.0
@export var friction: float = 2200.0
@export var accel_air_mult: float = 0.65
@export var jump_h_speed_mult: float = 1.0   # velocidad horizontal máx en el aire (1.0 = igual que en el piso)
@export var coyote_time: float = 0.14
@export var jump_buffer_time: float = 0.18
@export var step_up_max: float = 48.0     # altura máx (px) que sube solo al caminar contra un borde

# Game feel de cámara por forma.
@export var camera_zoom: Vector2 = Vector2.ONE        # zoom objetivo al estar transformado
@export var sprint_zoom_out: float = 0.0              # zoom-out extra al correr (Lobo)
@export var sprint_min_speed: float = 99999.0         # velocidad para activar el zoom de sprint
@export var landing_squash: float = 0.0               # squash al aterrizar (proporcional a impacto)
@export var turn_tilt_cam: float = 0.0                # inclinación de cámara transitoria al girar
@export var camera_lookahead_mult: float = 1.0        # multiplicador de lookahead por forma

# Fluidez de combate: multiplicador de recuperación post-golpe (menor = encadena más rápido)
# e impulso hacia adelante al golpear (lunge; 0 = golpe estático).
@export var mult_recuperacion: float = 1.0
@export var lunge_light: float = 70.0
@export var lunge_heavy: float = 150.0
@export var melee_sticky: float = 0.0               # persecución al enemigo durante el golpe activo (0 = golpe estático)


func tick(_player: CharacterBody2D, _delta: float) -> void:
	pass


func is_dashing() -> bool:
	return false


func dash_speed() -> float:
	return 0.0


func is_gliding(_player: CharacterBody2D) -> bool:
	return false


func try_jump(player: CharacterBody2D) -> void:
	if _jumps_usados >= jumps:
		return
	if player.has_method("squash_y"):
		player.squash_y(0.14, 0.08)
	var vel_factor := clampf(absf(player.velocity.x) / maxf(speed, 1.0), 0.0, 1.0)
	player.velocity.y = jump_velocity * (1.0 + 0.08 * vel_factor)
	var max_h := speed * jump_h_speed_mult
	player.velocity.x = clampf(player.velocity.x, -max_h, max_h)
	player.set("_salto_aereo_limitado", true)
	if player.has_method("stretch_y"):
		player.stretch_y(0.18, 0.2)
	if player.has_method("_emitir_polvo"):
		player._emitir_polvo(0.6)
	_jumps_usados += 1
	if _jumps_usados >= 2:
		on_second_jump(player)


func on_second_jump(_player: CharacterBody2D) -> void:
	pass


func can_jump() -> bool:
	return _jumps_usados < jumps


func on_floor(_player: CharacterBody2D) -> void:
	_jumps_usados = 0


func on_landing(_player: CharacterBody2D, _fall_impact: float) -> void:
	pass


func light_damage_at(step: int) -> int:
	return attack_damage + attack_damage / 2 * (step - 1)


func heavy_damage_at(step: int) -> int:
	return heavy_damage + heavy_damage / 2 * (step - 1)


func perform_light(player: CharacterBody2D, step: int) -> void:
	player.enable_melee(attack_size, attack_range, light_damage_at(step), light_knockback)


func perform_heavy(player: CharacterBody2D, step: int) -> void:
	player.enable_melee(heavy_size, heavy_range, heavy_damage_at(step), 150.0)


func perform_special(_player: CharacterBody2D) -> void:
	pass


func perform_combo(player: CharacterBody2D, combo: Dictionary) -> void:
	player.enable_melee(
		combo.get("tamano", attack_size),
		combo.get("rango", attack_range),
		combo.get("dano", attack_damage),
		combo.get("knockback", 200.0)
	)


func perform_jump_attack(player: CharacterBody2D, heavy: bool) -> void:
	if heavy:
		player.enable_melee(heavy_size, heavy_range, heavy_damage)
	else:
		player.enable_melee(attack_size, attack_range, attack_damage)


func reset_form_state() -> void:
	_jumps_usados = 0
