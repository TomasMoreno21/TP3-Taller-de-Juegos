extends Node2D
## Jefe final: la Estrella (el Arzobispo, líder del culto, transformado). Fija en el fondo, unida al piso por
## un tallo; NO daña por contacto. El origen del nodo es el piso de la arena, en la base del tallo.
## F1 (ciclo): llaves (ojos verdes a distintas alturas) → el ojo central se abre arriba y el Oso
## rompe el nudo del tallo → la Estrella se inclina y el ojo baja: ventana de castigo.
## F2 (ciclo): al entrar, el piso central se rompe (foso con pinchos: Lobo/Murciélago lo cruzan).
## Torretas (ojos verdes que disparan; una acorazada = Oso) + barridos de luz desde el ojo →
## el ojo se eleva fuera del alcance del salto: ventana aérea (Murciélago). El parry del Humano
## devuelve los disparos al ojo central. Por ahora la F3 repite el ciclo de la F2.
## Se integra al Encounter igual que un enemigo manual (preparar_ola / activar / died / health).

signal salud_cambio(hp: int, max_hp: int)
signal fase_cambio(fase: int)
signal reiniciado   # la arena se reinició: el HUD apaga la barra del jefe
signal died

const LANZA_SCENE := preload("res://scenes/lanza_estrella.tscn")
const ORBE_VIDA_SCENE := preload("res://scenes/pickup_vida.tscn")
const ATAQUE_SCENE := preload("res://scenes/ataque_jefe.tscn")

enum Fase { UNO, DOS, TRES }

@export_group("Vida y daño")
@export var vida_max := 600
@export var ola_asignada := 0               ## para el Encounter (enemigo manual)
@export_range(0.0, 1.0, 0.01) var umbral_fase2 := 0.66   ## fracción de vida donde empieza la F2
@export_range(0.0, 1.0, 0.01) var umbral_fase3 := 0.33
@export var curacion_fin_fase := 25         ## orbe de vida al cambiar de fase
@export var distancia_orbe := 520.0         ## px del centro (del lado del jugador) donde aparece el orbe

@export_group("F1: llaves, nudo y castigo")
@export var energia_por_ojo := 12.0         ## energía que da cerrar un ojo verde
@export var ventana_castigo := 4.5          ## s que el ojo queda bajo y golpeable
@export var altura_ojo_castigo := 200.0     ## px sobre el piso a los que baja el ojo al inclinarse
@export var inclinacion_castigo := 0.3      ## rad que se ladea al inclinarse
@export var tiempo_inclinarse := 0.6
@export var respiro_tras_castigo := 1.5     ## s sin ataques después de cada castigo
@export var espera_inicio := 1.2            ## s entre la entrada y el primer ciclo

@export_group("Lanza")
@export var dano_lanza := 15
@export var aviso_lanza := 0.8
@export var intervalo_lanza := 2.6          ## mientras hay llaves abiertas
@export var intervalo_lanza_nudo := 3.4     ## mientras el Oso rompe el nudo
@export var ancho_lanza := 70.0
@export var empuje_lanza := 260.0

@export_group("F2: torretas, barrido y ventana aérea")
@export var dano_torreta := 8
@export var intervalo_torreta := 3.0        ## s entre disparos de cada torreta
@export var aviso_torreta := 0.5            ## s con la pupila roja antes de disparar
@export var velocidad_torreta := 420.0
@export var escalonado_torreta := 0.8       ## s entre el primer disparo de una torreta y la siguiente
@export var dano_minimo_coraza := 24        ## golpe mínimo del Oso para cerrar la torreta acorazada
@export var ventana_aerea := 4.0            ## s que el ojo queda elevado y golpeable
@export var altura_ojo_aerea := 680.0       ## px sobre el piso: fuera del doble salto del Lobo (~540)
@export var tiempo_elevarse := 0.7
@export var dano_reflejo := 30              ## disparo devuelto con parry que llega al ojo central
@export var radio_reflejo := 120.0
@export var velocidad_reflejo := 900.0
@export var dano_barrido := 12
@export var aviso_barrido := 0.9
@export var velocidad_barrido := 650.0
@export var intervalo_barrido := 6.0
@export var primer_barrido := 3.0           ## s desde que se abren las torretas
@export var ancho_barrido := 160.0
@export var barrido_bajo_alto := 110.0      ## franja baja: del piso a esta altura (hay que saltarla)
@export var barrido_alto_desde := 170.0     ## franja alta: Lobo (160) y Murciélago (133) pasan por debajo
@export var barrido_alto_hasta := 420.0
@export var aviso_derrumbe := 1.2           ## s de temblor antes de que el piso central se rompa

@export_group("Apariencia")
@export var nombre_jefe := "EL ARZOBISPO"   ## nombre en las barras de cine ("" = solo barras)
@export var intro_cine := true
@export var intro_duracion := 2.6
@export var giro_velocidad := 0.12          ## rad/s que gira la estrella en reposo
@export var color_fase1 := Color(0.85, 0.25, 0.75)
@export var color_fase2 := Color(0.6, 0.3, 0.9)
@export var color_fase3 := Color(0.9, 0.2, 0.3)
@export var muerte_slowmo := 2.6
@export var muerte_slowmo_escala := 0.2

var health := 0
var fase: int = Fase.UNO
var enemy_data: Enemigo   # solo alimenta el factor de peso del hitstop del jugador

var _activo := false
var _muerto := false
var _invocado := false
var _estado := "inactivo"   # inactivo | llaves | nudo | castigo | respiro | transicion
var _gen := 0
var _ciclo := 0
var _llaves_vivas := 0
var _lanza_t := 0.0
var _ventana_t := 0.0
var _fase_pendiente := false
var _altura_ojo := 550.0    # altura de reposo del ojo (posición de Cuerpo en la escena)
var _tw_cuerpo: Tween
var _tw_ojo: Tween
var _tw_flash: Tween
var _tw_losa: Tween
var _barrido_t := 0.0
var _barrido_alto := false
var _disparos: Array = []

@onready var tallo: Polygon2D = $Tallo
@onready var cuerpo: Node2D = $Cuerpo
@onready var estrella: Polygon2D = $Cuerpo/Estrella
@onready var ojo = $Cuerpo/Ojo   # ojo_central.gd
@onready var hurtbox = $Cuerpo/Hurtbox   # ojo_central_hurtbox.gd
@onready var nudo = $Nudo   # nudo_tallo.gd
@onready var ojos_raiz: Node2D = $Ojos
@onready var losa: StaticBody2D = $LosaCentral
@onready var foso = $Foso   # foso_pinchos.gd


func _ready() -> void:
	add_to_group("boss")
	health = vida_max
	enemy_data = Enemigo.new()
	enemy_data.max_health = vida_max
	_altura_ojo = -cuerpo.position.y
	hurtbox.jefe = self
	hurtbox.collision_layer = 2
	hurtbox.collision_mask = 0
	_hurtbox_on(false)
	estrella.color = color_fase1
	nudo.roto.connect(_on_nudo_roto)
	for o in _ojos():
		o.cerrado.connect(_on_llave_cerrada)
		o.disparo.connect(_on_disparo_torreta)


# --- API del Encounter (misma firma que enemy.gd) ---

func preparar_ola() -> void:
	reiniciado.emit()
	_gen += 1   # corta el ciclo que esté esperando
	_activo = false
	_invocado = false
	_estado = "inactivo"
	_fase_pendiente = false
	health = vida_max
	fase = Fase.UNO
	_ciclo = 0
	estrella.color = color_fase1
	_limpiar_lanzas()
	for o in _ojos():
		o.cerrar_silencioso()
	_llaves_vivas = 0
	_disparos.clear()
	_restaurar_piso()
	nudo.restaurar()
	_hurtbox_on(false)
	_poner_ojo(0.0)
	_poner_cuerpo(false, true)


func activar() -> void:
	if _invocado or _muerto:
		return
	_invocado = true
	_activo = true
	salud_cambio.emit(health, vida_max)
	fase_cambio.emit(fase)
	_cine_entrada()
	_bucle()


## Anti soft-lock del Encounter (no debería pasar: la Estrella no se mueve).
func matar_por_caida() -> void:
	if _muerto:
		return
	health = 0
	_morir()


## La Estrella solo recibe daño por el ojo (ver golpe_ojo); el cuerpo no es golpeable.
func take_damage(_cantidad: int, _kb: float = 0.0, _dir: int = 1, _critico: bool = false) -> void:
	pass


# --- Bucle de la pelea ---

func _bucle() -> void:
	_gen += 1
	var gen := _gen
	await _esperar(espera_inicio)
	while _sigue(gen):
		if fase == Fase.UNO:
			await _ciclo_f1(gen)
		else:
			await _ciclo_f2(gen)


func _ciclo_f1(gen: int) -> void:
	# 1) Llaves: hay que cerrar los ojos verdes de este ciclo.
	_estado = "llaves"
	_lanza_t = intervalo_lanza * 0.6
	var llaves := _llaves_del_ciclo()
	_llaves_vivas = llaves.size()
	for o in llaves:
		o.abrir(energia_por_ojo)
	while _sigue(gen) and _llaves_vivas > 0:
		await _esperar(0.1)
	if not _sigue(gen):
		return
	# 2) El ojo se abre arriba (fuera de alcance) y el nudo del tallo se puede romper (Oso).
	_estado = "nudo"
	_lanza_t = maxf(_lanza_t, 1.2)
	_poner_ojo(0.6)
	nudo.activar()
	while _sigue(gen) and not nudo.esta_roto():
		await _esperar(0.1)
	if not _sigue(gen):
		return
	# 3) Castigo: se inclina, el ojo baja y se puede golpear.
	_estado = "castigo"
	_limpiar_lanzas()
	_poner_ojo(1.0)
	await _poner_cuerpo(true)
	if not _sigue(gen):
		return
	_hurtbox_on(true)
	_ventana_t = ventana_castigo
	while _sigue(gen) and _estado == "castigo" and _ventana_t > 0.0:
		await _esperar(0.1)
		_ventana_t -= 0.1
	_hurtbox_on(false)
	if not _sigue(gen):
		return
	_poner_ojo(0.0)
	await _poner_cuerpo(false)
	nudo.restaurar()
	if _fase_pendiente:
		await _transicion_fase(gen)
		return
	_estado = "respiro"
	await _esperar(respiro_tras_castigo)
	_ciclo += 1


func _ciclo_f2(gen: int) -> void:
	# 1) Torretas: hay que cerrarlas (una de cada lado del foso; la acorazada pide al Oso).
	_estado = "torretas"
	_barrido_t = primer_barrido
	var torres := _torretas_del_ciclo()
	_llaves_vivas = torres.size()
	for i in torres.size():
		var o = torres[i]
		o.intervalo_disparo = intervalo_torreta
		o.aviso_disparo = aviso_torreta
		o.dano_disparo = dano_torreta
		o.velocidad_disparo = velocidad_torreta
		o.dano_minimo_coraza = dano_minimo_coraza
		o.abrir_torreta(energia_por_ojo, 1.0 + escalonado_torreta * i)
	while _sigue(gen) and _llaves_vivas > 0 and not _fase_pendiente:
		await _esperar(0.1)
	for o in torres:
		if o.abierto:
			o.cerrar_silencioso()
	if not _sigue(gen):
		return
	if _fase_pendiente:   # los parrys la llevaron al umbral
		_limpiar_lanzas()
		await _transicion_fase(gen)
		return
	# 2) Ventana aérea: el ojo se eleva fuera del alcance del salto.
	_estado = "ventana_aerea"
	_limpiar_lanzas()
	_poner_ojo(1.0)
	await _mover_cuerpo(altura_ojo_aerea, 0.0, tiempo_elevarse)
	if not _sigue(gen):
		return
	_hurtbox_on(true)
	_ventana_t = ventana_aerea
	while _sigue(gen) and _estado == "ventana_aerea" and _ventana_t > 0.0:
		await _esperar(0.1)
		_ventana_t -= 0.1
	_hurtbox_on(false)
	if not _sigue(gen):
		return
	_poner_ojo(0.0)
	await _mover_cuerpo(_altura_ojo, 0.0, tiempo_elevarse)
	if _fase_pendiente:
		await _transicion_fase(gen)
		return
	_estado = "respiro"
	await _esperar(respiro_tras_castigo)
	_ciclo += 1


func _sigue(gen: int) -> bool:
	return gen == _gen and _activo and not _muerto


func _physics_process(delta: float) -> void:
	if not _activo or _muerto:
		return
	if _estado != "castigo" and _estado != "ventana_aerea":
		estrella.rotation += giro_velocidad * delta
	_mirar_jugador(delta)
	_revisar_reflejos()
	if _estado == "torretas":
		_barrido_t -= delta
		if _barrido_t <= 0.0:
			_lanzar_barrido()
			_barrido_t = intervalo_barrido
	if _estado == "llaves" or _estado == "nudo":
		_lanza_t -= delta
		if _lanza_t <= 0.0:
			_lanzar_lanza()
			_lanza_t = intervalo_lanza if _estado == "llaves" else intervalo_lanza_nudo


# --- Llaves (ojos verdes) ---

func _ojos() -> Array:
	var lista := []
	if ojos_raiz == null:
		return lista
	for o in ojos_raiz.get_children():
		if o.has_method("abrir"):
			lista.append(o)
	return lista


## Los ojos con `ciclo_llave` == ciclo actual (los ciclos se repiten en rueda).
func _llaves_del_ciclo() -> Array:
	var ciclos: Array[int] = []
	for o in _ojos():
		var c := int(o.get("ciclo_llave"))
		if c >= 0 and not ciclos.has(c):
			ciclos.append(c)
	var lista := []
	if ciclos.is_empty():
		return lista
	ciclos.sort()
	var actual := ciclos[_ciclo % ciclos.size()]
	for o in _ojos():
		if int(o.get("ciclo_llave")) == actual:
			lista.append(o)
	return lista


func _on_llave_cerrada() -> void:
	if _estado != "llaves" and _estado != "torretas":
		return
	_llaves_vivas = maxi(_llaves_vivas - 1, 0)
	if _llaves_vivas == 0:
		_rugido(5.0)


func _on_nudo_roto() -> void:
	_rugido(9.0)


# --- Castigo: daño al ojo ---

func golpe_ojo(cantidad: int, _dir: int, _critico: bool) -> void:
	if _muerto or not _activo or (_estado != "castigo" and _estado != "ventana_aerea"):
		return
	_recibir_dano(cantidad)


## Resta vida sin saltear fases: al llegar al umbral la ventana se corta y la fase queda pendiente.
func _recibir_dano(cantidad: int) -> void:
	var piso := _vida_piso_fase()
	health = maxi(health - cantidad, piso)
	salud_cambio.emit(health, vida_max)
	_flash()
	if health <= 0:
		_morir()
		return
	if piso > 0 and health <= piso:
		# Llegó al umbral: la ventana se corta y la fase cambia al reincorporarse.
		_fase_pendiente = true
		if _estado == "castigo" or _estado == "ventana_aerea":
			_estado = "fin_castigo"


## Vida mínima de la fase actual: el daño de una ventana no saltea fases.
func _vida_piso_fase() -> int:
	match fase:
		Fase.UNO:
			return int(round(vida_max * umbral_fase2))
		Fase.DOS:
			return int(round(vida_max * umbral_fase3))
	return 0


func _transicion_fase(gen: int) -> void:
	_fase_pendiente = false
	_estado = "transicion"
	fase = mini(fase + 1, Fase.TRES)
	fase_cambio.emit(fase)
	var col := _color_fase()
	estrella.color = col
	_rugido(10.0)
	if DisplayServer.get_name() != "headless":
		JefeCine.grieta(get_tree(), col)
		_slowmo(0.5, 0.35)
	_soltar_orbe_vida()
	_ciclo = 0
	if fase == Fase.DOS:
		await _romper_piso()
	await _esperar(2.0)
	if not _sigue(gen):
		return


func _soltar_orbe_vida() -> void:
	if curacion_fin_fase <= 0:
		return
	var orbe: Node2D = ORBE_VIDA_SCENE.instantiate()
	orbe.set("curacion", curacion_fin_fase)
	var destino: Node = get_tree().current_scene if get_tree().current_scene != null else get_parent()
	destino.add_child(orbe)
	# Del lado del jugador, fuera del foso central (que se abre al entrar a la F2).
	var p := _obtener_player()
	var lado := -1.0 if p == null or p.global_position.x < global_position.x else 1.0
	orbe.global_position = global_position + Vector2(lado * distancia_orbe, -60)


func _color_fase() -> Color:
	match fase:
		Fase.DOS:
			return color_fase2
		Fase.TRES:
			return color_fase3
	return color_fase1


# --- Lanza ---

func _lanzar_lanza() -> void:
	var p := _obtener_player()
	if p == null:
		return
	var objetivo := Vector2(p.global_position.x, global_position.y)
	# La punta inferior/lateral más cercana en x al jugador.
	var mejor := Vector2.ZERO
	var mejor_d := INF
	var centro := cuerpo.global_position
	var pts := estrella.polygon
	for i in range(0, pts.size(), 2):
		var punta := estrella.to_global(pts[i])
		if punta.y < centro.y - 40.0:
			continue
		var d := absf(punta.x - objetivo.x)
		if d < mejor_d:
			mejor_d = d
			mejor = punta
	if mejor_d == INF:
		return
	var l = LANZA_SCENE.instantiate()
	l.desde = mejor
	l.hasta = objetivo
	l.dano = dano_lanza
	l.aviso = aviso_lanza
	l.ancho = ancho_lanza
	l.empuje = empuje_lanza
	l.color = estrella.color.lightened(0.2)
	var destino: Node = get_tree().current_scene if get_tree().current_scene != null else get_parent()
	destino.add_child(l)


func _limpiar_lanzas() -> void:
	for n in get_tree().get_nodes_in_group("ataque_jefe"):
		if is_instance_valid(n):
			n.queue_free()


# --- Visual ---

func _poner_ojo(apertura: float) -> void:
	if _tw_ojo != null and _tw_ojo.is_valid():
		_tw_ojo.kill()
	if DisplayServer.get_name() == "headless":
		ojo.apertura = apertura
		return
	_tw_ojo = create_tween()
	_tw_ojo.tween_property(ojo, "apertura", apertura, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


## Inclina la Estrella (el ojo baja a `altura_ojo_castigo`) o la vuelve a erguir.
func _poner_cuerpo(inclinada: bool, instantaneo: bool = false) -> void:
	if inclinada and not instantaneo:
		var cam := get_viewport().get_camera_2d()
		if cam != null and cam.has_method("shake"):
			cam.shake(9.0, 0.3)
	var altura := altura_ojo_castigo if inclinada else _altura_ojo
	var rot := inclinacion_castigo if inclinada else 0.0
	await _mover_cuerpo(altura, rot, 0.0 if instantaneo else tiempo_inclinarse, inclinada)


## Lleva el ojo a `altura` px sobre el piso con la rotación `rot` (dur 0 = al instante).
func _mover_cuerpo(altura: float, rot: float, dur: float, rebote: bool = false) -> void:
	if _tw_cuerpo != null and _tw_cuerpo.is_valid():
		_tw_cuerpo.kill()
	if dur <= 0.0 or DisplayServer.get_name() == "headless":
		cuerpo.position.y = -altura
		cuerpo.rotation = rot
		_ajustar_tallo()
		return
	_tw_cuerpo = create_tween().set_parallel(true)
	var trans := Tween.TRANS_BOUNCE if rebote else Tween.TRANS_CUBIC
	_tw_cuerpo.tween_property(cuerpo, "position:y", -altura, dur).set_trans(trans).set_ease(Tween.EASE_OUT)
	_tw_cuerpo.tween_property(cuerpo, "rotation", rot, dur)
	_tw_cuerpo.tween_method(func(_v: float) -> void: _ajustar_tallo(), 0.0, 1.0, dur)
	await _tw_cuerpo.finished


# --- F2: torretas, barrido, reflejos y piso roto ---

## Los ojos con `ciclo_torreta` == ciclo actual (en rueda, como las llaves).
func _torretas_del_ciclo() -> Array:
	var ciclos: Array[int] = []
	for o in _ojos():
		var c := int(o.get("ciclo_torreta"))
		if c >= 0 and not ciclos.has(c):
			ciclos.append(c)
	var lista := []
	if ciclos.is_empty():
		return lista
	ciclos.sort()
	var actual := ciclos[_ciclo % ciclos.size()]
	for o in _ojos():
		if int(o.get("ciclo_torreta")) == actual:
			lista.append(o)
	return lista


func _on_disparo_torreta(proyectil: Node) -> void:
	_disparos.append(proyectil)


## Un disparo de torreta devuelto con parry vuela guiado al ojo central y le pega (fuera de ventana).
func _revisar_reflejos() -> void:
	var i := _disparos.size() - 1
	while i >= 0:
		var d: Variant = _disparos[i]   # Variant: un proyectil liberado no rompe la asignación
		if not is_instance_valid(d) or d.is_queued_for_deletion():
			_disparos.remove_at(i)
		elif not d.enemy_shot:
			var objetivo: Vector2 = ojo.global_position
			if not d.has_meta("al_ojo"):
				d.set_meta("al_ojo", true)
				d.set("homing", false)
				d.set("speed", velocidad_reflejo)
				d.set("_life", 3.0)
			d.direction = (objetivo - d.global_position).normalized()
			if d.global_position.distance_to(objetivo) <= radio_reflejo:
				_disparos.remove_at(i)
				d.queue_free()
				_golpe_reflejo()
		i -= 1


func _golpe_reflejo() -> void:
	if _muerto or not _activo or fase == Fase.UNO:
		return
	_recibir_dano(dano_reflejo)
	_rugido(5.0)


## Barrido de luz desde el ojo hacia los dos lados. Alterna franja baja (saltar) y alta (pasar por debajo).
func _lanzar_barrido() -> void:
	_barrido_alto = not _barrido_alto
	var desde := barrido_alto_desde if _barrido_alto else 0.0
	var hasta := barrido_alto_hasta if _barrido_alto else barrido_bajo_alto
	var destino: Node = get_tree().current_scene if get_tree().current_scene != null else get_parent()
	for d in [-1, 1]:
		var a = ATAQUE_SCENE.instantiate()
		a.dano = dano_barrido
		a.velocidad = velocidad_barrido
		a.dir = d
		a.tamano = Vector2(ancho_barrido, hasta - desde)
		a.color = estrella.color.lightened(0.35)
		a.aviso = aviso_barrido
		a.recorrido_max = 1300.0
		destino.add_child(a)
		a.global_position = global_position + Vector2(d * ancho_barrido * 0.5, -(desde + hasta) * 0.5)


## Entrada a la F2: el piso bajo la Estrella tiembla y se rompe; queda el foso con pinchos.
func _romper_piso() -> void:
	nudo.activo = false
	var headless := DisplayServer.get_name() == "headless"
	var cam := get_viewport().get_camera_2d()
	if not headless:
		if cam != null and cam.has_method("shake"):
			cam.shake(5.0, aviso_derrumbe)
		Burst.emitir(self, losa.global_position, Color(0.42, 0.3, 0.55), 14, 1.2)
	var gen := _gen
	await _esperar(aviso_derrumbe)
	if gen != _gen:
		return   # la arena se reinició durante el temblor: el piso queda entero
	var cs := losa.get_node_or_null("Collision") as CollisionShape2D
	if cs != null:
		cs.set_deferred("disabled", true)
	foso.activo = true
	nudo.visible = false
	if cam != null and cam.has_method("shake"):
		cam.shake(12.0, 0.4)
	if headless:
		losa.visible = false
		return
	JuiceFx.escombros(get_tree(), losa.global_position + Vector2(0, -20), Color(0.42, 0.3, 0.55), 18, 1.3)
	if _tw_losa != null and _tw_losa.is_valid():
		_tw_losa.kill()
	_tw_losa = create_tween().set_parallel(true)
	_tw_losa.tween_property(losa, "position:y", 260.0, 0.5).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	_tw_losa.tween_property(losa, "modulate:a", 0.0, 0.5)


func _restaurar_piso() -> void:
	if _tw_losa != null and _tw_losa.is_valid():
		_tw_losa.kill()
	losa.position.y = 0.0
	losa.modulate.a = 1.0
	losa.visible = true
	var cs := losa.get_node_or_null("Collision") as CollisionShape2D
	if cs != null:
		cs.set_deferred("disabled", false)
	foso.activo = false


## El tallo se acorta con el cuerpo (su polígono va del piso a la altura de reposo).
func _ajustar_tallo() -> void:
	if tallo != null and _altura_ojo > 0.0:
		tallo.scale.y = -cuerpo.position.y / _altura_ojo


func _mirar_jugador(delta: float) -> void:
	var p := _obtener_player()
	if p == null or ojo == null:
		return
	var hacia: Vector2 = (p.global_position - (ojo as Node2D).global_position).normalized() * 30.0
	ojo.mirada = (ojo.mirada as Vector2).lerp(hacia, 5.0 * delta)
	ojo.queue_redraw()


func _hurtbox_on(on: bool) -> void:
	var cs := hurtbox.get_node_or_null("Collision") as CollisionShape2D
	if cs != null:
		cs.set_deferred("disabled", not on)
	if on:
		var p := _obtener_player()
		if p is PhysicsBody2D:
			(p as PhysicsBody2D).add_collision_exception_with(hurtbox)


func _flash() -> void:
	if DisplayServer.get_name() == "headless":
		return
	if _tw_flash != null and _tw_flash.is_valid():
		_tw_flash.kill()
	cuerpo.modulate = Color(2.2, 2.2, 2.2)
	_tw_flash = create_tween()
	_tw_flash.tween_property(cuerpo, "modulate", Color.WHITE, 0.15)


func _rugido(fuerza: float) -> void:
	var cam := get_viewport().get_camera_2d()
	if cam != null and cam.has_method("shake"):
		cam.shake(fuerza, 0.35)


func _cine_entrada() -> void:
	if not intro_cine or DisplayServer.get_name() == "headless":
		return
	JefeCine.entrada(get_tree(), nombre_jefe, color_fase1, intro_duracion)


func _morir() -> void:
	if _muerto:
		return
	_muerto = true
	_activo = false
	_estado = "inactivo"
	_hurtbox_on(false)
	_limpiar_lanzas()
	for o in _ojos():
		o.cerrar_silencioso()
	_rugido(14.0)
	if DisplayServer.get_name() != "headless":
		_slowmo(muerte_slowmo, muerte_slowmo_escala)
		JefeCine.destello_final(get_tree(), muerte_slowmo * 0.55)
		_poner_ojo(1.0)   # el ojo se abre del todo: el niño adentro (el final se arma en el paso 5)
	died.emit()


# --- Utilidades ---

func _obtener_player() -> Node2D:
	return get_tree().get_first_node_in_group("player") as Node2D


func _esperar(t: float) -> void:
	await get_tree().create_timer(t, false).timeout   # respeta la pausa


func _slowmo(duracion: float, escala: float) -> void:
	var hs := get_node_or_null("/root/Hitstop")
	if hs != null and hs.has_method("slowmo"):
		hs.slowmo(duracion, escala)
