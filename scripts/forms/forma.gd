class_name Forma
extends Resource

@export var form_name: String = "Forma"
@export var speed: float = 200.0
@export var jump_velocity: float = -420.0
@export var gravity_scale: float = 1.0
@export var max_health: int = 100
@export var jumps: int = 1

var _jumps_usados := 0

# Conexión de golpes: segundos desde que se inicia el ataque hasta que el daño
# puede conectar (ventana de impacto alineada al pleno swing).
@export var melee_hit_delay: float = 0.05

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
@export var special_range: float = 150.0
@export var special_size: Vector2 = Vector2(160, 90)
@export var special_knockback: float = 240.0
@export var heavy_knockback: float = 150.0
@export var special_cost: float = 0.0            # energía que cuesta cada especial (0 = gratis; si no alcanza, no sale)
@export var drenaje_mult: float = 1.0            # multiplicador del drenaje de energía mientras está transformado (>1 = dura menos)
@export var dano_recibido_mult: float = 1.0      # multiplicador del daño que recibe el jugador en esta forma (<1 = resistente, >1 = frágil)
@export var onda_transformacion_radio: float = 0.0  # al transformarse empuja/daña alrededor (0 = sin onda)
@export var onda_transformacion_dano: int = 0
@export var onda_transformacion_knockback: float = 0.0
@export var flap_impulso: float = 0.0            # aleteo en el aire: impulso hacia arriba (0 = no aletea)
@export var flap_costo: float = 0.0              # energía por aleteo
@export var salto_rot_grados: float = 0.0        # inclinación del cuerpo al subir/caer (0 = sin balanceo)
@export var salto_estiramiento: float = 0.0      # estirado vertical al subir en el aire (0 = sin)
@export var caida_estiramiento: float = 0.0      # estirado vertical al caer (0 = sin)
@export var apex_compacto: float = 0.0           # cuerpo compacto en el ápice del salto (0 = sin)
@export var congelar_en_aire: bool = true        # en el aire el ciclo de piernas se detiene (no corre en el vacío)
@export var anim_impacto: Dictionary = {"attack1": 2, "attack2": 1, "attack_full": 2, "lobo_attack": 1}   # frame de cada animación de ataque en el que conecta el golpe (se sincroniza con el daño)
@export var impacto_sostener: float = 0.07       # s que se sostiene el frame de impacto antes de recuperar
@export var special_cooldown: float = 0.0        # espera entre especiales fuera de combate (0 = sin límite)
@export var special_cooldown_combate: float = 0.0  # espera entre especiales en combate (0 = sin límite)

# Combos por secuencia (desbloqueables al subir de nivel)
# Cada entry: {"nombre", "secuencia" (Array de "light"/"heavy"/"special"), "dano", "knockback", "tamano", "rango"}
@export var combos: Array[Dictionary] = []

@export var color: Color = Color(1, 1, 1)
@export var collider_size: Vector2 = Vector2(16, 40)
@export var flight_lift: float = 0.0         # px que flota el sprite sobre su base (volar/planeo)
@export var hit_zoom: float = 1.02
@export var shake_golpe_ligero: float = 7.5
@export var shake_golpe_pesado: float = 12.0
@export var shake_golpe_combo: float = 15.0
@export var lean_angulo: float = 3.0   # inclinación leve del sprite según velocidad (grados)

# Inercia de movimiento (Ítem 5): aceleración al arrancar (más alto = más ágil)
# y rozamiento al soltar el input (más alto = frena más seco, bajo = derrapa).
@export var accel: float = 2400.0
@export var friction: float = 2200.0
@export var accel_air_mult: float = 0.65
@export var jump_h_speed_mult: float = 1.0   # velocidad horizontal máx en el aire (1.0 = igual que en el piso)
@export var despegue_speed_mult: float = 0.0 # arranca el salto a esta fracción de speed si hay input direccional (0 = off)
@export var coyote_time: float = 0.14
@export var jump_buffer_time: float = 0.18
@export var jump_cut_multiplier: float = 0.42
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
@export var lunge_light: float = 0.0     # px que avanza el cuerpo al dar un golpe ligero (0 = sin avance)
@export var lunge_heavy: float = 0.0     # ídem golpe pesado
@export var lunge_combo: float = 0.0     # ídem remate del combo
@export var melee_sticky: float = 0.0               # persecución al enemigo durante el golpe activo (0 = golpe estático)
# Early-exit (Capcom): al pasar este % del recovery se libera movimiento/salto/chain.
# El recovery largo queda solo en el finisher del combo (0 = early-exit desactivado).
@export var recovery_early_fraccion: float = 0.35


## Avance (px) del cuerpo al golpear. Las formas pueden variarlo por paso del combo.
func lunge_para(tipo: String, _step: int) -> float:
	match tipo:
		"light":
			return lunge_light
		"heavy":
			return lunge_heavy
		"combo":
			return lunge_combo
	return 0.0


## Retardo hasta que el golpe puede conectar (sincronizar con el frame del impacto).
func hit_delay_para(_tipo: String, _step: int) -> float:
	return melee_hit_delay


## Multiplicador de recuperación por golpe (el cierre de una cadena puede ser más lento).
func mult_recuperacion_para(_tipo: String, _step: int) -> float:
	return mult_recuperacion


## Frame de la animación de ataque desde el que arranca (saltear la preparación en golpes encadenados).
func anim_frame_inicio(_tipo: String, _step: int) -> int:
	return 0


## Pose extra del sprite al golpear (rotación/estirón); cada forma la define a su gusto.
func pose_ataque(_player: CharacterBody2D, _tipo: String, _step: int) -> void:
	pass


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
	if despegue_speed_mult > 0.0:
		var dir_jump := Input.get_axis("move_left", "move_right")
		if absf(dir_jump) > 0.1:
			player.velocity.x = clampf(dir_jump * speed * despegue_speed_mult, -max_h, max_h)
	player.set("_salto_aereo_limitado", true)
	if player.has_method("_emitir_polvo"):
		player._emitir_polvo(0.6)
	_jumps_usados += 1
	player.set("_coyote_time", 0.0)   # el salto ya gastó el coyote (si no, un 2.º toque "salta" en falso y bloquea el aleteo)
	if player.has_method("_sonido_salto"):
		player._sonido_salto(_jumps_usados)
	if _jumps_usados >= 2:
		on_second_jump(player)


func on_second_jump(_player: CharacterBody2D) -> void:
	pass


func can_jump() -> bool:
	return _jumps_usados < jumps


func on_floor(_player: CharacterBody2D) -> void:
	_jumps_usados = 0


## Al pasar el coyote time en el aire sin haber saltado, el salto "de suelo" se pierde
## (caminar fuera de un borde no regala un salto extra).
func perder_salto_suelo() -> void:
	if _jumps_usados == 0:
		_jumps_usados = 1


func on_landing(_player: CharacterBody2D, _fall_impact: float) -> void:
	pass


func light_damage_at(step: int) -> int:
	return attack_damage + attack_damage / 2 * (step - 1)


func heavy_damage_at(step: int) -> int:
	return heavy_damage + heavy_damage / 2 * (step - 1)


func perform_light(player: CharacterBody2D, step: int) -> void:
	player.enable_melee(attack_size, attack_range, light_damage_at(step), light_knockback)


func perform_heavy(player: CharacterBody2D, step: int) -> void:
	player.enable_melee(heavy_size, heavy_range, heavy_damage_at(step), heavy_knockback)


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
		player.enable_melee(heavy_size, heavy_range, heavy_damage, heavy_knockback)
	else:
		player.enable_melee(attack_size, attack_range, attack_damage, light_knockback)


func reset_form_state() -> void:
	_jumps_usados = 0
