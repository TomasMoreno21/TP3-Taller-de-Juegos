extends CharacterBody2D
## Arzobispo: jefe final del bosque corrupto. PRESIDE la pelea flotando arriba y
## ATRÁS (z bajo, domina la pantalla): nunca se le pega al cuerpo.
## Para dañarlo hay que completar un ritual de 3 barreras que se repite en
## ciclos hasta su caída:
##   1. LEGIÓN  — aparecen cultistas que le dan escudo (invulnerable); matalos.
##   2. CRISTALES — invoca cristales de energía; solo los rompe el sónico del
##      Murciélago. Al romperlos cae su guardia.
##   3. ZONA MARCADA — baja una zona brillante al alcance del jugador; pegarle
##      en la marca hace daño de verdad. La marca rota entre 3 sitios (slots).
## Cada ciclo completo endurece el siguiente (más cultistas, ventana más corta)
## y al bajar la vida el jefe se corrompe (Fase.DOS > 66%, Fase.TRES > 33%):
## furia = color + más cultistas + orbes más frecuentes. Todo @export para
## tunear desde el Inspector. La barra y el nombre los muestra el HUD.

signal salud_cambio(hp: int, max_hp: int)
signal fase_cambio(fase: int)
signal died

const ENEMY_SCENE := preload("res://scenes/enemy.tscn")
const CRISTAL_SCENE := preload("res://scenes/cristal.tscn")
const PROYECTIL_SCENE := preload("res://scenes/projectile.tscn")

enum Fase { UNO, DOS, TRES }

# Sitios marcados a los que puede bajar la zona (x local del jefe).
const ZONA_SLOTS: Array[float] = [-190.0, 0.0, 190.0]

@export_group("Vida y daño")
@export var vida_max := 600
@export var ola_asignada := 0  # para integrarse al Encounter como enemigo manual
@export var dano_orb := 14
@export var dano_zona := 60    # daño real al jefe por golpe en la zona marcada

@export_group("Gates")
@export var legion_base := 2
@export var legion_max := 6
@export var cristales_por_ciclo := 3
@export var golpes_para_romper_cristal := 2
@export var toques_base_zona := 3
@export var ventana_zona := 6.5
@export var ventana_zona_por_vuelta := 0.7
@export var ventana_zona_min := 3.2
@export var intervalo_orbes := 2.2
@export var pausa_entre_ciclos := 1.4

@export_group("Vuelo")
@export var altura_vuelo := 260.0   # px sobre el piso a los que preside
@export var drift_seguimiento := 0.3

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
var _shield_active := false
var _gate := "inactivo"   # inactivo | legion | cristales | zona
var _vuelta := 0

var _cristales: Array[Node] = []
var _cristales_vivos := 0
var _invocados: Array[Node] = []
var _legion_vivos := 0

var _orbe_timer := 0.0
var _telegraph_timer := 0.0
var _telegraph_color := Color(1, 1, 1)
var _slot_idx := 0
var _zona_toques := 0
var _zona_ventana := 0.0
var _zona_t := 0.0
var _zona_mov := 0.0

var _piso_y := 0.0
var _centro_arena := 0.0
var _medio_arena := 360.0
var _dir := -1
var _player_cache: Node2D
var _tint_tween: Tween
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
@onready var tentaculo: Polygon2D = $Visual/Tentaculo
@onready var collider: CollisionShape2D = $Collision
@onready var sombra: Polygon2D = $Sombra
@onready var zona: StaticBody2D = $ZonaGolpe
@onready var zona_shape: CollisionShape2D = $ZonaGolpe/ZonaShape
@onready var zona_dardo: Polygon2D = $ZonaGolpe/ZonaVisual/Dardo
@onready var zona_anillo: Polygon2D = $ZonaGolpe/ZonaVisual/Anillo


func _ready() -> void:
	add_to_group("boss")
	health = vida_max
	_piso_y = global_position.y
	enemy_data = Enemigo.new()
	enemy_data.max_health = vida_max
	_audio_mgr = get_node_or_null("/root/AudioManager")
	_roar_audio = sonido_roar if sonido_roar != null else _generar_ruido(0.55, 130.0, 50.0, 0.9)
	_whoosh_audio = _generar_ruido(0.3, 750.0, 190.0, 0.5)
	_aplicar_color(color_fase1)
	# Entidad de fondo: nunca golpeable por melee directa (solo la zona marcada).
	collider.set_deferred("disabled", true)
	if zona_anillo != null:
		zona_anillo.polygon = _anillo_poligono(22, 36, 8)
	apuntar_zona(false)


# --- API para el Encounter (misma firma que enemy.gd) ---

func preparar_ola() -> void:
	_activo = false
	_invocado = false
	_gate = "inactivo"
	_shield_active = false
	if visual != null:
		visual.visible = false
	apuntar_zona(false)
	_limpiar_cristales()
	_limpiar_invocados()


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
	_vuelta = 0
	salud_cambio.emit(health, vida_max)
	_ritual_entrada()
	_hablar([
		"¡EL ARZOBISPO! Preside desde su trono de energía corrupta.",
		"Para herirlo tendrás que: matar a sus fieles, romper sus cristales",
		"y golpear la zona marcada cuando baje.",
	])
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
	if _shield_active:
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
	var nuevo_fase := _fase_para_hp()
	if nuevo_fase != fase:
		_cambiar_fase(nuevo_fase)
	if _audio_mgr != null and sonido_golpe != null:
		_audio_mgr.play_sfx_sincronizado(sonido_golpe, volumen_golpe_db)


## Un golpe conectó con la zona marcada → daño real al jefe.
func _golpe_en_zona(_cantidad: int) -> void:
	if _muerto or not _activo or _gate != "zona":
		return
	if _shield_active:
		_mostrar_absorbido(_cantidad)
		return
	take_damage(dano_zona, 0, 1, false)
	_zona_toques = maxi(_zona_toques - 1, 0)
	if _zona_toques > 0:
		_mover_zona_slot()


# --- Física (flotación presidencial) ---

func _physics_process(delta: float) -> void:
	if _muerto or not _activo:
		return
	_hover(delta)
	_telegraph_tick(delta)
	_orbe_tick(delta)
	if zona != null and zona.visible:
		_pulso_zona_visual()


func _hover(delta: float) -> void:
	var player := _obtener_player()
	var tgt_x := _centro_arena
	if player != null:
		var dx: float = (player as Node2D).global_position.x - _centro_arena
		tgt_x = _centro_arena + clampf(dx * drift_seguimiento, -230.0, 230.0)
	var sway := sin(Time.get_ticks_msec() * 0.002) * 26.0
	global_position.x = lerpf(global_position.x, tgt_x + sway, 2.2 * delta)
	global_position.y = lerpf(global_position.y, _piso_y - altura_vuelo, 3.0 * delta)
	var plx := (player as Node2D).global_position.x if player != null else global_position.x
	var nuevo_dir := 1 if plx > global_position.x else -1
	if _dir != nuevo_dir:
		_dir = nuevo_dir
		_voltear()


func _voltear() -> void:
	if visual == null:
		return
	var esc := absf(visual.scale.x)
	visual.scale = Vector2(esc * _dir, visual.scale.y)


func _telegraph_tick(delta: float) -> void:
	if _telegraph_timer <= 0.0:
		return
	_telegraph_timer -= delta
	aura.visible = true
	aura.color = Color(_telegraph_color.r, _telegraph_color.g, _telegraph_color.b, maxf(_telegraph_timer, 0.0))
	if _telegraph_timer <= 0.0:
		aura.visible = false


func _orbe_tick(delta: float) -> void:
	_orbe_timer -= delta
	if _orbe_timer > 0.0:
		return
	if _gate != "legion" and _gate != "cristales":
		return
	var player := _obtener_player()
	if is_instance_valid(player):
		_disparar_orb((player as Node2D).global_position - global_position, 0.0, dano_orb, 500.0)
	_orbe_timer = _intervalo_orbe()


func _intervalo_orbe() -> float:
	return maxf(intervalo_orbes - fase * 0.3 - _vuelta * 0.15, 1.0)


# --- Bucle de las 3 barreras ---

func _ronda() -> void:
	await _esperar(0.4)
	while _activo and not _muerto:
		await _gate_legion()
		if not _activo or _muerto:
			break
		_hablar(["Su guardia cede... ¡Rompe sus cristales de energía!"])
		await _esperar(0.9)
		await _gate_cristales()
		if not _activo or _muerto:
			break
		_hablar(["¡Cae! Golpea la zona marcada."])
		await _esperar(0.7)
		await _gate_zona()
		if not _activo or _muerto:
			break
		_vuelta += 1
		await _esperar(pausa_entre_ciclos)


# Barrera 1: Legión de fieles (le dan escudo).

func _gate_legion() -> void:
	_gate = "legion"
	_shield_active = true
	_pulso_aura(color_fase2)
	var cant := _legion_size()
	_legion_vivos = 0
	for i in range(cant):
		_spawn_cultista(i, cant)
	_hablar(["Sus fieles lo protegen.", "Acaba con ellos para abrir su guardia."])
	while _legion_vivos > 0 and _activo and not _muerto:
		await _esperar(0.4)


func _legion_size() -> int:
	return clampi(legion_base + _vuelta + fase, legion_base, legion_max)


func _spawn_cultista(i: int, total: int) -> void:
	var e := ENEMY_SCENE.instantiate()
	e.set("tipo", "cultista")
	e.set("spawn_telegrafiado", true)
	e.set("ritual_duracion", 0.7)
	var lado := 1.0 if i % 2 == 0 else -1.0
	var fila := floori(i / 2.0)
	var x := _centro_arena + lado * (_medio_arena - 60.0 * (fila + 1.0))
	var destino: Node = get_tree().current_scene if get_tree().current_scene != null else get_parent()
	destino.add_child(e)
	e.global_position = Vector2(x, _piso_y)
	e.activar()
	if e.has_signal("died"):
		e.died.connect(_on_cultista_muerto)
	_invocados.append(e)
	_legion_vivos += 1


func _on_cultista_muerto() -> void:
	if _legion_vivos > 0:
		_legion_vivos -= 1
		if _legion_vivos == 0:
			_pulso_aura(color_fase1)


# Barrera 2: cristales de energía (escudo sónico del Murciélago).

func _gate_cristales() -> void:
	_gate = "cristales"
	_shield_active = true
	_pulso_aura(color_fase2)
	_invocar_cristales()
	while _cristales_vivos > 0 and _activo and not _muerto:
		await _esperar(0.4)
	_shield_active = false


func _invocar_cristales() -> void:
	for i in range(cristales_por_ciclo):
		var c := CRISTAL_SCENE.instantiate()
		var off := (float(i) - float(cristales_por_ciclo - 1) * 0.5) * 170.0
		c.set("cristal_color", color_fase2)
		c.set("golpes_para_romper", golpes_para_romper_cristal)
		c.set("solo_murcielago", true)
		var destino: Node = get_tree().current_scene if get_tree().current_scene != null else get_parent()
		destino.add_child(c)
		c.global_position = Vector2(_centro_arena + off, _piso_y - altura_vuelo - 30.0)
		c.cristal_destruido.connect(_on_cristal_roto)
		_cristales.append(c)
		_cristales_vivos += 1


func _on_cristal_roto() -> void:
	_cristales_vivos = maxi(_cristales_vivos - 1, 0)
	if _cristales_vivos <= 0:
		_rugido()


# Barrera 3: zona marcada que baja al jugador (daño real).

func _gate_zona() -> void:
	_gate = "zona"
	_shield_active = false
	apuntar_zona(true)
	_zona_toques = toques_base_zona + _vuelta
	_zona_ventana = maxf(ventana_zona - _vuelta * ventana_zona_por_vuelta, ventana_zona_min)
	_zona_t = 0.0
	_zona_mov = 0.0
	while _activo and not _muerto and _zona_toques > 0 and _zona_t < _zona_ventana:
		_zona_t += 0.1
		_zona_mov += 0.1
		await _esperar(0.1)
		if _zona_mov >= 1.0:
			_zona_mov = 0.0
			_mover_zona_slot()
	apuntar_zona(false)


func apuntar_zona(on: bool) -> void:
	if zona != null:
		zona.visible = on
	if zona_shape != null:
		zona_shape.set_deferred("disabled", not on)
	if tentaculo != null:
		tentaculo.visible = on
	if on:
		_slot_idx = 0
		zona.position = Vector2(ZONA_SLOTS[0], zona.position.y)
		_zap_dardo()


func _mover_zona_slot() -> void:
	if zona == null:
		return
	_slot_idx = (_slot_idx + 1) % ZONA_SLOTS.size()
	zona.position.x = ZONA_SLOTS[_slot_idx]
	_zap_dardo()
	_tele_ateos(0.25, Color(1, 0.85, 0.5))
	if _audio_mgr != null and _whoosh_audio != null:
		_audio_mgr.play_sfx(_whoosh_audio, -4.0)
	var cam := get_viewport().get_camera_2d()
	if cam != null and cam.has_method("shake"):
		cam.shake(3.0, 0.18)


func _zap_dardo() -> void:
	if zona_dardo == null:
		return
	zona_dardo.color = Color(1, 1, 0.8)
	var tw := create_tween()
	tw.tween_property(zona_dardo, "scale", Vector2(1.5, 1.5), 0.08)
	tw.tween_property(zona_dardo, "scale", Vector2.ONE, 0.14)
	tw.tween_callback(func() -> void:
		if is_instance_valid(zona_dardo):
			zona_dardo.color = Color(1, 0.92, 0.55))


func _pulso_zona_visual() -> void:
	if zona_anillo != null:
		var pulso := 1.0 + sin(Time.get_ticks_msec() * 0.006) * 0.07
		zona_anillo.scale = Vector2(pulso, pulso)
		zona_anillo.rotation += get_physics_process_delta_time() * 1.6
	if zona_dardo != null:
		zona_dardo.color = Color(1, 0.92, 0.55).lightened(sin(Time.get_ticks_msec() * 0.01) * 0.08)


# --- Transición de fase (corrupción) / muerte ---

func _fase_para_hp() -> int:
	var pct := float(health) / float(vida_max)
	if pct > 0.66:
		return Fase.UNO
	if pct > 0.33:
		return Fase.DOS
	return Fase.TRES


func _cambiar_fase(nueva: int) -> void:
	if nueva < Fase.UNO or nueva > Fase.TRES or nueva == fase:
		return
	fase = nueva
	fase_cambio.emit(fase)
	_aplicar_color(_color_fase())
	_rugido()
	_pulso_aura(_color_fase())
	if fase == Fase.TRES:
		_hablar(["¡SE ENFURECIÓ!", "Mismo ritual, pero ya estaba harto de tus formas."])
	else:
		_hablar(["Se corrompe... ¡aprovechá su furia para la zona marcada!"])
	var cam := get_viewport().get_camera_2d()
	if cam != null and cam.has_method("shake"):
		cam.shake(8.0, 0.5)


func _color_fase() -> Color:
	match fase:
		Fase.DOS:
			return color_fase2
		Fase.TRES:
			return color_fase3
	return color_fase1


func _morir() -> void:
	if _muerto:
		return
	_muerto = true
	_activo = false
	apuntar_zona(false)
	_limpiar_cristales()
	_limpiar_invocados()
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


func _limpiar_invocados() -> void:
	for n in _invocados:
		if is_instance_valid(n):
			n.queue_free()
	_invocados.clear()
	_legion_vivos = 0


# --- Herramientas ---

func _disparar_orb(to_player: Vector2, ang: float, dmg: int, speed: float) -> void:
	var base := to_player.normalized() if to_player.length_squared() > 0.01 else Vector2(_dir, 0.0)
	var c := cos(ang)
	var s := sin(ang)
	var dir := Vector2(base.x * c - base.y * s, base.x * s + base.y * c)
	var proj := PROYECTIL_SCENE.instantiate()
	var destino: Node = get_tree().current_scene if get_tree().current_scene != null else get_parent()
	# enemy_shot se resuelve en _ready del proyectil (define la mask). Debe
	# setearse ANTES de add_child o el orb no golpea al jugador (y puede golpear
	# aliados). Ver projectile.gd.
	proj.set("direction", dir.normalized())
	proj.set("speed", speed)
	proj.set("damage", dmg)
	proj.set("enemy_shot", true)
	destino.add_child(proj)
	proj.global_position = global_position + Vector2(0, -120)


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


func _anillo_poligono(puntos: int, r_ext: float, grosor: float) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in range(puntos):
		var a := TAU * float(i) / float(puntos)
		pts.append(Vector2(cos(a), sin(a)) * r_ext)
	for i in range(puntos):
		var a := TAU * (1.0 - float(i) / float(puntos))
		pts.append(Vector2(cos(a), sin(a)) * (r_ext - grosor))
	return pts


func _tele_ateos(dur: float, color: Color) -> void:
	_telegraph_timer = dur
	_telegraph_color = color
	aura.visible = true
	aura.color = Color(color.r, color.g, color.b, dur)
	_pulso_aura(color)


func _pulso_aura(color: Color) -> void:
	if aura == null:
		return
	aura.visible = true
	aura.color = Color(color.r, color.g, color.b, 0.4)
	aura.scale = Vector2(0.55, 0.55)
	var tw := create_tween()
	tw.tween_property(aura, "scale", Vector2(1.2, 1.2), 0.55).set_trans(Tween.TRANS_CUBIC)
	tw.parallel().tween_property(aura, "color:a", 0.0, 0.55)
	tw.tween_callback(func() -> void:
		if is_instance_valid(aura):
			aura.visible = false)


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
	p.self_modulate = _color_fase()
	p.amount = 26
	get_tree().root.add_child(p)
	p.restart()
	p.emitting = true


# --- Audio ---

func _rugido() -> void:
	if _audio_mgr != null and _roar_audio != null:
		_audio_mgr.play_sfx(_roar_audio, -8.0)


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
