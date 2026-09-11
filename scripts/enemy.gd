extends CharacterBody2D

signal died

const GRAVITY := 980.0
const MAX_FALL_SPEED := 950.0

@export var tipo: String = "cultista"
@export var enemy_data: Enemigo
@export var ola_asignada: int = 0          # a qué ola pertenece (enemigo manual del Encounter)
@export var spawn_telegrafiado: bool = false  # aparece con el círculo ritual antes de actuar
@export var ritual_duracion: float = 0.7  # tiempo del círculo ritual antes de que el enemigo actúe
@export var sonido_golpe: AudioStream
@export var volumen_golpe_db := 0.0
@export var perseguir_fuera_rango: bool = false  # los proyectiles se quedan donde spawnnean y atacan a rango
@export var limite_caida := 6000.0

const FRAMES_POR_TIPO := {
	"cultista": preload("res://resources/enemigo1_frames.tres"),
	"arquero": preload("res://resources/enemigo2_frames.tres"),
	"chaman": null,
}

var health: int = 40
var _activo := true
var _telegraph_timer := 0.0
var _ritual: Polygon2D
var _attack_timer := 0.0
var _dir := -1
var _attack_anim := ""
var _attack_anim_timer := 0.0
var _stun_timer := 0.0
var _windup_timer := 0.0
var _lunge_timer := 0.0
var _lunge_hit := false
var _ultima_pos_valida := Vector2.ZERO

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
			d.attack_damage = 12
			d.attack_range = 110.0
			d.attack_cooldown = 0.7
			d.windup_tiempo = 0.28
			d.lunge_velocidad = 420.0
			d.color = Color(0.55, 0.38, 0.3)
			d.collider_size = Vector2(127, 380)
			d.visual_scale = Vector2.ONE
			d.offset_visual_x = 3.3
			d.knockback_resist = 0.55
		"arquero":
			d.tipo_nombre = "Arquero"
			d.max_health = 60
			d.speed = 95.0
			d.attack_damage = 15
			d.attack_cooldown = 1.4
			d.projectile = true
			d.shoot_range = 850.0
			d.retrocede_dist = 170.0
			d.proyectil_speed = 430.0
			d.color = Color(0.42, 0.3, 0.5)
			d.collider_size = Vector2(103, 410)
			d.visual_scale = Vector2.ONE
			d.offset_visual_x = 5.3
			d.knockback_resist = 0.45
		"chaman":
			d.tipo_nombre = "Chamán"
			d.max_health = 155
			d.speed = 72.0
			d.stop_distance = 40.0
			d.attack_damage = 18
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
	return d


func _ready() -> void:
	add_to_group("enemy")
	_mirar_jugador()
	if enemy_data == null or enemy_data.tipo_nombre.is_empty() or enemy_data.tipo_nombre == "Sectario":
		enemy_data = config_por_tipo(tipo)
	if enemy_data != null:
		health = enemy_data.max_health
		var frames: SpriteFrames = FRAMES_POR_TIPO.get(tipo)
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


func activar() -> void:
	if spawn_telegrafiado:
		_telegraph_timer = maxf(ritual_duracion, 0.05)
		_mostrar_circulo_ritual()
	else:
		visual.visible = true
		_activo = true
		_colision(true)


func _colision(on: bool) -> void:
	if collide_shape != null:
		collide_shape.set_deferred("disabled", not on)


func _mostrar_circulo_ritual() -> void:
	_ritual = Polygon2D.new()
	if enemy_data != null:
		_ritual.color = Color(enemy_data.color.r, enemy_data.color.g, enemy_data.color.b, 0.7)
	else:
		_ritual.color = Color(0.8, 0.4, 0.4, 0.7)
	_ritual.polygon = _circulo_poligono(24)
	var pies_y := 0.0
	if collide_shape != null and collide_shape.shape is RectangleShape2D:
		pies_y = collide_shape.position.y + collide_shape.shape.size.y * 0.5
	_ritual.position = Vector2(0, pies_y)
	add_child(_ritual)
	var tw := create_tween()
	tw.tween_property(_ritual, "scale", Vector2(1.5, 1.5), 0.6)
	tw.parallel().tween_property(_ritual, "modulate:a", 0.0, 0.6)


func _circulo_poligono(puntos: int) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in range(puntos):
		var ang := TAU * float(i) / float(puntos)
		pts.append(Vector2(cos(ang), sin(ang)) * 22.0)
	return pts


func _physics_process(delta: float) -> void:
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
	if global_position.y > limite_caida:
		matar_por_caida()
		return
	_mirar_jugador()
	if _telegraph_timer > 0.0:
		_telegraph_timer -= delta
		velocity.x = 0.0
		_update_animacion()
		move_and_slide()
		if _telegraph_timer <= 0.0:
			visual.visible = true
			_activo = true
			_colision(true)
			if is_instance_valid(_ritual):
				_ritual.queue_free()
		return
	if not _activo:
		velocity.x = 0.0
		_update_animacion()
		move_and_slide()
		return
	if _stun_timer > 0.0:
		# Hitstun: el enemigo no persigue ni ataca; el knockback se frena solo.
		_stun_timer -= delta
		velocity.x = move_toward(velocity.x, 0.0, 180.0 * delta)
		velocity.y = minf(velocity.y + GRAVITY * delta, MAX_FALL_SPEED)
		_update_animacion()
		move_and_slide()
		return
	var player := get_tree().get_first_node_in_group("player")
	if _attack_timer > 0.0:
		_attack_timer -= delta
	if _attack_anim_timer > 0.0:
		_attack_anim_timer -= delta

	# gravedad
	velocity.y = minf(velocity.y + GRAVITY * delta, MAX_FALL_SPEED)

	if player == null:
		velocity.x = 0.0
		_update_animacion()
		return

	var dist := global_position.distance_to(player.global_position)

	if _usar_proyectil():
		if dist <= enemy_data.shoot_range and _attack_timer <= 0.0:
			_disparar(player)
			_attack_timer = enemy_data.attack_cooldown
		if enemy_data.retrocede_dist > 0.0 and dist <= enemy_data.retrocede_dist:
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
			if enemy_data.windup_tiempo > 0.0:
				_windup_timer = enemy_data.windup_tiempo
				_reproducir_animacion_ataque("attack1")
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
	var player := get_tree().get_first_node_in_group("player")
	if player == null:
		return
	_dir = 1 if player.global_position.x > global_position.x else -1
	if visual != null:
		visual.scale.x = absf(visual.scale.x) * -_dir


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


func _update_animacion() -> void:
	if animated == null or not animated.visible:
		return
	var nombre := "idle"
	if _attack_anim_timer > 0.0:
		nombre = _attack_anim
	elif not is_on_floor():
		nombre = "jump"
	elif absf(velocity.x) > 10.0:
		nombre = "run"
	if animated.animation != nombre:
		animated.play(nombre)


func _reproducir_animacion_ataque(nombre: String) -> void:
	_attack_anim = nombre
	_attack_anim_timer = 0.35


func _usar_proyectil() -> bool:
	return enemy_data != null and enemy_data.projectile


func _ataque_melee(player: Node2D) -> void:
	_reproducir_animacion_ataque("attack1")
	player.take_damage(enemy_data.attack_damage, 0.0, _dir)


func _disparar(player: Node2D) -> void:
	_reproducir_animacion_ataque("attack2")
	var to_player: Vector2 = player.global_position - global_position
	var dir: Vector2 = to_player.normalized() if to_player.length_squared() > 0.01 else Vector2(_dir, 0.0)
	var proj: Area2D = preload("res://scenes/projectile.tscn").instantiate()
	proj.global_position = global_position + Vector2(_dir * 25.0, -10.0)
	proj.set("direction", dir)
	proj.set("speed", enemy_data.proyectil_speed)
	proj.set("damage", enemy_data.attack_damage)
	proj.set("enemy_shot", true)
	var destino: Node = get_tree().current_scene if get_tree().current_scene != null else get_parent()
	destino.add_child(proj)


func take_damage(cantidad: int, knockback: float = 0.0, dir: int = 1) -> void:
	if health <= 0:
		return
	health -= cantidad
	if visual != null:
		visual.modulate = Color(1, 0.6, 0.6)
		var base_scale := visual.scale
		var sx := absf(base_scale.x)
		var sy := base_scale.y
		# El squash preserva el facing actual: usar `dir` aquí voltearía al sprite
		# hacia el lado opuesto al jugador (el golpe viene de la dirección opuesta).
		var signo := signf(base_scale.x)
		if signo == 0.0:
			signo = 1.0
		var tw2 := create_tween()
		tw2.tween_property(visual, "scale", Vector2(signo * sx * 1.15, sy * 0.85), 0.05)
		tw2.tween_property(visual, "scale", Vector2(signo * sx, sy), 0.09).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		if DisplayServer.get_name() != "headless":
			var lbl := Label.new()
			lbl.text = str(cantidad)
			lbl.add_theme_font_size_override("font_size", 22)
			lbl.add_theme_color_override("font_color", Color(1, 0.85, 0.3))
			lbl.z_index = 10
			var scn: Node = get_tree().current_scene if get_tree().current_scene != null else get_parent()
			scn.add_child(lbl)
			lbl.global_position = global_position + Vector2(randf_range(-12, 12), -50)
			var tw3 := lbl.create_tween()
			tw3.tween_property(lbl, "global_position:y", lbl.global_position.y - 32, 0.6).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
			tw3.parallel().tween_property(lbl, "modulate:a", 0.0, 0.6)
			tw3.tween_callback(lbl.queue_free)
	var audio_mgr := get_node_or_null("/root/AudioManager")
	if audio_mgr != null:
		# el sonido del cuerpo suena cuando la animación se des-congela (impacto visible)
		audio_mgr.play_sfx_sincronizado(sonido_golpe, volumen_golpe_db)
	var en_ataque := _windup_timer > 0.0 or _lunge_timer > 0.0
	var armadura: bool = enemy_data != null and enemy_data.armadura_ataque and en_ataque
	if knockback > 0.0 and not armadura:
		var resist: float = enemy_data.knockback_resist if enemy_data != null else 1.0
		velocity.x = dir * knockback * (1.0 - resist)
		_stun_timer = 0.22
	if not armadura:
		_windup_timer = 0.0
		_lunge_timer = 0.0
	await get_tree().create_timer(0.08).timeout
	if is_instance_valid(visual):
		visual.modulate = Color(1, 1, 1)
	if health <= 0:
		_morir()


func _morir() -> void:
	var player := get_tree().get_first_node_in_group("player")
	if player != null and player.has_method("on_enemy_killed"):
		(player as Node2D).on_enemy_killed()
	died.emit()
	_freeze_hitstop(0.09)
	if DisplayServer.get_name() != "headless":
		var cam := get_viewport().get_camera_2d()
		if cam != null and cam.has_method("punch"):
			cam.punch(1.05)
	_liberar_only()
	set_physics_process(false)
	_colision(false)
	_burst_particulas()
	_soltar_orbe_vida()
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


func _burst_particulas() -> void:
	if DisplayServer.get_name() == "headless":
		return
	var p: CPUParticles2D = (load("res://scenes/burst.tscn") as PackedScene).instantiate()
	p.global_position = global_position
	p.self_modulate = enemy_data.color if enemy_data != null else Color(0.6, 0.3, 0.3)
	get_tree().root.add_child(p)
	p.restart()
	p.emitting = true
