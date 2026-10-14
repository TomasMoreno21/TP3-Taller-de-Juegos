extends Node2D
## Jefe final: la Estrella (el Arzobispo, líder del culto, transformado). Fija en el fondo, unida al piso por
## un tallo; NO daña por contacto. El origen del nodo es el piso de la arena, en la base del tallo.
## La vida NO va en el HUD: se lee en el cuerpo (8 puntas que se agrietan y caen, 1 cada 75).
## Ojos verdes: aparecen por tandas de 3-4 en `PuntosOjos` (franjas de altura = forma que piden);
## de los abiertos, uno al azar avisa y dispara un rayo (nunca dos a la vez). Parry del rayo = -30.
## F1 (ciclo): tandas de llaves → el ojo central se abre arriba y el Oso rompe el nudo del tallo →
## la Estrella se inclina y el ojo baja: ventana de castigo.
## F2 (ciclo): al entrar, el piso central se rompe (foso con pinchos: Lobo/Murciélago lo cruzan).
## Tandas de torretas (una acorazada = Oso, a los dos lados del foso) + barridos de luz desde el
## ojo → el ojo se eleva fuera del alcance del salto: ventana aérea (Murciélago).
## Por ahora la F3 repite el ciclo de la F2.
## Se integra al Encounter igual que un enemigo manual (preparar_ola / activar / died / health).

signal salud_cambio(hp: int, max_hp: int)
signal fase_cambio(fase: int)
signal reiniciado   # la arena se reinició: el HUD apaga la barra del jefe
signal died

const LANZA_SCENE := preload("res://scenes/lanza_estrella.tscn")
const ORBE_VIDA_SCENE := preload("res://scenes/pickup_vida.tscn")
const ATAQUE_SCENE := preload("res://scenes/ataque_jefe.tscn")
const OJO_SCENE := preload("res://scenes/ojo_verde.tscn")

enum Fase { UNO, DOS, TRES }

@export_group("Vida y daño")
@export var vida_max := 600
@export var ola_asignada := 0               ## para el Encounter (enemigo manual)
@export_range(0.0, 1.0, 0.01) var umbral_fase2 := 0.66   ## fracción de vida donde empieza la F2
@export_range(0.0, 1.0, 0.01) var umbral_fase3 := 0.33
@export var curacion_fin_fase := 25         ## orbe de vida al cambiar de fase
@export var distancia_orbe := 520.0         ## px del centro (del lado del jugador) donde aparece el orbe
@export var mostrar_barra_hud := false      ## la vida se lee en las puntas del cuerpo, no en el HUD
@export var orden_puntas: Array[int] = [0, 4, 2, 6, 1, 5, 3, 7]   ## en qué orden se rompen las puntas (0 = arriba)

@export_group("Ojos verdes (tandas)")
@export var ojos_por_tanda_min := 3
@export var ojos_por_tanda_max := 4
@export var tandas_por_ciclo := 2
@export var escalonado_aparicion := 0.25    ## s entre la aparición de un ojo y el siguiente de la tanda
@export var franja_media := 220.0           ## altura (px) desde la que un punto es "medio" (no lo alcanza el Oso)
@export var franja_alta := 420.0            ## desde aquí "alto": Lobo con doble salto o Murciélago
@export var franja_muy_alta := 620.0        ## desde aquí "muy alto": solo Murciélago
@export var lado_foso := 300.0              ## |x| mínimo de las torretas (a los costados del foso)
@export var semilla := 0                    ## 0 = al azar; fija = tandas repetibles (tests)

@export_group("Rayo de los ojos")
@export var dano_rayo := 10
@export var aviso_rayo := 0.7
@export var ancho_rayo := 36.0
@export var largo_rayo := 2600.0
@export var intervalo_rayo_f1 := 2.4        ## convive con la lanza
@export var intervalo_rayo_f2 := 1.6
@export var primer_rayo := 1.5              ## s desde que abre la primera tanda
@export var color_rayo := Color(0.55, 1.0, 0.45)
@export var dano_reflejo := 30              ## rayo devuelto con parry: daño al ojo central

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
@export var dano_minimo_coraza := 24        ## golpe mínimo del Oso para cerrar la torreta acorazada
@export var ventana_aerea := 4.0            ## s que el ojo queda elevado y golpeable
@export var altura_ojo_aerea := 1100.0      ## px sobre el piso: fuera del Lobo desde la plataforma más alta (380 + 354 + 185)
@export var tiempo_elevarse := 0.7
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
@export var recorrido_barrido := 1500.0     ## px que viaja cada barrido desde el ojo

@export_group("F2: sala más grande")
@export var escala_arena_f2 := 0.8          ## multiplica el zoom de la forma (< 1 = la cámara se aleja)
@export var centro_camara_f2 := Vector2(0, -665)   ## centro de la cámara en la F2, relativo al origen (piso)
@export var subida_techo := 390.0           ## px que sube el techo de raíces
@export var escala_jefe_f2 := 1.3
@export var altura_ojo_f2 := 650.0          ## altura de reposo del ojo en la F2
@export var duracion_agrandar := 1.5
@export var subida_plataformas := 420.0     ## px desde abajo con que aparecen las plataformas

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
var _altura_reposo := 550.0 # reposo actual (sube en la F2)
var _techo_y0 := 0.0
var _plat_y0: Array = []
var _tw_sala: Tween
var _tw_cuerpo: Tween
var _tw_ojo: Tween
var _tw_flash: Tween
var _tw_losa: Tween
var _barrido_t := 0.0
var _barrido_alto := false
var _rng := RandomNumberGenerator.new()
var _ojos_vivos: Array = []   # ojos de la tanda actual (los cerrados se liberan solos)
var _rayo_t := 0.0
var _ultimo_tirador: Node = null
var _puntas: Array = []        # punta_estrella.gd, en orden Punta1..8
var _puntas_rotas := 0

@onready var tallo: Polygon2D = $Tallo
@onready var cuerpo: Node2D = $Cuerpo
@onready var estrella: Node2D = $Cuerpo/Estrella
@onready var nucleo: Polygon2D = $Cuerpo/Estrella/Nucleo
@onready var ojo = $Cuerpo/Ojo   # ojo_central.gd
@onready var hurtbox = $Cuerpo/Hurtbox   # ojo_central_hurtbox.gd
@onready var nudo = $Nudo   # nudo_tallo.gd
@onready var ojos_raiz: Node2D = $Ojos            # contenedor de los ojos creados
@onready var puntos_raiz: Node2D = $PuntosOjos     # Marker2D: dónde pueden aparecer
@onready var puntos_f2: Node2D = $PuntosOjosF2     # idem en la sala grande de la F2 (vacío = usa PuntosOjos)
@onready var techo: StaticBody2D = $TechoArena
@onready var plataformas_raiz: Node2D = $PlataformasF2
@onready var losa: StaticBody2D = $LosaCentral
@onready var foso = $Foso   # foso_pinchos.gd


func _ready() -> void:
	add_to_group("boss")
	health = vida_max
	enemy_data = Enemigo.new()
	enemy_data.max_health = vida_max
	_altura_ojo = -cuerpo.position.y
	_altura_reposo = _altura_ojo
	_techo_y0 = techo.position.y
	for pl in plataformas_raiz.get_children():
		_plat_y0.append((pl as Node2D).position.y)
	_restaurar_sala()
	hurtbox.jefe = self
	hurtbox.collision_layer = 2
	hurtbox.collision_mask = 0
	_hurtbox_on(false)
	for n in estrella.get_children():
		if n.has_method("romper"):
			_puntas.append(n)
	_pintar(color_fase1)
	nudo.roto.connect(_on_nudo_roto)
	_sembrar()


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
	_pintar(color_fase1)
	_limpiar_lanzas()
	_limpiar_ojos()
	_llaves_vivas = 0
	_puntas_rotas = 0
	for pt in _puntas:
		pt.restaurar()
	_sembrar()
	_restaurar_piso()
	_restaurar_sala()
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
	_rayo_t = primer_rayo
	for _t in tandas_por_ciclo:
		await _tanda(gen, false)
		if not _sigue(gen) or _fase_pendiente:
			break
	_limpiar_ojos()
	if not _sigue(gen):
		return
	if _fase_pendiente:   # los parrys la llevaron al umbral
		_limpiar_lanzas()
		await _transicion_fase(gen)
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
	_rayo_t = primer_rayo
	for _t in tandas_por_ciclo:
		await _tanda(gen, true)
		if not _sigue(gen) or _fase_pendiente:
			break
	_limpiar_ojos()
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
	await _mover_cuerpo(_altura_reposo, 0.0, tiempo_elevarse)
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
	if _estado == "llaves" or _estado == "torretas":
		_rayo_t -= delta
		if _rayo_t <= 0.0:
			_disparar_rayo()
			_rayo_t = intervalo_rayo_f1 if fase == Fase.UNO else intervalo_rayo_f2
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


# --- Ojos verdes por tandas ---

func _sembrar() -> void:
	if semilla != 0:
		_rng.seed = semilla
	else:
		_rng.randomize()


## Ojos de la tanda actual que siguen abiertos.
func _ojos() -> Array:
	return _ojos_vivos.filter(func(o) -> bool: return is_instance_valid(o) and not o.is_queued_for_deletion())


## Abre una tanda y espera a que la cierren. `torretas`: una acorazada y ojos a los dos lados del foso.
func _tanda(gen: int, torretas: bool) -> void:
	var puntos := _elegir_puntos(torretas)
	_ojos_vivos.clear()
	_llaves_vivas = puntos.size()
	for i in puntos.size():
		var o = OJO_SCENE.instantiate()
		o.position = puntos[i]
		o.dano_minimo_coraza = dano_minimo_coraza
		ojos_raiz.add_child(o)
		o.cerrado.connect(_on_llave_cerrada)
		o.aparecer(energia_por_ojo, torretas and i == 0, escalonado_aparicion * i)
		_ojos_vivos.append(o)
	while _sigue(gen) and _llaves_vivas > 0 and not _fase_pendiente:
		await _esperar(0.1)


func _franja(punto: Vector2) -> int:
	var h := -punto.y
	if h >= franja_muy_alta:
		return 3
	if h >= franja_alta:
		return 2
	if h >= franja_media:
		return 1
	return 0


## Puntos de la tanda (posición local). Llaves: uno bajo, uno medio y uno alto/muy alto (+1 al azar).
## Torretas: el primero es bajo (acorazado) y hay ojos a los dos lados del foso.
func _elegir_puntos(torretas: bool) -> Array:
	var libres: Array = []
	var raiz := puntos_f2 if fase != Fase.UNO and puntos_f2 != null and puntos_f2.get_child_count() > 0 else puntos_raiz
	for m in raiz.get_children():
		if m is Node2D and (not torretas or absf((m as Node2D).position.x) > lado_foso):
			libres.append((m as Node2D).position)
	var n := mini(_rng.randi_range(ojos_por_tanda_min, ojos_por_tanda_max), libres.size())
	var elegidos: Array = []
	var requisitos: Array = []
	if torretas:
		requisitos = [func(p: Vector2) -> bool: return _franja(p) == 0]
	else:
		requisitos = [
			func(p: Vector2) -> bool: return _franja(p) == 0,
			func(p: Vector2) -> bool: return _franja(p) == 1,
			func(p: Vector2) -> bool: return _franja(p) >= 2]
	for req in requisitos:
		_sacar(libres, elegidos, req)
	if torretas and not elegidos.is_empty():
		var lado: float = signf(elegidos[0].x)
		_sacar(libres, elegidos, func(p: Vector2) -> bool: return signf(p.x) != lado)
	while elegidos.size() < n and not libres.is_empty():
		_sacar(libres, elegidos, func(_p: Vector2) -> bool: return true)
	return elegidos


## Pasa de `libres` a `elegidos` un punto al azar que cumpla `req` (si no hay, cualquiera).
func _sacar(libres: Array, elegidos: Array, req: Callable) -> void:
	if libres.is_empty():
		return
	var aptos := libres.filter(req)
	if aptos.is_empty():
		aptos = libres
	var p: Vector2 = aptos[_rng.randi() % aptos.size()]
	libres.erase(p)
	elegidos.append(p)


func _limpiar_ojos() -> void:
	for o in ojos_raiz.get_children():
		if o.has_method("desaparecer"):
			o.desaparecer()
	_ojos_vivos.clear()


## Un ojo abierto al azar (distinto del anterior) avisa y dispara un rayo recto al jugador.
func _disparar_rayo() -> void:
	var p := _obtener_player()
	if p == null:
		return
	var candidatos := _ojos().filter(func(o) -> bool: return o.abierto)
	if candidatos.size() > 1:
		candidatos.erase(_ultimo_tirador)
	if candidatos.is_empty():
		return
	var o = candidatos[_rng.randi() % candidatos.size()]
	_ultimo_tirador = o
	o.avisar(aviso_rayo)
	var desde: Vector2 = o.global_position
	var r = LANZA_SCENE.instantiate()
	r.rayo = true
	r.fuente = o
	r.desde = desde
	r.hasta = desde + (p.global_position - desde).normalized() * largo_rayo
	r.dano = dano_rayo
	r.aviso = aviso_rayo
	r.activo = 0.15
	r.retraer = 0.2
	r.ancho = ancho_rayo
	r.empuje = 180.0
	r.color = color_rayo
	r.devuelto.connect(_on_rayo_devuelto)
	var destino: Node = get_tree().current_scene if get_tree().current_scene != null else get_parent()
	destino.add_child(r)


## Parry del rayo: vuelve del jugador al ojo central y le hace daño (aun fuera de la ventana).
func _on_rayo_devuelto(pos: Vector2) -> void:
	if _muerto or not _activo:
		return
	_recibir_dano(dano_reflejo)
	_rugido(5.0)
	if DisplayServer.get_name() == "headless":
		return
	var linea := Line2D.new()
	linea.points = PackedVector2Array([pos, ojo.global_position])
	linea.width = ancho_rayo * 0.6
	linea.default_color = Color(0.85, 0.95, 1.0)
	linea.z_index = 6
	var destino: Node = get_tree().current_scene if get_tree().current_scene != null else get_parent()
	destino.add_child(linea)
	var tw := linea.create_tween()
	tw.tween_property(linea, "modulate:a", 0.0, 0.3)
	tw.tween_callback(linea.queue_free)


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
	_actualizar_puntas()
	_flash()
	if health <= 0:
		_morir()
		return
	if piso > 0 and health <= piso:
		# Llegó al umbral: la ventana se corta y la fase cambia al reincorporarse.
		_fase_pendiente = true
		if _estado == "castigo" or _estado == "ventana_aerea":
			_estado = "fin_castigo"


## La vida en el cuerpo: cada `vida_max / 8` perdida rompe una punta; la siguiente se agrieta.
func _actualizar_puntas() -> void:
	if _puntas.is_empty():
		return
	var por_punta := float(vida_max) / float(_puntas.size())
	var perdida := float(vida_max - health)
	var rotas := mini(floori(perdida / por_punta + 0.0001), _puntas.size())
	for i in _puntas.size():
		var idx: int = orden_puntas[i] if i < orden_puntas.size() else i
		if idx < 0 or idx >= _puntas.size():
			continue
		var pt = _puntas[idx]
		if i < rotas:
			pt.romper()
		elif i == rotas:
			pt.dano = clampf((perdida - rotas * por_punta) / por_punta, 0.0, 1.0)
	_puntas_rotas = rotas


func _puntas_sanas() -> Array:
	return _puntas.filter(func(pt) -> bool: return not pt.rota)


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
	_pintar(col)
	_rugido(10.0)
	if DisplayServer.get_name() != "headless":
		JefeCine.grieta(get_tree(), col)
		_slowmo(0.5, 0.35)
	_soltar_orbe_vida()
	_ciclo = 0
	if fase == Fase.DOS:
		await _romper_piso()
		await _agrandar_sala()
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
	for pt in _puntas_sanas():
		var punta: Vector2 = pt.to_global(pt.vertice())
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
	l.color = nucleo.color.lightened(0.2)
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
	var altura := altura_ojo_castigo if inclinada else _altura_reposo
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


# --- F2: barrido y piso roto ---

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
		a.color = nucleo.color.lightened(0.35)
		a.aviso = aviso_barrido
		a.recorrido_max = recorrido_barrido
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


## Entrada a la F2: el techo sube, la cámara se aleja, la Estrella crece y salen las plataformas.
func _agrandar_sala() -> void:
	var gen := _gen
	_altura_reposo = altura_ojo_f2
	var cam := get_viewport().get_camera_2d()
	var headless := DisplayServer.get_name() == "headless"
	var dur := 0.0 if headless else duracion_agrandar
	if cam != null and cam.has_method("escala_arena"):
		cam.escala_arena(escala_arena_f2, dur)
		cam.mover_arena(global_position + centro_camara_f2)
	for pl in plataformas_raiz.get_children():
		_poner_plataforma(pl, true)
	if headless:
		techo.position.y = _techo_y0 - subida_techo
		cuerpo.scale = Vector2.ONE * escala_jefe_f2
		cuerpo.position.y = -_altura_reposo
		_ajustar_tallo()
		for i in plataformas_raiz.get_child_count():
			(plataformas_raiz.get_child(i) as Node2D).position.y = _plat_y0[i]
		return
	if cam != null and cam.has_method("shake"):
		cam.shake(6.0, dur)
	JuiceFx.escombros(get_tree(), techo.global_position + Vector2(0, 260), Color(0.42, 0.3, 0.55), 20, 1.2)
	if _tw_sala != null and _tw_sala.is_valid():
		_tw_sala.kill()
	_tw_sala = create_tween().set_parallel(true)
	_tw_sala.tween_property(techo, "position:y", _techo_y0 - subida_techo, dur).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	_tw_sala.tween_property(cuerpo, "scale", Vector2.ONE * escala_jefe_f2, dur).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_tw_sala.tween_property(cuerpo, "position:y", -_altura_reposo, dur).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	_tw_sala.tween_method(func(_v: float) -> void: _ajustar_tallo(), 0.0, 1.0, dur)
	for i in plataformas_raiz.get_child_count():
		var pl := plataformas_raiz.get_child(i) as Node2D
		pl.position.y = _plat_y0[i] + subida_plataformas
		pl.modulate.a = 0.0
		_tw_sala.tween_property(pl, "position:y", _plat_y0[i], dur).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		_tw_sala.tween_property(pl, "modulate:a", 1.0, dur * 0.5)
	await _tw_sala.finished
	if gen != _gen:
		return


## Vuelve la sala de la F1 al instante (reinicio de la pelea).
func _restaurar_sala() -> void:
	if _tw_sala != null and _tw_sala.is_valid():
		_tw_sala.kill()
	_altura_reposo = _altura_ojo
	techo.position.y = _techo_y0
	cuerpo.scale = Vector2.ONE
	for i in plataformas_raiz.get_child_count():
		var pl := plataformas_raiz.get_child(i) as Node2D
		if i < _plat_y0.size():
			pl.position.y = _plat_y0[i]
		_poner_plataforma(pl, false)
	var cam := get_viewport().get_camera_2d() if is_inside_tree() else null
	if cam != null and cam.has_method("escala_arena"):
		cam.escala_arena(1.0, 0.0)


func _poner_plataforma(pl: Node, on: bool) -> void:
	(pl as CanvasItem).visible = on
	(pl as CanvasItem).modulate.a = 1.0
	var cs := pl.get_node_or_null("Collision") as CollisionShape2D
	if cs != null:
		cs.set_deferred("disabled", not on)


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
		tallo.scale.x = cuerpo.scale.x


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


func _pintar(col: Color) -> void:
	nucleo.color = col
	for pt in _puntas:
		pt.color = col


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
	_limpiar_ojos()
	for pt in _puntas:
		pt.romper()
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
