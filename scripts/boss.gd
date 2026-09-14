extends CharacterBody2D
## Arzobispo: jefe final del bosque corrupto (el "antiguo poder oculto" que la
## secta despierta). Pelea contra óptima por forma, NO bloqueante:
##  - Fase 1 (100-66%): ronda en el suelo. Orbes en abanico + embestida + sismo.
##                      Oso rompe la armadura por umbral; Humano chipea DPS.
##  - Fase 2 (66-33%): flota e invoca cultistas (+energía). Escudo = cristales
##                      de energía que SOLO rompe el sónico del Murciélago; al
##                      romperlos cae a la arena y queda expuesto (ventana).
##  - Fase 3 (33-0%): enfurecido. Embistida rápida + ondas + ráfagas; ventana
##                      breve tras cada patrón (Lobo esquiva, Oso/Humano DPS).
## Todo es @export para tunear desde el Inspector. La barra de vida y el nombre
## los muestra el HUD (group "boss").

signal salud_cambio(hp: int, max_hp: int)
signal fase_cambio(fase: int)
signal died

const GRAVITY := 980.0
const MAX_FALL_SPEED := 950.0

const ENEMY_SCENE := preload("res://scenes/enemy.tscn")
const CRISTAL_SCENE := preload("res://scenes/cristal.tscn")
const PROYECTIL_SCENE := preload("res://scenes/projectile.tscn")

enum Fase { UNO, DOS, TRES }

# Abanico de orbes (rad). Triangulado para dar variedad sin repetir.
const ABANICO := [-0.55, -0.28, 0.0, 0.28, 0.55]

@export_group("Vida y daño")
@export var vida_max := 600
@export var ola_asignada := 0  # para integrarse al Encounter como enemigo manual
@export var dano_toque := 16
@export var dano_embestida := 26
@export var dano_orb := 14
@export var dano_onda := 18
@export var armor_umbral_fase1 := 17  # golpes con daño >= umbral rompen su guardia
@export var armor_umbral_fase3 := 0   # fase 3: sin guardia, a pura ventana

@export_group("Movimiento")
@export var vel_embestida := 820.0
@export var vel_persecucion := 250.0
@export var altura_vuelo := 320.0     # px sobre el piso al flotar en fase 2

@export_group("Timing")
@export var pausa_entre_patrones := 1.1
@export var ventana_f2 := 4.0         # ventana en el suelo tras romper cristales
@export var ventana_f3 := 0.9         # ventana tras cada patrón en fase 3
@export var cristales_por_ciclo := 3
@export var golpes_para_romper_cristal := 2
@export var invocadores_por_oleada := 2
@export var cada_invocacion_aerea := 9.0
@export var cada_invocacion_fase1 := 16.0

@export_group("Apariencia")
@export var color_fase1 := Color(0.28, 0.5, 0.32)
@export var color_fase2 := Color(0.45, 0.32, 0.6)
@export var color_fase3 := Color(0.62, 0.2, 0.18)

@export_group("Audio")
@export var sonido_golpe: AudioStream
@export var volumen_golpe_db := -14.0
# Si se deja vacío, el rugido se genera por código (ruido grave sintetizado).
@export var sonido_roar: AudioStream

var health := 0
var fase: int = Fase.UNO
var enemy_data: Enemigo   # solo alimenta el factor de peso del hitstop del jugador

var _activo := false
var _muerto := false
var _invocado := false
var _armadura_activa := false
var _stun_timer := 0.0
var _telegraph_timer := 0.0
var _telegraph_color := Color(1, 1, 1)
var _modo_mov := "quieto"   # quieto | chase | dash | flotar | caer
var _dash_dir := 1
var _dash_hasta := 0.0
var _forzar_aereo := false
var _cristales_vivos := 0
var _timer_invocacion_aerea := 0.0
var _timer_invocacion_fase1 := 0.0
var _contacto_timer := 0.0
var _piso_y := 0.0
var _centro_arena := 0.0
var _medio_arena := 360.0
var _dir := -1
var _spawned: Array[Node] = []
var _cristales: Array[Node] = []
var _tint_tween: Tween
var _player_cache: Node2D
var _roar_audio: AudioStream
var _whoosh_audio: AudioStream
var _audio_mgr: Node

@onready var visual: Node2D = $Visual
@onready var mitra: Polygon2D = $Visual/Mitra
@onready var roba: Polygon2D = $Visual/Roba
@onready var ojo_izq: Polygon2D = $Visual/Ojos/IZQ
@onready var ojo_der: Polygon2D = $Visual/Ojos/DER
@onready var halo: Polygon2D = $Visual/Halo
@onready var aura: Polygon2D = $Visual/Aura
@onready var collider: CollisionShape2D = $Collision
@onready var cuerpo_dano: Area2D = $CuerpoDano
@onready var sombra: Polygon2D = $Sombra


func _ready() -> void:
	add_to_group("boss")
	health = vida_max
	_piso_y = global_position.y
	enemy_data = Enemigo.new()
	enemy_data.max_health = vida_max
	_audio_mgr = get_node_or_null("/root/AudioManager")
	_roar_audio = sonido_roar if sonido_roar != null else _generar_ruido(0.55, 130.0, 50.0, 0.9)
	_whoosh_audio = _generar_ruido(0.3, 750.0, 190.0, 0.5)
	cuerpo_dano.body_entered.connect(_on_contacto)
	_aplicar_color(color_fase1)
	_telegraph_timer = 0.0


# --- API para el Encounter (misma firma que enemy.gd) ---

func preparar_ola() -> void:
	_activo = false
	_invocado = false
	_modo_mov = "quieto"
	if visual != null:
		visual.visible = false
	_colisionar(false)


func activar() -> void:
	if _invocado or _muerto:
		return
	_invocado = true
	_activo = true
	_piso_y = global_position.y
	var arena := _datos_arena()
	_centro_arena = arena[0]
	_medio_arena = arena[1]
	visual.visible = true
	_colisionar(true)
	_ritual_entrada()
	salud_cambio.emit(health, vida_max)
	_ronda()


## Mata al jefe desde afuera (anti soft-lock del Encounter si cae a un pozo).
func matar_por_caida() -> void:
	if _muerto:
		return
	health = 0
	_morir()


# --- Heridas del jugador ---

func take_damage(cantidad: int, knockback: float = 0.0, dir: int = 1, critico: bool = false) -> void:
	if _muerto or not _activo or health <= 0:
		return
	if _armadura_activa:
		_mostrar_absorbido(cantidad)
		return
	var umbral := _umbral_actual()
	if umbral > 0 and cantidad < umbral:
		_mostrar_absorbido(cantidad)
		return
	health = maxi(health - cantidad, 0)
	salud_cambio.emit(health, vida_max)
	_flash_tint()
	if DisplayServer.get_name() != "headless":
		_mostrar_dano(cantidad, critico, health <= 0)
	if health <= 0:
		_morir()
		return
	if knockback > 0.0:
		velocity.x = dir * knockback * 0.22
	var nuevo_fase := _fase_para_hp()
	if nuevo_fase != fase:
		_cambiar_fase(nuevo_fase)
	if _audio_mgr != null and sonido_golpe != null:
		_audio_mgr.play_sfx_sincronizado(sonido_golpe, volumen_golpe_db)


# --- Física ---

func _physics_process(delta: float) -> void:
	if _muerto or not _activo:
		return
	if _telegraph_timer > 0.0:
		_telegraph_timer -= delta
		aura.visible = true
		aura.color = Color(_telegraph_color.r, _telegraph_color.g, _telegraph_color.b, _telegraph_timer)
		if _telegraph_timer <= 0.0 and is_instance_valid(aura):
			aura.visible = false
	if _stun_timer > 0.0:
		_stun_timer -= delta
		velocity.x = move_toward(velocity.x, 0.0, 500.0 * delta)
		_apply_gravity(delta)
	else:
		match _modo_mov:
			"chase":
				_perseguir(delta)
			"dash":
				var dir_to := 1.0 if _dash_hasta > global_position.x else -1.0
				velocity.x = dir_to * vel_embestida
				_apply_gravity(delta)
			"flotar":
				velocity.y = 0.0
				global_position.y = lerpf(global_position.y, _piso_y - altura_vuelo, minf(3.0 * delta, 1.0))
			"caer":
				_apply_gravity(delta)
			_:
				velocity.x = move_toward(velocity.x, 0.0, 700.0 * delta)
				_apply_gravity(delta)
	move_and_slide()
	_contacto_tick()
	_timer_invocacion_aerea -= delta
	_timer_invocacion_fase1 -= delta


func _apply_gravity(delta: float) -> void:
	if _modo_mov != "flotar":
		velocity.y = minf(velocity.y + GRAVITY * delta, MAX_FALL_SPEED)


func _perseguir(delta: float) -> void:
	var player := _obtener_player()
	if player == null:
		_modo_mov = "quieto"
		return
	var dx: float = player.global_position.x - global_position.x
	velocity.x = signf(dx) * vel_persecucion
	if _dir != signf(dx) and dx != 0.0:
		_dir = int(signf(dx))
		_voltear()


func _voltear() -> void:
	if visual == null:
		return
	var esc := absf(visual.scale.x)
	visual.scale = Vector2(esc * _dir, visual.scale.y)


func _contacto_tick() -> void:
	if _muerto or not _activo:
		return
	if _contacto_timer > 0.0:
		_contacto_timer -= get_physics_process_delta_time()
		return
	for b in cuerpo_dano.get_overlapping_bodies():
		if b.is_in_group("player"):
			_contacto_timer = 0.55
			var dmg := dano_embestida if _modo_mov == "dash" else dano_toque
			var kb := 190.0 if _modo_mov == "dash" else 60.0
			b.take_damage(dmg, kb, _dir)
			return


func _on_contacto(body: Node) -> void:
	if _contacto_timer > 0.0 or _muerto or not _activo:
		return
	if body.is_in_group("player"):
		_contacto_timer = 0.55
		var dmg := dano_embestida if _modo_mov == "dash" else dano_toque
		var kb := 190.0 if _modo_mov == "dash" else 60.0
		body.take_damage(dmg, kb, _dir)


# --- Rondas (FSM con corrutinas) ---

func _ronda() -> void:
	await _esperar(0.4)
	while _activo and not _muerto:
		if _forzar_aereo:
			_forzar_aereo = false
			await _ronda_aerea()
			if not _activo or _muerto:
				break
			continue
		await _aproximar()
		if not _activo or _muerto:
			break
		if fase == Fase.TRES:
			await _hacer_patron_tres()
		else:
			await _hacer_patron_uno()
		if not _activo or _muerto:
			break
		await _esperar(pausa_entre_patrones)


func _aproximar() -> void:
	var player := _obtener_player()
	if player == null:
		return
	_modo_mov = "chase"
	var t := 0.0
	while t < 1.2 and _activo and not _muerto and is_instance_valid(player):
		if absf((player as Node2D).global_position.x - global_position.x) < 250.0:
			break
		await _esperar(0.1)
		t += 0.1
	_modo_mov = "quieto"


func _hacer_patron_uno() -> void:
	if _timer_invocacion_fase1 <= 0.0:
		_invocar(1, "cultista")
		_timer_invocacion_fase1 = cada_invocacion_fase1
	var p := _elegir(["embestida", "ornadas", "sismo", "ornadas"])
	match p:
		"embestida":
			await _embestida(false)
		"ornadas":
			await _ornadas(1)
		_:
			await _sismo(1)


func _hacer_patron_tres() -> void:
	var p := _elegir(["embestida", "ornadas", "sismo", "embestida"])
	match p:
		"embestida":
			await _embestida(true)
		"ornadas":
			await _ornadas(2)
		_:
			await _sismo(2)
	if _activo and not _muerto:
		# La ventana de daño tras cada patrón (recoil en el suelo).
		_stun_timer = ventana_f3
		_modo_mov = "quieto"
		await _esperar(ventana_f3)
		_stun_timer = 0.0


func _embestida(rapida: bool) -> void:
	var player := _obtener_player()
	var tel := 0.28 if rapida else 0.55
	_tele_ateos(tel, Color(1, 0.9, 0.6))
	await _esperar(tel)
	if not _activo or _muerto:
		_modo_mov = "quieto"
		return
	var recorridos := 3 if rapida else 2
	while recorridos > 0 and _activo and not _muerto:
		var target: Vector2 = (player as Node2D).global_position if is_instance_valid(player) else global_position
		_dash_dir = -1 if target.x < global_position.x else 1
		_dash_hasta = _centro_arena + _dash_dir * (_medio_arena - 40.0)
		_modo_mov = "dash"
		_voltear()
		_whoosh()
		var dist := absf(_dash_hasta - global_position.x)
		var t := clampf(dist / vel_embestida, 0.25, 1.2)
		await _esperar(t)
		if not _activo or _muerto:
			break
		recorridos -= 1
		_modo_mov = "quieto"
		await _esperar(0.18 if not rapida else 0.1)
	_modo_mov = "quieto"


func _ornadas(veces: int) -> void:
	var player := _obtener_player()
	_tele_ateos(0.4, Color(1, 0.8, 0.5))
	await _esperar(0.4)
	for v in range(veces):
		if not _activo or _muerto:
			break
		if is_instance_valid(player):
			var base: Vector2 = (player as Node2D).global_position - global_position
			for ang in ABANICO:
				_disparar_orb(base, ang, dano_orb, 460.0 + v * 40.0)
		await _esperar(0.22)
	_modo_mov = "quieto"


func _sismo(veces: int) -> void:
	var player := _obtener_player()
	_tele_ateos(0.55, Color(1, 0.85, 0.5))
	await _esperar(0.55)
	for v in range(veces):
		if not _activo or _muerto:
			break
		_golpe_piso()
		if is_instance_valid(player):
			var hacia: float = signf((player as Node2D).global_position.x - global_position.x)
			_onda_por_piso(dano_onda, hacia if hacia != 0.0 else 1.0)
		await _golpe_piso()
		await _esperar(0.4)
	_modo_mov = "quieto"


# --- Fase 2: aéreo + cristales + invocaciones ---

func _ronda_aerea() -> void:
	while _activo and not _muerto and fase == Fase.DOS:
		await _torcer_aereo()
		if not _activo or _muerto:
			break
		_invocar_cristales()
		while _activo and not _muerto and fase == Fase.DOS:
			if _cristales_vivos <= 0:
				break
			await _esperar(0.9)
			if not _activo or _muerto:
				return
			var player := _obtener_player()
			if is_instance_valid(player):
				_disparar_orb((player as Node2D).global_position - global_position, 0.0, dano_orb, 500.0)
			if _timer_invocacion_aerea <= 0.0:
				_invocar(invocadores_por_oleada, "cultista")
				_timer_invocacion_aerea = cada_invocacion_aerea
		if _activo and not _muerto:
			await _caer_y_ventana(ventana_f2)


func _torcer_aereo() -> void:
	_armadura_activa = true
	_modo_mov = "flotar"
	_voltear()
	_rugido()
	_hablar([
		"¡Se eleva! Su escudo son cristales de energía corrupta.",
		"ROMPELOS con el sónico del Murciélago para abrir su defensa.",
	])
	if visual != null:
		visual.scale = Vector2(visual.scale.x * 1.12, visual.scale.y * 0.88)
		await _esperar(0.15)
		if is_instance_valid(visual):
			visual.scale = Vector2(visual.scale.x / 1.12, visual.scale.y / 0.88)


func _invocar_cristales() -> void:
	for i in range(cristales_por_ciclo):
		var c := CRISTAL_SCENE.instantiate()
		var off_x := (float(i) - float(cristales_por_ciclo - 1) * 0.5) * 180.0
		c.set("cristal_color", color_fase2)
		c.set("golpes_para_romper", golpes_para_romper_cristal)
		c.set("float_amplitude", 14.0)
		var destino: Node = get_tree().current_scene if get_tree().current_scene != null else get_parent()
		destino.add_child(c)
		c.global_position = Vector2(
			_centro_arena + off_x,
			global_position.y - 150.0
		)
		c.cristal_destruido.connect(_on_cristal_roto)
		_cristales.append(c)
		_cristales_vivos += 1


func _on_cristal_roto() -> void:
	_cristales_vivos = maxi(_cristales_vivos - 1, 0)
	if _cristales_vivos <= 0:
		_rugido()


func _caer_y_ventana(dur: float) -> void:
	_armadura_activa = false
	_modo_mov = "caer"
	var t := 0.0
	while t < dur and _activo and not _muerto:
		await _esperar(0.05)
		t += 0.05
		if is_on_floor():
			_modo_mov = "quieto"
	_modo_mov = "quieto"


# --- Transición de fase / muerte ---

func _fase_para_hp() -> int:
	var pct := float(health) / float(vida_max)
	if pct > 0.66:
		return Fase.UNO
	if pct > 0.33:
		return Fase.DOS
	return Fase.TRES


func _umbral_actual() -> int:
	if fase == Fase.TRES:
		return armor_umbral_fase3
	return armor_umbral_fase1


func _cambiar_fase(nueva: int) -> void:
	if nueva < Fase.UNO or nueva > Fase.TRES or nueva == fase:
		return
	fase = nueva
	fase_cambio.emit(fase)
	var cam := get_viewport().get_camera_2d()
	match nueva:
		Fase.DOS:
			_aplicar_color(color_fase2)
			_forzar_aereo = true
			_rugido()
			_hablar(["¡EL ARZOBISPO DESPIERTA su verdadera forma!"])
			if cam != null and cam.has_method("shake"):
				cam.shake(6.0, 0.5)
		Fase.TRES:
			_aplicar_color(color_fase3)
			# Corta el ciclo aéreo: la fase 3 es puramente en el suelo.
			_forzar_aereo = false
			_armadura_activa = false
			_rugido()
			_hablar(["¡SE ENFURECIÓ!", "Esquivalo con el Lobo y castigalo en la ventana."])
			if cam != null and cam.has_method("shake"):
				cam.shake(8.0, 0.6)
			_stun_timer = 1.2


func _morir() -> void:
	if _muerto:
		return
	_muerto = true
	_activo = false
	_modo_mov = "quieto"
	_limpiar_cristales()
	for n in _spawned:
		if is_instance_valid(n):
			n.queue_free()
	_spawned.clear()
	_colisionar(false)
	if _audio_mgr != null and _roar_audio != null:
		_audio_mgr.play_sfx(_roar_audio, -6.0)
	var cam := get_viewport().get_camera_2d()
	if cam != null and cam.has_method("shake"):
		cam.shake(14.0, 0.7)
	_freeze_hitstop(0.14)
	_slowmo(0.7, 0.3)
	if DisplayServer.get_name() != "headless":
		_burst_muerte()
	if visual != null:
		visual.modulate = Color(4, 4, 4, 1)
		var tw := create_tween()
		tw.tween_property(visual, "modulate:a", 0.0, 0.55)
		tw.parallel().tween_property(sombra, "modulate:a", 0.0, 0.55)
		tw.tween_callback(queue_free)
	died.emit()


func _limpiar_cristales() -> void:
	for c in _cristales:
		if is_instance_valid(c):
			c.queue_free()
	_cristales.clear()
	_cristales_vivos = 0


# --- Enemigos invocados (alimentan la energía del jugador al morir) ---

func _invocar(cant: int, tipo: String) -> void:
	for i in range(cant):
		var e := ENEMY_SCENE.instantiate()
		e.set("tipo", tipo)
		e.set("spawn_telegrafiado", true)
		e.set("ritual_duracion", 0.8)
		var lado := 1.0 if i % 2 == 0 else -1.0
		var x := _centro_arena + lado * (_medio_arena + 150.0 - float(i) * 60.0)
		var destino: Node = get_tree().current_scene if get_tree().current_scene != null else get_parent()
		destino.add_child(e)
		e.global_position = Vector2(x, _piso_y)
		e.activar()
		_spawned.append(e)


# --- Herramientas ---

func _disparar_orb(to_player: Vector2, ang: float, dmg: int, speed: float) -> void:
	var base := to_player.normalized() if to_player.length_squared() > 0.01 else Vector2(_dir, 0.0)
	var c := cos(ang)
	var s := sin(ang)
	var dir := Vector2(base.x * c - base.y * s, base.x * s + base.y * c)
	var proj := PROYECTIL_SCENE.instantiate()
	var destino: Node = get_tree().current_scene if get_tree().current_scene != null else get_parent()
	destino.add_child(proj)
	proj.global_position = global_position + Vector2(0, -120)
	proj.set("direction", dir.normalized())
	proj.set("speed", speed)
	proj.set("damage", dmg)
	proj.set("enemy_shot", true)


func _onda_por_piso(dmg: int, hacia: float) -> void:
	var proj := PROYECTIL_SCENE.instantiate()
	var destino: Node = get_tree().current_scene if get_tree().current_scene != null else get_parent()
	destino.add_child(proj)
	proj.global_position = Vector2(global_position.x + hacia * 70.0, global_position.y - 50.0)
	proj.set("direction", Vector2(hacia, 0))
	proj.set("speed", 620.0)
	proj.set("damage", dmg)
	proj.set("enemy_shot", true)


func _ritual_entrada() -> void:
	var anillo := Polygon2D.new()
	anillo.polygon = _circulo_poligono(26, 90.0)
	anillo.color = Color(0.6, 0.2, 0.2, 0.7)
	anillo.position = Vector2(0, 20)
	add_child(anillo)
	var tw := create_tween()
	tw.tween_property(anillo, "scale", Vector2(1.6, 1.6), 0.7)
	tw.parallel().tween_property(anillo, "modulate:a", 0.0, 0.7)
	tw.tween_callback(anillo.queue_free)
	_rugido()
	var cam := get_viewport().get_camera_2d()
	if cam != null and cam.has_method("shake"):
		cam.shake(4.0, 0.5)


func _circulo_poligono(puntos: int, radio: float) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in range(puntos):
		var ang := TAU * float(i) / float(puntos)
		pts.append(Vector2(cos(ang), sin(ang)) * radio)
	return pts


func _tele_ateos(dur: float, color: Color) -> void:
	_telegraph_timer = dur
	_telegraph_color = color
	aura.visible = true
	aura.color = Color(color.r, color.g, color.b, dur)
	_modo_mov = "quieto"


func _golpe_piso() -> void:
	var cam := get_viewport().get_camera_2d()
	if cam != null and cam.has_method("shake"):
		cam.shake(9.0, 0.5)
	_freeze_hitstop(0.1)
	if visual != null:
		var base := visual.scale
		visual.scale = Vector2(base.x * 1.18, base.y * 0.8)
		await _esperar(0.06)
		if is_instance_valid(visual):
			visual.scale = Vector2(absf(base.x) * signf(visual.scale.x), base.y)
	_rugido()


func _flash_tint() -> void:
	if visual == null:
		return
	if _tint_tween != null and _tint_tween.is_valid():
		_tint_tween.kill()
	visual.modulate = Color(1, 0.6, 0.6)
	_tint_tween = create_tween()
	_tint_tween.tween_property(visual, "modulate", Color.WHITE, 0.1)


func _mostrar_absorbido(cantidad: int) -> void:
	if DisplayServer.get_name() == "headless":
		return
	var lbl := Label.new()
	lbl.text = "·" if cantidad <= 0 else str(cantidad)
	lbl.add_theme_font_size_override("font_size", 24)
	lbl.add_theme_constant_override("outline_size", 4)
	lbl.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.7))
	lbl.add_theme_color_override("font_color", Color(0.75, 0.8, 0.85))
	lbl.z_index = 12
	var destino: Node = get_tree().current_scene if get_tree().current_scene != null else get_parent()
	destino.add_child(lbl)
	lbl.global_position = global_position + Vector2(randf_range(-18, 18), -180)
	var tw := lbl.create_tween()
	tw.tween_property(lbl, "global_position:y", lbl.global_position.y - 26, 0.4)
	tw.parallel().tween_property(lbl, "modulate:a", 0.0, 0.4)
	tw.tween_callback(lbl.queue_free)


func _mostrar_dano(cantidad: int, critico: bool, murio: bool) -> void:
	var fuerte := critico or murio
	var lbl := Label.new()
	lbl.text = str(cantidad)
	var tam := 30 if fuerte else 24
	lbl.add_theme_font_size_override("font_size", tam)
	lbl.add_theme_constant_override("outline_size", maxi(4, tam / 5))
	lbl.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
	if murio:
		lbl.add_theme_color_override("font_color", Color(1, 0.92, 0.55))
	elif critico:
		lbl.add_theme_color_override("font_color", Color(1, 0.6, 0.18))
	else:
		lbl.add_theme_color_override("font_color", Color(1, 0.85, 0.3))
	lbl.z_index = 12
	var destino: Node = get_tree().current_scene if get_tree().current_scene != null else get_parent()
	destino.add_child(lbl)
	lbl.scale = Vector2(1.6, 1.6)
	lbl.global_position = global_position + Vector2(randf_range(-18, 18), -190)
	var subida := 52.0 if fuerte else 34.0
	var dur := 0.8 if fuerte else 0.55
	var tw := lbl.create_tween()
	tw.tween_property(lbl, "scale", Vector2.ONE, 0.12).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(lbl, "global_position:y", lbl.global_position.y - subida, dur).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(lbl, "modulate:a", 0.0, dur)
	tw.tween_callback(lbl.queue_free)


func _aplicar_color(color: Color) -> void:
	if mitra != null:
		mitra.color = color.lerp(Color(1, 1, 1), 0.12)
	if roba != null:
		roba.color = color.darkened(0.15)
	if halo != null:
		halo.color = Color(color.r, color.g, color.b, 0.25)
	if ojo_izq != null and ojo_der != null:
		var rojo := color_fase3 if fase == Fase.TRES else Color(1.0, 0.25, 0.15)
		ojo_izq.color = rojo
		ojo_der.color = rojo


func _burst_muerte() -> void:
	var p: CPUParticles2D = (load("res://scenes/burst.tscn") as PackedScene).instantiate()
	p.global_position = global_position + Vector2(0, -180)
	p.self_modulate = color_fase3 if fase == Fase.TRES else color_fase2
	p.amount = 26
	get_tree().root.add_child(p)
	p.restart()
	p.emitting = true


func _colisionar(on: bool) -> void:
	if collider != null:
		collider.set_deferred("disabled", not on)
	if cuerpo_dano != null:
		cuerpo_dano.set_deferred("monitoring", on)


# --- Audio ---

func _rugido() -> void:
	if _audio_mgr != null and _roar_audio != null:
		_audio_mgr.play_sfx(_roar_audio, -8.0)


func _whoosh() -> void:
	if _audio_mgr != null and _whoosh_audio != null:
		_audio_mgr.play_sfx(_whoosh_audio, -6.0)


func _hablar(lineas: Array) -> void:
	var dialogo := get_node_or_null("/root/Dialogo")
	if dialogo != null:
		dialogo.mostrar(lineas, "Amuleto")


## Natural: genera un rugido grave con envolvente y pitch descendente.
func _generar_ruido(duracion: float, freq_ini: float, freq_fin: float, vol: float) -> AudioStream:
	var sr := 22050
	var n := int(duracion * sr)
	var data := PackedByteArray()
	data.resize(n * 2)
	var sem := 0
	for i in n:
		sem = (sem * 1103515245 + 12345) & 0x7FFFFFFF
		var rnd := float(sem) / 1073741824.0 - 1.0
		var t := float(i) / float(n)
		var freq := lerpf(freq_ini, freq_fin, t)
		var env := sin(PI * minf(t * 1.5, 1.0))
		var v := (sin(TAU * freq * t) * 0.6 + rnd * 0.4) * env * vol
		var s := int(clampf(v, -1.0, 1.0) * 12000.0)
		data[i * 2] = s & 0xFF
		data[i * 2 + 1] = (s >> 8) & 0xFF
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = sr
	wav.stereo = false
	wav.data = data
	return wav


func _datos_arena() -> Array:
	var enc := get_tree().get_first_node_in_group("encounter")
	if enc != null and "arena_center" in enc and "arena_medio_ancho" in enc:
		return [float(enc.arena_center.x), float(enc.arena_medio_ancho)]
	return [global_position.x, _medio_arena]


func _elegir(opciones: Array) -> String:
	return str(opciones[randi() % opciones.size()])


func _obtener_player() -> Node2D:
	if not is_instance_valid(_player_cache):
		_player_cache = get_tree().get_first_node_in_group("player")
	return _player_cache


func _esperar(t: float) -> void:
	await get_tree().create_timer(t).timeout


func _freeze_hitstop(duracion: float = 0.07) -> void:
	var hs := get_node_or_null("/root/Hitstop")
	if hs != null and hs.has_method("freeze"):
		hs.freeze(duracion)


func _slowmo(duracion: float, escala: float) -> void:
	var hs := get_node_or_null("/root/Hitstop")
	if hs != null and hs.has_method("slowmo"):
		hs.slowmo(duracion, escala)