@tool
extends Node2D
## Jefe final: la Estrella (el Arzobispo, líder del culto, transformado). Fija en el fondo, unida al piso por
## un tallo; NO daña por contacto. El origen del nodo es el piso de la arena, en la base del tallo.
## La vida NO va en el HUD: se lee en el ojo (venas rojas que crecen con el daño). La cabeza (arte de
## Micaela) nunca se parte ni se rompe.
## Ojos verdes: aparecen por tandas de 3-4 en `PuntosOjos` (franjas de altura = forma que piden);
## de los abiertos, uno al azar avisa y dispara un rayo (nunca dos a la vez). Parry del rayo = -30.
## F1 (ciclo): tandas de llaves → el ojo central se abre arriba y el Oso rompe el nudo del tallo →
## la Estrella se inclina y el ojo baja: ventana de castigo.
## F2 (ciclo): al entrar, el piso central se rompe (foso con pinchos: Lobo/Murciélago lo cruzan).
## Tandas de torretas (una acorazada = Oso, a los dos lados del foso) + rayo grueso del ojo (avisa y pega 35) +
## ojo → el ojo se eleva fuera del alcance del salto: ventana aérea (Murciélago).
## F3 (duelo, refs: Maestro de Almas, Hilda Berg, Mantis Lords): sin ojos verdes. Se arranca del tallo,
## flota y encadena combos (embestida, rocas que giran, estalactitas) y cada combo cierra con una picada
## que la deja clavada en el piso con el ojo a tiro (a veces cerrado: el Oso lo fuerza; a veces el niño de escudo).
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

const UV_REF := Vector2(939.0, 663.0)   ## tamaño del arte base de la cabeza: las UV de Núcleo y puntas están en esta escala

@export_group("Vida y daño")
@export var vida_max := 600
@export var ola_asignada := 0               ## para el Encounter (enemigo manual)
@export_range(0.0, 1.0, 0.01) var umbral_fase2 := 0.66   ## fracción de vida donde empieza la F2
@export_range(0.0, 1.0, 0.01) var umbral_fase3 := 0.33
@export var curacion_fin_fase := 25         ## orbe de vida al cambiar de fase
@export var distancia_orbe := 520.0         ## px del centro (del lado del jugador) donde aparece el orbe
@export var mostrar_barra_hud := false      ## la vida se lee en el cuerpo (grietas finas + venas del ojo), no en el HUD
@export var orden_puntas: Array[int] = [5, 0, 3, 1, 2, 6, 4]   ## en qué orden se agrietan las puntas (nunca se rompen)
@export var color_grietas := Color(0.2, 0.14, 0.24)   ## grietas finas sobre el dibujo (oscuras: el arte es claro)
@export var grosor_grietas := 5.0
@export var mult_dano_sonico := 1.0         ## en la F3 el sónico del Murciélago le pega siempre: multiplica su daño
@export var sonido_rebote: AudioStream = preload("res://assets/audio/sfx/gen/rebote_coraza.wav")   ## golpe al ojo cerrado sin la fuerza del Oso
@export_range(0.0, 1.0, 0.01) var tinte_fase := 0.0   ## cuánto tiñe el color de la F2/F3 al dibujo (0 = sin tinte, conserva el color original; la F1 nunca se tiñe)
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
@export var intervalo_rayo_f1 := 2.1        ## convive con la lanza
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
@export var golpes_nudo := 1               ## golpes fuertes del Oso para romper el círculo del nudo
@export var tope_dano_castigo := 70         ## daño máximo por ventana de castigo (la F1 pide ~3 ciclos)
@export var rampa_tandas_f1: Array[int] = [2, 3, 3]   ## tandas de llaves por ciclo (ciclo 1, 2, 3+)

@export_group("Lanza")
@export var dano_lanza := 15
@export var dano_lanza_f1 := 10            ## en la F1 la lanza pega menos (convive con rayos y acoso)
@export var aviso_lanza := 0.8
@export var intervalo_lanza := 2.0          ## mientras hay llaves abiertas
@export var intervalo_lanza_nudo := 2.4     ## mientras el Oso rompe el nudo
@export var intervalo_lanza_f2 := 2.6       ## F2: también caen lanzas durante las torretas
@export var anticipo_lanza := 0.35           ## la lanza apunta adelante del jugador si corre (× velocidad × aviso)
@export var acoso_quieto := 1.6             ## s quieto (F1/F2) hasta que le cae una lanza encima
@export var acoso_distancia := 120.0        ## px que tiene que moverse para no contar como quieto
@export var acoso_min := 1.0                ## s mínimos entre lanzas de acoso
@export var ancho_lanza := 70.0
@export var empuje_lanza := 260.0

@export_group("F2: torretas y ventana aérea")
@export var dano_minimo_coraza := 24        ## golpe mínimo del Oso para cerrar la torreta acorazada
@export var ventana_aerea := 7.0            ## s que el ojo queda elevado y golpeable
@export var altura_ojo_aerea := 1000.0      ## px sobre el piso: fuera del Lobo desde las plataformas cercanas al centro (330 + 354 + 185 + radio)
@export var tiempo_elevarse := 0.7
@export_subgroup("Rampa por ciclo (ciclo 1, 2, 3+)")
@export var rampa_tandas: Array[int] = [1, 2, 2]          ## tandas de torretas por ciclo
@export var rampa_ojos_max: Array[int] = [3, 3, 4]        ## ojos máximos por tanda
@export var rampa_rayo: Array[float] = [2.3, 1.9, 1.6]    ## s entre rayos
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
@export var escalonado_oleada := 0.35       ## s entre la entrada de un enemigo y el siguiente
@export var separacion_oleada := 300.0      ## px entre filas de cultistas (no entran amontonados)
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
@export var cabeza_f3: SpriteFrames = preload("res://resources/jefe_cabeza_f3.tres")  ## arte de la cabeza al entrar a la F3 (segunda "personalidad"); null = sin cambio
## zoom del arte de la F3 dentro de la Estrella (1 = calza el canvas; >1 = dibujo más grande)
@export var arte_f3_escala := 1.0:
	set(v):
		arte_f3_escala = v
		if Engine.is_editor_hint():
			_refrescar_preview()
## corrimiento del arte de la F3 (px del arte, desde el centro)
@export var arte_f3_offset := Vector2.ZERO:
	set(v):
		arte_f3_offset = v
		if Engine.is_editor_hint():
			_refrescar_preview()
## solo-editor: dibuja el arte de la F3 sobre la Estrella para acomodar escala/offset viendo el resultado en vivo
@export var previsualizar_f3 := false:
	set(v):
		previsualizar_f3 = v
		if Engine.is_editor_hint():
			_refrescar_preview()
@export var muerte_slowmo := 2.6
@export_group("Ajuste F3 (editá con Previsualizar F3)")
## mueve el dibujo de la cabeza (Estrella) en la F3
@export var estrella_f3_offset := Vector2.ZERO:
	set(v):
		estrella_f3_offset = v
		if Engine.is_editor_hint():
			_refrescar_preview()
## agranda el dibujo de la cabeza (Estrella) en la F3
@export var estrella_f3_escala := 1.0:
	set(v):
		estrella_f3_escala = v
		if Engine.is_editor_hint():
			_refrescar_preview()
## mueve el ojo en la F3
@export var ojo_f3_offset := Vector2.ZERO:
	set(v):
		ojo_f3_offset = v
		if Engine.is_editor_hint():
			_refrescar_preview()
## agranda el ojo en la F3 (los golpeables siguen al ojo)
@export var ojo_f3_escala := 1.0:
	set(v):
		ojo_f3_escala = v
		if Engine.is_editor_hint():
			_refrescar_preview()
@export_group("Claridad (tips del Amuleto y señales)")
@export var aviso_cierre := 1.0             ## s finales de una ventana en que el ojo parpadea y la Estrella tiembla
@export var temblor_cierre := 5.0           ## px de temblor de la Estrella antes de cerrar el ojo
@export var tip_ojos := "¡Cerrá sus ojos! Lo debilitan."           ## primera tanda de la F2
@export var tip_coraza := "Ese ojo tiene coraza… solo el Oso la parte."   ## primer ojo acorazado
@export var tip_ventana := "¡Abrió el ojo! Volale encima, rápido."    ## primera ventana aérea
@export var tip_amuleto := "¡El amuleto arde! Tus formas aguantan más."   ## al empezar la pelea
@export var tip_clavada := "¡Quedó clavada! Golpeá el ojo."   ## primera vez que se clava en la F3

@export_group("F3: duelo")
@export var altura_duelo := 650.0           ## altura del ojo mientras pelea
@export var seguimiento_duelo := 2.2        ## qué tan rápido sigue al jugador en x entre ataques
@export var respiro_entre_ataques := 0.35
@export var respiro_duelo := 0.5            ## después de cada ventana
@export var ventana_duelo := 2.0            ## s clavada con el ojo vulnerable
@export var altura_agotada := 220.0         ## clavada: el ojo a esta altura (lo alcanza cualquier forma parada)
@export var ancho_cuerpo := 360.0           ## media anchura del cuerpo para el daño por contacto (× escala)
@export var alto_cuerpo_arriba := 330.0     ## px del cuerpo sobre el ojo (× escala)
@export var alto_cuerpo_abajo := 311.0      ## px del cuerpo bajo el ojo (× escala)
@export var dano_picada := 20
@export var aviso_picada := 0.75
@export var altura_picada := 1000.0         ## desde dónde cae
@export var dano_onda_picada := 12
@export var velocidad_onda_picada := 600.0
@export var dano_embestida := 18
@export var aviso_embestida := 0.8
@export var velocidad_embestida := 1500.0
@export var hueco_embestida := 200.0        ## px libres bajo la estrella al embestir (Lobo y Murciélago pasan)
@export var ancho_carga_blaster := 14.0    ## px de la franja mientras carga (al disparar se ensancha)
@export var color_carga_blaster := Color(1, 0.96, 0.96)   ## destello de la franja al disparar
@export var retroceso_blaster := 40.0      ## px que retrocede al cargar (retroceso del cañón)
@export var prob_diagonal := 0.4
@export var dano_orbe := 12
@export var orbes_cantidad := 3            ## rocas que arranca del piso y hace girar
@export var orbe_radio := 60.0
@export var orbes_radio_ini := 300.0
@export var orbes_radio_fin := 750.0
@export var orbes_duracion := 3.5
@export var orbes_aviso := 0.7            ## s que tardan en subir del piso (no dañan)
@export var orbes_giro := 2.4               ## rad/s
@export var color_roca := Color(0.3, 0.3, 0.34)   ## rocas y estalactitas (paleta de la cueva)
@export var dano_estalactita := 15
@export var estalactitas_cantidad := 3
@export var aviso_estalactitas := 1.3       ## s que tiemblan en el techo (con la sombra en el piso) antes de caer
@export var caida_estalactita := 0.4
@export var golpes_caparazon := 1           ## golpes fuertes del Oso para romper el círculo del ojo cerrado
@export var tiempo_caparazon := 4.0         ## si no lo abre en este tiempo, se desclava sin ventana
@export_range(0.0, 1.0, 0.05) var prob_caparazon := 0.4    ## a veces cae con el ojo cerrado
@export_range(0.0, 1.0, 0.05) var prob_escudo_nino := 0.3   ## a veces usa al niño de escudo
@export var duracion_escudo := 1.0
@export var tope_dano_ventana := 40         ## daño máximo por ventana: al llegar, el ojo se cierra
@export var apertura_duelo := 1.0           ## apertura del ojo en el duelo (1 = arte completo; un valor parcial recorta el dibujo)
@export var absorber_traidor := true        ## al entrar a la F3 absorbe al cultista arrepentido del N3
@export var traidor_frames: SpriteFrames = preload("res://resources/enemigo1_frames.tres")
@export var traidor_aura: PackedScene = preload("res://scenes/aura_mistica.tscn")
@export var traidor_distancia := 750.0      ## px del centro (del lado contrario al jugador)
@export var traidor_altura := 260.0         ## px sobre el piso
@export var aparicion_traidor := 0.9
@export var forcejeo_traidor := 0.9         ## s que se resiste antes de ser arrastrado
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
@export var sonido_aparicion: AudioStream = preload("res://assets/audio/sfx/gen/jefe_grito.wav")   ## grito al salir del piso
@export var volumen_aparicion_db := 0.0
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
var _acoso_pos := Vector2.ZERO
var _acoso_t := 0.0
var _acoso_cd := 0.0
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
var _cabeza_base: SpriteFrames
var _uv_nucleo := PackedVector2Array()
var _uv_puntas: Array = []     # UV base por punta (alineado con _puntas)
var _preview_f3: Node2D = null  # solo-editor: contenedor de los clones del arte F3
var _preview_transform := false  # solo-editor: el preview tiene aplicado el transform de F3
var _estrella_pos0 := Vector2.ZERO
var _estrella_scale0 := Vector2.ONE
var _ojo_pos0 := Vector2.ZERO
var _ojo_scale0 := Vector2.ONE
var _abierta_offset0 := Vector2.ZERO
var _hurt_col0 := Vector2.ONE
var _blanco_col0 := Vector2.ONE
var _circulo_radio0 := 0.0
var _sin_tallo := false       # F3: se arrancó del tallo
var _x_base := 0.0            # x del cuerpo que respeta el temblor del aviso de cierre
var _temblando := false
var _ultimo_ataque := ""
var _orbes_nodos: Array = []
var _orbes_t := 0.0
var _orbes_ang := 0.0
var _contacto_dano := 0          # >0 mientras un ataque daña por contacto
var _golpes_cap := 0
var _dano_ventana := 0
var _estalactitas: Array = []
var _traidor: Node2D = null

@onready var tallo: Polygon2D = $Tallo
@onready var cuerpo: Node2D = $Cuerpo
@onready var estrella: Node2D = $Cuerpo/Estrella
@onready var nucleo: Polygon2D = get_node_or_null("Cuerpo/Estrella/Nucleo")  # cabeza de polígonos (opcional: puede usarse el AnimatedSprite2D Cabeza)
@onready var cabeza: AnimatedSprite2D = get_node_or_null("Cuerpo/Cabeza")   # arte de Micaela: fuente de los frames
@onready var cabeza_f3_nodo: AnimatedSprite2D = get_node_or_null("Cuerpo/CabezaF3")   # cabeza de la F3 (sprite aparte)
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
@onready var circulo_ojo = get_node_or_null("Cuerpo/CirculoOjo")   # circulo_proteccion.gd: ojo clavado cerrado (F3)
@onready var circulo_nudo = get_node_or_null("CirculoNudo")         # circulo_proteccion.gd: nudo del tallo (F1)
@onready var blanco_sonico = get_node_or_null("Cuerpo/BlancoSonico")   # blanco_sonico.gd


func _ready() -> void:
	if Engine.is_editor_hint():
		_capturar_arte_base()
		_capturar_transforms()
		_refrescar_preview()
		return
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
	_capturar_arte_base()
	_capturar_transforms()
	if nucleo != null:
		nucleo.visible = true            # por si la escena quedó guardada con el preview F3 activo
	for pt in _puntas:
		(pt as CanvasItem).visible = true
		pt.color_grieta = color_grietas
		pt.grosor_grieta = grosor_grietas
	_aplicar_transform_fase(false)        # F1: golpeables alineados al ojo
	_pintar(color_fase1)
	nudo.roto.connect(_on_nudo_roto)
	if nudo.has_signal("rebotado"):
		nudo.rebotado.connect(func() -> void:
			if circulo_nudo != null:
				circulo_nudo.rebote())
	nudo.golpes_para_romper = golpes_nudo
	nudo.roto.connect(func() -> void:
		if circulo_nudo != null:
			circulo_nudo.romper())
	if blanco_sonico != null:
		blanco_sonico.jefe = self
	_sembrar()
	if cabeza != null:
		_cabeza_base = cabeza.sprite_frames
		cabeza.frame_changed.connect(_sync_textura)
	if cabeza_f3_nodo != null:
		cabeza_f3_nodo.play("cabeza")
	_aplicar_fase_cabeza(false)


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
	_poner_arte_base()
	_aplicar_transform_fase(false)
	_limpiar_lanzas()
	_limpiar_ojos()
	_llaves_vivas = 0
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
	_limpiar_estalactitas()
	_limpiar_traidor()
	_contener_ataque(false)
	if ojo != null:
		ojo.nino_escudo = 0.0
		ojo.herida = 0.0
	_marcas()
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
	var pj := _obtener_player()
	if pj is PhysicsBody2D and blanco_sonico != null:
		(pj as PhysicsBody2D).add_collision_exception_with(blanco_sonico)   # el blanco del sónico no es una pared
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
	for _t in maxi(int(_rampa(rampa_tandas_f1, tandas_por_ciclo)), 1):
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
	_poner_ojo(1.0)
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
	_dano_ventana = 0
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
	var en_ventana := (_estado == "castigo" or _estado == "ventana_aerea" or _estado == "clavada") and _ventana_t > 0.0
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
	if Engine.is_editor_hint() or not _activo or _muerto:
		return
	_aviso_cierre_tick()
	_marcas()
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
	if _estado == "llaves" or _estado == "nudo" or (_estado == "torretas" and intervalo_lanza_f2 > 0.0):
		_lanza_t -= delta
		if _lanza_t <= 0.0 and _hay_rayo_chico():
			_lanza_t = 0.4   # nunca lanza y rayo a la vez: espera a que pase el rayo
		elif _lanza_t <= 0.0:
			_lanzar_lanza()
			match _estado:
				"llaves":
					_lanza_t = intervalo_lanza
				"nudo":
					_lanza_t = intervalo_lanza_nudo
				_:
					_lanza_t = intervalo_lanza_f2
	_acoso_tick(delta)


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
	if _estado == "clavada":
		var resto := tope_dano_ventana - _dano_ventana
		if resto <= 0:
			return
		var c := mini(cantidad, resto)
		_dano_ventana += c
		_recibir_dano(c)
		if not _muerto and _dano_ventana >= tope_dano_ventana and _estado == "clavada":
			_estado = "fin_castigo"   # tope de la ventana: el ojo se cierra
		return
	if _estado == "castigo":
		var resto_c := tope_dano_castigo - _dano_ventana
		if resto_c <= 0:
			return
		var c2 := mini(cantidad, resto_c)
		_dano_ventana += c2
		_recibir_dano(c2)
		if not _muerto and _dano_ventana >= tope_dano_castigo and _estado == "castigo":
			_estado = "fin_castigo"   # tope de la ventana: se levanta
		return
	if _estado != "ventana_aerea":
		return
	_recibir_dano(cantidad)


## Resta vida sin saltear fases: al llegar al umbral la ventana se corta y la fase queda pendiente.
func _recibir_dano(cantidad: int) -> void:
	var piso := _vida_piso_fase()
	health = maxi(health - cantidad, piso)
	salud_cambio.emit(health, vida_max)
	_herida_ojo()
	_flash()
	if health <= 0:
		_morir()
		return
	if piso > 0 and health <= piso:
		# Llegó al umbral: la ventana se corta y la fase cambia al reincorporarse.
		_fase_pendiente = true
		if _estado == "castigo" or _estado == "ventana_aerea":
			_estado = "fin_castigo"


## La vida se lee en el ojo: las venas crecen con la vida perdida y la pupila se encoge con cada golpe.
## La cabeza (arte de Micaela) nunca se parte ni se rompe.
func _herida_ojo() -> void:
	ojo.herida = clampf(1.0 - float(health) / float(maxi(vida_max, 1)), 0.0, 1.0)
	if ojo.has_method("golpe"):
		ojo.golpe()
	# Grietas finas de luz sobre el dibujo, en orden; nada se parte ni se desprende (pedido de Micaela).
	if _puntas.is_empty():
		return
	var por_punta := float(vida_max) / float(_puntas.size())
	var perdida := float(vida_max - health)
	for i in _puntas.size():
		var idx: int = orden_puntas[i] if i < orden_puntas.size() else i
		if idx >= 0 and idx < _puntas.size():
			_puntas[idx].dano = clampf(perdida / por_punta - float(i), 0.0, 1.0)


## Círculos de protección: encendidos solo cuando hace falta el Oso (nudo activo / ojo clavado cerrado).
func _marcas() -> void:
	_circulo(circulo_nudo, _activo and nudo.activo and not nudo.esta_roto())
	_circulo(circulo_ojo, _activo and _estado == "caparazon")
	if blanco_sonico != null:
		var cs := blanco_sonico.get_node_or_null("Collision") as CollisionShape2D
		var on := _activo and fase == Fase.TRES
		if cs != null and cs.disabled == on:
			cs.set_deferred("disabled", not on)


func _circulo(c: Node, on: bool) -> void:
	if c == null:
		return
	if on:
		c.encendido = true
	elif not c.rompiendo:
		c.encendido = false


## F3: el sónico del Murciélago le pega siempre (no solo en las ventanas), salvo cuando no está en juego.
## En la F1 y la F2 el blanco está apagado: los disparos cuentan solo en las ventanas (como siempre).
func sonico_vale() -> bool:
	if _muerto or not _activo or not cuerpo.visible or fase != Fase.TRES:
		return false
	return not (_estado in ["inactivo", "aparicion", "transicion", "interludio", "absorcion", "escudo", "caparazon"])


func golpe_sonico(cantidad: int, dir: int, critico: bool) -> void:
	if hurtbox.get_node("Collision").disabled == false:
		golpe_ojo(cantidad, dir, critico)   # en una ventana cuenta como golpe al ojo (con su tope)
		return
	if not sonico_vale():
		return
	_recibir_dano(maxi(int(round(cantidad * mult_dano_sonico)), 0))


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
	_aplicar_transform_fase(fase == Fase.TRES)
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
		_aplicar_fase_cabeza(true)
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

## Quieto mucho tiempo en la F1/F2 (llaves, nudo, torretas): le cae una lanza justo encima.
func _acoso_tick(delta: float) -> void:
	_acoso_cd -= delta
	var p := _obtener_player()
	if p == null or not (_estado in ["llaves", "nudo", "torretas"]):
		_acoso_t = 0.0
		return
	if p.global_position.distance_to(_acoso_pos) > acoso_distancia:
		_acoso_pos = p.global_position
		_acoso_t = 0.0
		return
	_acoso_t += delta
	if _acoso_t >= acoso_quieto and _acoso_cd <= 0.0 and not _hay_rayo_chico():
		_lanzar_lanza(false)
		_acoso_t = 0.0
		_acoso_cd = acoso_min


## `anticipar`: apunta adelante del jugador si corre (quieto da igual).
func _lanzar_lanza(anticipar: bool = true) -> void:
	var p := _obtener_player()
	if p == null:
		return
	var vx := 0.0
	if anticipar and p.get("velocity") is Vector2:
		vx = (p.get("velocity") as Vector2).x
	var objetivo := Vector2(p.global_position.x + vx * aviso_lanza * anticipo_lanza, global_position.y)
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
		# Sin puntas (cabeza de sprite): cae desde la cabeza.
		var head := _nodo_head()
		mejor = head.global_position if head != null else centro
	var l = LANZA_SCENE.instantiate()
	l.desde = mejor
	l.hasta = objetivo
	l.dano = dano_lanza_f1 if fase == Fase.UNO else dano_lanza
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
		if i < tipos.size() - 1:
			await _esperar(escalonado_oleada)
			if not _sigue(gen):
				return
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
	var x := global_position.x + lado * (_mitad_vista() - margen_spawn - fila * separacion_oleada)
	var y := global_position.y - 150.0
	if tipo == "arquero":
		# Los arqueros aparecen en las plataformas altas y disparan desde arriba.
		for pl in plataformas_raiz.get_children():
			var n2 := pl as Node2D
			if n2.visible and n2.position.y < -450.0 and signf(n2.position.x) == lado:
				x = n2.global_position.x
				y = n2.global_position.y - 150.0
				break
	var destino: Node = get_tree().current_scene if get_tree().current_scene != null else get_parent()
	destino.add_child(e)
	e.global_position = Vector2(x, y)
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
	_poner_ojo(apertura_duelo)
	var segunda := health < int(round(vida_max * umbral_fase3 * 0.5))
	var n := 2 if segunda else 1
	for _k in n:
		await _esperar(respiro_entre_ataques)
		if not _sigue(gen):
			return
		var opciones := ["embestida", "orbes", "estalactitas"]
		opciones.erase(_ultimo_ataque)
		var ataque: String = opciones[_rng.randi() % opciones.size()]
		_ultimo_ataque = ataque
		match ataque:
			"embestida":
				await _embestida(gen, segunda)
			"orbes":
				await _orbes(gen)
			"estalactitas":
				await _lluvia_estalactitas(gen)
		if not _sigue(gen):
			return
		_estado = "duelo"
	# Cierra siempre con la picada que la clava (en la segunda mitad, antes una encadenada).
	await _esperar(respiro_entre_ataques)
	if segunda and _sigue(gen):
		await _picada(gen, false)
	if not _sigue(gen):
		return
	await _picada(gen, true)
	if not _sigue(gen):
		return
	await _clavada(gen)
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
## `clavar`: queda hundida en el piso con el ojo a tiro (la ventana la abre `_clavada`).
func _picada(gen: int, clavar: bool = false) -> void:
	_estado = "picada"
	var p := _obtener_player()
	if p == null:
		return
	var headless := DisplayServer.get_name() == "headless"
	var x := clampf(to_local(p.global_position).x, -_limite_x(), _limite_x())
	if not headless:
		var tw := create_tween()
		tw.tween_property(cuerpo, "modulate:a", 0.0, 0.15)
		await tw.finished
	cuerpo.position = Vector2(x, -altura_picada)
	_x_base = x
	_ajustar_tallo()
	var sombra := _sombra_piso(x, aviso_picada)
	if not headless:
		create_tween().tween_property(cuerpo, "modulate:a", 1.0, 0.15)
	await _esperar(aviso_picada)
	if is_instance_valid(sombra):
		sombra.queue_free()
	if not _sigue(gen):
		return
	_contacto_dano = dano_picada
	await _mover_cuerpo(altura_agotada if clavar else alto_cuerpo_abajo * cuerpo.scale.x, 0.0, 0.2)
	_contacto(dano_picada)
	_contacto_dano = 0
	_x_base = x
	if not _sigue(gen):
		return
	_rugido(14.0 if clavar else 10.0)
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
	if clavar:
		if not headless:
			JuiceFx.escombros(get_tree(), to_global(Vector2(x, -10)), Color(0.32, 0.32, 0.36), 20, 1.4)
		return
	await _esperar(0.2)
	if not _sigue(gen):
		return
	await _mover_cuerpo(altura_duelo, 0.0, 0.35)


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
	await _carga_blaster(linea, lado)
	if is_instance_valid(linea):
		linea.queue_free()
	if not _sigue(gen):
		return
	_contacto_dano = dano_embestida
	await _ir_a(hasta, desde.distance_to(hasta) / maxf(velocidad_embestida, 1.0))
	if ida_y_vuelta and _sigue(gen):
		await _esperar(0.25)
		await _ir_a(desde, desde.distance_to(hasta) / maxf(velocidad_embestida, 1.0))
	_contacto_dano = 0
	if not _sigue(gen):
		return
	await _mover_cuerpo(altura_duelo, 0.0, 0.35)


## Gaster Blaster (Sans, Undertale): la franja nace fina y parpadea mientras la Estrella retrocede y
## tiembla con el ojo abierto; al final se ensancha de golpe en blanco (el disparo).
func _carga_blaster(linea: Line2D, lado: float) -> void:
	if DisplayServer.get_name() == "headless":
		await _esperar(aviso_embestida)
		return
	_poner_ojo(1.0)
	var ancho := linea.width
	var col := _color_fase()
	linea.width = ancho_carga_blaster
	var carga := maxf(aviso_embestida - 0.2, 0.05)
	var x0 := cuerpo.position.x
	var tw := create_tween()
	tw.tween_property(cuerpo, "position:x", x0 + lado * retroceso_blaster, carga).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	var t := 0.0
	while t < carga and is_instance_valid(linea):
		var k := t / carga
		var blanco := fmod(t * lerpf(6.0, 22.0, k), 1.0) < 0.5   # parpadeo cada vez más rápido
		linea.default_color = Color(1, 1, 1, 0.55) if blanco else Color(col.r, col.g, col.b, 0.35)
		cuerpo.rotation = sin(t * 60.0) * 0.03 * k
		await _esperar(0.03)
		t += 0.03
	cuerpo.rotation = 0.0
	if is_instance_valid(linea):
		linea.default_color = Color(color_carga_blaster.r, color_carga_blaster.g, color_carga_blaster.b, 0.85)
		linea.create_tween().tween_property(linea, "width", ancho, 0.08).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_flash()
	_rugido(8.0)
	await _esperar(0.2)


func _ancho_franja() -> float:
	return (alto_cuerpo_arriba + alto_cuerpo_abajo) * cuerpo.scale.x * 0.5


## Roca de la cueva: polígono irregular con la paleta del nivel (no usa el arte del jefe).
func _roca(radio: float) -> Polygon2D:
	var r := Polygon2D.new()
	var pts := PackedVector2Array()
	for k in 9:
		var a := TAU * float(k) / 9.0
		pts.append(Vector2(cos(a), sin(a)) * radio * _rng.randf_range(0.75, 1.1))
	r.polygon = pts
	r.color = color_roca
	r.z_index = 4
	var borde := Line2D.new()
	var b := pts.duplicate()
	b.append(pts[0])
	borde.points = b
	borde.width = 5.0
	borde.default_color = color_roca.darkened(0.45)
	r.add_child(borde)
	_destino().add_child(r)
	return r


## Rocas en órbita: arranca rocas del piso, suben (sin dañar) y giran a su alrededor alejándose.
func _orbes(gen: int) -> void:
	_estado = "orbes"
	_limpiar_orbes()
	for i in orbes_cantidad:
		var o := _roca(orbe_radio)
		var piso := to_global(Vector2(cuerpo.position.x + (float(i) - (orbes_cantidad - 1) * 0.5) * 260.0, -orbe_radio))
		o.set_meta("piso", piso)
		o.global_position = piso
		if DisplayServer.get_name() != "headless":
			JuiceFx.escombros(get_tree(), piso + Vector2(0, orbe_radio), color_roca, 6, 0.8)
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
	var subida := clampf(_orbes_t / maxf(orbes_aviso, 0.01), 0.0, 1.0)
	var p := _obtener_player()
	for i in _orbes_nodos.size():
		var o = _orbes_nodos[i]
		if not is_instance_valid(o):
			continue
		var ang := _orbes_ang + TAU * float(i) / float(maxi(_orbes_nodos.size(), 1))
		var orbita: Vector2 = cuerpo.global_position + Vector2(cos(ang), sin(ang)) * r
		if activos:
			o.global_position = orbita
		else:
			var piso: Vector2 = o.get_meta("piso")
			o.global_position = piso.lerp(orbita, ease(subida, 0.4))   # suben del piso a la órbita
		o.rotation += 3.0 * delta
		if activos and p != null and float(p.get("_invuln_timer") if p.get("_invuln_timer") != null else 0.0) <= 0.0:
			if p.global_position.distance_to(o.global_position) < orbe_radio + 70.0:
				p.take_damage(dano_orbe, 220.0, 1 if p.global_position.x >= o.global_position.x else -1)


func _limpiar_orbes() -> void:
	for o in _orbes_nodos:
		if is_instance_valid(o):
			o.queue_free()
	_orbes_nodos.clear()


## Estalactitas: hace temblar el techo; sobre cada sombra del piso (una bajo el jugador) una estalactita
## tiembla y después cae.
func _lluvia_estalactitas(gen: int) -> void:
	_estado = "estalactitas"
	var p := _obtener_player()
	if p == null:
		return
	_rugido(5.0)
	var lim := _limite_x() + 300.0
	var xs: Array = [clampf(to_local(p.global_position).x, -lim, lim)]
	var intentos := 0
	while xs.size() < estalactitas_cantidad and intentos < 40:
		intentos += 1
		var x := _rng.randf_range(-lim, lim)
		if xs.all(func(o) -> bool: return absf(float(o) - x) > 350.0):
			xs.append(x)
	var techo_y := techo.global_position.y + 270.0
	var sombras: Array = []
	for x in xs:
		var e := Polygon2D.new()
		e.polygon = PackedVector2Array([Vector2(-55, 0), Vector2(55, 0), Vector2(12, 200), Vector2(0, 250), Vector2(-14, 190)])
		e.color = color_roca
		e.z_index = 4
		_destino().add_child(e)
		e.global_position = Vector2(to_global(Vector2(float(x), 0.0)).x, techo_y)
		e.set_meta("x0", e.global_position.x)
		_estalactitas.append(e)
		sombras.append(_sombra_piso(float(x), aviso_estalactitas))
		if DisplayServer.get_name() != "headless":
			var tw := e.create_tween().set_loops(maxi(int(aviso_estalactitas / 0.08), 1))
			tw.tween_property(e, "position:x", e.position.x + 6.0, 0.04)
			tw.tween_property(e, "position:x", e.position.x - 6.0, 0.04)
			e.set_meta("tw", tw)
			JuiceFx.escombros(get_tree(), e.global_position + Vector2(0, 30), color_roca, 3, 0.5)
	await _esperar(aviso_estalactitas)
	for a in sombras:
		if is_instance_valid(a):
			a.queue_free()
	if not _sigue(gen):
		_limpiar_estalactitas()
		return
	for e in _estalactitas:
		if is_instance_valid(e):
			_caer_estalactita(e)
	await _esperar(caida_estalactita + 0.3)
	_limpiar_estalactitas()


func _caer_estalactita(e: Polygon2D) -> void:
	var x: float = e.get_meta("x0")
	var desde := Vector2(x, e.global_position.y)
	var hasta := Vector2(x, global_position.y - 250.0)   # la punta toca el piso
	var golpeo := [false]
	var paso := func(k: float) -> void:
		if not is_instance_valid(e):
			return
		e.global_position = desde.lerp(hasta, k * k)
		var p := _obtener_player()
		if golpeo[0] or p == null or float(p.get("_invuln_timer") if p.get("_invuln_timer") != null else 0.0) > 0.0:
			return
		var punta := e.global_position.y + 250.0
		if absf(p.global_position.x - x) < 90.0 and p.global_position.y > e.global_position.y - 100.0 and p.global_position.y < punta + 60.0:
			golpeo[0] = true
			p.take_damage(dano_estalactita, 240.0, 1 if p.global_position.x >= x else -1)
	if DisplayServer.get_name() == "headless":
		for n in range(1, 11):
			paso.call(float(n) / 10.0)
		return
	if e.has_meta("tw"):
		var tw_tiembla = e.get_meta("tw")
		if tw_tiembla is Tween and tw_tiembla.is_valid():
			tw_tiembla.kill()
	var tw := e.create_tween()
	tw.tween_method(paso, 0.0, 1.0, caida_estalactita)
	tw.tween_callback(func() -> void:
		JuiceFx.escombros(get_tree(), Vector2(x, global_position.y - 20.0), color_roca, 10, 1.0)
		if is_instance_valid(e):
			e.visible = false)


func _limpiar_estalactitas() -> void:
	for e in _estalactitas:
		if is_instance_valid(e):
			e.queue_free()
	_estalactitas.clear()


## Clavada en el piso tras la picada: a veces con el ojo cerrado (el Oso lo fuerza), a veces con el niño
## de escudo (el padre no ataca). Después, ojo abierto: ventana corta con tope de daño.
func _clavada(gen: int) -> void:
	_contacto_dano = 0
	_limpiar_orbes()
	_x_base = cuerpo.position.x
	_tip_una_vez("clavada", tip_clavada)
	if _rng.randf() < prob_caparazon:
		var abierto: bool = await _caparazon(gen)
		if not _sigue(gen):
			return
		if not abierto:
			await _desclavar()
			return
	if _rng.randf() < prob_escudo_nino:
		await _escudo_nino(gen)
		if not _sigue(gen):
			return
	_estado = "clavada"
	_dano_ventana = 0
	_poner_ojo(1.0)
	_hurtbox_on(true)
	_ventana_t = ventana_duelo
	while _sigue(gen) and _estado == "clavada" and _ventana_t > 0.0:
		await _esperar(0.1)
		_ventana_t -= 0.1
	_ventana_t = 0.0
	_hurtbox_on(false)
	if not _sigue(gen):
		return
	await _desclavar()


## Se arranca del piso y vuelve a flotar.
func _desclavar() -> void:
	_poner_ojo(apertura_duelo)
	_rugido(6.0)
	if DisplayServer.get_name() != "headless":
		JuiceFx.escombros(get_tree(), to_global(Vector2(cuerpo.position.x, -10)), Color(0.32, 0.32, 0.36), 10, 1.0)
	await _mover_cuerpo(altura_duelo, 0.0, 0.35)


## Cae con el ojo cerrado. Devuelve true si el Oso lo forzó a abrirse a tiempo.
func _caparazon(gen: int) -> bool:
	_estado = "caparazon"
	_golpes_cap = 0
	_poner_ojo(0.0)
	_rugido(6.0)
	_sugerir_forma(2, tiempo_caparazon)
	_hurtbox_on(true)
	var t := 0.0
	while _sigue(gen) and _estado == "caparazon" and t < tiempo_caparazon:
		await _esperar(0.1)
		t += 0.1
	_hurtbox_on(false)
	return _estado == "caparazon_roto"


## Golpe al ojo cerrado: solo la fuerza del Oso lo entreabre; con `golpes_caparazon` se abre del todo.
func _golpe_caparazon(cantidad: int) -> void:
	var p := _obtener_player()
	var es_oso := p != null and int(p.get("current_form")) == 2
	if not es_oso or cantidad < dano_minimo_coraza:
		Burst.emitir(self, ojo.global_position, Color(0.55, 0.55, 0.6), 4, 0.5)   # rebote
		_rugido(2.0)
		if circulo_ojo != null:
			circulo_ojo.rebote()
		var audio := get_node_or_null("/root/AudioManager")
		if audio != null and sonido_rebote != null:
			audio.play_sfx(sonido_rebote, -4.0, 0.1)
		return
	_golpes_cap += 1
	_flash()
	_rugido(6.0)
	Burst.emitir(self, ojo.global_position, Color(0.7, 0.7, 0.75), 8, 0.8)
	if _golpes_cap < golpes_caparazon:
		return   # sigue cerrado hasta abrirse del todo (una apertura parcial recortaba el arte)
	_estado = "caparazon_roto"
	if circulo_ojo != null:
		circulo_ojo.romper()
	_poner_ojo(1.0)


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


## Al empezar la F3 se cobra al traidor: el cultista arrepentido del N3 aparece en su humo violeta,
## se resiste y la Estrella lo arrastra hasta fundirlo con ella.
func _absorber(gen: int) -> void:
	_estado = "absorcion"
	_limpiar_traidor()
	if not absorber_traidor or traidor_frames == null:
		return
	var t := Node2D.new()
	t.z_index = 3
	if traidor_aura != null:
		var aura := traidor_aura.instantiate() as Node2D
		aura.position = Vector2(0, 8)
		t.add_child(aura)
	var spr := AnimatedSprite2D.new()
	spr.sprite_frames = traidor_frames
	if traidor_frames.has_animation("idle"):
		spr.play("idle")
	t.add_child(spr)
	_destino().add_child(t)
	var p := _obtener_player()
	var lado := 1.0 if p == null or to_local(p.global_position).x < 0.0 else -1.0   # del lado contrario al jugador
	t.global_position = to_global(Vector2(lado * traidor_distancia, -traidor_altura))
	spr.flip_h = lado < 0.0   # el sprite base mira a la izquierda: así mira hacia la Estrella
	_traidor = t
	if DisplayServer.get_name() == "headless":
		_limpiar_traidor()
		_flash()
		return
	var humo := Color(0.55, 0.35, 0.85)
	t.modulate.a = 0.0
	Burst.emitir(self, t.global_position, humo, 24, 1.4)
	var tw := t.create_tween()
	tw.tween_property(t, "modulate:a", 1.0, aparicion_traidor)
	await tw.finished
	if not _sigue(gen) or not is_instance_valid(t):
		_limpiar_traidor()
		return
	# Se resiste: tiembla y retrocede un poco mientras la Estrella tira de él.
	_rugido(5.0)
	var x0 := t.global_position.x
	var tw_f := t.create_tween()
	tw_f.tween_property(t, "global_position:x", x0 + lado * 60.0, forcejeo_traidor).set_trans(Tween.TRANS_SINE)
	var tw_t := t.create_tween().set_loops(maxi(int(forcejeo_traidor / 0.06), 1))
	tw_t.tween_property(spr, "position:y", -5.0, 0.03)
	tw_t.tween_property(spr, "position:y", 5.0, 0.03)
	await tw_f.finished
	if not _sigue(gen) or not is_instance_valid(t):
		_limpiar_traidor()
		return
	tw_t.kill()
	# Arrastrado hasta la Estrella: gira, se achica y toma su color.
	var tw2: Tween = t.create_tween().set_parallel(true)
	tw2.tween_property(t, "global_position", cuerpo.global_position, duracion_absorcion).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw2.tween_property(t, "scale", Vector2.ONE * 0.15, duracion_absorcion).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw2.tween_property(t, "rotation", -lado * TAU, duracion_absorcion).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw2.tween_property(t, "modulate", _color_fase(), duracion_absorcion)
	await _esperar(duracion_absorcion)
	_limpiar_traidor()
	if not _sigue(gen):
		return
	Burst.emitir(self, cuerpo.global_position, humo, 30, 1.6)
	_flash()
	_rugido(12.0)
	var cam := get_viewport().get_camera_2d()
	if cam != null and cam.has_method("punch"):
		cam.punch(1.06)
	var tw3 := create_tween()
	tw3.tween_property(cuerpo, "scale", cuerpo.scale * 1.12, 0.12)
	tw3.tween_property(cuerpo, "scale", cuerpo.scale, 0.25)
	await tw3.finished


func _limpiar_traidor() -> void:
	if _traidor != null and is_instance_valid(_traidor):
		_traidor.queue_free()
	_traidor = null


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


## Aviso en el piso de lo que cae: mancha oscura + aro del color de la fase que late y se cierra
## hacia el centro durante `dur` (se lee cuánto falta).
func _sombra_piso(x: float, dur: float = 0.0) -> Node2D:
	var s := Polygon2D.new()
	var pts := PackedVector2Array()
	for k in 24:
		pts.append(Vector2(cos(TAU * k / 24.0) * 260.0, sin(TAU * k / 24.0) * 26.0))
	s.polygon = pts
	s.color = Color(0, 0, 0, 0.6)
	s.z_index = 3
	var aro := Line2D.new()
	var b := pts.duplicate()
	b.append(pts[0])
	aro.points = b
	aro.width = 7.0
	var col := _color_fase().lightened(0.25)
	aro.default_color = Color(col.r, col.g, col.b, 0.95)
	s.add_child(aro)
	_destino().add_child(s)
	s.global_position = to_global(Vector2(x, -6.0))
	if dur > 0.0 and DisplayServer.get_name() != "headless":
		aro.create_tween().tween_property(aro, "scale", Vector2(0.2, 0.2), dur).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		var tw := s.create_tween().set_loops(maxi(int(dur / 0.2), 1))
		tw.tween_property(s, "modulate:a", 0.6, 0.1)
		tw.tween_property(s, "modulate:a", 1.0, 0.1)
	return s


func _linea_aviso(desde: Vector2, hasta: Vector2) -> Line2D:
	var l := Line2D.new()
	l.points = PackedVector2Array([to_global(desde), to_global(hasta)])
	l.width = _ancho_franja()
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


## El cuerpo nuevo (CuerpoSprite) reemplaza al tallo y al nudo: quedan ocultos siempre.
func _ajustar_tallo() -> void:
	if tallo != null:
		tallo.visible = false


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
	if nucleo != null:
		nucleo.color = c
	elif cabeza != null:
		cabeza.modulate = c
	if cabeza_f3_nodo != null:
		cabeza_f3_nodo.modulate = c
	for pt in _puntas:
		pt.color = c


## Cada frame de la cabeza animada (arte de Micaela) se copia a las piezas texturizadas.
## El arte base va tal cual (UV originales); el de la F3, de otro tamaño, se re-mapea para calzar en la Estrella.
func _sync_textura() -> void:
	if nucleo == null or cabeza == null or cabeza.sprite_frames == null:
		return
	var tex := cabeza.sprite_frames.get_frame_texture(cabeza.animation, cabeza.frame)
	if tex == null:
		return
	nucleo.texture = tex
	for pt in _puntas:
		pt.texture = tex
	var es_f3 := cabeza_f3 != null and cabeza.sprite_frames == cabeza_f3
	nucleo.uv = _uv_para(_uv_nucleo, tex, es_f3)
	for i in _puntas.size():
		if i < _uv_puntas.size():
			_puntas[i].uv = _uv_para(_uv_puntas[i], tex, es_f3)


## UV de una pieza para la textura dada. Arte base: las UV originales. Arte de la F3: remapea su
## canvas sobre el de la estrella (mismo encuadre que el arte base), con zoom y corrimiento editables.
func _uv_para(base: PackedVector2Array, tex: Texture2D, es_f3: bool) -> PackedVector2Array:
	if base.is_empty() or not es_f3:
		return base
	var tam := Vector2(float(tex.get_width()), float(tex.get_height()))
	var s := tam / UV_REF * arte_f3_escala
	var centro := tam * 0.5 + arte_f3_offset
	var ref_c := UV_REF * 0.5
	var out := PackedVector2Array()
	for p in base:
		out.append((p - ref_c) * s + centro)
	return out


## Vuelve al arte de la cabeza base (al reiniciar el intento).
func _poner_arte_base() -> void:
	_aplicar_fase_cabeza(false)


## Muestra la cabeza base (F1/F2) o la de la F3. Con polígonos (legado) la Estrella se texturiza;
## sin polígonos usa el sprite Cabeza (F1/F2) o el sprite aparte CabezaF3 (F3).
func _aplicar_fase_cabeza(es_f3: bool) -> void:
	if nucleo != null:
		if cabeza_f3_nodo != null:
			cabeza_f3_nodo.visible = false
		if cabeza != null:
			var frames: SpriteFrames = cabeza_f3 if (es_f3 and cabeza_f3 != null) else _cabeza_base
			if frames != null and cabeza.sprite_frames != frames:
				cabeza.sprite_frames = frames
				cabeza.play("cabeza")
			cabeza.visible = false
			_sync_textura()
		return
	if cabeza != null:
		cabeza.visible = not es_f3
	if cabeza_f3_nodo != null:
		cabeza_f3_nodo.visible = es_f3
		if es_f3:
			cabeza_f3_nodo.play("cabeza")


## Captura (una vez) la lista de puntas y las UV base del arte, para reproducirlas con otro encuadre.
func _capturar_arte_base() -> void:
	_puntas.clear()
	_uv_puntas.clear()
	if estrella == null or nucleo == null:
		return
	for n in estrella.get_children():
		if n.has_method("romper"):
			_puntas.append(n)
	_uv_nucleo = nucleo.uv.duplicate()
	for pt in _puntas:
		_uv_puntas.append((pt as Polygon2D).uv.duplicate())


## Nodo que dibuja la cabeza: la Estrella (polígonos) o, si no existen, el AnimatedSprite2D Cabeza.
func _nodo_head() -> Node2D:
	if nucleo == null:
		return cabeza
	return estrella


## Captura (una vez) las poses base del dibujo y del ojo para poder moverlos/escalarlos solo en la F3.
func _capturar_transforms() -> void:
	var head := _nodo_head()
	if head != null:
		_estrella_pos0 = head.position
		_estrella_scale0 = head.scale
	if ojo != null:
		_ojo_pos0 = ojo.position
		_ojo_scale0 = ojo.scale
		_abierta_offset0 = ojo.abierta_offset
	var hc: CollisionShape2D = null
	if hurtbox != null:
		hc = hurtbox.get_node_or_null("Collision") as CollisionShape2D
	if hc != null:
		_hurt_col0 = hc.scale
	var bc: CollisionShape2D = null
	if blanco_sonico != null:
		bc = blanco_sonico.get_node_or_null("Collision") as CollisionShape2D
	if bc != null:
		_blanco_col0 = bc.scale
	if circulo_ojo != null:
		_circulo_radio0 = circulo_ojo.radio


## Centro visual del ojo abierto (coordenadas de Cuerpo): donde debe pegarle el jugador.
func _centro_ojo() -> Vector2:
	if ojo == null:
		return Vector2.ZERO
	return (ojo.position as Vector2) + (ojo.scale as Vector2) * (ojo.abierta_offset as Vector2)


## Aplica (F3) o restaura (F1/F2) la pose del dibujo de la cabeza y del ojo. Los golpeables
## (Hurtbox, BlancoSonico, CirculoOjo) siguen al ojo para que los golpes calcen con lo que se ve.
func _aplicar_transform_fase(es_f3: bool) -> void:
	if nucleo != null and estrella != null:
		estrella.position = _estrella_pos0 + (estrella_f3_offset if es_f3 else Vector2.ZERO)
		estrella.scale = _estrella_scale0 * (estrella_f3_escala if es_f3 else 1.0)
	if ojo != null:
		ojo.position = _ojo_pos0 + (ojo_f3_offset if es_f3 else Vector2.ZERO)
		ojo.scale = _ojo_scale0 * (ojo_f3_escala if es_f3 else 1.0)
	_alinear_golpeables()


func _alinear_golpeables() -> void:
	if ojo == null:
		return
	var c := _centro_ojo()
	var factor: float = (ojo.scale as Vector2).x / maxf(_ojo_scale0.x, 0.0001)
	if hurtbox != null:
		hurtbox.position = c
		var hc := hurtbox.get_node_or_null("Collision") as CollisionShape2D
		if hc != null:
			hc.scale = _hurt_col0 * factor
	if blanco_sonico != null:
		blanco_sonico.position = c
		var bc := blanco_sonico.get_node_or_null("Collision") as CollisionShape2D
		if bc != null:
			bc.scale = _blanco_col0 * factor
	if circulo_ojo != null:
		circulo_ojo.position = c
		circulo_ojo.radio = _circulo_radio0 * factor


# ---------------------------------------------------------------- preview en el editor (@tool)

## Solo-editor: dibuja el arte de la F3 sobre la Estrella con clones que NO se guardan en la escena,
## así se acomoda `arte_f3_escala` / `arte_f3_offset` viendo el encuadre real en vivo.
func _refrescar_preview() -> void:
	if not Engine.is_editor_hint() or not is_inside_tree():
		return
	if nucleo == null:
		# Cabeza de sprite: el preview solo muestra/oculta el sprite aparte de la F3.
		if cabeza_f3_nodo != null:
			cabeza_f3_nodo.visible = previsualizar_f3
			if previsualizar_f3:
				cabeza_f3_nodo.play("cabeza")
		if cabeza != null:
			cabeza.visible = not previsualizar_f3
		return
	if estrella == null:
		return
	var tex: Texture2D = null
	if previsualizar_f3 and cabeza_f3 != null and not _uv_nucleo.is_empty():
		tex = cabeza_f3.get_frame_texture(&"cabeza", 0)
	if tex == null:
		if _preview_transform:
			_aplicar_transform_fase(false)
			_preview_transform = false
		_limpiar_preview()
		return
	_aplicar_transform_fase(true)
	_preview_transform = true
	if _preview_f3 == null or not is_instance_valid(_preview_f3):
		_preview_f3 = Node2D.new()
		_preview_f3.name = "__preview_f3"
		estrella.add_child(_preview_f3)
		_preview_f3.owner = null
	for c in _preview_f3.get_children():
		_preview_f3.remove_child(c)
		c.free()
	_agregar_clon_preview(nucleo, _uv_nucleo, tex)
	for i in _puntas.size():
		if i < _uv_puntas.size():
			_agregar_clon_preview(_puntas[i] as Polygon2D, _uv_puntas[i], tex)


func _agregar_clon_preview(orig: Polygon2D, uv_base: PackedVector2Array, tex: Texture2D) -> void:
	if orig == null:
		return
	var clon := Polygon2D.new()
	clon.polygon = orig.polygon
	clon.color = Color.WHITE
	clon.texture = tex
	clon.uv = _uv_para(uv_base, tex, true)
	clon.owner = null
	_preview_f3.add_child(clon)
	orig.visible = false


## Guarda/restaura el preview alrededor de guardar la escena, para no persistir el arte F3 en el editor.
func _notification(what: int) -> void:
	if not Engine.is_editor_hint():
		return
	if what == NOTIFICATION_EDITOR_PRE_SAVE:
		if _preview_transform:
			_aplicar_transform_fase(false)
			_preview_transform = false
		_limpiar_preview()
	elif what == NOTIFICATION_EDITOR_POST_SAVE:
		_refrescar_preview()


func _limpiar_preview() -> void:
	if _preview_f3 != null and is_instance_valid(_preview_f3):
		for c in _preview_f3.get_children():
			_preview_f3.remove_child(c)
			c.free()
		var padre := _preview_f3.get_parent()
		if padre != null:
			padre.remove_child(_preview_f3)
		_preview_f3.free()
		_preview_f3 = null
	if nucleo != null:
		nucleo.visible = true
	for pt in _puntas:
		if is_instance_valid(pt):
			(pt as CanvasItem).visible = true


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
		_grito(volumen_aparicion_db - 6.0)
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
	_grito(volumen_aparicion_db)
	JuiceFx.escombros(get_tree(), global_position + Vector2(0, -30), Color(0.42, 0.3, 0.55), 26, 1.5)
	if cam != null and cam.has_method("shake"):
		cam.shake(aparicion_shake_max * 1.4, 0.8)
	if cam != null and cam.has_method("punch"):
		cam.punch(1.05)
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


## Grito de la Estrella (aparición; en los reintentos, más bajo).
func _grito(volumen_db: float) -> void:
	var audio := get_node_or_null("/root/AudioManager")
	if audio != null and sonido_aparicion != null:
		audio.play_sfx(sonido_aparicion, volumen_db)


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
	_marcas()
	foso.set("dano", 0)   # tras la victoria el foso no mata (si no, derrota y victoria se pisaban)
	_estado = "inactivo"
	_hurtbox_on(false)
	_limpiar_lanzas()
	_limpiar_ojos()
	_limpiar_invocados()
	_limpiar_orbes()
	_limpiar_estalactitas()
	_limpiar_traidor()
	_contener_ataque(false)
	_contacto_dano = 0
	_energia_jefe(false)
	_ambiente_combate(false)
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
