extends Camera2D

signal modo_cambio(modo: String)

var _shake_timer := 0.0
var _shake_strength := 0.0
var _modo := "seguir"
var _fija_pos := Vector2.ZERO
var _zoom_objetivo := Vector2.ONE
var _punch_scale := 1.0
var _tilt := 0.0
var _lookahead_actual := 0.0
var _zoom_velocidad := 1.0
var _framing_scale := 1.0
var _arena_tween: Tween
var _descenso_t := 0.0
var _offset_descenso := 0.0
var _look_offset := Vector2.ZERO

@export var suavizado := 6.0
@export var desplazamiento := Vector2(0, -220)
@export var suavizado_zoom := 5.0
@export var lookahead := 0.28    # anticipación de cámara según velocidad horizontal
@export var lookahead_umbral := 100.0    # velocidad (px/s) recién pasada la cual empieza el adelanto
@export var lookahead_ataque := 140.0    # adelanto fijo (px) hacia el facing mientras se ataca
@export var suavizado_lookahead := 3.0  # qué tan suave entra y sale el adelanto
@export var deadzone_horizontal := 24.0  # zona muerta en X (traga micro-correcciones, evita temblor)
@export var deadzone_vertical := 200.0  # salto dentro de este rango casi no mueve la cámara al subir (pico Humano=184)
@export var seguimiento_vertical_leve := 0.15  # cuánto sí se mueve dentro de la deadzone al subir
@export var suavizado_subida := 2.2  # al subir: lento
@export var suavizado_bajada := 7.0  # al bajar: brusco y rápido
@export var tiempo_descenso_extendido := 0.7  # segundos planeando/bajando para anticipar abajo
@export var offset_descenso_extendido := 420.0  # px que baja más la cámara en descenso prolongado
@export var suavizado_descenso_extendido := 4.0  # qué tan suave entra/sale ese offset extra
@export var look_stick_amplitud := 220.0  # px máximos que desplaza la cámara el stick derecho
@export var look_stick_suavizado := 5.0  # suavizado del desplazamiento del stick derecho
@export var intensidad_shake := 1.0  # multiplicador global del shake (0 = desactivado; accesibilidad)
# Restauración al suelo: al aterrizar en la misma línea de piso que antes del
# salto, recentra rápido a la altura recordada (anti-bob / sin deriva vertical).
@export var restaurar_suelo := true
@export var restaura_tolerancia := 12.0  # px de diferencia de altura para considerar "mismo piso"
@export var restaura_ventana := 0.15  # s que dura el recentrado tras aterrizar
# Zoom por velocidad: aporte único y acotado (disciplina de zoom transversal).
@export var zoom_velocidad_min := 200.0  # velocidad (px/s) a la que empieza a alejar
@export var zoom_velocidad_rango := 450.0  # rango de velocidad hasta el alejamiento máximo
@export var zoom_velocidad_max := 0.05  # alejamiento máximo por velocidad (antes 0.08)
# Anticipación de salto: predice el pico del arco y lo encuadra con curva suave
@export var gravedad_referencia := 980.0
@export var anticip_apex_max := 110.0  # px máximos que sube el encuadre al predecir el pico
@export var anticip_apex_umbral := -120.0  # velocidad vertical (vy) que dispara la anticipación
@export var anticip_apex_factor := 0.5  # fracción del pico calculado que se acomoda
@export var suavizado_apex := 3.0  # suavizado al subir; al bajar reusa suavizado_bajada

var _apex_look := 0.0
var _shake_dir := Vector2.ZERO
var _shake_rot_amplitud := 0.0
var _shake_duracion := 0.15
var _suelo_y := INF
var _restaura_t := 0.0
var _vuelo_previo := false


func _ready() -> void:
	_modo = "seguir"
	_zoom_objetivo = zoom
	# Arranca ya encuadrada sobre el jugador (evita que al cargar el nivel la
	# cámara muestre la esquina del mundo mientras el diálogo de introducción corre).
	var player := get_tree().get_first_node_in_group("player") as Node2D
	if player != null:
		global_position = player.global_position + desplazamiento


## True mientras el jugador planea (murciélago) o cae de forma sostenida.
func _bajando_prolongado(player: Node) -> bool:
	if "forms" in player and "current_form" in player and "velocity" in player:
		var fg = (player as Node).get("forms")[(player as Node).get("current_form")]
		if fg != null and fg.has_method("is_gliding"):
			if fg.call("is_gliding", player):
				return true
		if not (player as CharacterBody2D).is_on_floor() and (player as CharacterBody2D).velocity.y > 60.0:
			return true
	return false


func _process(delta: float) -> void:
	# Desplazamiento de cámara con stick derecho del joystick.
	var look_dir := Vector2(Input.get_axis("cam_izq", "cam_der"), Input.get_axis("cam_arr", "cam_abj"))
	_look_offset = _look_offset.lerp(look_dir * look_stick_amplitud, minf(look_stick_suavizado * delta, 1.0))
	if _shake_timer > 0.0:
		_shake_timer -= delta
		var t := clampf(_shake_timer / _shake_duracion, 0.0, 1.0) if _shake_duracion > 0.0 else 1.0
		var cur_strength := _shake_strength * (t * t) * intensidad_shake
		if _shake_dir == Vector2.ZERO:
			offset = Vector2(randf_range(-1, 1), randf_range(-1, 1)) * cur_strength + _look_offset
		else:
			var perp := Vector2(-_shake_dir.y, _shake_dir.x)
			var despl := _shake_dir * cur_strength + perp * randf_range(-1, 1) * cur_strength * 0.6
			offset = despl + _look_offset
		if _shake_rot_amplitud > 0.0:
			rotation = rotation * (1.0 - minf(8.0 * delta, 1.0)) + deg_to_rad(randf_range(-_shake_rot_amplitud, _shake_rot_amplitud)) * t
		if _shake_timer <= 0.0:
			offset = _look_offset
			_shake_dir = Vector2.ZERO
			_shake_rot_amplitud = 0.0
	else:
		offset = _look_offset

	# Zoom por velocidad (1) + punch + encuadre de arena
	var objetivo := _zoom_objetivo * _punch_scale * _zoom_velocidad * _framing_scale
	if zoom.distance_to(objetivo) > 0.0001:
		zoom = zoom.lerp(objetivo, minf(suavizado_zoom * delta, 1.0))
	else:
		zoom = objetivo

	# El punch de zoom recupera con curva suave (ease out).
	if _punch_scale > 1.0:
		_punch_scale = lerpf(_punch_scale, 1.0, minf(4.0 * delta, 1.0))

	# Tilt de cámara transitorio (giro de Lobo) -> recupera a 0.
	if absf(_tilt) > 0.01:
		rotation = lerpf(rotation, 0.0, minf(suavizado * 0.5 * delta, 1.0))
		if absf(rotation) < 0.01:
			_tilt = 0.0
			rotation = 0.0


func _physics_process(delta: float) -> void:
	if _modo == "fija":
		global_position = global_position.lerp(_fija_pos, minf(suavizado * delta, 1.0))
		return

	var player := get_tree().get_first_node_in_group("player")
	if player == null:
		return
	var trepando: bool = false
	if player is Node:
		var tv = (player as Node).get("_trepando")
		if tv != null:
			trepando = bool(tv)
	var desp := Vector2(0, -180) if trepando else desplazamiento
	var destino := (player as Node2D).global_position + desp
	# (2) Anticipación de salto: predice el pico del arco según la gravedad
	# de la forma activa y encuadra un poco más arriba con curva suave.
	var vel_y: float = (player as Node2D).velocity.y
	var apex_objetivo := 0.0
	if vel_y < anticip_apex_umbral:
		var grav_mult := 1.0
		if "forms" in player and "current_form" in player:
			var f_apex = (player as Node).get("forms")[(player as Node).get("current_form")]
			if f_apex != null and "gravity_scale" in f_apex:
				var gs: Variant = f_apex.get("gravity_scale")
				if gs != null:
					grav_mult = float(gs)
		var g_ef := gravedad_referencia * maxf(grav_mult, 0.1)
		var pico := (-vel_y) * (-vel_y) / (2.0 * g_ef)
		apex_objetivo = -minf(pico * anticip_apex_factor, anticip_apex_max)
	var suav_apex := suavizado_apex if apex_objetivo < _apex_look else suavizado_bajada
	_apex_look = lerpf(_apex_look, apex_objetivo, minf(suav_apex * delta, 1.0))
	destino.y += _apex_look
	# (3) Bajar 20px antes de caer fuerte (anticipa impacto)
	var p_body := player as CharacterBody2D
	if vel_y > 550.0 and not p_body.is_on_floor():
		destino.y += 20.0
	# (1) Zoom por velocidad + (7) suavizado de bajada si planea
	var vel_x: float = (player as Node2D).velocity.x
	var look_mult := 1.0
	if trepando:
		look_mult = 0.22
	elif "forms" in player and "current_form" in player:
		var f = (player as Node).get("forms")[(player as Node).get("current_form")]
		if f != null and "camera_lookahead_mult" in f:
			look_mult = f.get("camera_lookahead_mult")
	# Al atacar el adelanto se congela hacia el facing del golpe (legibilidad en
	# combate: no sigue empujando junto a la velocidad de movimiento).
	var atacando: bool = false
	var atacando_dir := 0.0
	if "_attacking" in (player as Node) and "facing" in (player as Node):
		atacando = bool((player as Node).get("_attacking"))
		if atacando:
			atacando_dir = signf(float((player as Node).get("facing")))
	var objetivo_la := clampf(atacando_dir * lookahead_ataque, -160.0, 160.0) if atacando \
		else clampf(maxf(absf(vel_x) - lookahead_umbral, 0.0) * lookahead * look_mult * signf(vel_x), -160.0, 160.0)
	_lookahead_actual = lerpf(_lookahead_actual, objetivo_la, minf(suavizado_lookahead * delta, 1.0))
	destino.x += _lookahead_actual
	if absf(destino.x - global_position.x) < deadzone_horizontal:
		destino.x = global_position.x
	# (1) Zoom por velocidad: min→0, min+rango→máx (aporte único y acotado).
	var extra_zoom := clampf((absf(vel_x) - zoom_velocidad_min) / zoom_velocidad_rango, 0.0, 1.0) * zoom_velocidad_max
	_zoom_velocidad = 1.0 - extra_zoom
	# Vertical asimétrico: subir lento (deadzone + suavizado bajo), bajar brusco (7) o suave si planea (4) — trepando enfoca vertical
	var dz_vert := 40.0 if trepando else deadzone_vertical
	var suav_up := 3.2 if trepando else suavizado_subida
	var dy = destino.y - global_position.y
	var suavizado_y: float
	if dy < 0:
		if absf(dy) < dz_vert:
			var seg := 0.45 if trepando else seguimiento_vertical_leve
			destino.y = global_position.y + dy * seg
		suavizado_y = suav_up
	else:
		var gliding := false
		if "forms" in player and "current_form" in player:
			var fg = (player as Node).get("forms")[(player as Node).get("current_form")]
			if fg != null and fg.has_method("is_gliding"):
				gliding = fg.call("is_gliding", player)
		suavizado_y = 3.0 if trepando else (4.0 if gliding else suavizado_bajada)
	# (9) Descenso/planeo prolongado: desplaza la cámara hacia abajo para
	# mostrar la zona de abajo antes de que el jugador la alcance.
	var bajando_extendido := _bajando_prolongado(player)
	if bajando_extendido:
		_descenso_t += delta
	else:
		_descenso_t = 0.0
	var objetivo_offset := offset_descenso_extendido if _descenso_t >= tiempo_descenso_extendido else 0.0
	_offset_descenso = lerpf(_offset_descenso, objetivo_offset, minf(suavizado_descenso_extendido * delta, 1.0))
	destino.y += _offset_descenso

	# (10) Restauración al suelo: si al aterrizar la altura es la misma que la
	# del piso del que se salió (dentro de la tolerancia), recentra rápido a esa
	# línea recordada en vez de quedar derivado por el apex del salto.
	if not trepando:
		var target_suelo := (player as Node2D).global_position.y + desp.y
		if p_body.is_on_floor():
			if _vuelo_previo and restaurar_suelo and absf(target_suelo - _suelo_y) <= restaura_tolerancia:
				_restaura_t = restaura_ventana
			if _restaura_t > 0.0:
				destino.y = _suelo_y
				suavizado_y = maxf(suavizado_y, suavizado_bajada)
				_restaura_t = maxf(_restaura_t - delta, 0.0)
			else:
				_suelo_y = target_suelo
			_vuelo_previo = false
		else:
			_vuelo_previo = true
			if _suelo_y == INF:
				_suelo_y = target_suelo

	global_position.x = lerpf(global_position.x, destino.x, minf(suavizado * delta, 1.0))
	global_position.y = lerpf(global_position.y, destino.y, minf(suavizado_y * delta, 1.0))


func fijar_zoom(objetivo: Vector2) -> void:
	_zoom_objetivo = objetivo


func punch(escala: float = 1.03) -> void:
	_punch_scale = maxf(_punch_scale, escala)


func tilt(angulo: float) -> void:
	_tilt = angulo
	rotation = angulo


func modo_arena(centro: Vector2) -> void:
	_modo = "fija"
	_fija_pos = centro
	global_position = centro
	modo_cambio.emit("arena")


func modo_normal() -> void:
	_modo = "seguir"
	modo_cambio.emit("seguir")
	var player := get_tree().get_first_node_in_group("player") as Node2D
	if player != null:
		var dest := player.global_position + desplazamiento
		var tw := create_tween()
		tw.tween_property(self, "global_position", dest, 0.8).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)


## Encuadre de arena: aleja la cámara un toque (escala < 1) al entrar a una arena
## para leer el escenario y vuelve suave al zoom normal. Multiplicador aparte:
## no estorba al zoom punch/golpes (que recuperan por su cuenta).
func encuadre_arena(escala_out: float = 0.96, duracion: float = 0.7) -> void:
	if _arena_tween != null and _arena_tween.is_valid():
		_arena_tween.kill()
	_arena_tween = create_tween()
	_arena_tween.tween_property(self, "_framing_scale", escala_out, 0.2).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_arena_tween.tween_property(self, "_framing_scale", 1.0, duracion).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)


func shake(strength: float = 8.0, duration: float = 0.15, dir: Vector2 = Vector2.ZERO) -> void:
	_shake_timer = duration
	_shake_duracion = duration
	_shake_strength = strength
	_shake_dir = dir.normalized() if dir.length_squared() > 0.0 else Vector2.ZERO
	if _shake_rot_amplitud <= 0.0:
		_shake_rot_amplitud = clampf(strength * 0.12 * intensidad_shake, 0.0, 0.2)
