extends Node2D
## Jefe final: la Estrella (el Arzobispo, líder del culto, transformado). Fija en el fondo, unida al piso por
## un tallo; NO daña por contacto. El origen del nodo es el piso de la arena, en la base del tallo.
## La vida NO va en el HUD: se lee en el cuerpo (8 puntas que se agrietan y caen, 1 cada 75).
## Ojos verdes: aparecen por tandas de 3-4 en `PuntosOjos` (franjas de altura = forma que piden);
## de los abiertos, uno al azar avisa y dispara un rayo (nunca dos a la vez). Parry del rayo = -30.
## F1 (ciclo): tandas de llaves → el ojo central se abre arriba y el Oso rompe el nudo del tallo →
## la Estrella se inclina y el ojo baja: ventana de castigo.
## F2 (ciclo): al entrar, el piso central se rompe (foso con pinchos: Lobo/Murciélago lo cruzan).
## Tandas de torretas (una acorazada = Oso, a los dos lados del foso) + rayo grueso del ojo (avisa y pega 35) +
## ojo → el ojo se eleva fuera del alcance del salto: ventana aérea (Murciélago).
## F3 (duelo, refs: Maestro de Almas, Hilda Berg, Mantis Lords): sin ojos verdes. Se arranca del tallo,
## flota y encadena combos (picada con ondas, embestida horizontal/diagonal, orbes que giran, lluvia de
## lanzas) y después queda agotada a ras del piso con el ojo vulnerable.
## Se integra al Encounter igual que un enemigo manual (preparar_ola / activar / died / health).

signal salud_cambio(hp: int, max_hp: int)
signal fase_cambio(fase: int)
signal reiniciado   # la arena se reinició: el HUD apaga la barra del jefe
signal died

const LANZA_SCENE := preload("res://scenes/lanza_estrella.tscn")
const ORBE_VIDA_SCENE := preload("res://scenes/pickup_vida.tscn")
const OJO_SCENE := preload("res://scenes/ojo_verde.tscn")
const ATAQUE_SCENE := preload("res://scenes/ataque_jefe.tscn")
const ENEMY_SCENE := preload("res://scenes/enemy.tscn")

enum Fase { UNO, DOS, TRES }

@export_group("Vida y daño")
@export var vida_max := 600
@export var ola_asignada := 0               ## para el Encounter (enemigo manual)
@export_range(0.0, 1.0, 0.01) var umbral_fase2 := 0.66   ## fracción de vida donde empieza la F2
@export_range(0.0, 1.0, 0.01) var umbral_fase3 := 0.33
@export var curacion_fin_fase := 25         ## orbe de vida al cambiar de fase
@export var distancia_orbe := 520.0         ## px del centro (del lado del jugador) donde aparece el orbe
@export var mostrar_barra_hud := false      ## la vida se lee en las puntas del cuerpo, no en el HUD
@export var orden_puntas: Array[int] = [5, 0, 3, 1, 2, 6, 4]   ## en qué orden se rompen las puntas (5 = arriba, 0 = derecha)
@export_range(0.0, 1.0, 0.01) var tinte_fase := 0.35   ## cuánto tiñe el color de la F2/F3 al dibujo (la F1 sin tinte)
@export var drenaje_energia_jefe := 0.35   ## multiplicador del gasto de energía en la pelea ("el amuleto arde")

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
@export var primer_rayo := 2.0              ## s desde que abre la tanda (los ojos terminan de aparecer)
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

@export_group("F2: torretas y ventana aérea")
@export var dano_minimo_coraza := 24        ## golpe mínimo del Oso para cerrar la torreta acorazada
@export var ventana_aerea := 7.0            ## s que el ojo queda elevado y golpeable
@export var altura_ojo_aerea := 1110.0      ## px sobre el piso: fuera del Lobo desde la plataforma más alta (420 + 354 + 185 + radio)
@export var tiempo_elevarse := 0.7
@export_subgroup("Rampa por ciclo (ciclo 1, 2, 3+)")
@export var rampa_tandas: Array[int] = [1, 2, 2]          ## tandas de torretas por ciclo
@export var rampa_ojos_max: Array[int] = [3, 3, 4]        ## ojos máximos por tanda
@export var rampa_rayo: Array[float] = [3.0, 2.4, 2.0]    ## s entre rayos
@export var rampa_rayo_grueso: Array[float] = [0.0, 8.0, 7.0] ## s entre rayos gruesos del ojo (0 = sin)
@export_subgroup("")
@export var aviso_derrumbe := 1.2           ## s de temblor antes de que el piso central se rompa

@export_group("Rayo grueso del ojo (F2)")
@export var dano_rayo_grueso := 25
@export var aviso_rayo_grueso := 1.3        ## s que marca la dirección (franja translúcida) antes de disparar
@export var ancho_rayo_grueso := 70.0
@export var primer_rayo_grueso := 3.0       ## s desde que se abren las torretas
@export var color_rayo_grueso := Color(0.75, 0.9, 1.0)

@export_group("F2: sala más grande")
@export var escala_arena_f2 := 0.72         ## multiplica el zoom de la forma (< 1 = la cámara se aleja)
@export var centro_camara_f2 := Vector2(0, -746)   ## centro de la cámara en la F2, relativo al origen (piso)
@export var subida_techo := 580.0           ## px que sube el techo de raíces
@export var escala_jefe_f2 := 1.15
@export var altura_ojo_f2 := 650.0          ## altura de reposo del ojo en la F2
@export var duracion_agrandar := 1.5
@export var subida_plataformas := 420.0     ## px desde abajo con que aparecen las plataformas

@export_group("F2: interludio (la Estrella se hunde y manda enemigos)")
@export var oleada1_cultistas := 3
@export var oleada2_cultistas := 2
@export var oleada2_arqueros := 2
@export var pausa_entre_oleadas := 1.5
@export var margen_spawn := 150.0           ## px desde el borde visible donde entran los enemigos
@export var tiempo_hundirse := 1.2
@export var tiempo_resurgir := 1.4
@export var profundidad_escondida := 500.0  ## px bajo el piso donde queda el cuerpo escondido

@export_group("Apariencia")
@export var nombre_jefe := "EL ARZOBISPO"   ## nombre en las barras de cine ("" = solo barras)
@export var intro_cine := true
@export var intro_duracion := 2.6
@export var giro_velocidad := 0.12          ## rad/s que gira la estrella en reposo
@export var color_fase1 := Color(0.85, 0.25, 0.75)
@export var color_fase2 := Color(0.6, 0.3, 0.9)
@export var color_fase3 := Color(0.9, 0.2, 0.3)
@export var muerte_slowmo := 2.6
@export_group("Claridad (tips del Amuleto y señales)")
@export var aviso_cierre := 1.0             ## s finales de una ventana en que el ojo parpadea y la Estrella tiembla
@export var temblor_cierre := 5.0           ## px de temblor de la Estrella antes de cerrar el ojo
@export var tip_ojos := "¡Cerrá sus ojos! Lo debilitan."           ## primera tanda de la F2
@export var tip_coraza := "Ese ojo tiene coraza… solo el Oso la parte."   ## primer ojo acorazado
@export var tip_ventana := "¡Abrió el ojo! Volale encima, rápido."    ## primera ventana aérea
@export var tip_amuleto := "¡El amuleto arde! Tus formas aguantan más."   ## al empezar la pelea

@export_group("F3: duelo")
@export var altura_duelo := 650.0           ## altura del ojo mientras pelea
@export var seguimiento_duelo := 1.2        ## qué tan rápido sigue al jugador en x entre ataques
@export var respiro_entre_ataques := 1.0
@export var respiro_duelo := 1.5            ## después de cada ventana
@export var ventana_duelo := 3.0            ## s agotada con el ojo vulnerable
@export var altura_agotada := 220.0         ## el ojo a esta altura: lo alcanza cualquier forma parada
@export var ancho_cuerpo := 360.0           ## media anchura del cuerpo para el daño por contacto (× escala)
@export var alto_cuerpo_arriba := 330.0     ## px del cuerpo sobre el ojo (× escala)
@export var alto_cuerpo_abajo := 311.0      ## px del cuerpo bajo el ojo (× escala)
@export var dano_picada := 20
@export var aviso_picada := 1.0
@export var altura_picada := 1000.0         ## desde dónde cae
@export var dano_onda_picada := 12
@export var velocidad_onda_picada := 600.0
@export var dano_embestida := 18
@export var aviso_embestida := 1.1
@export var velocidad_embestida := 1000.0
@export var hueco_embestida := 200.0        ## px libres bajo la estrella al embestir (Lobo y Murciélago pasan)
@export var prob_diagonal := 0.4
@export var dano_orbe := 12
@export var orbes_cantidad := 2
@export var orbe_radio := 60.0
@export var orbes_radio_ini := 300.0
@export var orbes_radio_fin := 750.0
@export var orbes_duracion := 3.5
@export var orbes_aviso := 0.6
@export var orbes_giro := 2.4               ## rad/s
@export var dano_cuchilla := 15
@export var cuchillas_cantidad := 3
@export var aviso_cuchillas := 1.2
@export var vuelo_cuchilla := 0.45
@export var escala_pieza := 0.45            ## tamaño de las puntas rotas que reusa (órbita y cuchillas)
@export var golpes_caparazon := 3           ## golpes fuertes del Oso para romper el caparazón
@export var tiempo_caparazon := 6.0         ## si no se rompe en este tiempo, se levanta sin ventana
@export_range(0.0, 1.0, 0.05) var prob_escudo_nino := 0.35   ## al romper el caparazón, a veces usa al niño de escudo
@export var duracion_escudo := 1.5
@export var tope_dano_ventana := 40         ## daño máximo por ventana: al llegar, el ojo se cierra
@export var absorber_cultistas := 3         ## al entrar a la F3 absorbe devotos
@export var duracion_absorcion := 1.8

@export_group("Ambiente por fase (latido de la sala y luciérnagas)")
@export var latido_color_fase: Array[Color] = [Color(0.68, 0.7, 0.94), Color(0.66, 0.56, 0.92), Color(0.86, 0.56, 0.62)]
@export var latido_frec_fase: Array[float] = [0.5, 0.8, 1.1]
@export var latido_int_fase: Array[float] = [0.03, 0.05, 0.07]
@export var luciernagas_color_fase: Array[Color] = [Color(0.25, 0.9, 0.85), Color(0.6, 0.45, 0.95), Color(0.95, 0.4, 0.4)]
@export var luciernagas_nucleo_fase: Array[Color] = [Color(0.75, 1.0, 0.95), Color(0.85, 0.8, 1.0), Color(1.0, 0.8, 0.8)]
@export var duracion_cambio_ambiente := 1.5
@export var latido_pico_aparicion := 0.12   ## intensidad del latido cuando la Estrella sale del piso

@export_group("Ambiente de combate")
@export var piedritas_pelea := true          ## caen polvo y piedras del techo de vez en cuando (sin daño)
@export var intervalo_piedritas := Vector2(4.0, 8.0)

@export_group("Aparición (estilo Cult of the Lamb)")
@export var aparicion_cine := true          ## sube desde el suelo con temblor la primera vez
@export var aparicion_temblor := 2.0        ## s de temblor creciente antes de salir
@export var aparicion_subida := 0.6         ## s que tarda en salir del piso
@export var aparicion_shake_max := 12.0
@export_group("")
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
var _invocados: Array = []
var _invocados_vivos := 0
var _aparicion_vista := false
var _piedritas_t := 3.0
var _tips_dados := {}
var _tw_cuerpo: Tween
var _tw_ojo: Tween
var _tw_flash: Tween
var _tw_losa: Tween
var _grueso_t := 0.0
var _grueso_activo := false
var _rng := RandomNumberGenerator.new()
var _ojos_vivos: Array = []   # ojos de la tanda actual (los cerrados se liberan solos)
var _rayo_t := 0.0
var _ultimo_tirador: Node = null
var _puntas: Array = []        # punta_estrella.gd, en orden Punta1..8
var _puntas_rotas := 0
var _sin_tallo := false       # F3: se arrancó del tallo
var _x_base := 0.0            # x del cuerpo que respeta el temblor del aviso de cierre
var _temblando := false
var _ultimo_ataque := ""
var _orbes_nodos: Array = []
var _orbes_t := 0.0
var _orbes_ang := 0.0
var _contacto_dano := 0          # >0 mientras un ataque daña por contacto
var _caparazon_nodos: Array = []
var _golpes_cap := 0
var _dano_ventana := 0
var _cuchillas: Array = []
var _devotos: Array = []

@onready var tallo: Polygon2D = $Tallo
@onready var cuerpo: Node2D = $Cuerpo
@onready var estrella: Node2D = $Cuerpo/Estrella
@onready var nucleo: Polygon2D = $Cuerpo/Estrella/Nucleo
@onready var cabeza: AnimatedSprite2D = get_node_or_null("Cuerpo/Cabeza")   # arte de Micaela: fuente de los frames
@onready var ojo = $Cuerpo/Ojo   # ojo_central.gd
@onready var hurtbox = $Cuerpo/Hurtbox   # ojo_central_hurtbox.gd
@onready var nudo = $Nudo   # nudo_tallo.gd
@onready var ojos_raiz: Node2D = $Ojos            # contenedor de los ojos creados
@onready var puntos_raiz: Node2D = $PuntosOjos     # Marker2D: dónde pueden aparecer
@onready var puntos_f2: Node2D = $PuntosOjosF2     # idem en la sala grande de la F2 (vacío = usa PuntosOjos)
@onready var techo: StaticBody2D = $TechoArena
@onready var plataformas_raiz: Node2D = $PlataformasF2
@onready var bordes_foso: StaticBody2D = $BordesFoso   # topes solo para enemigos (capa 3): no caen al pozo
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
	if cabeza != null:
		cabeza.visible = false
		cabeza.frame_changed.connect(_sync_textura)
		_sync_textura()


# --- API del Encounter (misma firma que enemy.gd) ---

func preparar_ola() -> void:
	reiniciado.emit()
	_gen += 1   # corta el ciclo que esté esperando
	_ventana_t = 0.0
	get_tree().call_group("orbe_jefe", "queue_free")   # los orbes del intento anterior no se acumulan
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
	_restaurar_destruibles()
	_limpiar_invocados()
	_grueso_activo = false
	_sin_tallo = false
	_contacto_dano = 0
	_limpiar_orbes()
	_limpiar_caparazon()
	_limpiar_cuchillas()
	_limpiar_devotos()
	_contener_ataque(false)
	if ojo != null:
		ojo.nino_escudo = 0.0
	_x_base = 0.0
	cuerpo.position.x = 0.0
	cuerpo.modulate.a = 1.0
	cuerpo.visible = true
	cuerpo.rotation = 0.0
	nudo.restaurar()
	_hurtbox_on(false)
	_poner_ojo(0.0)
	_poner_cuerpo(false, true)
	_energia_jefe(false)
	_ambiente_combate(false)
	_ambiente_fase(true)
	if aparicion_cine and not _aparicion_vista:
		cuerpo.position.y = profundidad_escondida   # escondida bajo el piso hasta la aparición
		cuerpo.visible = false
		nudo.visible = false
		_ajustar_tallo()


func activar() -> void:
	if _invocado or _muerto:
		return
	_invocado = true
	_activo = true
	salud_cambio.emit(health, vida_max)
	fase_cambio.emit(fase)
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
	await _aparicion(gen)
	if not _sigue(gen):
		return
	_energia_jefe(true)
	_ambiente_combate(true)
	_tip_una_vez("amuleto", tip_amuleto)
	var hud := get_tree().get_first_node_in_group("hud")
	if hud != null and hud.get("dial") != null and hud.dial.has_method("pulso_energia"):
		hud.dial.pulso_energia()
	await _esperar(espera_inicio)
	while _sigue(gen):
		if fase == Fase.UNO:
			await _ciclo_f1(gen)
		elif fase == Fase.DOS:
			await _ciclo_f2(gen)
		else:
			await _ciclo_f3(gen)


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
	_ventana_t = 0.0   # (si la ventana se cortó antes, el aviso de cierre de la siguiente parpadeaba y temblaba de más)
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
	_grueso_t = primer_rayo_grueso
	_rayo_t = primer_rayo
	for _t in maxi(int(_rampa(rampa_tandas, tandas_por_ciclo)), 1):
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
	_tip_una_vez("ventana", tip_ventana)
	_sugerir_forma(3, ventana_aerea)   # solo el Murciélago llega
	_ventana_t = ventana_aerea
	while _sigue(gen) and _estado == "ventana_aerea" and _ventana_t > 0.0:
		await _esperar(0.1)
		_ventana_t -= 0.1
	_ventana_t = 0.0
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


## Valor de la rampa de la F2 para el ciclo actual (el último se repite; vacía = `defecto`).
func _rampa(valores: Array, defecto: float) -> float:
	if valores.is_empty():
		return defecto
	return float(valores[mini(_ciclo, valores.size() - 1)])


## Globo del Amuleto la primera vez que pasa algo (se puede editar o vaciar desde el Inspector).
func _tip_una_vez(clave: String, texto: String) -> void:
	if texto == "" or _tips_dados.has(clave):
		return
	_tips_dados[clave] = true
	var dialogo := get_node_or_null("/root/Dialogo")
	if dialogo != null and dialogo.has_method("mostrar_tip"):
		dialogo.mostrar_tip([texto])


## Late en el HUD la forma que hace falta (si el jugador no la tiene puesta).
func _sugerir_forma(idx: int, seg: float) -> void:
	var p := _obtener_player()
	if p != null and int(p.get("current_form")) == idx:
		return
	var hud := get_tree().get_first_node_in_group("hud")
	if hud != null and hud.has_method("sugerir_forma"):
		hud.sugerir_forma(idx, seg)


## Último tramo de una ventana: el ojo parpadea y la Estrella tiembla (se va a cerrar).
func _aviso_cierre_tick() -> void:
	var en_ventana := (_estado == "castigo" or _estado == "ventana_aerea" or _estado == "agotada") and _ventana_t > 0.0
	if en_ventana and _ventana_t <= aviso_cierre:
		var t := Time.get_ticks_msec() * 0.001
		ojo.apertura = 0.7 + 0.3 * absf(sin(t * 14.0))
		cuerpo.position.x = _x_base + sin(t * 55.0) * temblor_cierre
		_temblando = true
	elif _temblando:
		_temblando = false
		cuerpo.position.x = _x_base


func _sigue(gen: int) -> bool:
	return gen == _gen and _activo and not _muerto


func _physics_process(delta: float) -> void:
	if not _activo or _muerto:
		return
	if _estado != "castigo" and _estado != "ventana_aerea" and _estado != "agotada":
		estrella.rotation += giro_velocidad * delta
	_aviso_cierre_tick()
	if _estado == "duelo":
		_seguir_jugador(delta)
	if _contacto_dano > 0:
		_contacto(_contacto_dano)
	if not _orbes_nodos.is_empty():
		_orbes_tick(delta)
	_mirar_jugador(delta)
	if piedritas_pelea and _estado != "aparicion":
		_piedritas_t -= delta
		if _piedritas_t <= 0.0:
			_piedritas_t = randf_range(intervalo_piedritas.x, intervalo_piedritas.y)
			if DisplayServer.get_name() != "headless":
				JuiceFx.escombros(get_tree(), techo.global_position + Vector2(randf_range(-1100.0, 1100.0), 270.0), Color(0.3, 0.3, 0.34), 4, 0.7)
	if (_estado == "llaves" or _estado == "torretas") and not _grueso_activo:
		_rayo_t -= delta
		if _rayo_t <= 0.0:
			_disparar_rayo()
			_rayo_t = intervalo_rayo_f1 if fase == Fase.UNO else _rampa(rampa_rayo, 2.0)
	if _estado == "torretas" and _rampa(rampa_rayo_grueso, 0.0) > 0.0 and not _grueso_activo:
		_grueso_t -= delta
		if _grueso_t <= 0.0:
			_rayo_grueso()
			_grueso_t = _rampa(rampa_rayo_grueso, 7.0)
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
		o.sonico_cierra = _franja(puntos[i]) >= 2   # más de media pantalla: vale el sónico
		ojos_raiz.add_child(o)
		o.cerrado.connect(_on_llave_cerrada)
		o.aparecer(energia_por_ojo, torretas and i == 0, escalonado_aparicion * i)
		_ojos_vivos.append(o)
	if torretas:
		_tip_una_vez("ojos", tip_ojos)
		if not puntos.is_empty():
			_tip_una_vez("coraza", tip_coraza)
			_sugerir_forma(2, 6.0)   # la coraza es del Oso
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
	var maximo := ojos_por_tanda_max if fase == Fase.UNO else int(_rampa(rampa_ojos_max, ojos_por_tanda_max))
	var n := mini(_rng.randi_range(ojos_por_tanda_min, maxi(maximo, ojos_por_tanda_min)), libres.size())
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
	if _muerto or not _activo:
		return
	if _estado == "caparazon":
		_golpe_caparazon(cantidad)
		return
	if _estado == "agotada":
		var resto := tope_dano_ventana - _dano_ventana
		if resto <= 0:
			return
		var c := mini(cantidad, resto)
		_dano_ventana += c
		_recibir_dano(c)
		if not _muerto and _dano_ventana >= tope_dano_ventana and _estado == "agotada":
			_estado = "fin_castigo"   # tope de la ventana: el ojo se cierra
		return
	if _estado != "castigo" and _estado != "ventana_aerea":
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
	_ambiente_fase()
	_rugido(10.0)
	if DisplayServer.get_name() != "headless":
		JefeCine.grieta(get_tree(), col)
		_slowmo(0.5, 0.35)
	_soltar_orbe_vida()
	_ciclo = 0
	if fase == Fase.DOS:
		_destruir_grupo("destruible_f2")
		await _romper_piso()
		if not _sigue(gen):
			return
		await _hundirse()
		if not _sigue(gen):
			return
		await _agrandar_sala()
		if not _sigue(gen):
			return
		await _interludio(gen)
		if not _sigue(gen):
			return
		await _resurgir()
		return
	if fase == Fase.TRES:
		await _derrumbe_f3()
		if not _sigue(gen):
			return
		await _absorber(gen)
		if not _sigue(gen):
			return
		await _arrancarse()
		if not _sigue(gen):
			return
	await _esperar(2.0)
	if not _sigue(gen):
		return


func _soltar_orbe_vida() -> void:
	if curacion_fin_fase <= 0:
		return
	var orbe: Node2D = ORBE_VIDA_SCENE.instantiate()
	orbe.set("curacion", curacion_fin_fase)
	orbe.add_to_group("orbe_jefe")
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
	l.color = _color_fase().lightened(0.2)
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


# --- F2: rayo grueso y piso roto ---

## El ojo se abre rápido, apunta al jugador, marca la dirección con una franja ancha y dispara un
## rayo grueso que cruza la sala. El combate sigue mientras tanto; el ojo no se puede golpear.
func _rayo_grueso() -> void:
	var p := _obtener_player()
	if p == null:
		return
	_grueso_activo = true
	for _i in 20:   # nunca junto a un rayo chico (encierros): espera hasta 2 s a que termine
		if not _hay_rayo_chico():
			break
		await _esperar(0.1)
	_poner_ojo(1.0)
	await _esperar(0.3)
	if _muerto or not _activo or _estado != "torretas":
		_grueso_activo = false
		return
	var desde: Vector2 = ojo.global_position
	var r = LANZA_SCENE.instantiate()
	r.rayo = true
	r.desde = desde
	r.hasta = desde + (p.global_position - desde).normalized() * largo_rayo
	r.dano = dano_rayo_grueso
	r.aviso = aviso_rayo_grueso
	r.activo = 0.35
	r.retraer = 0.3
	r.ancho = ancho_rayo_grueso
	r.ancho_aviso = ancho_rayo_grueso
	r.empuje = 320.0
	r.color = color_rayo_grueso
	r.devuelto.connect(_on_rayo_devuelto)
	var destino: Node = get_tree().current_scene if get_tree().current_scene != null else get_parent()
	destino.add_child(r)
	await _esperar(aviso_rayo_grueso + 0.65)
	if _estado == "torretas":
		_poner_ojo(0.0)
	_rayo_t = maxf(_rayo_t, 0.5)   # respiro antes del próximo rayo chico
	_grueso_activo = false


func _hay_rayo_chico() -> bool:
	for n in get_tree().get_nodes_in_group("ataque_jefe"):
		if is_instance_valid(n) and n.get("rayo") == true and float(n.get("ancho")) < ancho_rayo_grueso:
			return true
	return false


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
	_poner_bordes_foso(true)
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
	cuerpo.scale = Vector2.ONE * escala_jefe_f2   # escondido en el foso: crece sin verse
	if headless:
		techo.position.y = _techo_y0 - subida_techo
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
	for i in plataformas_raiz.get_child_count():
		var pl := plataformas_raiz.get_child(i) as Node2D
		pl.position.y = _plat_y0[i] + subida_plataformas
		pl.modulate.a = 0.0
		_tw_sala.tween_property(pl, "position:y", _plat_y0[i], dur).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		_tw_sala.tween_property(pl, "modulate:a", 1.0, dur * 0.5)
	await _tw_sala.finished
	if gen != _gen:
		return


## La Estrella se hunde por el foso con su tallo y desaparece.
func _hundirse() -> void:
	_poner_ojo(0.0)
	_rugido(8.0)
	if DisplayServer.get_name() == "headless":
		cuerpo.position.y = profundidad_escondida
		cuerpo.visible = false
		_ajustar_tallo()
		return
	JuiceFx.escombros(get_tree(), global_position + Vector2(0, -20), Color(0.42, 0.3, 0.55), 16, 1.2)
	if _tw_cuerpo != null and _tw_cuerpo.is_valid():
		_tw_cuerpo.kill()
	_tw_cuerpo = create_tween().set_parallel(true)
	_tw_cuerpo.tween_property(cuerpo, "position:y", profundidad_escondida, tiempo_hundirse).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	_tw_cuerpo.tween_property(cuerpo, "rotation", 0.0, tiempo_hundirse)
	_tw_cuerpo.tween_method(func(_v: float) -> void: _ajustar_tallo(), 0.0, 1.0, tiempo_hundirse)
	await _tw_cuerpo.finished
	cuerpo.visible = false
	_ajustar_tallo()


## Vuelve a subir por el foso, ya agrandada, y ruge: empieza el ciclo de la F2.
func _resurgir() -> void:
	_limpiar_lanzas()
	cuerpo.position.y = profundidad_escondida
	cuerpo.rotation = 0.0
	cuerpo.visible = true
	_rugido(10.0)
	if DisplayServer.get_name() != "headless":
		JuiceFx.escombros(get_tree(), global_position + Vector2(0, -20), Color(0.42, 0.3, 0.55), 18, 1.3)
	await _mover_cuerpo(_altura_reposo, 0.0, tiempo_resurgir, true)
	_rugido(12.0)


## Mientras está escondida no ataca: solo 2 oleadas de enemigos comunes (respiro y curación).
func _interludio(gen: int) -> void:
	_estado = "interludio"
	await _oleada(gen, oleada1_cultistas, 0)
	if not _sigue(gen):
		return
	await _esperar(pausa_entre_oleadas)
	if not _sigue(gen):
		return
	await _oleada(gen, oleada2_cultistas, oleada2_arqueros)


func _oleada(gen: int, cultistas: int, arqueros: int) -> void:
	var tipos: Array = []
	for _i in cultistas:
		tipos.append("cultista")
	for _i in arqueros:
		tipos.append("arquero")
	_invocados_vivos = tipos.size()
	for i in tipos.size():
		_invocar(tipos[i], i)
	while _sigue(gen) and _invocados_vivos > 0:
		_revisar_limbo()
		await _esperar(0.2)


## Entran alternando costados, desde el borde visible menos `margen_spawn` (los topes del pozo no los dejan caer).
func _invocar(tipo: String, i: int) -> void:
	var e = ENEMY_SCENE.instantiate()
	e.set("tipo", tipo)
	e.set("spawn_telegrafiado", true)
	var lado := -1.0 if i % 2 == 0 else 1.0
	var fila := floori(i / 2.0)
	var x := global_position.x + lado * (_mitad_vista() - margen_spawn - fila * 140.0)
	var destino: Node = get_tree().current_scene if get_tree().current_scene != null else get_parent()
	destino.add_child(e)
	e.global_position = Vector2(x, global_position.y - 150.0)
	if e.has_method("activar"):
		e.activar()
	if e.has_signal("died"):
		e.died.connect(_on_invocado_muerto.bind(e))
	_invocados.append(e)


func _on_invocado_muerto(e: Node) -> void:
	if e.has_meta("contado"):
		return
	e.set_meta("contado", true)
	_invocados_vivos = maxi(_invocados_vivos - 1, 0)


## Anti soft-lock: un invocado que quedó fuera de la sala cuenta como muerto.
func _revisar_limbo() -> void:
	for e in _invocados:
		if is_instance_valid(e) and not e.has_meta("contado") and (e as Node2D).global_position.y > global_position.y + 400.0:
			if e.has_method("matar_por_caida"):
				e.matar_por_caida()
			_on_invocado_muerto(e)


func _limpiar_invocados() -> void:
	for e in _invocados:
		if is_instance_valid(e):
			e.queue_free()
	_invocados.clear()
	_invocados_vivos = 0


## Media vista horizontal de la cámara (la sala llega hasta ahí: las paredes siguen el borde).
func _mitad_vista() -> float:
	var cam := get_viewport().get_camera_2d()
	var z := cam.zoom.x if cam != null else 1.0
	return get_viewport().get_visible_rect().size.x * 0.5 / maxf(z, 0.01)


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


## Rompe las piezas del grupo (decoración que la Estrella destruye al cambiar de fase).
func _destruir_grupo(grupo: String) -> void:
	var headless := DisplayServer.get_name() == "headless"
	for n in get_tree().get_nodes_in_group(grupo):
		if not (n is Node2D) or not (n as Node2D).visible:
			continue
		var nd := n as Node2D
		if not nd.has_meta("pos0"):
			nd.set_meta("pos0", nd.position)
			nd.set_meta("esc0", nd.scale)
		if headless:
			nd.visible = false
			continue
		JuiceFx.escombros(get_tree(), nd.global_position + Vector2(0, -60), Color(0.32, 0.32, 0.36), 10, 1.0)
		var tw := nd.create_tween().set_parallel(true)
		tw.tween_property(nd, "position:y", nd.position.y + 120.0, 0.4).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		tw.tween_property(nd, "scale", nd.scale * 0.6, 0.4)
		tw.tween_property(nd, "modulate:a", 0.0, 0.4)
		tw.chain().tween_callback(func() -> void: nd.visible = false)
	_rugido(4.0)


## Reinicio: vuelve toda la decoración destruible a su lugar.
func _restaurar_destruibles() -> void:
	for grupo in ["destruible_f2", "destruible_f3"]:
		for n in get_tree().get_nodes_in_group(grupo):
			if not (n is Node2D):
				continue
			var nd := n as Node2D
			if nd.has_meta("pos0"):
				nd.position = nd.get_meta("pos0")
				nd.scale = nd.get_meta("esc0")
			nd.modulate.a = 1.0
			nd.visible = true


## Entrada a la F3: rompe lo que queda, se caen las plataformas y el pozo se cierra (vuelve el piso).
func _derrumbe_f3() -> void:
	_destruir_grupo("destruible_f3")
	var headless := DisplayServer.get_name() == "headless"
	var cam := get_viewport().get_camera_2d()
	if cam != null and cam.has_method("shake"):
		cam.shake(12.0, 0.8)
	for i in plataformas_raiz.get_child_count():
		var pl := plataformas_raiz.get_child(i) as Node2D
		var cs := pl.get_node_or_null("Collision") as CollisionShape2D
		if cs != null:
			cs.set_deferred("disabled", true)
		if headless:
			pl.visible = false
			continue
		JuiceFx.escombros(get_tree(), pl.global_position, Color(0.3, 0.3, 0.34), 14, 1.1)
		var tw := pl.create_tween().set_parallel(true)
		tw.tween_property(pl, "position:y", pl.position.y + 300.0, 0.6).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		tw.tween_property(pl, "modulate:a", 0.0, 0.6)
		tw.chain().tween_callback(func() -> void: pl.visible = false)
	# El pozo se cierra: la losa sube desde abajo y vuelve el piso.
	var p := _obtener_player()
	if p != null:
		var local := to_local(p.global_position)
		if absf(local.x) <= float(foso.ancho) * 0.5 and local.y > -143.0:
			p.global_position = to_global(Vector2(local.x, -150.0))   # dentro del pozo: arriba del piso nuevo
			p.set("velocity", Vector2.ZERO)
	foso.activo = false
	_poner_bordes_foso(false)
	losa.visible = true
	var cs_losa := losa.get_node_or_null("Collision") as CollisionShape2D
	if cs_losa != null:
		cs_losa.set_deferred("disabled", false)
	if headless:
		losa.position.y = 0.0
		losa.modulate.a = 1.0
		return
	if _tw_losa != null and _tw_losa.is_valid():
		_tw_losa.kill()
	losa.position.y = 260.0
	losa.modulate.a = 1.0
	JuiceFx.escombros(get_tree(), losa.global_position + Vector2(0, -260), Color(0.32, 0.32, 0.36), 18, 1.3)
	_tw_losa = create_tween()
	_tw_losa.tween_property(losa, "position:y", 0.0, 0.6).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	await _tw_losa.finished


# --- F3: duelo ---

## Se arranca del tallo (que se quiebra) y sube a la altura del duelo.
func _arrancarse() -> void:
	_sin_tallo = true
	if DisplayServer.get_name() != "headless":
		for k in 4:
			JuiceFx.escombros(get_tree(), global_position + Vector2(0, -80.0 - 130.0 * k), Color(0.36, 0.2, 0.32), 6, 0.9)
	_rugido(12.0)
	_ajustar_tallo()
	nudo.visible = false
	_x_base = cuerpo.position.x
	await _mover_cuerpo(altura_duelo, 0.0, 0.8, true)


## Combo de 2 ataques (3 en la segunda mitad) y después queda agotada.
func _ciclo_f3(gen: int) -> void:
	_estado = "duelo"
	var segunda := health < int(round(vida_max * umbral_fase3 * 0.5))
	var n := 3 if segunda else 2
	for _k in n:
		await _esperar(respiro_entre_ataques)
		if not _sigue(gen):
			return
		var opciones := ["picada", "embestida", "orbes", "cuchillas"]
		opciones.erase(_ultimo_ataque)
		var ataque: String = opciones[_rng.randi() % opciones.size()]
		_ultimo_ataque = ataque
		match ataque:
			"picada":
				await _picada(gen)
				if segunda and _sigue(gen):
					await _picada(gen)   # Maestro de Almas: picadas encadenadas
			"embestida":
				await _embestida(gen, segunda)
			"orbes":
				await _orbes(gen)
			"cuchillas":
				await _cuchillas_ataque(gen)
		if not _sigue(gen):
			return
		_estado = "duelo"
	await _agotada(gen)
	if not _sigue(gen):
		return
	_estado = "duelo"
	await _esperar(respiro_duelo)


## Dónde colgar efectos y ataques (la escena actual; en tests, el padre).
func _destino() -> Node:
	return get_tree().current_scene if get_tree().current_scene != null else get_parent()


func _limite_x() -> float:
	return maxf(_mitad_vista() - 450.0, 300.0)


func _seguir_jugador(delta: float) -> void:
	var p := _obtener_player()
	if p == null:
		return
	var objetivo := clampf(to_local(p.global_position).x, -_limite_x(), _limite_x())
	cuerpo.position.x = lerpf(cuerpo.position.x, objetivo, minf(seguimiento_duelo * delta, 1.0))
	cuerpo.position.y = lerpf(cuerpo.position.y, -altura_duelo, minf(3.0 * delta, 1.0))
	_x_base = cuerpo.position.x
	_ajustar_tallo()


## Daño por contacto: la caja del cuerpo (× escala) contra el cuerpo del jugador (pies → alto de su forma).
func _contacto(dano: int) -> void:
	var p := _obtener_player()
	if p == null or float(p.get("_invuln_timer") if p.get("_invuln_timer") != null else 0.0) > 0.0:
		return
	var esc := cuerpo.scale.x
	var c := cuerpo.global_position
	var pies := p.global_position.y + 143.0
	var alto := 318.0
	var formas = p.get("forms")
	if formas != null and int(p.get("current_form")) < formas.size():
		alto = float(formas[int(p.get("current_form"))].collider_size.y)
	var arriba := c.y - alto_cuerpo_arriba * esc
	var abajo := c.y + alto_cuerpo_abajo * esc
	if absf(p.global_position.x - c.x) < ancho_cuerpo * esc and pies > arriba and pies - alto < abajo:
		p.take_damage(dano, 300.0, 1 if p.global_position.x >= c.x else -1)


func _ataque_listo(gen: int) -> bool:
	return _sigue(gen)


## Maestro de Almas: se desvanece, reaparece arriba del jugador, avisa con sombra y cae; ondas a los lados.
func _picada(gen: int) -> void:
	_estado = "picada"
	var p := _obtener_player()
	if p == null:
		return
	var headless := DisplayServer.get_name() == "headless"
	var x := clampf(to_local(p.global_position).x, -_limite_x(), _limite_x())
	if not headless:
		var tw := create_tween()
		tw.tween_property(cuerpo, "modulate:a", 0.0, 0.25)
		await tw.finished
	cuerpo.position = Vector2(x, -altura_picada)
	_x_base = x
	_ajustar_tallo()
	var sombra := _sombra_piso(x)
	if not headless:
		create_tween().tween_property(cuerpo, "modulate:a", 1.0, 0.2)
	await _esperar(aviso_picada)
	if is_instance_valid(sombra):
		sombra.queue_free()
	if not _sigue(gen):
		return
	_contacto_dano = dano_picada
	await _mover_cuerpo(alto_cuerpo_abajo * cuerpo.scale.x, 0.0, 0.2)
	_contacto(dano_picada)
	_contacto_dano = 0
	if not _sigue(gen):
		return
	_rugido(10.0)
	if not headless:
		JuiceFx.escombros(get_tree(), to_global(Vector2(x, -10)), Color(0.32, 0.32, 0.36), 14, 1.2)
	for d in [-1, 1]:
		var a = ATAQUE_SCENE.instantiate()
		a.dano = dano_onda_picada
		a.velocidad = velocidad_onda_picada
		a.dir = d
		a.tamano = Vector2(120, 110)
		a.color = _color_fase().lightened(0.3)
		a.aviso = 0.05
		a.recorrido_max = _limite_x() * 2.0 + 600.0
		_destino().add_child(a)
		a.global_position = to_global(Vector2(x + d * 100.0, -55.0))
	await _esperar(0.4)
	if not _sigue(gen):
		return
	await _mover_cuerpo(altura_duelo, 0.0, 0.5)


## Tauro / Mantis: va a un borde, marca la trayectoria y cruza (horizontal con hueco abajo o en diagonal).
func _embestida(gen: int, ida_y_vuelta: bool) -> void:
	_estado = "embestida"
	var p := _obtener_player()
	if p == null:
		return
	var lado := 1.0 if to_local(p.global_position).x < cuerpo.position.x else -1.0   # arranca del lado opuesto
	var lim := _limite_x() + 150.0
	var diagonal := _rng.randf() < prob_diagonal
	var alto_horiz := hueco_embestida + alto_cuerpo_abajo * cuerpo.scale.x
	var desde := Vector2(lado * lim, -(1100.0 if diagonal else alto_horiz))
	var hasta := Vector2(-lado * lim, -(alto_cuerpo_abajo * cuerpo.scale.x if diagonal else alto_horiz))
	await _ir_a(desde, 0.5)
	if not _sigue(gen):
		return
	var linea := _linea_aviso(desde, hasta)
	await _esperar(aviso_embestida)
	if is_instance_valid(linea):
		linea.queue_free()
	if not _sigue(gen):
		return
	_contacto_dano = dano_embestida
	await _ir_a(hasta, desde.distance_to(hasta) / maxf(velocidad_embestida, 1.0))
	if ida_y_vuelta and _sigue(gen):
		await _esperar(0.35)
		await _ir_a(desde, desde.distance_to(hasta) / maxf(velocidad_embestida, 1.0))
	_contacto_dano = 0
	if not _sigue(gen):
		return
	await _mover_cuerpo(altura_duelo, 0.0, 0.5)


## Copia de una de sus puntas (pieza texturizada del dibujo), centrada, para reusarla como arma.
func _copia_punta(i: int) -> Polygon2D:
	var rotas := _puntas.filter(func(pt) -> bool: return pt.rota)
	var fuente = rotas[i % rotas.size()] if not rotas.is_empty() else _puntas[i % maxi(_puntas.size(), 1)]
	var c := Polygon2D.new()
	var centro := Vector2.ZERO
	for v in fuente.polygon:
		centro += v
	centro /= maxf(float(fuente.polygon.size()), 1.0)
	var pts := PackedVector2Array()
	for v in fuente.polygon:
		pts.append(v - centro)
	c.polygon = pts
	c.uv = fuente.uv
	c.texture = fuente.texture
	c.color = fuente.color
	c.scale = Vector2.ONE * escala_pieza * cuerpo.scale.x
	c.z_index = 4
	_destino().add_child(c)
	return c


## Puntas en órbita: sus puntas rotas giran a su alrededor y se alejan; aparecen tenues (aviso) antes de dañar.
func _orbes(gen: int) -> void:
	_estado = "orbes"
	_limpiar_orbes()
	var n := clampi(_puntas_rotas, 2, 4)
	for i in n:
		var o := _copia_punta(i)
		o.modulate.a = 0.3
		_orbes_nodos.append(o)
	_orbes_t = 0.0
	_orbes_ang = _rng.randf() * TAU
	_orbes_tick(0.0)
	await _esperar(orbes_aviso + orbes_duracion)
	_limpiar_orbes()


func _orbes_tick(delta: float) -> void:
	_orbes_t += delta
	_orbes_ang += orbes_giro * delta
	var activos := _orbes_t >= orbes_aviso
	var k := clampf((_orbes_t - orbes_aviso) / maxf(orbes_duracion, 0.01), 0.0, 1.0)
	var r := lerpf(orbes_radio_ini, orbes_radio_fin, k)
	var p := _obtener_player()
	for i in _orbes_nodos.size():
		var o = _orbes_nodos[i]
		if not is_instance_valid(o):
			continue
		var ang := _orbes_ang + TAU * float(i) / float(maxi(_orbes_nodos.size(), 1))
		o.global_position = cuerpo.global_position + Vector2(cos(ang), sin(ang)) * r
		o.rotation = ang + PI * 0.5
		o.modulate.a = 1.0 if activos else 0.3
		if activos and p != null and float(p.get("_invuln_timer") if p.get("_invuln_timer") != null else 0.0) <= 0.0:
			if p.global_position.distance_to(o.global_position) < orbe_radio + 70.0:
				p.take_damage(dano_orbe, 220.0, 1 if p.global_position.x >= o.global_position.x else -1)


func _limpiar_orbes() -> void:
	for o in _orbes_nodos:
		if is_instance_valid(o):
			o.queue_free()
	_orbes_nodos.clear()


## Cuchillas: levanta sus puntas rotas y las arroja girando a puntos marcados del piso (uno cerca del jugador).
func _cuchillas_ataque(gen: int) -> void:
	_estado = "cuchillas"
	var p := _obtener_player()
	if p == null:
		return
	var lim := _limite_x() + 300.0
	var xs: Array = [clampf(to_local(p.global_position).x, -lim, lim)]
	var intentos := 0
	while xs.size() < cuchillas_cantidad and intentos < 40:
		intentos += 1
		var x := _rng.randf_range(-lim, lim)
		if xs.all(func(o) -> bool: return absf(float(o) - x) > 350.0):
			xs.append(x)
	var avisos: Array = []
	for i in xs.size():
		var pieza := _copia_punta(i)
		pieza.global_position = cuerpo.global_position + Vector2(cos(TAU * i / xs.size()), sin(TAU * i / xs.size())) * 220.0
		var objetivo := to_global(Vector2(float(xs[i]), -60.0))
		_cuchillas.append(pieza)
		avisos.append(_sombra_piso(float(xs[i])))
		var linea := Line2D.new()
		linea.points = PackedVector2Array([pieza.global_position, objetivo])
		linea.width = 6.0
		linea.default_color = Color(_color_fase().r, _color_fase().g, _color_fase().b, 0.25)
		linea.z_index = 3
		_destino().add_child(linea)
		avisos.append(linea)
		pieza.set_meta("objetivo", objetivo)
	await _esperar(aviso_cuchillas)
	for a in avisos:
		if is_instance_valid(a):
			a.queue_free()
	if not _sigue(gen):
		_limpiar_cuchillas()
		return
	for pieza in _cuchillas:
		if is_instance_valid(pieza):
			_lanzar_cuchilla(pieza)
	await _esperar(vuelo_cuchilla + 0.6)
	_limpiar_cuchillas()


func _lanzar_cuchilla(pieza: Polygon2D) -> void:
	var desde := pieza.global_position
	var hasta: Vector2 = pieza.get_meta("objetivo")
	var golpeo := [false]
	var paso := func(k: float) -> void:
		if not is_instance_valid(pieza):
			return
		pieza.global_position = desde.lerp(hasta, k)
		pieza.rotation = k * TAU * 2.0
		var p := _obtener_player()
		if golpeo[0] or p == null or float(p.get("_invuln_timer") if p.get("_invuln_timer") != null else 0.0) > 0.0:
			return
		if p.global_position.distance_to(pieza.global_position) < 110.0:
			golpeo[0] = true
			p.take_damage(dano_cuchilla, 240.0, 1 if p.global_position.x >= pieza.global_position.x else -1)
	if DisplayServer.get_name() == "headless":
		for n in range(1, 11):
			paso.call(float(n) / 10.0)
		return
	var tw := pieza.create_tween()
	tw.tween_method(paso, 0.0, 1.0, vuelo_cuchilla)
	tw.tween_callback(func() -> void:
		JuiceFx.escombros(get_tree(), hasta + Vector2(0, 40), Color(0.32, 0.32, 0.36), 8, 0.9))


func _limpiar_cuchillas() -> void:
	for c in _cuchillas:
		if is_instance_valid(c):
			c.queue_free()
	_cuchillas.clear()


## Tras el combo cae y se cierra en un caparazón (lo rompe el Oso). A veces usa al niño de escudo
## (el padre no ataca). Recién después expone el ojo: ventana corta con tope de daño.
func _agotada(gen: int) -> void:
	_contacto_dano = 0
	_limpiar_orbes()
	_poner_ojo(0.0)
	await _mover_cuerpo(altura_agotada, 0.0, 0.5, true)
	if not _sigue(gen):
		return
	_x_base = cuerpo.position.x
	# 1) Caparazón
	var roto: bool = await _caparazon(gen)
	if not _sigue(gen):
		return
	if not roto:
		await _mover_cuerpo(altura_duelo, 0.0, 0.6)
		return
	# 2) A veces, el niño de escudo
	if _rng.randf() < prob_escudo_nino:
		await _escudo_nino(gen)
		if not _sigue(gen):
			return
	# 3) Ojo expuesto
	_estado = "agotada"
	_dano_ventana = 0
	_poner_ojo(1.0)
	_hurtbox_on(true)
	_ventana_t = ventana_duelo
	while _sigue(gen) and _estado == "agotada" and _ventana_t > 0.0:
		await _esperar(0.1)
		_ventana_t -= 0.1
	_hurtbox_on(false)
	if not _sigue(gen):
		return
	_poner_ojo(0.0)
	await _mover_cuerpo(altura_duelo, 0.0, 0.6)


## Cinco puntas se cierran sobre el ojo. Devuelve true si el Oso lo rompió a tiempo.
func _caparazon(gen: int) -> bool:
	_estado = "caparazon"
	_golpes_cap = 0
	_limpiar_caparazon()
	for i in 5:
		var pieza := _copia_punta(i)
		var ang := TAU * float(i) / 5.0 - PI * 0.5
		pieza.set_meta("ang", ang)
		pieza.rotation = ang + PI * 0.5
		pieza.global_position = cuerpo.global_position + Vector2(cos(ang), sin(ang)) * 380.0
		_caparazon_nodos.append(pieza)
		var hasta: Vector2 = cuerpo.global_position + Vector2(cos(ang), sin(ang)) * 120.0
		if DisplayServer.get_name() == "headless":
			pieza.global_position = hasta
		else:
			pieza.create_tween().tween_property(pieza, "global_position", hasta, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_rugido(6.0)
	_sugerir_forma(2, tiempo_caparazon)
	_hurtbox_on(true)
	var t := 0.0
	while _sigue(gen) and _estado == "caparazon" and t < tiempo_caparazon:
		await _esperar(0.1)
		t += 0.1
	_hurtbox_on(false)
	var roto := _estado == "caparazon_roto"
	if not roto:
		_limpiar_caparazon()
	return roto


func _golpe_caparazon(cantidad: int) -> void:
	var p := _obtener_player()
	var es_oso := p != null and int(p.get("current_form")) == 2
	if not es_oso or cantidad < dano_minimo_coraza:
		# Rebote: no es la fuerza del Oso.
		for pieza in _caparazon_nodos:
			if is_instance_valid(pieza):
				Burst.emitir(self, pieza.global_position, Color(0.55, 0.55, 0.6), 3, 0.5)
		_rugido(2.0)
		return
	_golpes_cap += 1
	_flash()
	_rugido(6.0)
	if _golpes_cap < golpes_caparazon:
		return
	# Roto: las piezas saltan.
	_estado = "caparazon_roto"
	for pieza in _caparazon_nodos:
		if not is_instance_valid(pieza):
			continue
		JuiceFx.escombros(get_tree(), pieza.global_position, Color(0.85, 0.82, 0.7), 8, 1.0)
		if DisplayServer.get_name() == "headless":
			continue
		var ang: float = pieza.get_meta("ang")
		var tw: Tween = pieza.create_tween().set_parallel(true)
		tw.tween_property(pieza, "global_position", pieza.global_position + Vector2(cos(ang), sin(ang)) * 260.0 + Vector2(0, 200), 0.5)
		tw.tween_property(pieza, "modulate:a", 0.0, 0.5)
	_caparazon_nodos_soltar()


func _caparazon_nodos_soltar() -> void:
	# Las piezas se liberan solas tras la animación (o al instante en headless).
	var nodos := _caparazon_nodos.duplicate()
	_caparazon_nodos.clear()
	if DisplayServer.get_name() == "headless":
		for n in nodos:
			if is_instance_valid(n):
				n.queue_free()
		return
	get_tree().create_timer(0.6, false).timeout.connect(func() -> void:
		for n in nodos:
			if is_instance_valid(n):
				n.queue_free())


func _limpiar_caparazon() -> void:
	for n in _caparazon_nodos:
		if is_instance_valid(n):
			n.queue_free()
	_caparazon_nodos.clear()


## El cultista aprieta al niño contra el iris: el padre no ataca hasta que el niño forcejea y queda libre.
func _escudo_nino(gen: int) -> void:
	_estado = "escudo"
	_poner_ojo(1.0)
	_contener_ataque(true)
	if DisplayServer.get_name() == "headless":
		ojo.nino_escudo = 1.0
	else:
		create_tween().tween_property(ojo, "nino_escudo", 1.0, 0.25)
	await _esperar(duracion_escudo)
	_contener_ataque(false)
	if not _sigue(gen):
		ojo.nino_escudo = 0.0
		return
	# El niño forcejea: la estrella tiembla y lo suelta.
	_rugido(7.0)
	if DisplayServer.get_name() == "headless":
		ojo.nino_escudo = 0.0
	else:
		create_tween().tween_property(ojo, "nino_escudo", 0.0, 0.3)


func _contener_ataque(on: bool) -> void:
	var p := _obtener_player()
	if p != null and "ataque_contenido" in p:
		p.ataque_contenido = on


## Al empezar la F3 se alimenta de su culto: devotos que flotan hacia la Estrella y se funden con ella.
func _absorber(gen: int) -> void:
	_estado = "absorcion"
	_limpiar_devotos()
	for i in absorber_cultistas:
		var e = ENEMY_SCENE.instantiate()
		e.set("tipo", "cultista")
		_destino().add_child(e)
		var lado := -1.0 if i % 2 == 0 else 1.0
		e.global_position = to_global(Vector2(lado * (500.0 + 250.0 * floorf(i / 2.0)), -150.0))
		e.set_physics_process(false)
		var vis = e.get("visual")
		if vis != null:
			vis.visible = true
		_devotos.append(e)
	if DisplayServer.get_name() == "headless":
		_limpiar_devotos()
		_flash()
		return
	for e in _devotos:
		var tw: Tween = (e as Node2D).create_tween().set_parallel(true)
		tw.tween_property(e, "global_position", cuerpo.global_position, duracion_absorcion).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		tw.tween_property(e, "scale", Vector2.ONE * 0.2, duracion_absorcion)
		tw.tween_property(e, "modulate", _color_fase(), duracion_absorcion)
	await _esperar(duracion_absorcion)
	_limpiar_devotos()
	if not _sigue(gen):
		return
	_flash()
	_rugido(12.0)
	var cam := get_viewport().get_camera_2d()
	if cam != null and cam.has_method("punch"):
		cam.punch(1.06)
	var tw2 := create_tween()
	tw2.tween_property(cuerpo, "scale", cuerpo.scale * 1.12, 0.12)
	tw2.tween_property(cuerpo, "scale", cuerpo.scale, 0.25)
	await tw2.finished


func _limpiar_devotos() -> void:
	for e in _devotos:
		if is_instance_valid(e):
			e.queue_free()
	_devotos.clear()


## Lleva el cuerpo a una posición local (x, y) en `dur` s (lineal). Respeta el tallo.
func _ir_a(destino: Vector2, dur: float) -> void:
	if _tw_cuerpo != null and _tw_cuerpo.is_valid():
		_tw_cuerpo.kill()
	if dur <= 0.0 or DisplayServer.get_name() == "headless":
		# Instantáneo: si el movimiento daña por contacto, se barre la trayectoria.
		var inicio := cuerpo.position
		if _contacto_dano > 0:
			for k in range(1, 21):
				cuerpo.position = inicio.lerp(destino, float(k) / 20.0)
				_contacto(_contacto_dano)
		cuerpo.position = destino
		_x_base = destino.x
		return
	_tw_cuerpo = create_tween()
	_tw_cuerpo.tween_property(cuerpo, "position", destino, dur)
	await _tw_cuerpo.finished
	_x_base = destino.x


func _sombra_piso(x: float) -> Node2D:
	var s := Polygon2D.new()
	var pts := PackedVector2Array()
	for k in 20:
		pts.append(Vector2(cos(TAU * k / 20.0) * 260.0, sin(TAU * k / 20.0) * 22.0))
	s.polygon = pts
	s.color = Color(0, 0, 0, 0.45)
	s.z_index = 3
	_destino().add_child(s)
	s.global_position = to_global(Vector2(x, -6.0))
	return s


func _linea_aviso(desde: Vector2, hasta: Vector2) -> Line2D:
	var l := Line2D.new()
	l.points = PackedVector2Array([to_global(desde), to_global(hasta)])
	l.width = (alto_cuerpo_arriba + alto_cuerpo_abajo) * cuerpo.scale.x * 0.5
	l.default_color = Color(_color_fase().r, _color_fase().g, _color_fase().b, 0.18)
	l.z_index = 3
	_destino().add_child(l)
	return l


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
	_poner_bordes_foso(false)


func _poner_bordes_foso(on: bool) -> void:
	for cs in bordes_foso.get_children():
		if cs is CollisionShape2D:
			(cs as CollisionShape2D).set_deferred("disabled", not on)


## El tallo se acorta con el cuerpo (su polígono va del piso a la altura de reposo).
func _ajustar_tallo() -> void:
	if tallo != null and _altura_ojo > 0.0:
		tallo.scale.y = -cuerpo.position.y / _altura_ojo
		tallo.scale.x = cuerpo.scale.x
		tallo.visible = cuerpo.visible and cuerpo.position.y < -10.0 and not _sin_tallo


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


## Color de fase: el dibujo de Micaela sin tinte en la F1; en la F2/F3 se tiñe `tinte_fase`.
func _pintar(col: Color) -> void:
	var c := Color.WHITE if col == color_fase1 else Color.WHITE.lerp(col, tinte_fase)
	nucleo.color = c
	for pt in _puntas:
		pt.color = c


## Cada frame de la cabeza animada (arte de Micaela) se copia a las piezas texturizadas.
func _sync_textura() -> void:
	if cabeza == null or cabeza.sprite_frames == null:
		return
	var tex := cabeza.sprite_frames.get_frame_texture(cabeza.animation, cabeza.frame)
	if tex == null:
		return
	nucleo.texture = tex
	for pt in _puntas:
		pt.texture = tex


## Latido de la sala (zona del grupo `latido_jefe`) y luciérnagas con el color de la fase actual.
func _ambiente_fase(instantaneo: bool = false) -> void:
	var i := clampi(fase, 0, 2)
	var zona := get_tree().get_first_node_in_group("latido_jefe")
	if zona != null:
		if i < latido_color_fase.size():
			zona.set("color_ambiente", latido_color_fase[i])
		if i < latido_frec_fase.size():
			zona.set("frecuencia", latido_frec_fase[i])
		if i < latido_int_fase.size():
			zona.set("intensidad", latido_int_fase[i])
	if i < luciernagas_color_fase.size():
		var cn: Color = luciernagas_nucleo_fase[i] if i < luciernagas_nucleo_fase.size() else Color.WHITE
		for l in get_tree().get_nodes_in_group("luciernagas_ambiente"):
			if l.has_method("tenir"):
				l.tenir(luciernagas_color_fase[i], cn, 0.0 if instantaneo else duracion_cambio_ambiente)


## En la pelea el ambiente sonoro queda solo con sus loops (sin acentos de suspenso); el latido sigue.
func _ambiente_combate(on: bool) -> void:
	for amb in get_tree().get_nodes_in_group("ambiente_sonoro"):
		if "solo_capas" in amb:
			amb.solo_capas = on


## "El amuleto arde": en la pelea las formas gastan menos energía.
func _energia_jefe(on: bool) -> void:
	var p := _obtener_player()
	if p != null and "mult_energia_externo" in p:
		p.mult_energia_externo = drenaje_energia_jefe if on else 1.0


## Aparición (Cult of the Lamb): temblor creciente con polvo y piedras, estalla desde el piso,
## ruge (el ojo se abre de golpe) y entran las barras con el nombre. Solo la primera vez.
func _aparicion(gen: int) -> void:
	if not aparicion_cine or _aparicion_vista:
		_cine_entrada()
		return
	_aparicion_vista = true
	_estado = "aparicion"
	var p := _obtener_player()
	if p != null:
		p.set("cinematica_activa", true)
		p.set("velocity", Vector2.ZERO)
	var headless := DisplayServer.get_name() == "headless"
	if headless:
		cuerpo.visible = true
		nudo.visible = true
		cuerpo.position.y = -_altura_reposo
		_ajustar_tallo()
		if p != null:
			p.set("cinematica_activa", false)
		return
	_silencio(true)
	var cam := get_viewport().get_camera_2d()
	var t := 0.0
	while t < aparicion_temblor:
		if gen != _gen:
			return
		var k := t / maxf(aparicion_temblor, 0.01)
		if cam != null and cam.has_method("shake"):
			cam.shake(2.0 + k * aparicion_shake_max * 0.6, 0.3)
		JuiceFx.escombros(get_tree(), global_position + Vector2(randf_range(-260.0, 260.0), -10.0), Color(0.42, 0.3, 0.55), 4 + int(k * 8.0), 0.8)
		JuiceFx.escombros(get_tree(), techo.global_position + Vector2(randf_range(-900.0, 900.0), 270.0), Color(0.3, 0.26, 0.36), 3, 0.7)
		await _esperar(0.25)
		t += 0.25
	if gen != _gen:
		return
	cuerpo.visible = true
	nudo.visible = true
	cuerpo.position.y = profundidad_escondida
	JuiceFx.escombros(get_tree(), global_position + Vector2(0, -30), Color(0.42, 0.3, 0.55), 26, 1.5)
	if cam != null and cam.has_method("shake"):
		cam.shake(aparicion_shake_max, 0.5)
	await _mover_cuerpo(_altura_reposo, 0.0, aparicion_subida, true)
	if gen != _gen:
		return
	if cam != null and cam.has_method("punch"):
		cam.punch(1.08)
	_slowmo(0.35, 0.4)
	var zona := get_tree().get_first_node_in_group("latido_jefe")
	if zona != null:
		zona.set("intensidad", latido_pico_aparicion)   # el corazón de la sala "golpea" al salir
		get_tree().create_timer(1.2, false).timeout.connect(_ambiente_fase)
	_poner_ojo(1.0)
	var tw := create_tween()
	for _i in 6:
		tw.tween_property(cuerpo, "position:x", 7.0, 0.04)
		tw.tween_property(cuerpo, "position:x", -7.0, 0.04)
	tw.tween_property(cuerpo, "position:x", 0.0, 0.04)
	await _esperar(0.6)
	_poner_ojo(0.0)
	_cine_entrada()
	await _esperar(0.8)
	_silencio(false)
	if p != null and is_instance_valid(p):
		p.set("cinematica_activa", false)


func _silencio(on: bool) -> void:
	var amb := get_tree().get_first_node_in_group("ambiente_sonoro")
	if amb != null and amb.has_method("pedir_silencio"):
		amb.pedir_silencio(self, 1.0 if on else 0.0)


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
	foso.set("dano", 0)   # tras la victoria el foso no mata (si no, derrota y victoria se pisaban)
	_estado = "inactivo"
	_hurtbox_on(false)
	_limpiar_lanzas()
	_limpiar_ojos()
	_limpiar_invocados()
	_limpiar_orbes()
	_limpiar_caparazon()
	_limpiar_cuchillas()
	_limpiar_devotos()
	_contener_ataque(false)
	_contacto_dano = 0
	_energia_jefe(false)
	_ambiente_combate(false)
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
