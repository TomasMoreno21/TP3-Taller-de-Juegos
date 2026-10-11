extends CharacterBody2D

signal died

const GRAVITY := 980.0
const MAX_FALL_SPEED := 950.0

@export var tipo: String = "cultista"
@export var enemy_data: Enemigo
@export var ola_asignada: int = 0          # a qué ola pertenece (enemigo manual del Encounter)
const TELEGRAFIA := preload("res://scripts/telegrafia_enemigo.gd")

@export var spawn_telegrafiado: bool = false  # aparece con el círculo ritual antes de actuar
@export var ritual_duracion: float = 0.7  # tiempo del círculo ritual antes de que el enemigo actúe
@export var sonido_golpe: AudioStream
@export var sonido_rebote: AudioStream = preload("res://assets/audio/sfx/gen/bloqueo.wav")   ## suena cuando un golpe cuerpo a cuerpo rebota contra un flotante
@export var volumen_rebote_db := -4.0
@export var sonido_muerte: AudioStream = preload("res://assets/audio/sfx/gen/enemigo_muerte.wav")
@export var sonido_disparo: AudioStream = preload("res://assets/audio/sfx/gen/arquero_disparo.wav")
@export var volumen_sfx_db := -10.0
@export var volumen_golpe_db := 0.0
@export var perseguir_fuera_rango: bool = false  # los proyectiles se quedan donde spawnnean y atacan a rango
@export var limite_caida := 6000.0
@export var stun_tilt_angulo := 14.0         # inclinación de la pose de stun (grados)
@export var stun_recuperar_tiempo := 0.06    # qué tan rápido vuelve a la vertical tras el stun
# Flinch caricaturesco: corte seco hacia adelante, pop de escala al reanudar y
# congelación del frame de la animación durante el hitstun.
@export var flinch_adelanto_px := 12.0        # px que se adelanta el cuerpo en el impacto
@export var flinch_pop_escala := 1.12         # escala del "pop" al recuperar la pose
@export var flinch_congela_anim := false      # true = congela la animación durante todo el stun (se ve trabado si seguís pegando)
@export var frames_impacto := {"attack1": 3, "attack2": 2}   # frame de cada animación de ataque en el que cae el tajo (se sincroniza con el daño)
@export var stun_anim := "idle"               # animación que sigue viva durante el stun ("" = la que corresponda al movimiento)
@export var max_atacantes_melee := 2          # cuántos cuerpo a cuerpo pueden estar atacando a la vez (los demás esperan)
@export var flash_aviso := Color(1.25, 1.2, 1.2)  # leve brillo al iniciar un ataque (aviso de lectura)
@export_group("Anticipación del ataque")
@export var ant_retroceso := 9.0      # px que se echa atrás antes de pegar
@export var ant_inclinacion := 0.12   # rad que se inclina hacia atrás
@export var ant_achatar := 0.08       # cuánto se achata (0.08 = 8 %)
@export var ant_temblor := 1.6        # px de temblor al final de la preparación
@export_group("")
@export var flash_impacto := 6.0               # brillo blanco quemado del impacto (1 = sin destello blanco)
@export var pausa_impacto := 0.05              # s que queda "colgado" tras el golpe antes de salir despedido (0 = sin)
@export var polvo_aterrizaje := true           # nube de polvo al caer de una altura
@export var pop_aparicion := true              # pequeño "pop" al aparecer sin ritual
@export var flinch_reflash := 0.55           # intensidad del flash si lo golpean de nuevo en pleno stun (0-1)

@export_group("Flotante")
@export var flotante: bool = false             # flota sobre el suelo sostenido por un aura mística (sin gravedad)
@export var alcance_flotante_mult := 1.2       # multiplica shoot_range del flotante (ve y dispara desde más lejos)
@export var altura_flote := 560.0             # px que se eleva sobre el piso donde lo pusiste en el editor
@export var flote_amplitud := 14.0             # vaivén vertical (px)
@export var flote_velocidad := 1.8             # velocidad del vaivén (rad/s)
@export var solo_proyectil := true             # flotante: el cuerpo a cuerpo rebota; solo daña el proyectil
@export var aura_escena: PackedScene = preload("res://scenes/aura_mistica.tscn")
@export_group("")

const FRAMES_POR_TIPO := {
	"cultista": preload("res://resources/enemigo1_frames.tres"),
	"arquero": preload("res://resources/enemigo2_frames.tres"),
	"chaman": null,
}

var health: int = 40
var _activo := true
var _telegraph_timer := 0.0
var _ritual: Node2D       # círculo de invocación (telegrafia_enemigo.gd)
var _tele: Node2D         # aviso del ataque en curso (telegrafia_enemigo.gd)
var _ant_a := 0.0         # pose de anticipación: 0 = normal, 1 = echado atrás y achatado
var _ant_t := 0.0
var _ant_dur := 0.0
var _ant_activa := false
var _ant_tween: Tween
var _ant_base_x := 0.0
var _en_flinch := false     # hay un flinch en curso: al terminar el stun se suelta el "pop"
var _ant_base_escala := Vector2.ONE
var _pies_h0 := 0.0
var _attack_anim :=""
var _attack_anim_timer := 0.0
var _ataque_frame_impacto := -1     # frame del tajo de la animación de ataque en curso (-1 = sin sincronizar)
var _ataque_vel_previa := 1.0       # velocidad de reproducción hasta llegar a ese frame
var _attack_timer := 0.0
var _dir := -1
var _player_cache: Node2D
var _stun_timer := 0.0
var _stun_dir := 1
var _usa_sprite := false            # false = enemigo dibujado con polígono (sin AnimatedSprite propio)
var _pausa_impacto_t := 0.0
var _kb_pendiente := 0.0
var _caida_max := 0.0
var _en_suelo_prev := true
var _anim_congelada := false
var _reaction_tween: Tween
var _stun_tween: Tween
var _tint_tween: Tween
var _windup_timer := 0.0
var _windup_disparo := 0.0
var _poise_hits := 0
var _poise_reset_t := 0.0
var _poise_ventana_t := 0.0
var _lunge_timer := 0.0
var _lunge_hit := false
var _ultima_pos_valida := Vector2.ZERO
var _melee_anim := ""
var _squash_tween: Tween
var _base_pos := Vector2.ZERO      # pose de reposo del visual (evita "drift" con golpes repetidos)
var _base_scale := Vector2.ONE
var _base_valida := false
var _flote_y := 0.0
var _flotando := false
var _flote_t := 0.0
var _aura: Node2D
## Lo pone el proyectil del jugador justo antes de llamar a take_damage (distingue disparo de cuerpo a cuerpo).
var golpe_proyectil := false

@onready var visual: Node2D = $Visual
@onready var poly: Polygon2D = $Visual/Poly
@onready var animated: AnimatedSprite2D = $Visual/Animated
@onready var collide_shape: CollisionShape2D = $Collision


func _freeze_hitstop(duracion: float = 0.07) -> void:
	var hs = get_node_or_null("/root/Hitstop")
	if hs != null and hs.has_method("freeze"):
		hs.freeze(duracion)


static func config_por_tipo(enemy_tipo: String) -> Enemigo:
	var d := Enemigo.new()
	match enemy_tipo:
		"cultista":
			d.tipo_nombre = "Cultista"
			d.max_health = 75
			d.speed = 140.0
			d.stop_distance = 30.0
			d.attack_damage = 10
			d.attack_range = 90.0
			d.attack_cooldown = 0.9
			d.windup_tiempo = 0.28
			d.lunge_velocidad = 420.0
			d.lunge_alcance = 75.0
			d.color = Color(0.55, 0.38, 0.3)
			d.collider_size = Vector2(127, 380)
			d.visual_scale = Vector2.ONE
			d.offset_visual_x = 3.3
			d.knockback_resist = 0.55
			d.stun_duracion = 0.35
			d.poise_max = 3
		"arquero":
			d.tipo_nombre = "Arquero"
			d.max_health = 60
			d.speed = 95.0
			d.attack_damage = 12
			d.attack_cooldown = 1.4
			d.projectile = true
			d.shoot_range = 1150.0
			d.retrocede_dist = 260.0
			d.proyectil_speed = 650.0
			d.color = Color(0.42, 0.3, 0.5)
			d.collider_size = Vector2(103, 410)
			d.visual_scale = Vector2.ONE
			d.offset_visual_x = 5.3
			d.knockback_resist = 0.45
			d.stun_duracion = 0.4
			d.windup_disparo = 0.42
			d.poise_max = 3
			d.sonico_dano_mult = 1.5
		"chaman":
			d.tipo_nombre = "Chamán"
			d.max_health = 155
			d.speed = 72.0
			d.stop_distance = 40.0
			d.attack_damage = 15
			d.attack_cooldown = 1.6
			d.projectile = true
			d.shoot_range = 950.0
			d.retrocede_dist = 190.0
			d.proyectil_speed = 470.0
			d.color = Color(0.4, 0.34, 0.24)
			d.collider_size = Vector2(102, 330)
			d.collider_pies_y = 65.4
			d.offset_visual_x = 0.0
			d.visual_scale = Vector2.ONE
			d.knockback_resist = 0.6
			d.stun_duracion = 0.35
			d.windup_disparo = 0.5
			d.poise_max = 4
			d.sonico_dano_mult = 1.2
			d.energia_al_morir = 20.0
			d.armor_umbral = 18  # solo golpes pesados (18+) rompen su ataque; Lobo/Murciélago no pueden
	return d


func _ready() -> void:
	add_to_group("enemy")
	_mirar_jugador()
	if enemy_data == null or enemy_data.tipo_nombre.is_empty() or enemy_data.tipo_nombre == "Sectario":
		enemy_data = config_por_tipo(tipo)
	if enemy_data != null:
		health = enemy_data.max_health
		var frames: SpriteFrames = FRAMES_POR_TIPO.get(tipo)
		_usa_sprite = frames != null
		if frames != null:
			poly.visible = false
			animated.visible = true
			animated.sprite_frames = frames
			animated.play("idle")
		else:
			animated.visible = false
			poly.visible = true
			poly.color = enemy_data.color
		if collide_shape != null:
			collide_shape.shape = collide_shape.shape.duplicate()
		if collide_shape != null and enemy_data.collider_size != Vector2.ZERO:
			# El CollisionShape2D dibuja el RectangleShape2D CENTRADO en su position:
			# dejar position.x en 0 centra la hitbox sobre el origen del nodo (donde
			# también se dibuja el sprite). Antes se sumaba -size.x/2 y la caja real
			# quedaba desplazada un ancho completo hacia la izquierda.
			var pies_offset: float = collide_shape.position.y + collide_shape.shape.size.y * 0.5
			if enemy_data.collider_pies_y > 0.0:
				pies_offset = enemy_data.collider_pies_y
			collide_shape.shape.size = enemy_data.collider_size
			collide_shape.position.x = 0.0
			collide_shape.position.y = pies_offset - enemy_data.collider_size.y * 0.5
		if enemy_data.visual_scale != Vector2.ZERO and visual != null:
			# Escala natural: el sprite se muestra a tamaño real y sus pies se alinean
			# con la base del collider (el sprite recién original usa escala de 48px).
			visual.scale = enemy_data.visual_scale
			var tex_h := 0.0
			if frames != null and frames.has_animation("idle") and frames.get_frame_count("idle") > 0:
				var tex: Texture2D = frames.get_frame_texture("idle", 0)
				if tex != null:
					tex_h = tex.get_height()
			var pies_y := 0.0
			if collide_shape != null and collide_shape.shape is RectangleShape2D:
				pies_y = collide_shape.position.y + collide_shape.shape.size.y * 0.5
			visual.position.y = pies_y - enemy_data.visual_scale.y * (animated.position.y + tex_h * 0.5)
			if tex_h > 0.0 and animated != null and DisplayServer.get_name() != "headless":
				_pies_h0 = tex_h
				animated.frame_changed.connect(_anclar_pies_frame)
				animated.animation_changed.connect(_anclar_pies_frame)
			# Corrige la asimetría del dibujo dentro de su lámina: si el centro visual
			# del personaje no coincide con el centro de la textura, se corre el sprite
			# para que la hitbox quede centrada sobre el personaje visible.
			if visual.position.x == 0.0:
				visual.position.x = -enemy_data.offset_visual_x
	else:
		health = 40


# --- API para el sistema de oleadas (Encounter) ---

func preparar_ola() -> void:
	_activo = false
	visual.visible = false
	_colision(false)


## Apoya los pies del collider sobre el piso más cercano (corrección máx. 120 px):
## evita enemigos incrustados en el terreno o flotando por posiciones puestas a mano.
func ajustar_al_suelo() -> void:
	if collide_shape == null or not (collide_shape.shape is RectangleShape2D):
		return
	var pies: float = collide_shape.position.y + collide_shape.shape.size.y * 0.5
	var query := PhysicsRayQueryParameters2D.create(
		global_position + Vector2(0.0, -150.0), global_position + Vector2(0.0, 250.0), 1)
	var hit := get_world_2d().direct_space_state.intersect_ray(query)
	if hit.is_empty():
		return
	var objetivo: float = hit.position.y - pies
	if absf(objetivo - global_position.y) <= 120.0:
		global_position.y = objetivo
		velocity = Vector2.ZERO


func activar() -> void:
	ajustar_al_suelo()
	if flotante:
		_elevar()
	if spawn_telegrafiado:
		_telegraph_timer = maxf(ritual_duracion, 0.05)
		_mostrar_circulo_ritual()
	else:
		visual.visible = true
		_activo = true
		_colision(true)
		_pop_al_aparecer()


## Sube al enemigo `altura_flote` sobre el piso y le pone el aura que lo sostiene.
func _elevar() -> void:
	if _flotando:
		return
	global_position.y -= altura_flote
	if enemy_data != null and enemy_data.projectile:
		enemy_data = enemy_data.duplicate()
		enemy_data.shoot_range *= alcance_flotante_mult
	_flote_y = global_position.y
	_flotando = true
	_flote_t = randf() * TAU
	if aura_escena != null:
		_aura = aura_escena.instantiate() as Node2D
		var pies := 0.0
		if collide_shape != null and collide_shape.shape is RectangleShape2D:
			pies = collide_shape.position.y + collide_shape.shape.size.y * 0.5
		_aura.position = Vector2(0.0, pies + 8.0)
		add_child(_aura)
		_aura.show_behind_parent = true


## Velocidad vertical: el flotante sigue su vaivén en vez de caer.
func _vel_y(delta: float) -> float:
	if flotante and _flotando:
		return (_flote_y + sin(_flote_t) * flote_amplitud - global_position.y) * 6.0
	return minf(velocity.y + GRAVITY * delta, MAX_FALL_SPEED)


func _colision(on: bool) -> void:
	if collide_shape != null:
		collide_shape.set_deferred("disabled", not on)


func _mostrar_circulo_ritual() -> void:
	var col := enemy_data.color if enemy_data != null else Color(0.8, 0.4, 0.4)
	var pies_y := 0.0
	if collide_shape != null and collide_shape.shape is RectangleShape2D:
		pies_y = collide_shape.position.y + collide_shape.shape.size.y * 0.5
	_ritual = TELEGRAFIA.ritual(self, pies_y, col, maxf(ritual_duracion, 0.05))


## Cuerpo (centro del collider) y altura de la cabeza, para ubicar los avisos de ataque.
func _geom_aviso() -> Array:
	var centro := Vector2.ZERO
	var cabeza := -80.0
	if collide_shape != null and collide_shape.shape is RectangleShape2D:
		centro = collide_shape.position
		cabeza = collide_shape.position.y - collide_shape.shape.size.y * 0.5
	return [centro, cabeza]


## Aviso del ataque que empieza (sutil): el enemigo se echa atrás y se achata (anticipación) y un brillito
## crece en su mano justo antes del golpe. Sin marcas en el piso.
func _telegrafiar(duracion: float, disparo: bool) -> void:
	_anticipacion_iniciar(duracion)
	if is_instance_valid(_tele):
		_tele.queue_free()
	var g := _geom_aviso()
	var centro: Vector2 = g[0]
	var cabeza: float = g[1]
	var arma := centro + Vector2(_dir * (24.0 if disparo else 30.0), -6.0)
	var embiste := enemy_data != null and enemy_data.lunge_velocidad > 0.0 and not disparo
	# El brillito viaja con el sprite (su pose de anticipación y su animación): se ancla en un punto de la mano
	# expresado en el espacio local del sprite, no en el mundo.
	var sp := _sprite_pose()
	var mano_local := sp.to_local(global_position + arma) if sp != null else Vector2.ZERO
	_tele = TELEGRAFIA.ataque(self, arma, cabeza, _dir, 0.0, duracion, embiste, sp, mano_local)


## Pose de anticipación: durante el windup el sprite se echa atrás, se inclina y se achata; en el último
## tramo tiembla y al soltar el golpe vuelve de golpe (con un rebote hacia adelante).
func _anticipacion_iniciar(duracion: float) -> void:
	if _ant_tween != null and _ant_tween.is_valid():
		_ant_tween.kill()
	var sp := _sprite_pose()
	if sp != null and absf(_ant_a) < 0.001:   # captura la pose de reposo del sprite
		_ant_base_x = sp.position.x
		_ant_base_escala = sp.scale
	_ant_dur = maxf(duracion, 0.05)
	_ant_t = 0.0
	_ant_activa = true


func _sprite_pose() -> Node2D:
	return animated if (animated != null and animated.visible) else poly


func _anticipacion_actualizar(delta: float) -> void:
	if _ant_activa:
		_ant_t += delta
		var u := clampf(_ant_t / (_ant_dur * 0.7), 0.0, 1.0)
		_ant_a = u * u * (3.0 - 2.0 * u)
		if _ant_t >= _ant_dur:
			_ant_activa = false
			_ant_tween = create_tween()
			_ant_tween.tween_property(self, "_ant_a", -0.4, 0.06).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
			_ant_tween.tween_property(self, "_ant_a", 0.0, 0.14).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	var sp := _sprite_pose()
	if sp == null:
		return
	if not _ant_activa and absf(_ant_a) < 0.001:
		if sp.rotation != 0.0 or sp.scale != _ant_base_escala:
			sp.rotation = 0.0
			sp.scale = _ant_base_escala
			sp.position.x = _ant_base_x
		return
	var temblor := 0.0
	if _ant_activa and _ant_t > _ant_dur * 0.7:
		temblor = sin(_ant_t * 90.0) * ant_temblor
	# En el espacio local del Visual, +x es "hacia atrás" (el Visual se espeja según hacia dónde mira).
	sp.position.x = _ant_base_x + ant_retroceso * _ant_a + temblor
	sp.rotation = ant_inclinacion * _ant_a
	sp.scale = _ant_base_escala * Vector2(1.0 + ant_achatar * 0.6 * _ant_a, 1.0 - ant_achatar * _ant_a)


## Inclinación de rechazo mientras dura el stun: se acerca suave al ángulo del golpe y, al terminar, vuelve a la vertical.
func _pose_stun_actualizar(delta: float) -> void:
	if visual == null or health <= 0:
		return
	var objetivo := 0.0
	var vel := 16.0
	if _stun_timer > 0.0:
		objetivo = deg_to_rad(-stun_tilt_angulo) * signf(_stun_dir)
		vel = 34.0
	elif absf(visual.rotation) < 0.002:
		if visual.rotation != 0.0 and _en_flinch:
			visual.rotation = 0.0
		return
	visual.rotation = lerpf(visual.rotation, objetivo, 1.0 - exp(-vel * delta))


func _anticipacion_cancelar() -> void:
	_ant_activa = false
	if _ant_tween != null and _ant_tween.is_valid():
		_ant_tween.kill()
	_ant_a = 0.0


func _cancelar_aviso() -> void:
	_anticipacion_cancelar()
	if is_instance_valid(_tele) and _tele.has_method("cancelar"):
		_tele.cancelar()
	_tele = null


func _circulo_poligono(puntos: int) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in range(puntos):
		var ang := TAU * float(i) / float(puntos)
		pts.append(Vector2(cos(ang), sin(ang)) * 22.0)
	return pts


func _physics_process(delta: float) -> void:
	_anticipacion_actualizar(delta)
	_pose_stun_actualizar(delta)
	if health <= 0:
		return
	# Guardia anti-NaN: una colisión degenerada con el jugador (bordes exactos)
	# puede volver no-finito el velocity/posición en move_and_slide. Si pasa,
	# se restaura la última posición válida en vez de volar al infinito.
	if not velocity.is_finite():
		velocity = Vector2.ZERO
	if not global_position.is_finite():
		global_position = _ultima_pos_valida
		velocity = Vector2.ZERO
		return
	_ultima_pos_valida = global_position
	# Optimización: un enemigo en espera (encuentro sin disparar), apoyado y lejos de la cámara no hace nada visible.
	if not _activo and _telegraph_timer <= 0.0 and is_on_floor():
		var p := _obtener_player()
		if p != null and global_position.distance_squared_to(p.global_position) > 9000000.0:
			return
	if global_position.y > limite_caida:
		matar_por_caida()
		return
	_mirar_jugador()
	_polvo_al_aterrizar()
	if _poise_reset_t > 0.0:
		_poise_reset_t -= delta
		if _poise_reset_t <= 0.0:
			_poise_hits = 0
	if _poise_ventana_t > 0.0:
		_poise_ventana_t -= delta
	if _telegraph_timer > 0.0:
		_telegraph_timer -= delta
		velocity.x = 0.0
		_update_animacion()
		move_and_slide()
		if _telegraph_timer <= 0.0:
			visual.visible = true
			_activo = true
			_colision(true)
		return
	if not _activo:
		velocity.x = 0.0
		_update_animacion()
		move_and_slide()
		return
	if _stun_timer > 0.0:
		# Hitstun: el enemigo no persigue ni ataca; el knockback se frena solo.
		_stun_timer -= delta
		if _stun_timer <= 0.0:
			_anim_congelada = false
			if animated != null and not animated.is_playing():
				animated.play()
			if _en_flinch:
				_en_flinch = false
				_reanudar_flinch(_base_scale)
		if _pausa_impacto_t > 0.0:
			# Colgado un instante en el impacto (asimetría: pesa más el golpe que el jugador),
			# y recién después sale despedido.
			_pausa_impacto_t -= delta
			if _pausa_impacto_t <= 0.0:
				velocity.x = _kb_pendiente
			else:
				velocity = Vector2.ZERO
				_update_animacion()
				move_and_slide()
				return
		velocity.x = move_toward(velocity.x, 0.0, 180.0 * delta)
		_flote_t += delta * flote_velocidad
		velocity.y = _vel_y(delta)
		_update_animacion()
		move_and_slide()
		return
	var player := _obtener_player()
	if _attack_timer > 0.0:
		_attack_timer -= delta
	if _attack_anim_timer > 0.0:
		_attack_anim_timer -= delta

	# gravedad (el flotante sigue su vaivén)
	_flote_t += delta * flote_velocidad
	velocity.y = _vel_y(delta)

	if player == null:
		velocity.x = 0.0
		_update_animacion()
		return

	var dist := global_position.distance_to(player.global_position)

	if _usar_proyectil():
		if _windup_disparo > 0.0:
			_windup_disparo -= delta
			if _windup_disparo <= 0.0:
				_disparar(player)
				_attack_timer = enemy_data.attack_cooldown
		elif dist <= enemy_data.shoot_range and _attack_timer <= 0.0:
			if enemy_data.windup_disparo > 0.0:
				_windup_disparo = enemy_data.windup_disparo
				_reproducir_animacion_ataque("attack2")
				_flash_aviso()
				_telegrafiar(enemy_data.windup_disparo, true)
			else:
				_disparar(player)
				_attack_timer = enemy_data.attack_cooldown
		if _windup_disparo > 0.0:
			velocity.x = 0.0
		elif enemy_data.retrocede_dist > 0.0 and dist <= enemy_data.retrocede_dist:
			velocity.x = -_dir * enemy_data.speed
		elif perseguir_fuera_rango:
			velocity.x = 0.0 if dist <= enemy_data.shoot_range else _dir * enemy_data.speed
		else:
			# Se queda en su punto de spawn: solo ataca dentro del rango de tiro.
			velocity.x = 0.0
	else:
		var gap := _gap_x(player)
		if _windup_timer > 0.0:
			_windup_timer -= delta
			velocity.x = 0.0
			if _windup_timer <= 0.0:
				if enemy_data.lunge_velocidad > 0.0:
					_lunge_timer = enemy_data.lunge_tiempo
					_lunge_hit = false
					_attack_timer = enemy_data.attack_cooldown
				else:
					_ataque_melee(player)
					_attack_timer = enemy_data.attack_cooldown
		elif _lunge_timer > 0.0:
			_lunge_timer -= delta
			if not _lunge_hit:
				velocity.x = _dir * enemy_data.lunge_velocidad
				if gap < enemy_data.lunge_alcance:
					_lunge_hit = true
					_ataque_melee(player)
			else:
				velocity.x = 0.0
			if _lunge_timer <= 0.0:
				velocity.x = 0.0
		elif _attack_timer > 0.0:
			var min_stop := enemy_data.attack_range * 0.55
			velocity.x = _dir * enemy_data.speed if gap > min_stop else 0.0
		elif gap <= enemy_data.attack_range:
			if not _puede_atacar_melee():
				# Hay otros atacando: espera en su sitio, mirando al jugador.
				velocity.x = 0.0
			elif enemy_data.windup_tiempo > 0.0:
				_windup_timer = enemy_data.windup_tiempo
				_flash_aviso()
				_telegrafiar(enemy_data.windup_tiempo, false)
				_melee_anim = "attack1" if randf() < 0.5 else "attack2"
				_reproducir_animacion_ataque(_melee_anim, enemy_data.windup_tiempo)
				_attack_anim_timer = enemy_data.windup_tiempo + enemy_data.lunge_tiempo + 0.12
			else:
				_ataque_melee(player)
				_attack_timer = enemy_data.attack_cooldown
		else:
			velocity.x = _dir * enemy_data.speed

	_update_animacion()
	move_and_slide()
	if is_on_floor() and velocity.y > 0:
		velocity.y = 0


func _mirar_jugador() -> void:
	var player := _obtener_player()
	if player == null:
		return
	_dir = 1 if player.global_position.x > global_position.x else -1
	if visual != null:
		visual.scale.x = absf(visual.scale.x) * -_dir


## Devuelve el player cacheado (evita el lookup de grupo por frame).
func _obtener_player() -> Node2D:
	if not is_instance_valid(_player_cache):
		_player_cache = get_tree().get_first_node_in_group("player")
	return _player_cache


func _gap_x(player: Node2D) -> float:
	var medio_enemigo := 0.0
	if collide_shape != null and collide_shape.shape is RectangleShape2D:
		medio_enemigo = (collide_shape.shape as RectangleShape2D).size.x * 0.5
	var medio_player := 0.0
	for c in player.get_children():
		if c is CollisionShape2D and c.shape is RectangleShape2D:
			medio_player = (c.shape as RectangleShape2D).size.x * 0.5
			break
	return maxf(absf(player.global_position.x - global_position.x) - medio_enemigo - medio_player, 0.0)


## Cada frame apoya su base donde la apoya el primer frame de idle (los pies no saltan entre animaciones).
func _anclar_pies_frame() -> void:
	var sf := animated.sprite_frames
	if sf == null or not sf.has_animation(animated.animation):
		return
	var tex := sf.get_frame_texture(animated.animation, animated.frame)
	if tex != null:
		animated.offset.y = _pies_h0 * 0.5 - (tex.get_height() * 0.5 - Pies.relleno_inferior(tex))


func _update_animacion() -> void:
	if animated == null or not animated.visible:
		return
	if _anim_congelada:
		# Fallback anti-trabado: nunca quedarse congelada si no hay hitstun activo.
		if _stun_timer <= 0.0:
			_anim_congelada = false
			animated.play()
		else:
			return
	var nombre := "idle"
	if _stun_timer > 0.0 and stun_anim != "" and animated.sprite_frames != null and animated.sprite_frames.has_animation(stun_anim):
		# En hitstun la animación sigue VIVA (idle) en vez de quedarse en el frame de ataque.
		animated.speed_scale = 1.0   # puede venir comprimida por el windup del ataque interrumpido
		if animated.animation != stun_anim or not animated.is_playing():
			animated.play(stun_anim)
		return
	if _attack_anim_timer > 0.0:
		nombre = _attack_anim
	elif not is_on_floor() and not flotante:
		nombre = "jump"
	elif absf(velocity.x) > 10.0:
		nombre = "run"
	if animated.animation != nombre:
		animated.play(nombre)
	# El trote acompaña la velocidad real (frena, acelera o es empujado).
	if nombre == "run" and enemy_data != null and enemy_data.speed > 0.0:
		var obj := clampf(absf(velocity.x) / enemy_data.speed, 0.4, 1.5)
		animated.speed_scale = lerpf(animated.speed_scale, obj, minf(12.0 * get_physics_process_delta_time(), 1.0))
	elif nombre == _attack_anim and _attack_anim_timer > 0.0 and _ataque_frame_impacto >= 0 and animated.frame < _ataque_frame_impacto:
		animated.speed_scale = _ataque_vel_previa   # la preparación se comprime para que el tajo caiga con el daño
	else:
		animated.speed_scale = 1.0


func _reproducir_animacion_ataque(tipo: String, t_impacto: float = 0.0) -> void:
	_attack_anim = tipo
	_attack_anim_timer = 0.35
	_ataque_frame_impacto = -1
	# Solo los tipos con sprites propios animan el ataque (el chamán es un polígono: no debe aparecer el sprite del cultista).
	if DisplayServer.get_name() != "headless" and _usa_sprite:
		animated.visible = true
		var sf := animated.sprite_frames
		if sf != null and sf.has_animation(tipo):
			animated.play(tipo)
			var fps := maxf(sf.get_animation_speed(tipo), 0.01)
			_attack_anim_timer = maxf(float(sf.get_frame_count(tipo)) / fps, 0.2)
			if t_impacto > 0.0 and frames_impacto.has(tipo):
				_planificar_impacto(sf, tipo, t_impacto)


## Sincroniza el tajo con el daño: los frames de preparación se comprimen (o estiran) para que el
## frame de impacto aparezca en `t_impacto`; desde ahí la animación sigue a su ritmo natural.
func _planificar_impacto(sf: SpriteFrames, tipo: String, t_impacto: float) -> void:
	var imp := clampi(int(frames_impacto[tipo]), 0, sf.get_frame_count(tipo) - 1)
	var fps := maxf(sf.get_animation_speed(tipo), 0.01)
	var previo := 0.0
	for i in imp:
		previo += sf.get_frame_duration(tipo, i) / fps
	var posterior := 0.0
	for i in range(imp, sf.get_frame_count(tipo)):
		posterior += sf.get_frame_duration(tipo, i) / fps
	_ataque_frame_impacto = imp
	_ataque_vel_previa = clampf(previo / maxf(t_impacto, 0.02), 0.2, 6.0) if imp > 0 else 1.0
	_attack_anim_timer = t_impacto + posterior
	animated.speed_scale = _ataque_vel_previa


func _usar_proyectil() -> bool:
	return enemy_data != null and enemy_data.projectile


## Cuántos cuerpo a cuerpo (otros) están ahora mismo en aviso/embestida.
func _puede_atacar_melee() -> bool:
	var atacando := 0
	for n in get_tree().get_nodes_in_group("enemy"):
		if n == self or not is_instance_valid(n) or n.get("health") == null or int(n.health) <= 0:
			continue
		if float(n.get("_windup_timer")) > 0.0 or float(n.get("_lunge_timer")) > 0.0:
			atacando += 1
	return atacando < max_atacantes_melee


## Destello corto al empezar un ataque: el jugador lee "esto viene ya".
func _flash_aviso(color: Color = Color(-1, -1, -1)) -> void:
	if visual == null:
		return
	if color.r < 0.0:
		color = flash_aviso
	if _tint_tween != null and _tint_tween.is_valid():
		_tint_tween.kill()
	visual.self_modulate = Color.WHITE   # el tween matado podía haber dejado el destello del golpe encendido
	visual.modulate = color
	_tint_tween = create_tween()
	_tint_tween.tween_property(visual, "modulate", Color(1, 1, 1), 0.12)


func _ataque_melee(player: Node2D) -> void:
	if _melee_anim.is_empty():
		_melee_anim = "attack1" if randf() < 0.5 else "attack2"
	_reproducir_animacion_ataque(_melee_anim)
	player.take_damage(enemy_data.attack_damage, 0.0, _dir)


func _disparar(player: Node2D) -> void:
	_reproducir_animacion_ataque("attack2")
	var to_player: Vector2 = player.global_position - global_position
	var dir: Vector2 = to_player.normalized() if to_player.length_squared() > 0.01 else Vector2(_dir, 0.0)
	var audio_d := get_node_or_null("/root/AudioManager")
	if audio_d != null:
		audio_d.play_sfx(sonido_disparo, volumen_sfx_db, 0.08)
	var proj: Area2D = preload("res://scenes/projectile.tscn").instantiate()
	proj.global_position = global_position + Vector2(_dir * 25.0, -10.0)
	proj.set("direction", dir)
	proj.set("speed", enemy_data.proyectil_speed)
	proj.set("damage", enemy_data.attack_damage)
	proj.set("enemy_shot", true)
	var destino: Node = get_tree().current_scene if get_tree().current_scene != null else get_parent()
	destino.add_child(proj)


func take_damage(cantidad: int, knockback: float = 0.0, dir: int = 1, critico: bool = false) -> void:
	if health <= 0:
		return
	var es_proyectil := golpe_proyectil
	golpe_proyectil = false
	if flotante and solo_proyectil and not es_proyectil:
		_rebotar_golpe()
		return
	health -= cantidad
	var murio := health <= 0
	if visual != null:
		if _tint_tween != null and _tint_tween.is_valid():
			_tint_tween.kill()
		# El flash queda congelado durante el hitstop automáticamente: los tweens
		# no avanzan con `Engine.time_scale = 0`, así que el rojo sostiene el freeze
		# y el fade reanuda al volver el tiempo (sin corrutinas que se pisen en racha).
		# Golpe repetido en pleno stun: flash más suave para que la ráfaga no parpadee.
		var re_golpe := _stun_timer > 0.0
		visual.modulate = Color(1, 1, 1).lerp(Color(1, 0.6, 0.6), flinch_reflash if re_golpe else 1.0)
		# Destello blanco quemado en el impacto (self_modulate): se sostiene durante el hitstop
		# y se apaga antes que el rojo → "blanco, luego rojo" como Hollow Knight.
		var f_blanco := lerpf(1.0, flash_impacto, 0.55 if re_golpe else 1.0)
		visual.self_modulate = Color(f_blanco, f_blanco, f_blanco, 1.0)
		_capturar_base()
		var sx := absf(_base_scale.x)
		var sy := _base_scale.y
		# El squash preserva el facing actual: usar `dir` aquí voltearía al sprite
		# hacia el lado opuesto al jugador (el golpe viene de la dirección opuesta).
		var signo := signf(_base_scale.x)
		if signo == 0.0:
			signo = 1.0
		if _squash_tween != null and _squash_tween.is_valid():
			_squash_tween.kill()
		_squash_tween = create_tween()
		var apretar := 0.9 if re_golpe else 0.85
		_squash_tween.tween_property(visual, "scale", Vector2(signo * sx * (2.0 - apretar), sy * apretar), 0.05)
		_squash_tween.tween_property(visual, "scale", Vector2(signo * sx, sy), 0.09).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	var audio_mgr := get_node_or_null("/root/AudioManager")
	if audio_mgr != null:
		# el sonido del cuerpo suena cuando la animación se des-congela (impacto visible)
		audio_mgr.play_sfx_sincronizado(sonido_golpe, volumen_golpe_db)
	var umbral := enemy_data.armor_umbral if enemy_data != null else 0
	var armadura: bool = umbral > 0 and cantidad < umbral
	var poise := enemy_data.poise_max if enemy_data != null else 0
	var rompe: bool = enemy_data != null and cantidad >= enemy_data.poise_rompe_dano
	if poise > 0 and _poise_ventana_t > 0.0 and not rompe:
		armadura = true   # resistiendo: el golpe daña pero no interrumpe
	if not armadura:
		if poise > 0:
			if rompe:
				_poise_ventana_t = 0.0
				_poise_hits = 0
			else:
				_poise_hits += 1
				_poise_reset_t = enemy_data.poise_recupera
				if _poise_hits >= poise:
					_poise_hits = 0
					_poise_ventana_t = enemy_data.poise_ventana
					_flash_aviso(Color(1.6, 1.5, 0.9))
		var dur_stun: float = enemy_data.stun_duracion if enemy_data != null else 0.22
		_stun_dir = 1 if dir == 0 else dir
		_stun_timer = maxf(_stun_timer, dur_stun)
		_windup_timer = 0.0
		_lunge_timer = 0.0
		if not _usar_proyectil():
			_attack_anim_timer = 0.0   # un golpe corta el ataque: sin esto, al salir del stun retoma un tajo viejo (se ve trabado)
			_ataque_frame_impacto = -1
			if animated != null:
				animated.speed_scale = 1.0
			_cancelar_aviso()   # el arquero sigue su disparo aunque lo golpeen: su aviso también
		if knockback > 0.0:
			var resist: float = enemy_data.knockback_resist if enemy_data != null else 1.0
			velocity.x = dir * knockback * (1.0 - resist)
			_kb_pendiente = velocity.x
			_pausa_impacto_t = pausa_impacto if health > 0 else 0.0
		_pose_stun(dur_stun)
	if health <= 0:
		_morir()
		return
	# El tint se funde a blanco pasado un toque; el tween se congela durante el
	# hitstop (time_scale 0) y reanuda al restaurar → flash congelado y fade bien.
	if is_instance_valid(visual):
		_tint_tween = create_tween()
		_tint_tween.tween_property(visual, "modulate", Color(1, 1, 1), 0.08)
		_tint_tween.parallel().tween_property(visual, "self_modulate", Color.WHITE, 0.04)


## El aura repele el cuerpo a cuerpo: destello violeta y chispas, sin daño.
func _rebotar_golpe() -> void:
	# Aviso claro de que el golpe cuerpo a cuerpo no le hace nada: sonido metálico, anillo de escudo,
	# chispas, destello y un rechazo del jugador.
	var audio_r := get_node_or_null("/root/AudioManager")
	if audio_r != null:
		audio_r.play_sfx(sonido_rebote, volumen_rebote_db, 0.06)
	var jugador := get_tree().get_first_node_in_group("player")
	if jugador != null and jugador.has_method("rebote_golpe"):
		jugador.rebote_golpe(1 if global_position.x >= (jugador as Node2D).global_position.x else -1)
	if DisplayServer.get_name() == "headless":
		return
	var centro := global_position + (collide_shape.position if collide_shape != null else Vector2.ZERO)
	Burst.emitir(self, centro, Color(0.8, 0.7, 1.0), 14, 1.1)
	var aro := Line2D.new()
	var pts := PackedVector2Array()
	for i in 25:
		var a := TAU * float(i) / 24.0
		pts.append(Vector2(cos(a), sin(a)) * 90.0)
	aro.points = pts
	aro.width = 6.0
	aro.default_color = Color(0.8, 0.72, 1.0, 0.95)
	aro.position = centro
	aro.scale = Vector2(0.5, 0.5)
	aro.z_index = 5
	JuiceCapa.obtener(get_tree()).add_child(aro)
	var tw_a := aro.create_tween().set_parallel(true)
	tw_a.tween_property(aro, "scale", Vector2(1.5, 1.5), 0.22).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw_a.tween_property(aro, "modulate:a", 0.0, 0.25)
	tw_a.chain().tween_callback(aro.queue_free)
	if visual != null:
		if _tint_tween != null and _tint_tween.is_valid():
			_tint_tween.kill()
		visual.modulate = Color(0.85, 0.7, 2.0)
		_tint_tween = create_tween()
		_tint_tween.tween_property(visual, "modulate", Color(1, 1, 1), 0.3)


## Reacción de flinch (estilo caricaturesco): congelo la animación en el frame del
## impacto, hago un corte seco hacia adelante, inclino el cuerpo hacia atrás durante
## todo el hitstun y al recuperar la pose hago un "pop" de escala.
func _pose_stun(dur_stun: float, _fuerza: float = 1.0) -> void:
	if visual == null:
		return
	if _reaction_tween != null and _reaction_tween.is_valid():
		_reaction_tween.kill()
	if _stun_tween != null and _stun_tween.is_valid():
		_stun_tween.kill()
	if _tint_tween != null and _tint_tween.is_valid():
		_tint_tween.kill()
	_capturar_base()
	var base_pos := _base_pos
	var base_scale := _base_scale
	var signo := signf(base_scale.x)
	if signo == 0.0:
		signo = 1.0
	# Congelo el frame de la animación al impacto: el cuerpo "se detiene" y reacciona.
	if animated != null and animated.visible and flinch_congela_anim:
		_anim_congelada = true
		animated.pause()
	# Corte seco: el cuerpo se adelanta bruscamente en la dirección del golpe y
	# vuelve en rebote (adelante y atrás, como un golpe de dibujo animado).
	var dir_flex := Vector2(signf(_stun_dir) * flinch_adelanto_px, 0.0)
	_reaction_tween = create_tween()
	_reaction_tween.tween_property(visual, "position", base_pos + dir_flex, 0.03)
	_reaction_tween.tween_property(visual, "position", base_pos - dir_flex * 0.5, 0.05).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	_reaction_tween.tween_property(visual, "position", base_pos, 0.05).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	# La inclinación hacia atrás (rechazo) la lleva `_pose_stun_actualizar` cada frame: en una tanda de golpes
	# se sostiene y se afloja suave, en vez de reiniciarse (y temblar) con cada impacto.
	_en_flinch = true


## Guarda la pose de reposo del visual. Si hay una reacción en curso NO la recapturo
## (tomaría la pose deformada y, con golpes seguidos, el cuerpo derivaría); solo
## sincronizo el signo de la escala por si el enemigo giró.
func _capturar_base() -> void:
	var en_curso := (_reaction_tween != null and _reaction_tween.is_valid()) \
		or (_squash_tween != null and _squash_tween.is_valid()) \
		or (_stun_tween != null and _stun_tween.is_valid())
	if not _base_valida or not en_curso:
		_base_pos = visual.position
		_base_scale = visual.scale
		_base_valida = true
	else:
		var s := signf(visual.scale.x)
		if s != 0.0 and s != signf(_base_scale.x):
			_base_scale.x = absf(_base_scale.x) * s


## Al terminar el hitstun: suelto la congelación del frame y hago un "pop" de escala
## que devuelve el cuerpo a su tamaño base con un rebote.
func _reanudar_flinch(base_scale: Vector2) -> void:
	if visual == null:
		return
	if animated != null and animated.visible and _anim_congelada:
		_anim_congelada = false
		animated.play()
	var signo := signf(base_scale.x)
	if signo == 0.0:
		signo = 1.0
	if _squash_tween != null and _squash_tween.is_valid():
		_squash_tween.kill()
	_squash_tween = create_tween()
	_squash_tween.tween_property(visual, "scale", Vector2(signo * absf(base_scale.x) * flinch_pop_escala, base_scale.y * flinch_pop_escala), 0.06)
	_squash_tween.tween_property(visual, "scale", base_scale, 0.09).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _morir() -> void:
	_cancelar_aviso()
	if _reaction_tween != null and _reaction_tween.is_valid():
		_reaction_tween.kill()
	if _stun_tween != null and _stun_tween.is_valid():
		_stun_tween.kill()
	if _tint_tween != null and _tint_tween.is_valid():
		_tint_tween.kill()
	var player := get_tree().get_first_node_in_group("player")
	if player != null and player.has_method("on_enemy_killed"):
		(player as Node2D).on_enemy_killed(enemy_data.energia_al_morir if enemy_data != null else 8.0)
	died.emit()
	if player != null and DisplayServer.get_name() != "headless":
		var en: float = enemy_data.energia_al_morir if enemy_data != null else 8.0
		AlmaEnergia.lanzar(get_tree(), global_position + Vector2(0, -60), player as Node2D, clampi(int(en * 0.3) + 1, 2, 6), Color(0.55, 0.95, 1.0))
	var audio_m := get_node_or_null("/root/AudioManager")
	if audio_m != null:
		audio_m.play_sfx(sonido_muerte, volumen_sfx_db, 0.1)
	_freeze_hitstop(0.09)
	if DisplayServer.get_name() != "headless":
		var cam := get_viewport().get_camera_2d()
		if cam != null and cam.has_method("punch"):
			cam.punch(1.05)
	_liberar_only()
	set_physics_process(false)
	_colision(false)
	if is_instance_valid(_aura):
		_aura.visible = false
	_burst_particulas()
	_soltar_orbe_vida()
	visual.self_modulate = Color.WHITE
	visual.modulate = Color(4, 4, 4, 1)
	var tw := create_tween()
	tw.tween_property(visual, "modulate:a", 0.0, 0.3)
	tw.parallel().tween_property(visual, "rotation", visual.rotation + deg_to_rad(8) * _dir, 0.3)
	tw.tween_interval(0.1)
	tw.tween_callback(queue_free)


## 55% de chance de soltar un orbe rojo de vida al morir.
func _soltar_orbe_vida() -> void:
	if randf() > 0.55:
		return
	var orbe: Area2D = preload("res://scenes/pickup_vida.tscn").instantiate()
	orbe.global_position = global_position
	var destino: Node = get_tree().current_scene if get_tree().current_scene != null else get_parent()
	destino.add_child(orbe)


func _liberar_only() -> void:
	_activo = false
	velocity = Vector2.ZERO


## Mata al enemigo desde afuera (ej: oleada fuera de la arena).
func matar_por_caida() -> void:
	if health <= 0:
		return
	health = 0
	_morir()


## Estallido de muerte: más grande y con más partículas cuanto más pesado es el enemigo.
func _burst_particulas() -> void:
	var color := enemy_data.color if enemy_data != null else Color(0.6, 0.3, 0.3)
	var peso := clampf(float(enemy_data.max_health) / 75.0, 0.8, 1.6) if enemy_data != null else 1.0
	Burst.emitir(self, global_position, color, int(16.0 * peso), peso)
	Burst.chispas(self, global_position, int(signf(_stun_dir)) if _stun_dir != 0 else 1, color.lightened(0.4), int(6.0 * peso), 1.2)


## Nube de polvo al caer de una altura (no al bajar un escalón).
func _polvo_al_aterrizar() -> void:
	var suelo := is_on_floor()
	if not suelo:
		_caida_max = maxf(_caida_max, velocity.y)
	elif not _en_suelo_prev and polvo_aterrizaje and _caida_max > 380.0 and collide_shape != null:
		var pies := global_position + Vector2(0.0, collide_shape.position.y + (collide_shape.shape.size.y * 0.5 if collide_shape.shape is RectangleShape2D else 40.0))
		Burst.emitir(self, pies, Color(0.6, 0.55, 0.45, 0.7), int(clampf(_caida_max / 100.0, 4.0, 10.0)), 0.55)
	if suelo:
		_caida_max = 0.0
	_en_suelo_prev = suelo


## "Pop" al aparecer sin ritual: nace un poco más chico y rebota a su tamaño.
func _pop_al_aparecer() -> void:
	if not pop_aparicion or DisplayServer.get_name() == "headless" or visual == null:
		return
	_capturar_base()   # fija la escala real antes de achicar (un golpe durante el pop no la toma como base)
	var esc := visual.scale
	visual.scale = esc * 0.7
	if _squash_tween != null and _squash_tween.is_valid():
		_squash_tween.kill()
	_squash_tween = create_tween()
	_squash_tween.tween_property(visual, "scale", esc, 0.16).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
