extends CharacterBody2D

signal form_changed(form_name: String)
signal forma_selectada_cambiada(forma_index: int)
signal attack_performed(attack_type: String, step: Variant)
signal health_changed(health: int, max_health: int)
signal dano_recibido(cantidad: int)
signal energia_changed(energia: float)
signal transformacion_agotada
signal racha_changed(cantidad: int)
signal parry_exitoso
signal transformacion_denegada
signal aterrizaje_fuerte(pos: Vector2, impacto: float)
signal pisoton(pos: Vector2)

enum Form { HUMAN, LOBO, OSO, MURCIELAGO }

const GRAVITY := 980.0
const MAX_FALL_SPEED := 950.0
const GLIDE_FALL_MULTIPLIER := 0.22
const COYOTE_TIME := 0.14  # base; overridden per form in _init()
const JUMP_BUFFER_TIME := 0.18  # base; overridden per form in _init()
const JUMP_CUT_MULTIPLIER := 0.42  # base; overridden per form in _init()
const FALL_GRAVITY_MULT := 1.8
const TURN_BOOST := 2.2
const TURN_BOOST_AIR := 1.6
const FRICTION_AIR_MULT := 0.7
const APEX_THRESHOLD := 48.0
const APEX_GRAVITY_MULT := 0.82
const APEX_CORE_THRESHOLD := 22.0
const APEX_CORE_MULT := 0.58
const TINT_ALPHA := 1.0  # antes 0.45; hacer self_modulate x form fue reportado como "azul oscuro"
const COMBO_WINDOW := 1.1
const LINEA_ESPESOR := 40.0
const ENERGIA_MAX := 100.0
const ENERGIA_DRAIN := 4.0
const ENERGIA_REGEN := 8.0
const ENERGIA_KILL := 20.0
const ENERGIA_PICKUP := 30.0
const ENERGIA_RESPAWN := 50.0
const RECOVERY_LIGHT := 0.28
const RECOVERY_HEAVY := 0.52
const RECOVERY_SPECIAL := 0.92
const RECOVERY_COMBO := 1.05
const MELEE_STICKY_REACH := 240.0
const MELEE_STICKY_PIVOT := 28.0
const MELEE_STICKY_SPEED_MULT := 0.85
const HITSTOP_LIGHT := 0.035
const HITSTOP_HEAVY := 0.07
const HITSTOP_SPECIAL := 0.09
const HITSTOP_COMBO := 0.11
@export var hitstop_dano := 0.0  # hitstop al recibir daño (0 = nada: solo shake + flash)
@export var hitstop_dano_pesado := 0.06     # pausa extra al recibir un golpe fuerte (>= umbral)
@export var hitstop_dano_umbral := 20       # daño mínimo para considerarlo golpe fuerte
@export var recoil_sprite := 8.0            # px que empuja el sprite hacia atrás al recibir daño
@export var temblor_dano := 0.13            # s que dura el micro-temblor del sprite (sin rotar)
@export var proyectil_mira_bajo := 45.0     # px por debajo del centro del enemigo a los que apunta el proyectil teledirigido del Murciélago
@export var zoom_heavy_mult := 1.025        # zoom punch extra en golpes pesados
@export var zoom_special_mult := 1.04       # zoom punch extra en el golpe especial
@export var zoom_combo_mult := 1.05         # zoom punch extra en el golpe que cierra combo
@export var shake_special := 16.0           # fuerza del shake para el golpe especial
@export var shake_tercer_mult := 1.3        # multiplicador de shake en el golpe que cierra combo
@export var hitstop_tercer_mult := 1.2      # multiplicador de hitstop en el golpe que cierra combo
# Feedback por racha de combos: al llegar a 3 y a 5 golpes seguidos, suben
# zoom punch, hitstop y el tamaño del spark (0 = sin extras en ese umbral).
@export var racha_zoom_3 := 1.03            # zoom punch extra al llegar a racha 3
@export var racha_zoom_5 := 1.06            # zoom punch extra al llegar a racha 5
@export var racha_hitstop_3 := 1.15         # multiplicador de hitstop al llegar a racha 3
@export var racha_hitstop_5 := 1.3          # multiplicador de hitstop al llegar a racha 5
@export var hitstop_max := 0.16             # tope del hitstop de un golpe (evita que la suma de multiplicadores trabe)
@export var hitstop_rafaga_mult := 0.7      # si el golpe llega poco después del anterior, el hitstop se acorta (ráfagas fluidas)
@export var parry_ventana := 0.16           # Humano: al empezar a bloquear, ventana (s) donde el golpe se devuelve (parry)
@export var parry_energia := 12.0          # energía que da un parry exitoso
@export var parry_onda_radio := 170.0       # el parry aturde a los enemigos cercanos
@export var tag_bonus_mult := 1.5           # cambiar de forma a mitad de racha: el próximo golpe pega esto de más
@export var tag_bonus_tiempo := 2.0         # cuánto dura ese bonus (s)
@export var tag_energia := 8.0              # energía que da el cambio de forma dentro de una racha
@export var flap_cooldown := 0.28           # s entre aleteos del Murciélago
@export var aleteo := 1.0                    # ritmo del aleteo visual quieto/planeando (0 = alas quietas)
@export_group("Cuerpo elástico")
@export var resorte_rigidez := 420.0        # cuánto tira el cuerpo de vuelta a su forma (más alto = más rápido)
@export var resorte_amort := 22.0           # freno del resorte (más bajo = más rebote)
@export var acel_inclinacion_grados := 3.0  # inclinación del cuerpo al acelerar/frenar (0 = sin)
@export var giro_squash := 0.07             # aplaste lateral al girar estando quieto
@export var respiracion_amp := 0.012        # cuánto respira el cuerpo parado (0 = quieto)
@export var respiracion_latido := 0.03      # cuánto se hincha con cada latido cuando quedás con poca vida
@export var respiracion_vel := 2.2         # ritmo de la respiración (rad/s)
@export var polvo_correr_intervalo := 0.24  # s entre nubes de polvo al correr (0 = sin polvo)
@export var eco_alpha := 0.32               # opacidad inicial de los ecos espectrales (0 = sin ecos)
@export var magnetismo_alcance := 340.0     # px: a qué distancia busca enemigo para el magnetismo
@export var magnetismo_mult := 1.6         # el avance del golpe se estira hasta este múltiplo para llegar al enemigo (1 = sin)
@export var escalon_distancia := 20.0       # px de avance con que el sprite alcanza la recta ajustada (menor = más pegado, mayor = más suave)
@export var rampa_distancia := 80.0         # px de recorrido sobre los que se ajusta la recta (una escalera de peldaños se vuelve rampa recta)
@export var suavizado_escalon := 6.0       # rapidez con que el sprite se asienta cuando estás quieto o en el aire (0 = sin suavizar)
@export var suavizado_escalon_max := 24.0   # px: desniveles mayores no se suavizan (teletransportes, caídas)
@export var transicion_salida_ataque := 0.12  # s que se disuelve la última pose del golpe al volver a idle/correr (0 = corte seco)
@export var piernas_vel_min := 0.15         # piso de la velocidad de las piernas al arrancar/frenar (antes 0.35: patinaban)
@export var reaccion_dano_en_ataque := true # recibir daño en pleno golpe corta el avance del ataque y el retroceso solo mueve el sprite en X
@export_group("")
@export var hitstop_rafaga_ventana := 0.4   # segundos entre golpes para considerarlo ráfaga
@export var racha_spark_3 := 1.35           # escala del spark al llegar a racha 3
@export var racha_spark_5 := 1.7            # escala del spark al llegar a racha 5
@export var spark_hundir_px := 14.0         # cuánto entra el spark en el cuerpo del enemigo desde su borde
@export var swing_visible := true           ## estela (medialuna) de cada ataque cuerpo a cuerpo
@export var swing_alpha := 0.55
@export var swing_alcance := 1.05          ## radio de la medialuna respecto del alcance del golpe
@export var swing_duracion := 0.13
@export_range(0.05, 0.6) var swing_grosor := 0.16  ## grosor máximo de la estela (fracción del radio)
@export_range(0.0, 1.0) var spark_altura := 0.42  # altura del impacto dentro del hitbox (0 = arriba, 1 = pies); 0.42 ≈ puño
@export var lobo_landing_squash_extra := 1.4  # multiplicador squash al aterrizar como Lobo (item 18)
@export var slowmo_transformacion := 0.07 # s de cámara lenta al transformarse (0 = off)
@export var slowmo_transformacion_escala := 0.4  # escala del tiempo mientras transforma
@export var tint_dano := Color(1.0, 0.28, 0.28)  # tinte del sprite al recibir daño
@export var tint_dano_duracion := 0.11  # s que tarda en volver al color normal
@export_group("Aviso de especial listo")
@export var tint_especial_listo := Color(1.7, 1.55, 1.1)  ## destello del sprite al terminar el cooldown del especial
@export var especial_listo_duracion := 0.18  ## s que tarda en volver al color normal
@export var sonido_especial_listo: AudioStream = preload("res://assets/audio/sfx/gen/checkpoint.wav")
@export var volumen_especial_listo_db := -20.0
@export_group("")
@export_group("Juice (golpe, transformación, parry)")
@export var tajo_luz := true                      ## tajo blanco diagonal sobre el enemigo al conectar
@export var tajo_escala := 0.6                    ## tamaño del tajo (sutil)
@export_range(0.0, 1.0) var tajo_alpha := 0.65    ## opacidad del tajo; su color sale de la forma activa
@export var transformacion_cine := true           ## destello, congelado y estallido de color al transformarse
@export var transformacion_congelado := 0.07      ## s con el mundo congelado al transformarse
@export var transformacion_slowmo := 0.2          ## s de cámara lenta justo después
@export var transformacion_slowmo_escala := 0.35
@export var transformacion_tinte_duracion := 0.5  ## s que la pantalla queda teñida del color de la forma
@export var transformacion_radio := 1500.0        ## alcance del estallido de rayos
@export var parry_bn := true                      ## pantalla en blanco y negro (menos tú) en el parry perfecto
@export var parry_congelado := 0.08               ## s con todo congelado al hacer un parry perfecto (corto: impacto sin cortar el ritmo)
## Cámara lenta del parry como curva: cada tramo es (duración en s, escala de tiempo). Entra lento y vuelve suave a 1.
@export var parry_slowmo_tramos: Array[Vector2] = [Vector2(0.16, 0.25), Vector2(0.2, 0.5), Vector2(0.3, 0.8)]
@export var contragolpe_tiempo := 1.3             ## s tras un parry en que el próximo golpe sale potenciado
@export var contragolpe_mult := 1.5               ## multiplicador de daño del contragolpe
@export var contragolpe_dano_min := 24            ## daño mínimo del contragolpe (rompe la resistencia/poise del enemigo)
@export_range(0.05, 0.6) var parry_radio_color := 0.2  ## círculo que conserva el color alrededor del jugador
@export var dano_cine := true                     ## recibir daño: pantalla sin color y bordes rojos
@export var dano_empuje_mult := 1.35              ## el golpe recibido te empuja más lejos
@export var oso_grietas := true                   ## el Oso agrieta el piso al aterrizar y al pisotón
@export var silencio_golpe_fuerte := true         ## el ambiente calla justo antes de un golpe pesado
@export var tono_combo := 0.03                    ## cuánto sube de agudo el golpe por cada golpe de racha (máx. 8)
@export_group("")
var _oso_grieta_ms := 0
var _tajo_alterno := false
const VIDA_MAX := 100

var forms: Array[Forma] = []
var current_form: int = Form.HUMAN
var forma_seleccionada: int = Form.HUMAN
var health: int = 100
var energia: float = ENERGIA_MAX
var god_mode := false
var facing := 1
var blocking := false

var _attacking := false
var _attack_timer := 0.0
var _ultimo_hitstop_s: float = -10.0
var _parry_t: float = 0.0
var _tag_t: float = 0.0
var _contra_t: float = 0.0
var _flap_cd: float = 0.0
var _picada: bool = false
var _pose_rot: float = 0.0        # rotación extra del sprite al golpear (rad), vuelve sola a 0
var _pose_tween: Tween
var _lunge_t: float = 0.0
var _dano_reciente_t := 0.0   # tras recibir daño: el avance/imán del ataque no pisan el retroceso
var _lunge_vel: float = 0.0
const LUNGE_DUR := 0.09           # el avance del golpe dura esto (la distancia la define la forma)
var _hit_applied := false
var _hit_delay := 0.0
var _whiff_applied := false
var _whiff_grace := 0.0
@export var whiff_recovery_mult := 1.15
const WHIFF_GRACE_TIME := 0.06
var _current_attack_damage := 0
var _current_attack_knockback := 0.0
var _current_attack_type := "light"
var _gravity_override: float = -1.0
var _coyote_time := 0.0
var _jump_buffer := 0.0
var _attack_air_buffer := 0.0
var _attack_air_buffer_type := ""
const ATTACK_AIR_BUFFER_TIME := 0.16
var _light_step := 0
var _heavy_step := 0
var _seq: Array[String] = []
var _combo_timer := 0.0
var _racha := 0
var _racha_timer := 0.0
var _buffered_attack := ""

var _early_exit_umbral := 0.0   # duración límite del recovery (segundos) para liberar movimiento/chain
var _early_liberado := false     # se true al pasar el umbral: movimiento/libre aunque el recovery siga
var _attack_anim_timer := 0.0
var _attack_anim_actual := "attack1"
var _attack_anim_cola: Array[String] = []
var _attack_anim_speed_scale := 1.0
var _attack_frame_dur := PackedFloat32Array()   # tiempo planificado de cada frame de la animación de ataque en curso
static var _tips_vistos: Dictionary = {}
@export var tips_ayuda := true             ## muestra avisos de ayuda la primera vez (parry, energía)
@export_group("Defensa")
@export var bloqueo_costo_energia := 3.0  ## energía base que gasta cada golpe bloqueado (0 = gratis)
@export var bloqueo_costo_por_dano := 0.25  ## energía extra por punto de daño bloqueado (golpes fuertes cuestan más)
@export var bloqueo_cooldown := 0.6       ## s sin poder volver a bloquear tras soltar (el parry exitoso lo evita)
@export var bloqueo_max := 0.0            ## s máximos de guardia continua (0 = sin límite; al pasarse hay que soltar el botón)
@export var bloqueo_empuje := 220.0       ## px/s que te empuja hacia atrás cada golpe bloqueado
@export var bloqueo_drenaje := 4.0        ## energía/s que gasta mantener la guardia (el parry no cuesta)
@export var bloqueo_energia_min := 10.0   ## sin energía no se puede bloquear hasta recuperar este mínimo
var _bloqueo_sin_energia := false
var _bloqueo_cd := 0.0
var _bloqueo_t := 0.0
var _bloqueo_agotado := false
var _bloqueo_sin_cd := false
@export_group("Alineación")
@export var anclar_pies := true         ## apoya la base de cada frame en el piso (evita flotar/hundirse)
@export var pies_hundidos := 4.0         ## px que los pies se meten en el suelo (sensación de peso)
@export var ajuste_frames: Dictionary = {}  ## offset por frame encima del anclaje; clave "anim:frame" o "anim" -> Vector2 (px). Ej: "lobo_idle:2" -> Vector2(0, -6)
@export_group("")
var _was_blocking := false
var _was_on_floor := false
var _suave_y := 0.0   # desfase visual (px) que absorbe el brinco del cuerpo en un desnivel y decae a 0
var _suave_x_prev := 0.0   # x del cuerpo en el frame anterior

var _suave_s := 0.0        # altura suavizada del suelo (mundo)
var _suave_hist_x: Array[float] = []   # muestras recientes (x, y) del cuerpo en el suelo para ajustar la recta
var _suave_hist_y: Array[float] = []
var _suave_entero := 0.0   # parte entera de _suave_y ya aplicada a visual.position.y
var _mat_suave: ShaderMaterial   # absorbe la fracción de píxel de _suave_y
var _fall_impact := 0.0
var _esc_off := Vector2.ZERO      # desvío de escala del resorte (0 = forma normal)
var _esc_vel := Vector2.ZERO
var _esc_reposo := Vector2.ZERO   # hacia dónde tira el resorte (poses de salto/apex)
var _acel_suave := 0.0
var _vx_prev := 0.0
var _t_resp := 0.0
var _polvo_paso_t := 0.0
var _eco_t := 0.0
var _tint_tween: Tween
var _recoil_tween: Tween
var _visual_base_x := 0.0          # x de reposo del sprite (el retroceso siempre vuelve acá)
var _tween_muerte: Tween
var _amb: Node                     # autoload Ambiente (cacheado)
var _turn_prev_facing := 0
var _base_sprite_scale := Vector2.ONE
var _spawn_position := Vector2.ZERO
var _tiene_checkpoint := false
var _checkpoint_forma := Form.HUMAN
var _checkpoint_vida := VIDA_MAX
var _checkpoint_energia := ENERGIA_MAX
var _derrota_activa := false
var cinematica_dir := 0.0         ## durante la intro: el jugador camina solo en esta dirección (0 = quieto; 0.35 = paso tranquilo)
var cinematica_activa := false   ## intro de nivel en curso: sin control ni daño (lo maneja intro_nivel.gd)
var _velo_muerte: CanvasLayer
var _invuln_timer := 0.0
var _invuln_sin_parpadeo := false
var _cooldown_formas: Dictionary = {}
const COOLDOWN_AGOTADA := 2.0
const COOLDOWN_TRANSFORM := 0.35   # anti-spam: el freno real son la energía mínima y el drenaje
var _cooldown_transform := 0.0
var _special_cooldown := 0.0
var _transform_buffer: float = 0.0
const TRANSFORM_BUFFER_TIME := 0.25
var _trepando: bool = false
var _enredadera_actual: Area2D = null
var _trepado_cooldown: float = 0.0
var _trepar_hold_t: float = 0.0
var _vine_coyote_timer: float = 0.0
var _vine_buffer_timer: float = 0.0
var _vine_particulas_timer: float = 0.0
var _vine_dir_hold_t: float = 0.0
var _salto_enredadera: bool = false
const VINE_COYOTE_TIME := 0.15
const VINE_BUFFER_TIME := 0.15
const TREPAR_ACCEL := 4200.0
const TREPAR_ACCEL_TURBO := 9000.0
const TREPAR_TURBO_INICIO := 0.15
const TREPAR_TURBO_RAMP := 0.45
const TREPAR_TURBO_MULT := 1.4
const TREPAR_DOWN_MULT := 1.5
const TREPAR_STOP_LERP := 8.0
const TREPAR_EXIT_HOLD := 0.1
const TREPAR_SALIR_COOLDOWN := 0.45
var _murci_glide_t: float = 0.0
var _was_gliding: bool = false
var _apex_squash_t: float = 0.0
var _step_up_cd: float = 0.0
var _step_up_hecho := false   # el último _try_step_up subió un escalón
var _salto_aereo_limitado: bool = false
@export var limite_caida := 12000.0
@export var sonido_golpe_liviano: AudioStream
@export var sonido_golpe_pesado: AudioStream
@export var sonido_transformacion: AudioStream
@export var sonido_swing: AudioStream = preload("res://assets/audio/sfx/gen/swing_1.wav")           ## "whoosh" de cada ataque cuerpo a cuerpo (suene o no el golpe)
@export var sonido_swing_pesado: AudioStream = preload("res://assets/audio/sfx/gen/swing_pesado.wav")
@export var volumen_swing_db := -12.0
@export var sonido_muerte: AudioStream = preload("res://assets/audio/sfx/gen/muerte_jugador.wav")
@export var reaparicion_automatica := true      ## al morir reaparece solo en el checkpoint (sin panel "HAS CAÍDO"); false = panel con Reintentar/Menú
@export var muerte_duracion := 0.9          ## s de cámara lenta + oscurecido antes del panel de derrota (0 = directo)
@export_range(0.05, 1.0) var muerte_slowmo_escala := 0.3

@export_group("Sonidos de movimiento")
## Pasos: suenan en los frames de la animación de correr en que el pie toca el suelo.
@export var pasos_humano: Array[AudioStream] = [preload("res://assets/audio/sfx/gen/paso_humano_1.wav"), preload("res://assets/audio/sfx/gen/paso_humano_2.wav"), preload("res://assets/audio/sfx/gen/paso_humano_3.wav"), preload("res://assets/audio/sfx/gen/paso_humano_4.wav")]
@export var pasos_lobo: Array[AudioStream] = [preload("res://assets/audio/sfx/gen/paso_lobo_1.wav"), preload("res://assets/audio/sfx/gen/paso_lobo_2.wav"), preload("res://assets/audio/sfx/gen/paso_lobo_3.wav"), preload("res://assets/audio/sfx/gen/paso_lobo_4.wav")]
@export var pasos_oso: Array[AudioStream] = [preload("res://assets/audio/sfx/gen/paso_oso_1.wav"), preload("res://assets/audio/sfx/gen/paso_oso_2.wav"), preload("res://assets/audio/sfx/gen/paso_oso_3.wav"), preload("res://assets/audio/sfx/gen/paso_oso_4.wav")]
@export var aleteos: Array[AudioStream] = [preload("res://assets/audio/sfx/gen/aleteo_1.wav"), preload("res://assets/audio/sfx/gen/aleteo_2.wav"), preload("res://assets/audio/sfx/gen/aleteo_3.wav")]
@export var pasos_frames_humano := PackedInt32Array([1, 4])   ## frames de "run" (6 frames) con pie apoyado
@export var pasos_frames_lobo := PackedInt32Array([1, 2])     ## "lobo_run": manos y patas (galope)
@export var pasos_frames_oso := PackedInt32Array([0, 3])      ## "oso_caminar"
@export var volumen_pasos_db := -15.0
@export var volumen_pasos_oso_db := -9.0
@export var volumen_aleteo_db := -16.0
@export var oso_paso_shake := 1.2                             ## sacudida leve de cámara por pisada del Oso (0 = nada)
@export var sonido_salto_humano: AudioStream = preload("res://assets/audio/sfx/gen/salto_humano.wav")
@export var sonido_salto_lobo: AudioStream = preload("res://assets/audio/sfx/gen/salto_lobo.wav")
@export var sonido_salto_oso: AudioStream = preload("res://assets/audio/sfx/gen/salto_oso.wav")
@export var sonido_doble_salto: AudioStream = preload("res://assets/audio/sfx/gen/doble_salto.wav")
@export var volumen_salto_db := -11.0
@export var sonido_aterrizaje_suave: AudioStream = preload("res://assets/audio/sfx/gen/aterrizaje_suave.wav")
@export var sonido_aterrizaje_fuerte: AudioStream = preload("res://assets/audio/sfx/gen/aterrizaje_fuerte.wav")
@export var aterrizaje_umbral := 180.0                        ## velocidad de caída mínima para que suene
@export var sonido_derrape: AudioStream = preload("res://assets/audio/sfx/gen/derrape.wav")
@export var volumen_derrape_db := -14.0
@export var sonido_liana_agarrar: AudioStream = preload("res://assets/audio/sfx/gen/liana_agarrar.wav")
@export var liana_trepar: Array[AudioStream] = [preload("res://assets/audio/sfx/gen/liana_trepar_1.wav"), preload("res://assets/audio/sfx/gen/liana_trepar_2.wav"), preload("res://assets/audio/sfx/gen/liana_trepar_3.wav")]
@export var sonido_liana_deslizar: AudioStream = preload("res://assets/audio/sfx/gen/liana_deslizar_loop.wav")   ## loop mientras baja rápido
@export var sonido_liana_soltar: AudioStream = preload("res://assets/audio/sfx/gen/liana_soltar.wav")
@export var volumen_liana_db := -12.0
@export var liana_trepar_intervalo := 0.24
@export_group("Sonidos de estado")
@export var sonido_dano: AudioStream = preload("res://assets/audio/sfx/gen/dano_jugador.wav")
@export var volumen_dano_db := -8.0
@export var sonido_bloqueo: AudioStream = preload("res://assets/audio/sfx/gen/bloqueo.wav")
@export var sonido_transformacion_bloqueada: AudioStream = preload("res://assets/audio/sfx/gen/transformacion_bloqueada.wav")
@export var sonido_energia_agotada: AudioStream = preload("res://assets/audio/sfx/gen/energia_agotada.wav")
@export var sonido_disparo: AudioStream = preload("res://assets/audio/sfx/gen/proyectil_disparo.wav")
@export var volumen_estado_db := -10.0
@export_group("")
@export var volumen_muerte_db := -4.0
@export var volumen_golpe_db := 0.0
@export var volumen_transformacion_db := 0.0
## Offsets de volumen (dB) para el golpe pesado y el especial, aplicados sobre volumen_golpe_db.
@export var volumen_golpe_pesado_db := 0.0
@export var volumen_special_db := 0.0
@export var invuln_transformacion := 0.8
@export var transformacion_pop := 0.32          ## rebote del cuerpo (resorte) al transformarse (0 = sin)
@export var transformacion_anillo := 230.0       ## radio del aro de onda al transformarse (0 = sin)
@export var golpe_rapido_tras_transformar := 1.0 ## s tras transformarte en que el primer ataque conecta sin retardo (0 = off)
var _golpe_rapido_t := 0.0
@export var invuln_dano := 0.8                  ## s de invulnerabilidad tras recibir un golpe
@export var energia_min_transformar := 25.0      ## energía mínima para transformarse (el retorno a Humano no la pide)

@onready var visual: AnimatedSprite2D = $Sprite2D
@onready var collision_shape: CollisionShape2D = $Collision
@onready var attack_area: Area2D = $AttackArea
@onready var attack_hitbox: CollisionShape2D = $AttackArea/AttackHitbox
@onready var polvo: CPUParticles2D = $Polvo
@onready var sombra: Polygon2D = $Sombra

var _derrape_cd := 0.0
var _t_sin_suelo := 0.0
var _denegar_cd := 0.0
var _liana_trepar_t := 0.0
var _liana_loop: AudioStreamPlayer

const FORMAS := [
	preload("res://resources/formas/humano.tres"),
	preload("res://resources/formas/lobo.tres"),
	preload("res://resources/formas/oso.tres"),
	preload("res://resources/formas/murcielago.tres"),
]


func _ready() -> void:
	pisoton.connect(func(_pos: Vector2) -> void: _juice_oso_suelo(900.0))
	if DisplayServer.get_name() != "headless":
		JuiceFx.precalentar.call_deferred(get_tree())
	add_to_group("player")
	for forma in FORMAS:
		forms.append(forma)
	health = VIDA_MAX
	_spawn_position = global_position
	_base_sprite_scale = Vector2(absf(visual.scale.x), visual.scale.y)
	_visual_base_x = visual.position.x
	_suave_s = global_position.y
	_suave_x_prev = global_position.x
	_mat_suave = ShaderMaterial.new()
	_mat_suave.shader = preload("res://resources/suave_vertical.gdshader")
	visual.material = _mat_suave
	floor_snap_length = 8.0
	floor_stop_on_slope = false
	floor_max_angle = deg_to_rad(45.0)
	wall_min_slide_angle = deg_to_rad(15.0)
	_apply_form()
	visual.frame_changed.connect(_on_frame_animacion)
	visual.animation_changed.connect(_anclar_pies)
	_liana_loop = AudioStreamPlayer.new()
	_liana_loop.stream = sonido_liana_deslizar
	_liana_loop.bus = &"SFX"
	add_child(_liana_loop)


## El jugador no puede salir de los límites de la cámara (izquierda, derecha y arriba; abajo queda libre para caídas al vacío).
func _limitar_a_camara() -> void:
	var cam := get_viewport().get_camera_2d()
	if cam == null:
		return
	var x := clampf(global_position.x, cam.limit_left, cam.limit_right)
	var y := maxf(global_position.y, cam.limit_top)
	if x != global_position.x:
		velocity.x = 0.0
	if y != global_position.y:
		velocity.y = maxf(velocity.y, 0.0)
	global_position = Vector2(x, y)

func _physics_process(delta: float) -> void:
	var dialogo_bloquea := _dialogo_bloquea_input()
	var quiere_bloquear := not dialogo_bloquea and Input.is_action_pressed("block")
	if not quiere_bloquear:
		_bloqueo_agotado = false
	_bloqueo_cd = maxf(_bloqueo_cd - delta, 0.0)
	if _was_blocking:
		_bloqueo_t += delta
		if bloqueo_max > 0.0 and _bloqueo_t >= bloqueo_max:
			_bloqueo_agotado = true
	else:
		_bloqueo_t = 0.0
	blocking = quiere_bloquear and not _bloqueo_agotado and _bloqueo_cd <= 0.0 and not _bloqueo_sin_energia
	if _was_blocking and not blocking:
		_bloqueo_cd = 0.0 if _bloqueo_sin_cd else bloqueo_cooldown
		_bloqueo_sin_cd = false
	if blocking != _was_blocking:
		if blocking:
			_cancelar_recuperacion()
		if blocking and current_form == Form.HUMAN:
			_parry_t = parry_ventana
		_was_blocking = blocking
		_update_tint()

	var data: Forma = forms[current_form]
	data.tick(self, delta)
	_derrape_cd = maxf(_derrape_cd - delta, 0.0)
	_t_sin_suelo = 0.0 if is_on_floor() else _t_sin_suelo + delta
	_denegar_cd = maxf(_denegar_cd - delta, 0.0)
	if _dano_reciente_t > 0.0:
		_dano_reciente_t = maxf(_dano_reciente_t - delta, 0.0)
	if _step_up_cd > 0.0:
		_step_up_cd = maxf(_step_up_cd - delta, 0.0)
	if _special_cooldown > 0.0:
		_special_cooldown = maxf(_special_cooldown - delta, 0.0)
		if _special_cooldown <= 0.0:
			_flash_especial_listo()
	_handle_enredadera(delta)
	if _attack_air_buffer > 0.0:
		_attack_air_buffer -= delta
		if _attack_air_buffer <= 0.0:
			_attack_air_buffer_type = ""

	var cmd_axis := Input.get_axis("move_left", "move_right")
	if absf(cmd_axis) < 0.35:
		cmd_axis = 0.0
	var cine_camina := cinematica_activa and cinematica_dir != 0.0 and not _derrota_activa
	if (dialogo_bloquea and not cine_camina) or _trepando:
		cmd_axis = 0.0
	elif cine_camina:
		cmd_axis = cinematica_dir
	# Durante el ataque solo se puede girar (cambiar de lado), no desplazarse.
	# El early-exit (pasar el umbral de recovery) libera el desplazamiento aunque siga recuperando.
	if _attacking and cmd_axis != 0.0:
		facing = 1 if cmd_axis > 0 else -1
		attack_area.position.x = absf(attack_area.position.x) * facing   # la hitbox acompaña el giro
	# Bloqueando el personaje se planta: solo puede girar hacia el enemigo.
	if blocking and cmd_axis != 0.0:
		facing = 1 if cmd_axis > 0 else -1
		attack_area.position.x = absf(attack_area.position.x) * facing
	var dir := 0.0 if ((_attacking and not _early_liberado) or blocking) else cmd_axis
	if dialogo_bloquea and not cine_camina:
		dir = 0.0
	if _trepando:
		dir = 0.0
	elif data.is_dashing():
		velocity.x = facing * data.dash_speed()
	else:
		if dir != 0.0:
			facing = 1 if dir > 0 else -1
			var base_boost := TURN_BOOST if is_on_floor() else TURN_BOOST_AIR
			var boost := base_boost if dir * velocity.x < 0.0 else 1.0
			if boost > 1.0 and absf(velocity.x) > 120.0 and is_on_floor():
				if current_form == Form.LOBO:
					_emitir_polvo(0.7, Vector2(-facing, -0.25))
					if _derrape_cd <= 0.0:
						_derrape_cd = 0.35
						_sfx(sonido_derrape, volumen_derrape_db, 0.1)
				else:
					_emitir_polvo(0.4)
			var air_mult := data.accel_air_mult if not is_on_floor() else 1.0
			var max_spd := data.speed
			if _salto_aereo_limitado and not is_on_floor():
				max_spd *= data.jump_h_speed_mult
			velocity.x = move_toward(velocity.x, dir * max_spd, data.accel * boost * air_mult * delta)
		else:
			if absf(velocity.x) > 250.0 and is_on_floor():
				squash_y(0.12, 0.15)
			var fric := data.friction * (FRICTION_AIR_MULT if not is_on_floor() else 1.0)
			velocity.x = move_toward(velocity.x, 0.0, fric * delta)

	_melee_sticky(data, delta)
	if _lunge_t > 0.0:
		_lunge_t -= delta
		if _attacking and is_on_floor():
			velocity.x = _lunge_vel
			if current_form == Form.LOBO:
				_eco_t -= delta
				if _eco_t <= 0.0:
					_eco_t = 0.03
					emitir_eco()
	if _picada:
		_eco_t -= delta
		if _eco_t <= 0.0:
			_eco_t = 0.04
			emitir_eco()

	if not dialogo_bloquea and not _trepando and Input.is_action_just_pressed("jump"):
		_cancelar_recuperacion()
		if _salto_enredadera:
			pass
		elif _coyote_time > 0.0 or data.can_jump():
			data.try_jump(self)
		elif data.flap_impulso > 0.0 and not is_on_floor() and _flap_cd <= 0.0 and energia >= data.flap_costo:
			_aletear(data)
		else:
			_jump_buffer = data.jump_buffer_time
	if current_form == Form.MURCIELAGO and not is_on_floor() and not dialogo_bloquea and not _trepando \
			and Input.is_action_just_pressed("move_down") and not _picada:
		_picada = true
		velocity.y = maxf(velocity.y, Murcielago.PICADA_VELOCIDAD)
		velocity.x *= 0.35
		stretch_y(0.22, 0.2)
	if not dialogo_bloquea and Input.is_action_just_released("jump") and velocity.y < 0.0:
		var t := clampf(velocity.y / data.jump_velocity, 0.0, 1.0)
		velocity.y *= lerpf(0.85, data.jump_cut_multiplier, t)

	var g: float = GRAVITY * data.gravity_scale
	if _gravity_override >= 0.0:
		g = _gravity_override
	var gliding := data.is_gliding(self)
	if gliding and current_form == Form.MURCIELAGO:
		if not _was_gliding:
			squash_y(0.12, 0.15)
		_murci_glide_t += delta
		_was_gliding = true
		var prog := clampf(_murci_glide_t / 1.4, 0.0, 1.0)
		g *= lerpf(0.18, 0.52, prog)
	else:
		if _was_gliding:
			stretch_y(0.14, 0.18)
		_was_gliding = false
		_murci_glide_t = 0.0
		if gliding:
			g *= GLIDE_FALL_MULTIPLIER
	# Apex hang escalonado: nÃºcleo del Ã¡pice muy flotante, banda cercana suave.
	if absf(velocity.y) < APEX_CORE_THRESHOLD:
		g *= APEX_CORE_MULT
	elif absf(velocity.y) < APEX_THRESHOLD:
		g *= APEX_GRAVITY_MULT
	if velocity.y > 0:
		g *= FALL_GRAVITY_MULT

	if is_on_floor() and velocity.y > 0:
		velocity.y = 0
	var prog_fall := clampf(_murci_glide_t / 1.4, 0.0, 1.0) if current_form == Form.MURCIELAGO and gliding else 0.0
	var max_fall := MAX_FALL_SPEED if not gliding else (lerpf(300.0, 520.0, prog_fall) if current_form == Form.MURCIELAGO else 380.0)
	velocity.y = min(velocity.y + g * delta, max_fall)
	if gliding:
		var dir_glide := 0.0 if (dialogo_bloquea or (_attacking and not _early_liberado)) else Input.get_axis("move_left", "move_right")
		if absf(dir_glide) < 0.35:
			dir_glide = 0.0
		if dir_glide != 0.0:
			var m := 1.35 if current_form == Form.MURCIELAGO else 1.1
			var a := 0.9 if current_form == Form.MURCIELAGO else 0.6
			velocity.x = move_toward(velocity.x, dir_glide * data.speed * m, data.accel * a * delta)
	var x_ini := global_position.x
	var vx_antes := velocity.x
	if is_on_floor() and not _trepando and absf(velocity.x) > 2.0:
		_try_step_up()
	move_and_slide()
	_limitar_a_camara()
	if _trepando:
		pass
	elif is_on_wall() and is_on_floor() and absf(velocity.x) > 2.0:
		# Chocar con el borde anuló la velocidad: al subir el escalón se conserva el impulso y se
		# termina el avance de este frame (rampas de peldaños muy juntos: varios escalones por frame).
		for _i in 3:
			_try_step_up()
			if not _step_up_hecho:
				break
			if absf(vx_antes) > absf(velocity.x):
				velocity.x = vx_antes
			var resto := vx_antes * delta - (global_position.x - x_ini)
			if absf(resto) < 0.5 or signf(resto) != signf(vx_antes):
				break
			move_and_collide(Vector2(resto, 0.0))
	if _step_up_hecho and not _trepando and velocity.y >= 0.0:
		apply_floor_snap()   # la holgura de la subida no se acumula: el cuerpo vuelve a apoyarse en el escalón
	_suavizar_desnivel(delta)
	if is_on_floor() and velocity.y > 0:
		velocity.y = 0
	_sprint_zoom(data)

	if is_on_floor():
		_salto_aereo_limitado = false
		data.on_floor(self)
		_coyote_time = data.coyote_time
		if not _was_on_floor:
			data.on_landing(self, _fall_impact)
			_squash_landing(data, _fall_impact)
			_sonido_aterrizaje(_fall_impact)
			_emitir_polvo(0.5)
			if _fall_impact > 350.0:
				aterrizaje_fuerte.emit(global_position, _fall_impact)
				_juice_oso_suelo(_fall_impact)
				var amb := get_node_or_null("/root/Ambiente")
				if amb != null:
					amb.empujar(global_position, clampf(_fall_impact / 1000.0, 0.15, 0.6))
			if _fall_impact > 600.0:
				var cam := get_viewport().get_camera_2d()
				if cam != null and cam.has_method("shake"):
					var fuerza := clampf((_fall_impact - 600.0) / 400.0, 0.0, 1.0) * 3.0 + 2.0
					cam.shake(fuerza, 0.12, Vector2(0, 1))
		_fall_impact = 0.0
		_was_on_floor = true
	else:
		if _was_on_floor:
			_fall_impact = 0.0
		else:
			_fall_impact = velocity.y
		_was_on_floor = false
		_coyote_time = maxf(_coyote_time - delta, 0.0)
		if _coyote_time <= 0.0 and not _trepando:
			data.perder_salto_suelo()
	if is_on_floor() and _attack_air_buffer_type != "" and _attack_air_buffer > 0.0 and not _attacking:
		var buffered := _attack_air_buffer_type
		_attack_air_buffer_type = ""
		_attack_air_buffer = 0.0
		_procesar_ataque(buffered, data, false)
	if sombra != null:
		if is_on_floor():
			sombra.visible = true
			if current_form == Form.MURCIELAGO:
				sombra.position = Vector2(0, 142)
				sombra.scale = Vector2(1.25, 1.1)
				sombra.modulate.a = 0.16
			else:
				sombra.position = Vector2(0, 85)
				sombra.scale = Vector2(1, 1)
				sombra.modulate.a = 0.22
		else:
			var space_state := get_world_2d().direct_space_state
			var params := PhysicsRayQueryParameters2D.create(global_position, global_position + Vector2(0, 600))
			params.collision_mask = 1
			var hit := space_state.intersect_ray(params)
			if hit.is_empty():
				sombra.visible = false
			else:
				var dist: float = hit.position.y - global_position.y
				var t := clampf(1.0 - dist / 500.0, 0.25, 1.0)
				sombra.visible = true
				sombra.global_position = hit.position + Vector2(0, -1)
				sombra.scale = Vector2(t, t)
				sombra.modulate.a = t * 0.22

	if _invuln_timer > 0.0:
		_invuln_timer -= delta
		if not _invuln_sin_parpadeo:
			visual.visible = fmod(_invuln_timer, 0.16) < 0.08
		if _invuln_timer <= 0.0:
			visual.visible = true
			_invuln_timer = 0.0
			_invuln_sin_parpadeo = false

	if _jump_buffer > 0.0:
		_jump_buffer -= delta
		if is_on_floor() or _coyote_time > 0.0 or data.can_jump():
			data.try_jump(self)
			_jump_buffer = 0.0


	if not dialogo_bloquea:
		_handle_attack(delta)
		_handle_seleccion_forma()
		_handle_formas_cruceta()
		_handle_forma_ciclo()
		_handle_transform()
	_check_attack_hits()
	_handle_racha(delta)
	_handle_energia(delta)
	if global_position.y > limite_caida:
		if god_mode and _spawn_position != Vector2.ZERO:
			global_position = _spawn_position   # en god_mode no se muere: vuelve al último punto seguro
			velocity = Vector2.ZERO
		else:
			health = 0
	_handle_death()
	_update_animacion()
	_actualizar_resorte(delta)


func _dialogo_bloquea_input() -> bool:
	if cinematica_activa:
		return true
	if _derrota_activa:
		return true   # muerto: sin control ni daño hasta reaparecer (evita golpes extra y acciones durante la caída)
	var dialogo := get_node_or_null("/root/Dialogo")
	return dialogo != null and dialogo.esta_activo()


func _handle_racha(delta: float) -> void:
	if _parry_t > 0.0:
		_parry_t = maxf(_parry_t - delta, 0.0)
	if _tag_t > 0.0:
		_tag_t = maxf(_tag_t - delta, 0.0)
	if _contra_t > 0.0:
		_contra_t = maxf(_contra_t - delta, 0.0)
	if _flap_cd > 0.0:
		_flap_cd = maxf(_flap_cd - delta, 0.0)
	if _racha_timer <= 0.0:
		return
	_racha_timer -= delta
	if _racha_timer <= 0.0:
		_racha = 0
		racha_changed.emit(_racha)


func _registrar_golpe_racha() -> void:
	_racha += 1
	_racha_timer = COMBO_WINDOW
	racha_changed.emit(_racha)


func _handle_attack(delta: float) -> void:
	var data: Forma = forms[current_form]
	var airborne := not is_on_floor()

	if _combo_timer > 0.0:
		_combo_timer -= delta
		if _combo_timer <= 0.0:
			_light_step = 0
			_heavy_step = 0
			_seq.clear()

	if _attacking and _attack_timer > 0.0:
		_attack_timer -= delta
		if _early_exit_umbral > 0.0 and _attack_timer <= _early_exit_umbral:
			var es_finisher: bool = _current_attack_type == "combo" \
				or _current_attack_type == "special" \
				or (_current_attack_type == "light" and _light_step >= forms[current_form].light_combo_steps) \
				or (_current_attack_type == "heavy" and _heavy_step >= forms[current_form].heavy_combo_steps)
			if not es_finisher and (_buffered_attack != "" or _attack_air_buffer_type != ""):
				# Chain casi inmediato (DMC5): en pasos intermedios el próximo golpe sale al instante.
				_attack_timer = minf(_attack_timer, 0.03)
			elif not _early_liberado:
				_early_liberado = true
		_buffer_durante_recuperacion()
		if _attack_timer <= 0.0:
			end_attack()
			_lanzar_buffered(data, airborne)
		return

	if Input.is_action_just_pressed("attack"):
		_procesar_ataque("light", data, airborne)
		if airborne:
			_attack_air_buffer_type = "light"
			_attack_air_buffer = ATTACK_AIR_BUFFER_TIME
	if Input.is_action_just_pressed("heavy"):
		_procesar_ataque("heavy", data, airborne)
		if airborne:
			_attack_air_buffer_type = "heavy"
			_attack_air_buffer = ATTACK_AIR_BUFFER_TIME
	if Input.is_action_just_pressed("special"):
		_procesar_ataque("special", data, airborne)
		if airborne:
			_attack_air_buffer_type = "special"
			_attack_air_buffer = ATTACK_AIR_BUFFER_TIME


func _buffer_durante_recuperacion() -> void:
	if _buffered_attack != "":
		return
	if Input.is_action_just_pressed("attack"):
		_buffered_attack = "light"
	elif Input.is_action_just_pressed("heavy"):
		_buffered_attack = "heavy"
	elif Input.is_action_just_pressed("special"):
		_buffered_attack = "special"


func _lanzar_buffered(data: Forma, airborne: bool) -> void:
	if _buffered_attack == "":
		return
	var tipo := _buffered_attack
	_buffered_attack = ""
	_procesar_ataque(tipo, data, airborne)


func _melee_sticky(data: Forma, delta: float) -> void:
	if not _attacking or _hit_applied or data.melee_sticky <= 0.0 or _dano_reciente_t > 0.0:
		return
	var objetivo := _buscar_enemigo_homing(MELEE_STICKY_REACH)
	if objetivo == null:
		return
	var dx := objetivo.global_position.x - global_position.x
	var dir := signf(dx)
	if dir == 0.0:
		return
	var dist := absf(dx)
	if dir != facing:
		if dist > MELEE_STICKY_PIVOT:
			return
		facing = int(dir)
		_aplicar_facing()
	velocity.x = move_toward(velocity.x, dir * data.speed * MELEE_STICKY_SPEED_MULT, data.melee_sticky * delta)


func _procesar_ataque(tipo: String, data: Forma, airborne: bool) -> void:
	match tipo:
		"light":
			_current_attack_type = "light"
			if airborne:
				_heavy_step = 0
				_light_step = 0
				data.perform_jump_attack(self, false)
				_play_attack_fx("light", 1)
				_punch_sprite(0.15)
				attack_performed.emit("light", _light_step)
				if current_form == Form.HUMAN:
					_iniciar_anim_ataque("attack1")   # el golpe aéreo también se anima (antes seguía con las piernas de correr)
			else:
				_heavy_step = 0
				var combo := _detectar_combo("light")
				if not combo.is_empty():
					_ejecutar_finisher(data, combo)
				else:
					var max_step: int = mini(data.light_combo_steps, _progresion().pasos_luz())
					_light_step = _light_step + 1 if _light_step < max_step else 1   # tras el último golpe la cadena vuelve al 1.º (no se queda en "tercer golpe")
					_combo_timer = COMBO_WINDOW
					data.perform_light(self, _light_step)
					_play_attack_fx("light", _light_step)
					_punch_sprite(0.15)
					attack_performed.emit("light", _light_step)
					if current_form == Form.HUMAN:
						_iniciar_anim_ataque("attack1")
		"heavy":
			_current_attack_type = "heavy"
			if airborne:
				_light_step = 0
				_heavy_step = 0
				_cancelar_anim_ataque()
				data.perform_jump_attack(self, true)
				_play_attack_fx("heavy", 1)
				_punch_sprite(0.3)
				attack_performed.emit("heavy", _heavy_step)
				if current_form == Form.HUMAN:
					_iniciar_anim_ataque("attack2")
			else:
				_light_step = 0
				_cancelar_anim_ataque()
				var combo := _detectar_combo("heavy")
				if not combo.is_empty():
					_ejecutar_finisher(data, combo)
				else:
					_heavy_step = _heavy_step + 1 if _heavy_step < data.heavy_combo_steps else 1
					_combo_timer = COMBO_WINDOW
					data.perform_heavy(self, _heavy_step)
					_play_attack_fx("heavy", _heavy_step)
					_punch_sprite(0.3)
					attack_performed.emit("heavy", _heavy_step)
					if current_form == Form.HUMAN:
						_iniciar_anim_ataque("attack2")
		"special":
			if _try_interact():
				return
			if _special_cooldown > 0.0 and forms[current_form].special_cooldown > 0.0:
				return
			var costo: float = forms[current_form].special_cost
			if costo > 0.0:
				if energia < costo:
					_denegar_transformacion()
					return
				energia -= costo
				energia_changed.emit(energia)
			_light_step = 0
			_heavy_step = 0
			_cancelar_anim_ataque()
			var combo := _detectar_combo("special")
			if not combo.is_empty():
				_ejecutar_finisher(data, combo)
			else:
				_current_attack_type = "special"
				_combo_timer = 0.0
				data.perform_special(self)
				_special_cooldown = data.special_cooldown_combate if _en_combate() else data.special_cooldown
				_play_attack_fx("special", 1)
				_punch_sprite(0.4)
				attack_performed.emit("special", 1)
				if current_form == Form.HUMAN:
					_iniciar_anim_ataque("attack_full")


func _detectar_combo(tipo: String) -> Dictionary:
	_seq.append(tipo)
	if _seq.size() > 3:
		_seq.pop_front()
	var data: Forma = forms[current_form]
	var desbloqueados: int = _progresion().combos_desbloqueados_forma(current_form)
	var total := mini(desbloqueados, data.combos.size())
	for i in range(total - 1, -1, -1):
		var c: Dictionary = data.combos[i]
		var seq: Array = c.get("secuencia", [])
		if seq.size() > _seq.size():
			continue
		var coincide := true
		for j in range(seq.size()):
			if _seq[_seq.size() - seq.size() + j] != seq[j]:
				coincide = false
				break
		if coincide:
			_seq.clear()
			return c
	return {}


func _ejecutar_finisher(data: Forma, combo: Dictionary) -> void:
	_current_attack_type = "combo"
	_light_step = 0
	_heavy_step = 0
	_cancelar_anim_ataque()
	_combo_timer = 0.0
	data.perform_combo(self, combo)
	_play_attack_fx("combo", 1)
	_punch_sprite(0.45)
	attack_performed.emit("combo", combo.get("nombre", "Combo"))
	if current_form == Form.HUMAN:
		_iniciar_anim_ataque("attack_full")
	if DisplayServer.get_name() != "headless":
		var p: CPUParticles2D = (preload("res://scenes/burst.tscn") as PackedScene).instantiate()
		p.global_position = global_position + Vector2(facing * 30, -20)
		p.self_modulate = Color(1, 0.85, 0.3, 0.9)
		p.amount = 8
		get_tree().root.add_child(p)
		p.restart()
		p.emitting = true


func enable_melee(size: Vector2, range: float, damage: int = -1, knockback: float = 0.0) -> void:
	_attacking = true
	_whiff_applied = false
	_whiff_grace = 0.0
	var data: Forma = forms[current_form]
	var paso := 1
	if _current_attack_type == "light":
		paso = maxi(_light_step, 1)
	elif _current_attack_type == "heavy":
		paso = maxi(_heavy_step, 1)
	_hit_delay = data.hit_delay_para(_current_attack_type, paso)
	if _golpe_rapido_t > 0.0:
		_hit_delay = 0.0   # primer ataque tras transformarte: conecta de inmediato
		_golpe_rapido_t = 0.0
	_silencio_previo_golpe()
	var rec := _recovery_for(_current_attack_type) * data.mult_recuperacion_para(_current_attack_type, paso)
	_attack_timer = rec
	# El lobo usa la misma cola que el humano: _iniciar_anim_ataque estira la
	# anim con speed_scale para que los 4 frames de lobo_attack duren
	# exactamente la recuperación -> se ve completa (no se corta al 1er frame).
	if current_form == Form.LOBO and visual.sprite_frames.has_animation("lobo_attack"):
		_iniciar_anim_ataque("lobo_attack", data.anim_frame_inicio(_current_attack_type, paso))
	_early_exit_umbral = rec * data.recovery_early_fraccion
	_early_liberado = false
	# ImÃ¡n suave al enemigo mÃ¡s cercano si estÃ¡s un poco lejos
	var objetivo := _buscar_enemigo_homing(200.0)
	if objetivo != null:
		var dir_enemigo := signf(objetivo.global_position.x - global_position.x)
		var dist := global_position.distance_to(objetivo.global_position)
		var alcance_real := range + size.x * 0.5
		var faltante := dist - alcance_real
		if dir_enemigo != 0 and absf(faltante) < 80.0 and faltante > 8.0:
			if dir_enemigo != facing:
				facing = int(dir_enemigo)
				_aplicar_facing()
		elif dir_enemigo != 0 and faltante <= 8.0 and dir_enemigo != facing:
			facing = int(dir_enemigo)
			_aplicar_facing()
	# Avance del cuerpo al golpear (solo en el piso) y pose extra del sprite.
	var avance := data.lunge_para(_current_attack_type, paso) if is_on_floor() else 0.0
	# Magnetismo: si hay un enemigo al frente un poco fuera de alcance, el avance se estira
	# (hasta `magnetismo_mult`×) para llegar a contacto en vez de pegarle al aire.
	var objetivo_mag := _buscar_enemigo_homing(magnetismo_alcance) if (avance > 0.0 and magnetismo_mult > 1.0) else null
	if objetivo_mag != null:
		var dx_m := objetivo_mag.global_position.x - global_position.x
		if signf(dx_m) == float(facing):
			var falta := absf(dx_m) - (range + size.x * 0.5) - _mitad_ancho(objetivo_mag)
			if falta > avance:
				avance = maxf(avance, minf(falta * 0.9, avance * magnetismo_mult))
	if avance > 0.0:
		_lunge_t = LUNGE_DUR
		_lunge_vel = facing * avance / (LUNGE_DUR * 1.2)
	else:
		_lunge_t = 0.0
	data.pose_ataque(self, _current_attack_type, paso)
	_hit_applied = false
	_current_attack_damage = forms[current_form].attack_damage if damage < 0 else damage
	_current_attack_knockback = knockback
	var coll: RectangleShape2D = collision_shape.shape
	var shape: RectangleShape2D = attack_hitbox.shape
	var total_range := range + size.x * 0.5
	var h := maxf(coll.size.y, size.y)
	shape.size = Vector2(total_range, h)
	attack_hitbox.shape = shape
	attack_hitbox.disabled = false
	attack_area.position = Vector2(facing * total_range * 0.5, collision_shape.position.y)
	attack_area.monitoring = true


func _recovery_for(attack_type: String) -> float:
	match attack_type:
		"light":
			return RECOVERY_LIGHT
		"heavy":
			return RECOVERY_HEAVY
		"special":
			return RECOVERY_SPECIAL
		"combo":
			return RECOVERY_COMBO
		_:
			return RECOVERY_LIGHT


## Cancela la recuperación de un golpe con salto/parry/transformación (control instantáneo).
## Sin `forzar` solo actúa en la fase de recuperación (ya conectó o pasó el umbral de salida).
## Mitad del ancho del collider del cuerpo (0 si no tiene).
func _mitad_ancho(body: Node2D) -> float:
	for c in body.get_children():
		if c is CollisionShape2D and (c as CollisionShape2D).shape != null:
			return (c as CollisionShape2D).shape.get_rect().size.x * 0.5 * absf(body.global_scale.x)
	return 0.0


func _cancelar_recuperacion(forzar: bool = false) -> bool:
	if not _attacking:
		return false
	if not forzar and not (_hit_applied or _early_liberado):
		return false
	_attack_timer = 0.0
	_buffered_attack = ""
	_lunge_t = 0.0
	_cancelar_anim_ataque()
	end_attack()
	return true


func end_attack() -> void:
	_attacking = false
	_early_liberado = false
	_hit_applied = false
	attack_area.monitoring = false
	attack_hitbox.disabled = true


func _make_rect_polygon(size: Vector2) -> PackedVector2Array:
	var w := size.x * 0.5
	var h := size.y * 0.5
	return PackedVector2Array([Vector2(-w, -h), Vector2(w, -h), Vector2(w, h), Vector2(-w, h)])


func _check_attack_hits() -> void:
	if not _attacking or _hit_applied:
		return
	if _hit_delay > 0.0:
		# Ventana de impacto: el daño aún no puede conectar (pleno swing).
		_hit_delay -= get_physics_process_delta_time()
		return
	var bodies := attack_area.get_overlapping_bodies()
	var objetivos: Array[Node2D] = []
	for b in bodies:
		if b == self:
			continue
		if b.has_method("registrar_golpe") or b.has_method("take_damage"):
			objetivos.append(b as Node2D)
			if objetivos.size() >= 2:
				break
	if objetivos.is_empty():
		if not _whiff_applied and (_current_attack_type == "light" or _current_attack_type == "heavy"):
			_whiff_grace += get_physics_process_delta_time()
			if _whiff_grace >= WHIFF_GRACE_TIME:
				_whiff_applied = true
				_attack_timer *= whiff_recovery_mult
		return
	var mult_tercer := 1.0
	if _current_attack_type == "light" and _light_step == forms[current_form].light_combo_steps:
		mult_tercer = 1.5
	elif _current_attack_type == "heavy" and _heavy_step == forms[current_form].heavy_combo_steps:
		mult_tercer = 1.5
	var critico := mult_tercer > 1.0 or _current_attack_type == "combo"
	var contra := _contra_t > 0.0
	if contra:
		_contra_t = 0.0
		critico = true
	var bono_tag := _tag_t > 0.0
	if bono_tag:
		_tag_t = 0.0
		critico = true
	for idx in range(mini(objetivos.size(), 2)):
		var body: Node2D = objetivos[idx]
		var dmg := _current_attack_damage
		if bono_tag:
			dmg = int(dmg * tag_bonus_mult)
		if contra and idx == 0:
			dmg = maxi(int(dmg * contragolpe_mult), contragolpe_dano_min)
		var kb := _current_attack_knockback * mult_tercer
		if idx == 1:
			dmg = int(dmg * 0.6)
			kb *= 0.6
		if body.has_method("registrar_golpe"):
			body.registrar_golpe(dmg)
			_aplicar_knockback(body)
		elif body.has_method("take_damage"):
			var vivia: bool = not ("health" in body) or body.health > 0
			body.take_damage(dmg, kb, facing, critico)
			if vivia and "health" in body and body.health <= 0:
				_freeze_slowmo(0.3 if _current_attack_type == "combo" else 0.22, 0.4)
		_spark_golpe(body, idx)
	var sonido_golpe: AudioStream = sonido_golpe_liviano if _current_attack_type == "light" else sonido_golpe_pesado
	var audio_mgr := get_node_or_null("/root/AudioManager")
	_hit_applied = true
	_registrar_golpe_racha()
	var dur_hitstop := _hitstop_por_tipo()
	if dur_hitstop > 0.0 and not objetivos.is_empty():
		# Hitstop por peso (Hollow Knight): los enemigos pesados congelan más.
		var peso := _factor_peso(objetivos[0])
		if objetivos.size() >= 2:
			peso *= 0.8  # multigolpe (SOR2): pegar a varios no multiplica la lentitud
		dur_hitstop *= peso
	if mult_tercer > 1.0:
		dur_hitstop *= hitstop_tercer_mult
	var racha_mult := _racha_feedback_mult()
	dur_hitstop *= racha_mult
	dur_hitstop = _limitar_hitstop(dur_hitstop)
	_freeze_hitstop(dur_hitstop)
	_zoom_punch_por_tipo(mult_tercer)
	_shake_por_tipo(mult_tercer)
	if audio_mgr != null:
		var vol := volumen_golpe_db
		if _current_attack_type == "heavy":
			vol += volumen_golpe_pesado_db
		elif _current_attack_type == "special":
			vol += volumen_special_db
		audio_mgr.play_sfx_sincronizado(sonido_golpe, vol, dur_hitstop > 0.0, 1.0 + minf(float(_racha), 8.0) * tono_combo)


## Golpe pesado: el ambiente calla durante la preparación y vuelve con el impacto (Hollow Knight).
func _silencio_previo_golpe() -> void:
	if not silencio_golpe_fuerte or DisplayServer.get_name() == "headless":
		return
	if not (_current_attack_type in ["heavy", "special", "combo"]) or _hit_delay < 0.08:
		return
	var amb := get_tree().get_first_node_in_group("ambiente_sonoro")
	if amb == null:
		return
	amb.pedir_silencio(self, 0.85)
	get_tree().create_timer(_hit_delay + 0.04, true, false, true).timeout.connect(func() -> void:
		var a := get_tree().get_first_node_in_group("ambiente_sonoro") if is_inside_tree() else null
		if a != null:
			a.pedir_silencio(self, 0.0))


## Tope + amortiguación en ráfaga: pegar seguido no acumula pausas que se sienten "trabadas".
func _limitar_hitstop(dur: float) -> float:
	var ahora := Time.get_ticks_msec() * 0.001
	if ahora - _ultimo_hitstop_s < hitstop_rafaga_ventana:
		dur *= hitstop_rafaga_mult
	_ultimo_hitstop_s = ahora
	return minf(dur, hitstop_max)


func _hitstop_por_tipo() -> float:
	var dur := 0.0
	match _current_attack_type:
		"light":
			dur = HITSTOP_LIGHT
		"heavy":
			dur = HITSTOP_HEAVY
		"special":
			dur = HITSTOP_SPECIAL
		"combo":
			dur = HITSTOP_COMBO
		_:
			return 0.0
	if current_form == Form.OSO:
		dur *= 1.25
	elif current_form == Form.LOBO:
		dur *= 0.85
	return dur


## Factor de hitstop según el peso del enemigo golpeado (null-safe: 1.0 sin datos).
func _factor_peso(body: Node2D) -> float:
	if body == null or not ("enemy_data" in body):
		return 1.0
	var ed: Resource = body.get("enemy_data")
	if ed == null or ed.get("max_health") == null:
		return 1.0
	return clampf(float(ed.max_health) / 75.0, 0.85, 1.4)


func _freeze_hitstop(duracion: float = -1.0) -> void:
	if duracion < 0.0:
		duracion = hitstop_dano
	if duracion <= 0.0:
		return
	var hs = get_node_or_null("/root/Hitstop")
	if hs != null and hs.has_method("freeze"):
		hs.freeze(duracion)


func _freeze_slowmo(duracion: float, escala: float) -> void:
	var hs = get_node_or_null("/root/Hitstop")
	if hs != null and hs.has_method("slowmo"):
		hs.slowmo(duracion, escala)


## Escala el feedback según la racha de combos: retorna un multiplicador de hitstop
## (1.0 sin racha) y la escala extra del spark se obtiene con `racha_spark_escala()`.
func _racha_feedback_mult() -> float:
	if _racha >= 5 and racha_hitstop_5 > 1.0:
		return racha_hitstop_5
	if _racha >= 3 and racha_hitstop_3 > 1.0:
		return racha_hitstop_3
	return 1.0


func racha_spark_escala() -> float:
	if _racha >= 5:
		return racha_spark_5
	if _racha >= 3:
		return racha_spark_3
	return 1.0


func _zoom_punch_por_tipo(mult_tercer: float = 1.0) -> void:
	var cam := get_viewport().get_camera_2d()
	if cam == null or not cam.has_method("punch"):
		return
	var escala := 1.02
	if current_form >= 0 and current_form < forms.size():
		escala = forms[current_form].hit_zoom
	match _current_attack_type:
		"heavy":
			escala *= zoom_heavy_mult
		"special":
			escala *= zoom_special_mult
		"combo":
			escala *= zoom_combo_mult
	if mult_tercer > 1.0 and _current_attack_type != "combo":
		escala *= zoom_combo_mult
	if _racha >= 5 and racha_zoom_5 > 1.0:
		escala *= racha_zoom_5
	elif _racha >= 3 and racha_zoom_3 > 1.0:
		escala *= racha_zoom_3
	cam.punch(escala)


func _shake_por_tipo(mult_tercer: float = 1.0) -> void:
	var cam := get_viewport().get_camera_2d()
	if cam == null or not cam.has_method("shake"):
		return
	var fuerza := 3.0
	if current_form >= 0 and current_form < forms.size():
		var forma: Forma = forms[current_form]
		match _current_attack_type:
			"light":
				fuerza = forma.shake_golpe_ligero + 0.5
			"heavy":
				fuerza = forma.shake_golpe_pesado + 0.5
			"combo":
				fuerza = forma.shake_golpe_combo + 0.5
			"special":
				fuerza = shake_special
	if mult_tercer > 1.0:
		fuerza *= shake_tercer_mult
	cam.shake(fuerza, 0.15, Vector2(facing, 0))


func _aplicar_knockback(body: Node2D) -> void:
	if _current_attack_knockback <= 0.0 or not body is RigidBody2D:
		return
	body.apply_impulse(Vector2(facing * _current_attack_knockback, -120.0))


func _spark_golpe(body: Node2D, idx: int) -> void:
	if DisplayServer.get_name() == "headless":
		return
	var p: CPUParticles2D = (preload("res://scenes/burst.tscn") as PackedScene).instantiate()
	p.global_position = _punto_impacto(body) + Vector2(0.0, randf_range(-10.0, 10.0))
	var tinte := Color(1, 0.9, 0.4, 0.95)
	if current_form >= 0 and current_form < forms.size():
		tinte = forms[current_form].color
	p.self_modulate = tinte
	p.amount = int(6 * racha_spark_escala())
	p.scale = Vector2.ONE * racha_spark_escala()
	get_tree().root.add_child(p)
	p.restart()
	p.emitting = true
	# Chorro direccional en el sentido del golpe (más fuerte con golpes pesados).
	var fuerte := 1.35 if _current_attack_type in ["heavy", "special", "combo"] else 1.0
	Burst.chispas(self, p.global_position, facing, tinte.lightened(0.45), int(5 * racha_spark_escala()), fuerte)
	_juice_golpe(p.global_position, tinte, idx)


## Tajo rojo fino en el punto de impacto.
func _juice_golpe(pos: Vector2, tinte: Color, idx: int) -> void:
	var pesado := _current_attack_type in ["heavy", "special", "combo"]
	var remate := _current_attack_type in ["special", "combo"]
	var racha := racha_spark_escala()
	if tajo_luz:
		_tajo_alterno = not _tajo_alterno
		var largo := (560.0 if remate else (430.0 if pesado else 320.0)) * tajo_escala * (0.75 + racha * 0.25)
		var grosor := (15.0 if remate else (12.0 if pesado else 9.0)) * tajo_escala
		var base: Color = forms[current_form].color if current_form < forms.size() else Color.WHITE
		TajoLuz.lanzar(JuiceCapa.obtener(get_tree()), pos, facing, _tajo_alterno, largo, grosor, Color(base.lerp(Color.WHITE, 0.45), tajo_alpha))


## Punto donde el golpe "toca" al objetivo: el borde del cuerpo que mira al jugador
## (hundido spark_hundir_px), a la altura del arma (spark_altura dentro del hitbox),
## acotado a la zona donde se cruzan hitbox y collider. Sin collider → origen del objetivo.
func _punto_impacto(body: Node2D) -> Vector2:
	var cuerpo := Rect2()
	for c in body.get_children():
		if c is CollisionShape2D and (c as CollisionShape2D).shape != null and not (c as CollisionShape2D).disabled:
			cuerpo = (c as CollisionShape2D).global_transform * (c as CollisionShape2D).shape.get_rect()
			break
	if cuerpo.size == Vector2.ZERO:
		return body.global_position
	var golpe: Rect2 = attack_hitbox.global_transform * attack_hitbox.shape.get_rect()
	var cruce := golpe.intersection(cuerpo)
	if cruce.size == Vector2.ZERO:
		cruce = cuerpo
	var borde := cuerpo.position.x if facing > 0 else cuerpo.end.x
	var x := clampf(borde + facing * spark_hundir_px, cruce.position.x, cruce.end.x)
	var y := clampf(golpe.position.y + golpe.size.y * spark_altura, cruce.position.y, cruce.end.y)
	return Vector2(x, y)


## Estela del golpe: medialuna vectorial del color de la forma que barre el alcance
## real del hitbox. Pasos pares del combo barren al revés (de abajo hacia arriba).
func _play_attack_fx(tipo: String, step: int) -> void:
	if attack_hitbox.disabled or attack_hitbox.shape == null:
		return
	_sfx(sonido_swing_pesado if tipo in ["heavy", "combo"] else sonido_swing, volumen_swing_db, 0.1)
	if not swing_visible or DisplayServer.get_name() == "headless":
		return
	# Alcance real en pantalla (el nodo del hitbox tiene escala propia).
	var rect_golpe: Rect2 = attack_hitbox.global_transform * attack_hitbox.shape.get_rect()
	var alcance := absf((rect_golpe.end.x if facing > 0 else rect_golpe.position.x) - global_position.x)
	# Centro detrás del hombro y radio mayor al alcance: la medialuna queda más
	# plana y por delante del cuerpo, barriendo la zona del golpe.
	var atras := alcance * 0.45
	var radio := clampf(alcance * swing_alcance + atras, 150.0, 480.0)
	var grosor: float = swing_grosor * {"light": 1.0, "heavy": 1.3, "special": 1.5, "combo": 1.6}.get(tipo, 1.0)
	var dur: float = swing_duracion * {"light": 1.0, "heavy": 1.2, "special": 1.3, "combo": 1.4}.get(tipo, 1.0)
	var desde := deg_to_rad(-42.0)
	var hasta := deg_to_rad(30.0)
	if step % 2 == 0:
		var tmp := desde
		desde = hasta
		hasta = tmp
	var puntos := PackedVector2Array()
	var colores := PackedColorArray()
	const N := 14
	var color: Color = forms[current_form].color.lerp(Color.WHITE, 0.35) if current_form < forms.size() else Color.WHITE
	# Estela: la cabeza (t=1) es nítida y la cola (t=0) se desvanece; el grosor es máximo cerca de la cabeza.
	for i in N + 1:
		var a := lerpf(desde, hasta, float(i) / N)
		puntos.append(Vector2(cos(a) * facing, sin(a)) * radio)
		colores.append(Color(color, swing_alpha * pow(float(i) / N, 1.4)))
	for i in range(N, -1, -1):
		var t := float(i) / N
		var r := radio * (1.0 - grosor * sin(PI * pow(t, 1.9)))
		var a := lerpf(desde, hasta, t)
		puntos.append(Vector2(cos(a) * facing, sin(a)) * r)
		colores.append(Color(color, swing_alpha * pow(t, 1.4)))
	var arco := Polygon2D.new()
	arco.polygon = puntos
	arco.vertex_colors = colores
	# Sin sombrear: la noche (CanvasModulate) no lo apaga.
	var mat := CanvasItemMaterial.new()
	mat.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
	arco.material = mat
	arco.z_index = 2
	arco.position = Vector2(-facing * atras, rect_golpe.position.y + rect_golpe.size.y * spark_altura - global_position.y)
	add_child(arco)
	arco.scale = Vector2.ONE * 0.85
	var giro := 0.22 * facing * (1.0 if step % 2 == 1 else -1.0)
	var tw := arco.create_tween().set_parallel(true)
	tw.tween_property(arco, "scale", Vector2.ONE * 1.08, dur).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(arco, "rotation", giro, dur)
	tw.tween_property(arco, "modulate:a", 0.0, dur).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.chain().tween_callback(arco.queue_free)


## Cuerpo elástico: squash/stretch/punch son IMPULSOS sobre un resorte de escala (se suman y
## rebotan sin pisarse). `duration` se conserva por compatibilidad con los llamadores.
func squash_y(amount: float, _duration: float = 0.0) -> void:
	_esc_off.y = clampf(_esc_off.y - amount, -0.6, 0.6)
	visual.position.y = _visual_base_y()


## Avanza el resorte y aplica la escala final (con facing, reposo de pose y respiración).
func _actualizar_resorte(delta: float) -> void:
	var d := minf(delta, 1.0 / 30.0)
	var acc := -resorte_rigidez * (_esc_off - _esc_reposo) - resorte_amort * _esc_vel
	_esc_vel += acc * d
	_esc_off += _esc_vel * d
	_esc_off = _esc_off.clamp(Vector2(-0.6, -0.6), Vector2(0.6, 0.6))
	var resp := 0.0
	if respiracion_amp > 0.0 and is_on_floor() and absf(velocity.x) < 10.0 and not _attacking:
		var f := _factor_cansancio()
		_t_resp += d * respiracion_vel * lerpf(1.0, 1.7, f)
		resp = sin(_t_resp) * respiracion_amp * lerpf(1.0, 2.6, f)
		if _amb == null:
			_amb = get_node_or_null("/root/Ambiente")
		if _amb != null:
			resp += float(_amb.latido) * respiracion_latido   # el cuerpo late con el corazón (mismo pulso que la viñeta)
	var base := Vector2(absf(_base_sprite_scale.x) * float(facing), _base_sprite_scale.y)
	visual.scale = Vector2(base.x * (1.0 + _esc_off.x), base.y * (1.0 + _esc_off.y + resp))


## escala: 0..1 (paso chico → aterrizaje fuerte). direccion != ZERO: polvo lateral
## rápido (derrape del Lobo) solo para esta emisión.
func _emitir_polvo(escala: float, direccion: Vector2 = Vector2.ZERO) -> void:
	if DisplayServer.get_name() == "headless" or polvo == null:
		return
	var lateral := direccion != Vector2.ZERO
	polvo.direction = direccion if lateral else Vector2.UP
	polvo.initial_velocity_min = 90.0 if lateral else 30.0
	polvo.initial_velocity_max = 160.0 if lateral else 80.0
	polvo.scale_amount_min = lerpf(0.8, 2.0, escala)
	polvo.scale_amount_max = lerpf(1.4, 3.2, escala)
	# Sale de todo el ancho de apoyo de la forma (Oso/Lobo pisan más ancho que el Humano).
	polvo.emission_rect_extents.x = collision_shape.shape.size.x * 0.25
	# Los golpes de polvo fuertes (salto/aterrizaje) reinician aunque haya pasos en vuelo.
	if escala >= 0.6:
		polvo.restart()
	polvo.emitting = true


func _emitir_burst_hojas() -> void:
	if DisplayServer.get_name() == "headless":
		return
	var p: CPUParticles2D = (preload("res://scenes/burst.tscn") as PackedScene).instantiate()
	p.global_position = global_position + Vector2(randf_range(-10, 10), -10)
	var amb := get_node_or_null("/root/Ambiente")
	var hojas: bool = amb == null or bool(amb.hay_hojas)
	p.self_modulate = Color(0.32, 0.6, 0.26, 0.9) if hojas else Color(0.6, 0.62, 0.7, 0.85)   # en la cueva: esquirlas de roca, no hojas
	p.amount = 6
	p.lifetime = 0.35
	get_tree().current_scene.add_child(p)
	p.restart()
	p.emitting = true


func _squash_landing(data: Forma, impacto: float) -> void:
	var amt := data.landing_squash
	if amt <= 0.0 or impacto <= 0.0:
		return
	if current_form == Form.LOBO:
		# Squash propio del Lobo (item 18): el aterrizaje del Lobo se siente
		# mír reforzado que el genérico — editable desde el inspector del player.
		amt *= lobo_landing_squash_extra
	var factor := clampf(impacto / 600.0, 0.3, 1.0)
	squash_y(amt * factor, 0.18)


func _sprint_zoom(data: Forma) -> void:
	var cam := get_viewport().get_camera_2d()
	if cam == null:
		return
	var vel := absf(velocity.x)
	var objetivo: Vector2 = data.camera_zoom
	if data.sprint_zoom_out > 0.0 and vel >= data.sprint_min_speed:
		objetivo = data.camera_zoom * (1.0 - data.sprint_zoom_out)
	cam.fijar_zoom(objetivo)


func stretch_y(amount: float, _duration: float = 0.0) -> void:
	_esc_off.y = clampf(_esc_off.y + amount, -0.6, 0.6)
	visual.position.y = _visual_base_y()


## 0 = sano y con energía; 1 = vida ≤ 30 % (o energía baja fuera de Humano). Sube la respiración y el temblor.
func _factor_cansancio() -> float:
	var f := clampf(inverse_lerp(0.3, 0.1, float(health) / float(VIDA_MAX)), 0.0, 1.0)
	if current_form != Form.HUMAN:
		f = maxf(f, clampf(inverse_lerp(25.0, 8.0, energia), 0.0, 1.0))
	return f


## Aleteo del Murciélago: impulso corto hacia arriba a cambio de energía.
func _aletear(data: Forma) -> void:
	_flap_cd = flap_cooldown
	energia = maxf(energia - data.flap_costo, 0.0)
	energia_changed.emit(energia)
	velocity.y = -data.flap_impulso
	_emitir_polvo(0.35)
	_picada = false


func apply_zip(impulso: float) -> void:
	velocity.x = facing * absf(impulso)


## Eco espectral: silueta del momento actual que se desvanece (lunge del Lobo, picada, pisotón).
## Copia la pose actual del sprite encima y la funde en `dur` s: el cambio de animación (p. ej. del
## final de un golpe a idle/correr, que arranca en otro frame) deja de verse como un corte seco.
func _disolver_pose(dur: float, alpha: float = 0.85) -> void:
	if dur <= 0.0 or DisplayServer.get_name() == "headless" or visual == null or not is_inside_tree():
		return
	var g := AnimatedSprite2D.new()
	g.sprite_frames = visual.sprite_frames
	g.animation = visual.animation
	g.frame = visual.frame
	g.speed_scale = 0.0
	g.texture_filter = visual.texture_filter
	g.flip_h = visual.flip_h
	g.offset = visual.offset
	g.position = visual.position
	g.scale = visual.scale
	g.rotation = visual.rotation
	g.skew = visual.skew
	g.self_modulate = visual.self_modulate
	g.modulate = Color(1, 1, 1, alpha)
	g.z_index = visual.z_index + 1
	add_child(g)
	var tw := g.create_tween()
	tw.tween_property(g, "modulate:a", 0.0, dur)   # lineal: el cambio se reparte parejo entre los frames
	tw.tween_callback(g.queue_free)


func emitir_eco() -> void:
	if eco_alpha <= 0.0 or DisplayServer.get_name() == "headless" or visual == null:
		return
	var color: Color = forms[current_form].color
	var eco := AnimatedSprite2D.new()
	eco.sprite_frames = visual.sprite_frames
	eco.animation = visual.animation
	eco.frame = visual.frame
	eco.speed_scale = 0.0
	eco.global_position = visual.global_position
	eco.rotation = visual.rotation   # global_rotation con escala X negativa (mirando a la izquierda) daba +180° y el eco salía cabeza abajo
	eco.skew = visual.skew
	eco.scale = visual.scale
	eco.modulate = Color(color.r, color.g, color.b, eco_alpha)
	eco.z_index = -1
	get_tree().current_scene.add_child(eco)
	var tw := eco.create_tween()
	tw.tween_property(eco, "modulate:a", 0.0, 0.26).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_callback(eco.queue_free)


func _mostrar_fantasma_forma(idx: int) -> void:
	if idx < 0 or idx >= forms.size() or DisplayServer.get_name() == "headless":
		return
	var data: Forma = forms[idx]
	var fantasma := AnimatedSprite2D.new()
	fantasma.sprite_frames = visual.sprite_frames
	fantasma.animation = visual.animation
	fantasma.frame = visual.frame
	fantasma.global_position = global_position
	fantasma.scale = visual.scale
	fantasma.modulate = Color(data.color.r, data.color.g, data.color.b, 0.35)
	fantasma.z_index = -1
	get_tree().current_scene.add_child(fantasma)
	var tw := fantasma.create_tween()
	tw.tween_property(fantasma, "modulate:a", 0.0, 0.32)
	tw.parallel().tween_property(fantasma, "scale", fantasma.scale * 1.12, 0.32)
	tw.tween_callback(fantasma.queue_free)


func _punch_sprite(amount: float) -> void:
	_esc_off = (_esc_off + Vector2(amount, amount)).clamp(Vector2(-0.6, -0.6), Vector2(0.6, 0.6))
	visual.position.y = _visual_base_y()


func _handle_energia(delta: float) -> void:
	if _cooldown_transform > 0.0:
		_cooldown_transform = maxf(_cooldown_transform - delta, 0.0)
	if _golpe_rapido_t > 0.0:
		_golpe_rapido_t = maxf(_golpe_rapido_t - delta, 0.0)
	for k in _cooldown_formas.keys():
		_cooldown_formas[k] -= delta
		if _cooldown_formas[k] <= 0.0:
			_cooldown_formas.erase(k)
	if blocking:
		energia = maxf(energia - bloqueo_drenaje * delta, 0.0)
	if energia <= 0.0:
		_bloqueo_sin_energia = true
	elif energia >= bloqueo_energia_min:
		_bloqueo_sin_energia = false
	if current_form == Form.HUMAN:
		if not blocking:   # guardia activa: no regenera (si no, el drenaje se compensaría solo)
			energia = minf(energia + ENERGIA_REGEN * delta, ENERGIA_MAX)
	else:
		var drain := ENERGIA_DRAIN * forms[current_form].drenaje_mult * (0.45 if not _en_combate() else 1.0)
		energia -= drain * delta
		if energia <= 0.0:
			energia = 0.0
			var agotada := current_form
			# Solo si el cambio se concretó (bajo un techo bajo puede no haber lugar: se reintenta sin repetir aviso ni sonido).
			if _transformar(Form.HUMAN, true):
				_cooldown_formas[agotada] = COOLDOWN_AGOTADA
				transformacion_agotada.emit()
				_sfx(sonido_energia_agotada, volumen_estado_db)
	energia_changed.emit(energia)


func _handle_seleccion_forma() -> void:
	# Solo Q (form_next) cicla la preselecciÃ³n del flujo viejo.
	# W/S/â†‘â†“ ya no tocan la selecciÃ³n: causaban transformaciones accidentales.
	if Input.is_action_just_pressed("form_next"):
		_avanzar_seleccion()


func _retroceder_seleccion() -> bool:
	var candidata := forma_seleccionada - 1
	for _i in range(forms.size()):
		candidata = posmod(candidata, forms.size())
		if _progresion().forma_desbloqueada(candidata) and not _forma_en_cooldown(candidata):
			if candidata != forma_seleccionada:
				forma_seleccionada = candidata
				forma_selectada_cambiada.emit(candidata)
				return true
			return false
		candidata -= 1
	return false


func _forma_en_cooldown(idx: int) -> bool:
	return _cooldown_formas.has(idx) and _cooldown_formas[idx] > 0.0

func _avanzar_seleccion() -> bool:
	var candidata := forma_seleccionada + 1
	for _i in range(forms.size()):
		candidata = posmod(candidata, forms.size())
		if _progresion().forma_desbloqueada(candidata) and not _forma_en_cooldown(candidata):
			if candidata != forma_seleccionada:
				forma_seleccionada = candidata
				forma_selectada_cambiada.emit(candidata)
				return true
			return false
		candidata += 1
	return false


func _handle_formas_cruceta() -> void:
	# La cruceta transforma directo: â†‘ MurciÃ©lago, â†’ Lobo, â† Oso, â†“ Humano.
	var objetivo := -1
	if Input.is_action_just_pressed("forma_arriba"):
		objetivo = Form.MURCIELAGO
	elif Input.is_action_just_pressed("forma_derecha"):
		objetivo = Form.LOBO
	elif Input.is_action_just_pressed("forma_izquierda"):
		objetivo = Form.OSO
	elif Input.is_action_just_pressed("forma_abajo"):
		objetivo = Form.HUMAN
	if objetivo < 0:
		return
	if not _progresion().forma_desbloqueada(objetivo) or _forma_en_cooldown(objetivo):
		_denegar_transformacion()
		return
	_transformar(objetivo)


func _handle_forma_ciclo() -> void:
	# RT/E: cicla la preselecciÃ³n hacia adelante; LT: hacia atrÃ¡s.
	# RB/T es quien confirma y transforma en la preseleccionada.
	if Input.is_action_just_pressed("forma_swap"):
		if _avanzar_seleccion():
			_mostrar_fantasma_forma(forma_seleccionada)
	elif Input.is_action_just_pressed("forma_prev"):
		if _retroceder_seleccion():
			_mostrar_fantasma_forma(forma_seleccionada)


func _handle_transform() -> void:
	if _transform_buffer > 0.0:
		_transform_buffer = maxf(_transform_buffer - get_physics_process_delta_time(), 0.0)
	if Input.is_action_just_pressed("transform"):
		_transform_buffer = TRANSFORM_BUFFER_TIME
	if _transform_buffer <= 0.0 or _cooldown_transform > 0.0:
		return
	if current_form != Form.HUMAN and forma_seleccionada == current_form:
		var prev_h: int = current_form
		_transformar(Form.HUMAN)
		if current_form != prev_h:
			_transform_buffer = 0.0
		return
	if forma_seleccionada == current_form:
		_avanzar_seleccion()
	if not _progresion().forma_desbloqueada(forma_seleccionada) or _forma_en_cooldown(forma_seleccionada):
		if Input.is_action_just_pressed("transform"):
			_denegar_transformacion()
		return
	var prev: int = current_form
	_transformar(forma_seleccionada)
	if current_form != prev:
		_transform_buffer = 0.0


## Devuelve true si la forma cambió (false si está en cooldown, es la misma o no hay espacio para el collider).
func _transformar(nueva: int, forzar: bool = false) -> bool:
	if not forzar and _cooldown_transform > 0.0:
		return false
	if nueva == current_form or (not forzar and _forma_en_cooldown(nueva)):
		return false
	if not forzar and nueva != Form.HUMAN and energia < energia_min_transformar:
		_denegar_transformacion()
		return false
	var data_nueva: Forma = forms[nueva]
	var prev_size: Vector2 = (collision_shape.shape as RectangleShape2D).size
	var prev_pos: Vector2 = collision_shape.position
	var new_pos_y := 142.5 - data_nueva.collider_size.y * 0.5
	(collision_shape.shape as RectangleShape2D).size = data_nueva.collider_size
	collision_shape.position.y = new_pos_y
	var bloqueado := test_move(global_transform, Vector2.ZERO)
	(collision_shape.shape as RectangleShape2D).size = prev_size
	collision_shape.position = prev_pos
	if bloqueado:
		if not forzar:
			_denegar_transformacion()   # forzada (energía agotada): se reintenta sin repetir el sonido cada frame
		return false
	forms[current_form].reset_form_state()
	current_form = nueva
	forma_seleccionada = nueva
	_limpiar_estado_transitorio()
	_cancelar_recuperacion(true)
	_cancelar_anim_ataque()
	_light_step = 0
	_heavy_step = 0
	_seq.clear()
	var data: Forma = forms[current_form]
	data.reset_form_state()
	_apply_form()
	var cine := transformacion_cine and DisplayServer.get_name() != "headless"
	_zoom_transform(data, cine)
	var cam := get_viewport().get_camera_2d()
	if cam != null and cam.has_method("punch"):
		cam.punch(1.07)
	if cine:
		_juice_transformacion(data, forzar)
	elif slowmo_transformacion > 0.0:
		_freeze_slowmo(slowmo_transformacion, slowmo_transformacion_escala)
	_particulas_regreso(data.color)
	if transformacion_pop > 0.0:
		_punch_sprite(transformacion_pop)
	if transformacion_anillo > 0.0:
		_anillo_onda(transformacion_anillo)
	if not forzar:
		_golpe_rapido_t = golpe_rapido_tras_transformar
		if _racha >= 2 and _racha_timer > 0.0:
			_tag_t = tag_bonus_tiempo
			energia = minf(energia + tag_energia, ENERGIA_MAX)
		if data.onda_transformacion_radio > 0.0:
			onda_area(data.onda_transformacion_radio, data.onda_transformacion_dano, data.onda_transformacion_knockback, false)
	_invuln_timer = maxf(_invuln_timer, invuln_transformacion)
	_invuln_sin_parpadeo = true
	var audio_mgr_t := get_node_or_null("/root/AudioManager")
	if audio_mgr_t != null:
		audio_mgr_t.play_sfx(sonido_transformacion, volumen_transformacion_db)
	if not forzar:
		_cooldown_transform = COOLDOWN_TRANSFORM
	form_changed.emit(data.form_name)
	forma_selectada_cambiada.emit(nueva)
	health_changed.emit(health, VIDA_MAX)
	return true


func _particulas_regreso(color: Color) -> void:
	if DisplayServer.get_name() == "headless":
		return
	var p: CPUParticles2D = (preload("res://scenes/burst.tscn") as PackedScene).instantiate()
	p.global_position = global_position + Vector2(0, 20)
	p.self_modulate = _tinte_forma(color)
	get_tree().root.add_child(p)
	p.restart()
	p.emitting = true


## Transformación cinematográfica: destello blanco que vira al color de la forma, mundo congelado y
## luego en cámara lenta, estallido de aros y rayos, y temblor (más fuerte en el Oso).
func _juice_transformacion(data: Forma, forzar: bool) -> void:
	var k := 0.5 if forzar else 1.0   # volver a Humano por falta de energía: versión suave
	var color := _tinte_forma(data.color)
	var dur_tinte := transformacion_tinte_duracion * k
	var layer := CanvasLayer.new()
	layer.layer = 100
	layer.process_mode = Node.PROCESS_MODE_ALWAYS
	var velo := ColorRect.new()
	velo.set_anchors_preset(Control.PRESET_FULL_RECT)
	velo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	velo.color = Color(1, 1, 1, 0.95)
	layer.add_child(velo)
	get_tree().root.add_child(layer)
	var tw := velo.create_tween()
	tw.set_ignore_time_scale(true)
	tw.tween_property(velo, "color", Color(color.r, color.g, color.b, 0.42 * k), 0.14)
	tw.tween_property(velo, "color:a", 0.0, dur_tinte)
	tw.tween_callback(layer.queue_free)
	var centro := global_position + Vector2(0, 90)
	OndaTransformacion.lanzar(JuiceCapa.obtener(get_tree()), centro, color.lightened(0.25), transformacion_radio * k, 24 if current_form != Form.OSO else 12, 0.45)
	var cam := get_viewport().get_camera_2d()
	if cam != null and cam.has_method("shake"):
		cam.shake((22.0 if current_form == Form.OSO else 12.0) * k, 0.3)
	var pausa := transformacion_congelado * k
	if pausa > 0.0:
		_freeze_hitstop(pausa)
	if transformacion_slowmo > 0.0:
		_freeze_slowmo(pausa + transformacion_slowmo * k, transformacion_slowmo_escala)


func _zoom_transform(data: Forma, cine: bool = false) -> void:
	var cam := get_viewport().get_camera_2d()
	if cam != null:
		cam.fijar_zoom(data.camera_zoom)
	if not cine:
		_flash_transformacion(data.color)
	if current_form != Form.HUMAN:
		_tip_una_vez("energia", "Las formas gastan energía. Al llegar a cero volvés a Humano; matá enemigos para recuperarla.")


## Aviso de ayuda que se muestra una sola vez por partida (no bloquea el juego).
func _tip_una_vez(clave: String, texto: String) -> void:
	if not tips_ayuda or _tips_vistos.has(clave) or DisplayServer.get_name() == "headless":
		return
	var dlg := get_node_or_null("/root/Dialogo")
	if dlg == null or not dlg.has_method("mostrar_tip"):
		return
	_tips_vistos[clave] = true
	dlg.mostrar_tip([texto], "Amuleto")


func _flash_transformacion(color: Color) -> void:
	if DisplayServer.get_name() == "headless":
		return
	var overlay := ColorRect.new()
	overlay.color = _tinte_forma(color, 0.85)
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	var layer := CanvasLayer.new()
	layer.layer = 100
	var destino: Node = get_tree().current_scene if get_tree().current_scene != null else get_tree().root
	destino.add_child(layer)
	layer.add_child(overlay)
	var tw := overlay.create_tween()
	tw.tween_property(overlay, "color:a", 0.0, 0.12)
	tw.tween_callback(func() -> void:
		layer.queue_free()
	)


## Desniveles chicos (escalones de 1 px, rampas hechas de peldaños, pegado al piso): el cuerpo se
## mueve a saltitos, pero el sprite sigue un terreno SUAVIZADO. `_suave_s` es la altura suave del
## suelo; avanza con la pendiente media reciente (así una escalera de peldaños se ve como una rampa
## recta) y se corrige hacia el cuerpo según la distancia recorrida en horizontal. El desfase
## resultante (`_suave_y` = suave - cuerpo) es lo que se aplica al sprite.
func _suavizar_desnivel(delta: float) -> void:
	var x := global_position.x
	var y := global_position.y
	if absf(y - _suave_s) > suavizado_escalon_max * 2.0:
		_suave_s = y   # teletransporte / caída larga: no hay nada que suavizar
		_suave_hist_x.clear()
		_suave_hist_y.clear()
	if suavizado_escalon <= 0.0 or _trepando or not is_on_floor():
		# En el aire o trepando no hay terreno que suavizar: se sincroniza rápido con el cuerpo.
		_suave_hist_x.clear()
		_suave_hist_y.clear()
		_suave_s = lerpf(_suave_s, y, 1.0 - exp(-30.0 * delta)) if suavizado_escalon > 0.0 else y
	else:
		var u := absf(x - _suave_x_prev)
		var n := _suave_hist_x.size()
		if n == 0 or absf(x - _suave_hist_x[n - 1]) >= 1.5:
			_suave_hist_x.append(x)
			_suave_hist_y.append(y)
		else:
			_suave_hist_y[n - 1] = y
		# Ventana: solo las posiciones de los últimos `rampa_distancia` px de recorrido.
		while _suave_hist_x.size() > 1 and absf(x - _suave_hist_x[0]) > rampa_distancia:
			_suave_hist_x.remove_at(0)
			_suave_hist_y.remove_at(0)
		n = _suave_hist_x.size()
		var objetivo := y
		if n >= 3 and absf(_suave_hist_x[n - 1] - _suave_hist_x[0]) >= 8.0:
			# Recta de mínimos cuadrados y(x) sobre la ventana, evaluada en la x actual: sobre una
			# escalera de peldaños de 1 px es la rampa recta que los une (sin retraso en rampas).
			var mx := 0.0
			var my := 0.0
			for i in n:
				mx += _suave_hist_x[i]
				my += _suave_hist_y[i]
			mx /= n
			my /= n
			var sxx := 0.0
			var sxy := 0.0
			for i in n:
				sxx += (_suave_hist_x[i] - mx) * (_suave_hist_x[i] - mx)
				sxy += (_suave_hist_x[i] - mx) * (_suave_hist_y[i] - my)
			if sxx > 1.0:
				objetivo = my + sxy / sxx * (x - mx)
		# Pequeña inercia en distancia para que al entrar/salir muestras de la ventana no haya tirones.
		_suave_s = lerpf(_suave_s, objetivo, 1.0 - exp(-u / maxf(escalon_distancia, 1.0))) if u > 0.25 else lerpf(_suave_s, y, 1.0 - exp(-suavizado_escalon * delta))
	_suave_x_prev = x
	_suave_y = clampf(_suave_s - y, -suavizado_escalon_max, suavizado_escalon_max)
	if absf(_suave_y) < 0.01:
		_suave_y = 0.0
	# El motor dibuja los nodos en píxeles enteros: la parte entera va a la posición y la
	# fracción la absorbe el shader del sprite (movimiento sub-píxel, sin brincos de 1 px).
	var entero := roundf(_suave_y)
	visual.position.y += entero - _suave_entero
	_suave_entero = entero
	if _mat_suave != null:
		_mat_suave.set_shader_parameter("desfase_px", _suave_y - entero)
		_mat_suave.set_shader_parameter("escala_y", absf(visual.scale.y))


func _visual_base_y() -> float:
	var lift := 0.0
	if current_form >= 0 and current_form < forms.size():
		lift = forms[current_form].flight_lift
	return collision_shape.position.y + 7.5 - lift + _suave_entero


func _apply_form() -> void:
	var data: Forma = forms[current_form]
	_aplicar_facing()
	visual.modulate = Color.WHITE
	visual.self_modulate = _tinte_forma(data.color)
	visual.skew = 0.0
	_cancelar_anim_ataque()
	collision_shape.shape.size = data.collider_size
	collision_shape.position.y = 142.5 - data.collider_size.y * 0.5
	if _recoil_tween != null and _recoil_tween.is_valid():
		_recoil_tween.kill()   # no debe pisar la Y de la forma nueva
	visual.position = Vector2(_visual_base_x, _visual_base_y())
	_anclar_pies()
	_gravity_override = -1.0
	blocking = false


func _tinte_forma(color: Color, alpha: float = 1.0) -> Color:
	# Tinte sutil: mezcla el color de la forma con blanco para no oscurecer el sprite
	var tint := color.lerp(Color.WHITE, 0.55)
	return Color(tint.r, tint.g, tint.b, alpha)


func _aplicar_facing() -> void:
	visual.scale.x = -absf(_base_sprite_scale.x) if facing < 0 else absf(_base_sprite_scale.x)
	var data: Forma = forms[current_form]
	if facing != _turn_prev_facing:
		if _turn_prev_facing != 0 and giro_squash > 0.0 and is_on_floor() and absf(velocity.x) < 40.0 and not _attacking:
			_esc_off.x = clampf(_esc_off.x - giro_squash, -0.6, 0.6)   # anticipación del giro estando quieto
		_turn_prev_facing = facing
		if data.turn_tilt_cam > 0.0:
			var cam := get_viewport().get_camera_2d()
			if cam != null and cam.has_method("tilt"):
				cam.tilt(-deg_to_rad(1.5) * facing)


func _update_tint() -> void:
	var data: Forma = forms[current_form]
	visual.modulate.a = 1.0 if blocking else TINT_ALPHA
	visual.self_modulate = _tinte_forma(data.color)


func _duracion_anim(anim: String) -> float:
	var sf: SpriteFrames = visual.sprite_frames
	if sf != null and sf.has_animation(anim):
		return float(sf.get_frame_count(anim)) / maxf(sf.get_animation_speed(anim), 0.01)
	return 0.5


## Reparte el tiempo del ataque entre los frames para que el frame de impacto (`Forma.anim_impacto`)
## se muestre justo cuando el golpe puede conectar (`_hit_delay`): la preparación se comprime, el
## impacto se sostiene un instante y el resto de los frames se reparte por la recuperación.
## Deja `_attack_frame_dur` vacío si la animación no tiene impacto definido.
func _planificar_anim_ataque(anim: String, fi: int) -> void:
	_attack_frame_dur.clear()
	var sf: SpriteFrames = visual.sprite_frames
	var data: Forma = forms[current_form]
	if sf == null or not sf.has_animation(anim) or not data.anim_impacto.has(anim):
		return
	var n := sf.get_frame_count(anim)
	var imp := clampi(int(data.anim_impacto[anim]), 0, n - 1)
	if fi > imp:
		return
	var total := maxf(_attack_timer, 0.12)
	var t_pre := maxf(_hit_delay, 0.03)
	var n_pre := imp - fi
	var n_post := n - imp - 1
	var dur_imp := data.impacto_sostener
	if n_pre == 0:
		dur_imp += t_pre   # arranca ya en el impacto: se sostiene hasta que el daño pueda conectar
	var gastado := (t_pre if n_pre > 0 else 0.0) + dur_imp
	var resto := maxf(total - gastado, 0.03 * n_post)
	var durs := PackedFloat32Array()
	durs.resize(n)
	for f in range(fi, imp):
		durs[f] = t_pre / float(n_pre)
	durs[imp] = dur_imp
	for f in range(imp + 1, n):
		durs[f] = resto / float(n_post)
	var suma := 0.0
	for f in n:
		suma += durs[f]
	if suma > total:
		for f in n:
			durs[f] *= total / suma
	_attack_frame_dur = durs


## Velocidad de reproducción para el frame actual de la animación de ataque (según el plan).
func _velocidad_anim_ataque() -> float:
	if _attack_frame_dur.is_empty() or visual.sprite_frames == null:
		return _attack_anim_speed_scale
	var f := clampi(visual.frame, 0, _attack_frame_dur.size() - 1)
	var d := _attack_frame_dur[f]
	var sf: SpriteFrames = visual.sprite_frames
	if d <= 0.0 or not sf.has_animation(visual.animation):
		return _attack_anim_speed_scale
	var natural := sf.get_frame_duration(visual.animation, f) / maxf(sf.get_animation_speed(visual.animation), 0.01)
	return natural / d


func _iniciar_anim_ataque(anim: String, frame_ini: int = 0) -> void:
	_attack_anim_cola.clear()
	_attack_anim_cola.append(anim)
	_attack_anim_actual = anim
	_attack_anim_timer = _attack_timer
	# Si arranca en un frame > 0, la parte que queda se estira para durar la recuperación.
	var n := maxi(visual.sprite_frames.get_frame_count(anim), 1) if visual.sprite_frames != null and visual.sprite_frames.has_animation(anim) else 1
	var fi := clampi(frame_ini, 0, n - 1)
	var fraccion := float(n - fi) / float(n)
	_attack_anim_speed_scale = _duracion_anim(anim) * fraccion / maxf(_attack_timer, 0.01)
	visual.play(anim)
	if fi > 0:
		visual.set_frame_and_progress(fi, 0.0)
	_planificar_anim_ataque(anim, fi)
	visual.speed_scale = _velocidad_anim_ataque()


## Pose extra al golpear: el sprite se inclina (cabeceo) y se estira un instante; vuelve solo.
func pose_ataque(rot_deg: float, alargar: float = 0.0, dur: float = 0.2) -> void:
	if _pose_tween != null and _pose_tween.is_valid():
		_pose_tween.kill()
	_pose_rot = deg_to_rad(rot_deg) * facing
	_pose_tween = create_tween()
	_pose_tween.tween_property(self, "_pose_rot", 0.0, dur).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	if alargar > 0.0:
		_punch_sprite(alargar)


func _cancelar_anim_ataque() -> void:
	_attack_anim_cola.clear()
	_attack_frame_dur.clear()
	_attack_anim_timer = 0.0
	_attack_anim_actual = "attack1"
	_attack_anim_speed_scale = 1.0


func _update_animacion() -> void:
	_esc_reposo = Vector2.ZERO
	_aplicar_facing()
# Ataques del Humano con cola propia: la anim se estira (speed_scale) para
	# durar exactamente la recuperación del golpe. Light -> attack1 (1-3),
	# Heavy -> attack2 (4-6), Special/Combo -> attack_full (1-6).
	if _attack_anim_cola.size() > 0:
		_attack_anim_timer -= get_physics_process_delta_time()
		if _attack_anim_timer <= 0.0:
			if _attack_anim_cola.size() > 1:
				_attack_anim_cola.pop_front()
				_attack_anim_actual = _attack_anim_cola[0]
				_attack_anim_timer = _duracion_anim(_attack_anim_actual) / maxf(_attack_anim_speed_scale, 0.05)
				visual.play(_attack_anim_actual)
			else:
				_disolver_pose(transicion_salida_ataque)   # la pose final del golpe se funde con la de reposo/correr
				_attack_anim_cola.clear()
				_attack_anim_timer = 0.0
		if _attack_anim_cola.size() > 0:
			var anim := _attack_anim_cola[0]
			if visual.animation != anim:
				visual.play(anim)
			visual.speed_scale = _velocidad_anim_ataque()
		var dt_a := get_physics_process_delta_time()
		visual.skew = lerpf(visual.skew, 0.0, minf(12.0 * dt_a, 1.0))
		visual.rotation = lerpf(visual.rotation, _pose_rot, minf(12.0 * dt_a, 1.0))
		return
	if _trepando:
		if visual.animation != "climb":
			visual.play("climb")
		var cs_anim: float = 260.0
		if _enredadera_actual != null:
			cs_anim = float(_enredadera_actual.get("climb_speed")) if _enredadera_actual.get("climb_speed") != null else 260.0
		visual.speed_scale = clampf(absf(velocity.y) / maxf(cs_anim, 1.0), 0.12, 2.0)
		visual.skew = lerpf(visual.skew, 0.0, minf(8.0 * get_physics_process_delta_time(), 1.0))
		visual.rotation = lerpf(visual.rotation, 0.0, minf(10.0 * get_physics_process_delta_time(), 1.0))
		return
	var data_glide: Forma = forms[current_form]
	if current_form == Form.MURCIELAGO and data_glide.is_gliding(self):
		if visual.animation != "murci_volar":
			visual.play("murci_volar")
		visual.speed_scale = aleteo
		var base_lean_g := clampf(velocity.x / maxf(data_glide.speed, 1.0), -1.0, 1.0) * deg_to_rad(data_glide.lean_angulo)
		visual.skew = lerpf(visual.skew, base_lean_g, minf(8.0 * get_physics_process_delta_time(), 1.0))
		var prog_rot := clampf(_murci_glide_t / 1.4, 0.0, 1.0)
		var ang := lerpf(5.0, 16.0, prog_rot)
		var ang_q := lerpf(3.0, 10.0, prog_rot)
		visual.rotation = lerpf(visual.rotation, deg_to_rad(ang) * facing, minf(6.0 * get_physics_process_delta_time(), 1.0))
		return
	var quieto := absf(velocity.x) < 10.0 and is_on_floor()
	var data: Forma = forms[current_form]
	var en_aire := not is_on_floor() and current_form != Form.MURCIELAGO
	# Salto en el lugar: se conserva la pose de reposo en vez de pasar a la de correr.
	var idle_aire := en_aire and absf(velocity.x) < 10.0 and visual.animation in ["idle", "lobo_idle", "oso_idle"]
	var anim := "run"
	if current_form == Form.MURCIELAGO and visual.sprite_frames.has_animation("murci_volar"):
		if not is_on_floor() and absf(velocity.y) > 20.0:
			anim = "murci_volar"
		elif visual.sprite_frames.has_animation("murci_run"):
			anim = "murci_run"
	elif current_form == Form.LOBO and _attacking and visual.sprite_frames.has_animation("lobo_attack"):
		anim = "lobo_attack"
	elif current_form == Form.LOBO and quieto and visual.sprite_frames.has_animation("lobo_idle"):
		anim = "lobo_idle"
	elif current_form == Form.LOBO and visual.sprite_frames.has_animation("lobo_run"):
		anim = "lobo_run"
	elif current_form == Form.OSO and quieto and visual.sprite_frames.has_animation("oso_idle"):
		anim = "oso_idle"
	elif current_form == Form.OSO and visual.sprite_frames.has_animation("oso_caminar"):
		anim = "oso_caminar"
	elif current_form == Form.HUMAN and quieto and visual.sprite_frames.has_animation("idle"):
		anim = "idle"
	if idle_aire:
		anim = visual.animation
	if visual.animation != anim:
		visual.play(anim)
	var dt_s := get_physics_process_delta_time()
	var escala_obj := 0.0
	if anim == "lobo_attack":
		escala_obj = 1.4
	elif anim == "lobo_idle" or anim == "oso_idle" or anim == "idle":
		escala_obj = 1.0
	elif en_aire and data.congelar_en_aire:
		escala_obj = 0.0  # congelado: sigue en el frame que traía al despegar y retoma al aterrizar
	elif absf(velocity.x) < 10.0:
		# El Murciélago sigue aleteando aunque esté quieto o no avance (0 = alas quietas).
		escala_obj = aleteo if current_form == Form.MURCIELAGO else 0.0
	else:
		var speed_min := piernas_vel_min if current_form != Form.MURCIELAGO else 0.7
		escala_obj = clampf(absf(velocity.x) / maxf(data.speed, 1.0), speed_min, 1.6)
		if current_form == Form.LOBO:
			escala_obj = pow(escala_obj, 0.82)
	# El ritmo de las piernas acompaña la velocidad con suavidad (antes saltaba de golpe).
	if anim == "lobo_attack" or escala_obj == 0.0 or visual.speed_scale == 0.0:
		visual.speed_scale = escala_obj
	else:
		visual.speed_scale = lerpf(visual.speed_scale, escala_obj, minf(14.0 * dt_s, 1.0))
	var base_lean := clampf(velocity.x / maxf(data.speed, 1.0), -1.0, 1.0) * deg_to_rad(data.lean_angulo)
	var lean_mult := 1.4 if not is_on_floor() else 1.0
	var lean := base_lean * lean_mult
	visual.skew = lerpf(visual.skew, lean, minf(8.0 * get_physics_process_delta_time(), 1.0))
	var dt := get_physics_process_delta_time()
	var target_rot := 0.0
	if not is_on_floor():
		# Pose de salto: estirado al subir, compacto en el ápice, alargado al caer (todas las formas).
		var mag := data.salto_rot_grados if absf(velocity.x) > 10.0 else data.salto_rot_grados * 0.5
		var lado: float = signf(velocity.x) if absf(velocity.x) > 10.0 else float(facing)
		if velocity.y < -30.0:
			target_rot = deg_to_rad(-mag) * lado
			_esc_reposo = Vector2(-data.salto_estiramiento * 0.5, data.salto_estiramiento)
		elif velocity.y > 80.0:
			target_rot = deg_to_rad(mag) * lado
			_esc_reposo = Vector2(-data.caida_estiramiento * 0.5, data.caida_estiramiento)
		elif absf(velocity.y) < APEX_CORE_THRESHOLD and not _trepando:
			_esc_reposo = Vector2(data.apex_compacto, -data.apex_compacto)
	else:
		# Inclinación al acelerar (hacia adelante) y al frenar (hacia atrás).
		var ax := (velocity.x - _vx_prev) / maxf(dt, 0.0001)
		_acel_suave = lerpf(_acel_suave, clampf(ax / maxf(data.accel, 1.0), -1.0, 1.0), minf(10.0 * dt, 1.0))
		target_rot += deg_to_rad(acel_inclinacion_grados) * _acel_suave
	_vx_prev = velocity.x
	# Cansancio: con poca vida/energía el cuerpo se encorva y tiembla apenas.
	var cansancio := _factor_cansancio()
	var aj := _ajuste_frame()
	if cansancio > 0.0:
		if quieto:
			target_rot += deg_to_rad(4.0) * facing * cansancio
		visual.offset.x = sin(Time.get_ticks_msec() * 0.06) * cansancio * (1.0 if current_form != Form.HUMAN else 0.0) + aj.x
	else:
		visual.offset.x = aj.x
	visual.rotation = lerpf(visual.rotation, target_rot + _pose_rot, minf(10.0 * dt, 1.0))
	# Polvo al correr (Oso más espaciado y pesado).
	if polvo_correr_intervalo > 0.0 and is_on_floor() and not _attacking and absf(velocity.x) > data.speed * 0.6:
		_polvo_paso_t -= dt
		if _polvo_paso_t <= 0.0:
			_polvo_paso_t = polvo_correr_intervalo * (1.4 if current_form == Form.OSO else 1.0)
			_emitir_polvo(0.4 if current_form == Form.OSO else 0.25)
	else:
		_polvo_paso_t = 0.0
	if current_form == Form.LOBO and is_on_floor() and absf(velocity.x) > 320.0:
		var cam_tilt2 := get_viewport().get_camera_2d()
		if cam_tilt2 != null and cam_tilt2.has_method("tilt"):
			cam_tilt2.tilt(-deg_to_rad(1.4) * signf(velocity.x) * clampf(absf(velocity.x) / 690.0, 0.0, 1.0))
	if current_form == Form.MURCIELAGO and not _trepando and not is_on_floor():
		var t := Time.get_ticks_msec() / 1000.0
		var onda := sin(t * 5.0) * 3.5 + sin(t * 9.0) * 1.8
		visual.position.y = _visual_base_y() + onda
	elif current_form == Form.MURCIELAGO and not _trepando:
		visual.position.y = lerpf(visual.position.y, _visual_base_y(), minf(6.0 * get_physics_process_delta_time(), 1.0))


func _handle_death() -> void:
	if health > 0 or god_mode or _derrota_activa:
		return
	_derrota_activa = true
	if DisplayServer.get_name() == "headless" or muerte_duracion <= 0.0:
		_mostrar_derrota()
		return
	_secuencia_muerte()


## Antes del panel "HAS CAÍDO": cámara lenta, destello del jugador, estallido del
## color de la forma y la pantalla que se oscurece hasta el mismo tono del panel.
func _secuencia_muerte() -> void:
	# Corta el parpadeo de invulnerabilidad del golpe letal: si no, el jugador puede
	# quedar invisible justo cuando se congela la escena.
	_invuln_timer = 0.0
	visual.visible = true
	var audio := get_node_or_null("/root/AudioManager")
	if audio != null:
		audio.play_sfx(sonido_muerte, volumen_muerte_db)
	var hs := get_node_or_null("/root/Hitstop")
	if hs != null:
		hs.slowmo(muerte_duracion, muerte_slowmo_escala)
	var cam := get_viewport().get_camera_2d()
	if cam != null and cam.has_method("punch"):
		cam.punch(1.08)
	if cam != null and cam.has_method("shake"):
		cam.shake(8.0, 0.25)
	Burst.emitir(self, visual.global_position, forms[current_form].color, 26, 1.6)
	visual.modulate = Color(3, 3, 3, 1)
	if _tween_muerte != null and _tween_muerte.is_valid():
		_tween_muerte.kill()
	# Reloj real (la cámara lenta no lo estira) y guardado para poder matarlo al reaparecer.
	_tween_muerte = create_tween().set_ignore_time_scale(true)
	_tween_muerte.tween_property(visual, "modulate", Color(0.35, 0.35, 0.45, 1), muerte_duracion * 0.6)
	var capa := CanvasLayer.new()
	capa.layer = 94
	var velo := ColorRect.new()
	velo.set_anchors_preset(Control.PRESET_FULL_RECT)
	velo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	velo.color = Color(0, 0, 0, 0)
	capa.add_child(velo)
	add_child(capa)   # hijo del jugador: si se cambia de escena durante la muerte, el velo se va con él
	var tv := velo.create_tween().set_ignore_time_scale(true)
	tv.tween_property(velo, "color:a", 0.6, muerte_duracion)
	# Reloj real: la cámara lenta no debe estirar la espera.
	await get_tree().create_timer(muerte_duracion, true, false, true).timeout
	if reaparicion_automatica:
		_velo_muerte = capa  # se quita con la pantalla ya en negro (evita un parpadeo)
	else:
		capa.queue_free()
	_mostrar_derrota()


## Reaparición automática: fundido corto → checkpoint (o recarga si no hay) → vuelta.
func _reaparecer_automatico() -> void:
	var t := TransicionPantalla.de(get_tree())
	if t.esta_ocupado():
		_reaparecer_ahora()
	else:
		t.fundido(_reaparecer_ahora)


func _reaparecer_ahora() -> void:
	get_tree().paused = false
	if is_instance_valid(_velo_muerte):
		_velo_muerte.queue_free()
	_velo_muerte = null
	if _tiene_checkpoint:
		reaparecer_en_checkpoint()
		var cam := get_viewport().get_camera_2d()
		if cam != null and cam.has_method("modo_normal"):
			cam.modo_normal(true)
		for e in get_tree().get_nodes_in_group("encounter"):
			if e.has_method("reiniciar"):
				e.reiniciar()
	else:
		get_tree().reload_current_scene()


func _mostrar_derrota() -> void:
	if reaparicion_automatica:
		_reaparecer_automatico()
		return
	var escena: PackedScene = load("res://scenes/derrota.tscn")
	var derrota: CanvasLayer = escena.instantiate()
	var destino: Node = get_tree().current_scene if get_tree().current_scene != null else get_parent()
	destino.add_child(derrota)
	get_tree().paused = true


## `ignora_bloqueo`: el daño letal del entorno (pinchos) no se puede bloquear.
func take_damage(cantidad: int, knockback: float = 0.0, dir: int = 1, ignora_bloqueo: bool = false) -> void:
	if ignora_bloqueo:
		blocking = false
		_parry_t = 0.0
	if _parry_t > 0.0 and blocking and not god_mode and _invuln_timer <= 0.0 and not _dialogo_bloquea_input():
		_parry_perfecto(dir)
		return
	if blocking and not god_mode and _invuln_timer <= 0.0 and not _dialogo_bloquea_input():
		_sfx(sonido_bloqueo, volumen_estado_db, 0.08)
		var costo := bloqueo_costo_energia + cantidad * bloqueo_costo_por_dano
		if costo > 0.0 and energia > 0.0:
			energia = maxf(energia - costo, 0.0)
			energia_changed.emit(energia)
		velocity.x = -dir * bloqueo_empuje
	if god_mode or blocking or _invuln_timer > 0.0 or _dialogo_bloquea_input():
		return
	cantidad = maxi(roundi(cantidad * forms[current_form].dano_recibido_mult), 1)
	health -= cantidad
	_sfx(sonido_dano, volumen_dano_db, 0.08)
	# Golpe fuerte = más daño = más pausa de impacto (y el cel el umbral queda sin pausa).
	var dur := hitstop_dano
	if cantidad >= hitstop_dano_umbral and hitstop_dano_pesado > dur:
		dur = hitstop_dano_pesado
	_freeze_hitstop(dur)
	health_changed.emit(health, VIDA_MAX)
	dano_recibido.emit(cantidad)
	if health > 0:
		_tip_una_vez("parry", "Bloqueá justo antes de que te golpeen para hacer un parry: no recibís daño y recuperás energía.")
	_shake_dano_recibido(dir)
	_flash_tint_dano()
	_juice_dano(cantidad)
	stretch_y(-0.12, 0.14)
	_recoil_dano(dir)
	if reaccion_dano_en_ataque and _attacking:
		_lunge_t = 0.0          # el avance del golpe no empuja contra el retroceso
		_dano_reciente_t = 0.25 # ni el imán del golpe tira hacia el enemigo
	if knockback > 0.0:
		velocity.x = dir * knockback * (dano_empuje_mult if dano_cine else 1.0)
	_invuln_timer = invuln_dano
	_invuln_sin_parpadeo = false
	_handle_death()


## Recibir daño: un instante sin color y con los bordes rojos (más fuerte cuanto más duele).
func _juice_dano(cantidad: int) -> void:
	if not dano_cine or DisplayServer.get_name() == "headless":
		return
	DanoPantalla.lanzar(get_tree(), 0.35 + cantidad / 40.0, 0.3 + minf(cantidad / 80.0, 0.2))


## Oso: grietas en el piso, polvo y temblor extra al aterrizar fuerte o al pisotón.
func _juice_oso_suelo(impacto: float) -> void:
	if not oso_grietas or current_form != Form.OSO or DisplayServer.get_name() == "headless":
		return
	var ahora := Time.get_ticks_msec()
	if ahora - _oso_grieta_ms < 350:
		return
	_oso_grieta_ms = ahora
	var k := clampf(impacto / 900.0, 0.5, 1.4)
	JuiceFx.grietas_suelo(get_tree(), global_position + Vector2(0, 142.0), 520.0 * k)
	JuiceFx.escombros(get_tree(), global_position + Vector2(0, 130.0), Color(0.42, 0.36, 0.3), int(8 * k), 0.7 * k)
	var cam := get_viewport().get_camera_2d()
	if cam != null and cam.has_method("shake"):
		cam.shake(16.0 * k, 0.28, Vector2(0, 1))
	_emitir_polvo(1.0)


func parry_activo() -> bool:
	return _parry_t > 0.0 and blocking and current_form == Form.HUMAN


## Bloqueo justo a tiempo: no recibe daño, recupera energía, aturde a los cercanos y hace un mini slow-mo.
func _parry_perfecto(_dir: int) -> void:
	_parry_t = 0.0
	_bloqueo_t = 0.0
	_bloqueo_sin_cd = true
	_invuln_timer = maxf(_invuln_timer, 0.3)
	energia = minf(energia + parry_energia, ENERGIA_MAX)
	energia_changed.emit(energia)
	_sfx(sonido_bloqueo, volumen_estado_db + 4.0, 0.05)
	var cine := parry_bn and DisplayServer.get_name() != "headless"
	if cine:
		# Parry cinematográfico: todo se congela, el mundo pasa a blanco y negro (menos vos) y queda
		# una cámara lenta para contraatacar.
		_freeze_hitstop(parry_congelado)
		var total_slow := _parry_slowmo_curva()
		ParryBN.lanzar(get_tree(), self, parry_congelado, total_slow * 0.7, parry_radio_color)
		OndaTransformacion.lanzar(JuiceCapa.obtener(get_tree()), global_position + Vector2(0, 90), Color(0.95, 0.98, 1.0), 1100.0, 12, 0.5)
	else:
		_freeze_hitstop(0.1)
		_freeze_slowmo(0.18, 0.4)
	onda_area(parry_onda_radio, 6, 380.0, false)
	stretch_y(0.16, 0.12)
	var cam := get_viewport().get_camera_2d()
	if cam != null and cam.has_method("punch"):
		cam.punch(1.09 if cine else 1.06)
	if not cine:
		_flash_transformacion(Color(0.9, 0.95, 1.0))
	_contra_t = contragolpe_tiempo
	parry_exitoso.emit()


## Cámara lenta del parry en tramos (entra lento, sale suave). Usa temporizadores en tiempo real.
## Devuelve la duración total de la curva.
func _parry_slowmo_curva() -> float:
	var total := 0.0
	var inicio := parry_congelado
	for tramo in parry_slowmo_tramos:
		var dur: float = tramo.x
		var esc: float = tramo.y
		if total <= 0.0:
			_freeze_slowmo(inicio + dur, esc)
		else:
			get_tree().create_timer(inicio + total, true, false, true).timeout.connect(
				func() -> void: _freeze_slowmo(dur, esc))
		total += dur
	return total


## Onda alrededor del jugador: daña y empuja a los enemigos cercanos. `solo_atras` excluye a los
## que están delante (los cubre el golpe frontal). Devuelve cuántos alcanzó.
func onda_area(radio: float, dano: int, knockback: float, solo_atras: bool = false, lado: int = 0) -> int:
	var golpeados := 0
	var frente := lado if lado != 0 else facing
	for n in get_tree().get_nodes_in_group("enemy"):
		if not is_instance_valid(n) or not (n is Node2D) or not n.has_method("take_damage"):
			continue
		if n.get("_activo") == false:
			continue   # enemigos de olas pendientes u ocultos: no se los golpea antes de su ola
		if "health" in n and int(n.health) <= 0:
			continue
		var dx: float = n.global_position.x - global_position.x
		var dy: float = n.global_position.y - global_position.y
		if absf(dx) > radio or absf(dy) > 320.0:
			continue
		if solo_atras and signf(dx) == float(frente):
			continue
		n.take_damage(dano, knockback, 1 if dx >= 0.0 else -1, false)
		golpeados += 1
	_anillo_onda(radio)
	var amb := get_node_or_null("/root/Ambiente")
	if amb != null:
		amb.empujar(global_position, clampf(radio / 300.0, 0.3, 1.0))
	return golpeados


func _anillo_onda(radio: float) -> void:
	if DisplayServer.get_name() == "headless":
		return
	var aro := Line2D.new()
	var pts := PackedVector2Array()
	for i in 33:
		var a := TAU * float(i) / 32.0
		pts.append(Vector2(cos(a), sin(a) * 0.35) * radio)
	aro.points = pts
	aro.width = 6.0
	aro.default_color = _tinte_forma(forms[current_form].color).lightened(0.4)
	aro.scale = Vector2(0.15, 0.15)
	aro.global_position = global_position + Vector2(0, 100)
	get_tree().root.add_child(aro)
	var tw := aro.create_tween()
	tw.tween_property(aro, "scale", Vector2.ONE, 0.22).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(aro, "modulate:a", 0.0, 0.26)
	tw.tween_callback(aro.queue_free)


## Rechazo direccional del sprite (empuja contra la dirección del golpe) sin rotar,
## con un micro-temblor corto al impacto y vuelta elástica.
func _recoil_dano(dir: int) -> void:
	if recoil_sprite <= 0.0:
		return
	if _recoil_tween != null and _recoil_tween.is_valid():
		_recoil_tween.kill()
	# Base fija (no la posición actual): dos golpes seguidos o un cambio de forma a mitad de tween
	# ya no dejan el sprite desplazado para siempre.
	var base := Vector2(_visual_base_x, _visual_base_y())
	_recoil_tween = create_tween()
	if reaccion_dano_en_ataque:
		# Solo se mueve el sprite en X: la Y la maneja el suavizado de desniveles (si no, el tween la pisa).
		visual.position.x = base.x - dir * recoil_sprite
		if temblor_dano > 0.0:
			var mitad_x: float = temblor_dano * 0.5
			_recoil_tween.tween_property(visual, "position:x", base.x - dir * recoil_sprite * 0.25, mitad_x)
			_recoil_tween.tween_property(visual, "position:x", base.x, temblor_dano)
		_recoil_tween.tween_property(visual, "position:x", base.x, 0.06).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		return
	visual.position = base + Vector2(-dir * recoil_sprite, 0)
	if temblor_dano > 0.0:
		var mitad: float = temblor_dano * 0.5
		_recoil_tween.tween_property(visual, "position", base + Vector2(-dir * recoil_sprite * 0.25, 0), mitad)
		_recoil_tween.tween_property(visual, "position", base, temblor_dano)
	_recoil_tween.tween_property(visual, "position", base, 0.06).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _shake_dano_recibido(dir: int = 1) -> void:
	var cam := get_viewport().get_camera_2d()
	if cam == null or not cam.has_method("shake"):
		return
	cam.shake(4.0, 0.12, Vector2(dir, 0))


func _flash_tint_dano() -> void:
	if _tint_tween != null and _tint_tween.is_valid():
		_tint_tween.kill()
	visual.modulate = tint_dano
	_tint_tween = create_tween()
	_tint_tween.tween_property(visual, "modulate", Color.WHITE, tint_dano_duracion)


## Avisa (sutil) que el cooldown del especial terminó: destello del sprite + tick suave.
func _flash_especial_listo() -> void:
	if visual == null or (_tween_muerte != null and _tween_muerte.is_valid()):
		return
	if _tint_tween != null and _tint_tween.is_valid():
		_tint_tween.kill()
	visual.modulate = tint_especial_listo
	_tint_tween = create_tween()
	_tint_tween.tween_property(visual, "modulate", Color.WHITE, especial_listo_duracion)
	_sfx(sonido_especial_listo, volumen_especial_listo_db, 0.05)


func heal_full() -> void:
	health = VIDA_MAX
	health_changed.emit(health, VIDA_MAX)


## Cura una cantidad sin superar la vida máxima (usado por el orbe rojo de vida).
func puede_curarse() -> bool:
	return health < VIDA_MAX


func curar(cantidad: int) -> void:
	health = clampi(health + cantidad, 0, VIDA_MAX)
	health_changed.emit(health, VIDA_MAX)


func actualizar_checkpoint(pos: Vector2) -> void:
	_spawn_position = pos
	_checkpoint_forma = current_form
	_checkpoint_vida = health
	_checkpoint_energia = energia
	_tiene_checkpoint = true


func tiene_checkpoint() -> bool:
	return _tiene_checkpoint


func reaparecer_en_checkpoint() -> void:
	if not _tiene_checkpoint:
		return
	global_position = _spawn_position
	velocity = Vector2.ZERO
	health = _checkpoint_vida
	energia = _checkpoint_energia
	_derrota_activa = false
	if _tween_muerte != null and _tween_muerte.is_valid():
		_tween_muerte.kill()   # si no, terminaba después y el jugador reaparecía oscuro
	visual.modulate = Color.WHITE
	_restaurar_forma(_checkpoint_forma)
	_limpiar_estado_transitorio()
	if _trepando:
		_salir_enredadera()
	end_attack()
	_cancelar_anim_ataque()
	blocking = false
	_light_step = 0
	_heavy_step = 0
	_seq.clear()
	_combo_timer = 0.0
	_tag_t = 0.0
	_contra_t = 0.0
	_murci_glide_t = 0.0
	_esc_off = Vector2.ZERO
	_esc_vel = Vector2.ZERO
	_pose_rot = 0.0
	_cooldown_transform = 0.0
	_cooldown_formas.clear()
	_invuln_sin_parpadeo = false
	_racha = 0
	_racha_timer = 0.0
	racha_changed.emit(0)   # el HUD apaga el indicador de racha
	_invuln_timer = 1.5
	_anillo_onda(150.0)   # ritual de reaparición: aro espectral en el checkpoint
	_particulas_regreso(forms[current_form].color)
	health_changed.emit(health, VIDA_MAX)
	energia_changed.emit(energia)
	# Las plataformas frágiles rotas vuelven a aparecer al reaparecer.
	get_tree().call_group("plataforma_fragil", "restaurar_tras_muerte")


## Estados de acción que no deben sobrevivir a un cambio de forma ni a una reaparición.
func _limpiar_estado_transitorio() -> void:
	_picada = false
	_parry_t = 0.0
	_flap_cd = 0.0
	_lunge_t = 0.0
	_buffered_attack = ""
	_attack_air_buffer_type = ""
	_attack_air_buffer = 0.0


func _restaurar_forma(nueva: int) -> void:
	if nueva == current_form:
		return
	forms[current_form].reset_form_state()
	current_form = nueva
	forma_seleccionada = nueva
	var data: Forma = forms[current_form]
	data.reset_form_state()
	_apply_form()
	_zoom_transform(data)
	form_changed.emit(data.form_name)
	forma_selectada_cambiada.emit(nueva)
	health_changed.emit(health, VIDA_MAX)


func recoger_energia() -> void:
	energia = minf(energia + ENERGIA_PICKUP, ENERGIA_MAX)
	energia_changed.emit(energia)


func on_enemy_killed(cantidad: float = ENERGIA_KILL) -> void:
	energia = minf(energia + cantidad, ENERGIA_MAX)
	energia_changed.emit(energia)


func fire_projectile(pos_referencia: Vector2 = Vector2.ZERO, alcance: float = 700.0) -> void:
	_sfx(sonido_disparo, volumen_estado_db, 0.08)
	var proj: Area2D = preload("res://scenes/projectile.tscn").instantiate()
	proj.global_position = global_position + Vector2(facing * 90.0, -60.0) + pos_referencia
	var dir_inicial := Vector2(facing, 0.0)
	if current_form == Form.MURCIELAGO:
		var objetivo := _buscar_enemigo_homing(3000.0)
		if objetivo != null:
			var to_obj: Vector2 = objetivo.global_position + Vector2(0.0, proyectil_mira_bajo) - proj.global_position
			if to_obj.length_squared() > 0.01:
				dir_inicial = to_obj.normalized()
		proj.set("homing", true)
		proj.set("homing_range", 3000.0)
		proj.set("homing_offset", Vector2(0.0, proyectil_mira_bajo))
		# Teledirigido agresivo: giro fuerte constantemente hacia el objetivo.
		proj.set("homing_strength", 30.0)
	proj.set("direction", dir_inicial)
	proj.set("speed", alcance)
	proj.set("damage", forms[current_form].special_damage)
	var destino: Node = get_tree().current_scene if get_tree().current_scene != null else get_parent()
	destino.add_child(proj)
	if current_form == Form.MURCIELAGO:
		velocity.x -= facing * 120.0
		squash_y(0.18, 0.25)
		var cam2 := get_viewport().get_camera_2d()
		if cam2 != null and cam2.has_method("shake"):
			cam2.shake(2.0, 0.08, Vector2(-facing, 0))


func _buscar_enemigo_homing(rango: float) -> Node2D:
	var mejor: Node2D = null
	var mejor_dist := rango
	for n in get_tree().get_nodes_in_group("enemy"):
		if not is_instance_valid(n) or not n.has_method("take_damage"):
			continue
		if n.get("_activo") == false:
			continue
		if "health" in n and n.health <= 0:
			continue
		var d := global_position.distance_to(n.global_position)
		if d < mejor_dist:
			mejor_dist = d
			mejor = n
	return mejor


func _try_interact() -> bool:
	for nodo in get_tree().get_nodes_in_group("interactable"):
		if nodo.has_method("try_interact") and nodo.try_interact(self):
			return true
	return false


func _try_step_up() -> void:
	_step_up_hecho = false
	if _step_up_cd > 0.0:
		return
	if not is_on_floor():
		return
	var max_h: float = 48.0
	if current_form >= 0 and current_form < forms.size():
		max_h = forms[current_form].step_up_max
	if max_h <= 0.0:
		return
	if absf(velocity.x) < 4.0 and absf(Input.get_axis("move_left", "move_right")) < 0.15:
		return
	# Anticipa: detecta el escalón DENTRO del avance de este frame (o ya pegado),
	# para subir antes de chocar y no perder velocidad. No espera contacto exacto.
	var avance := maxf(absf(velocity.x), 130.0) * get_physics_process_delta_time() + 2.0
	var adelante := minf(avance, 16.0)   # lo que realmente va a avanzar este frame (con tope)
	if not test_move(global_transform, Vector2(facing * avance, 0)):
		return
	# Alturas con 0.2 px de holgura sobre el peldaño entero (a ras de la esquina move_and_slide vuelve a chocar).
	for h in [0.6, 1.2, 1.8, 2.4, 3.2, 4.2, 5.2, 6.2, 7.2, 8.2, 10.2, 12.2, 16.2, 24.2, 32.2, 48.2]:
		if h - 0.2 > max_h:   # la holgura de 0.2 px no cuenta para el tope de la forma
			break
		# Probar "pararse sobre el escalón": en frente y a h px de altura.
		# test_move usa un transform ABSOLUTO (posición real en el mundo), así que
		# siempre se parte de global_transform, nunca de Transform2D(0, Vector2.ZERO).
		var sobre := global_transform.translated(Vector2(facing * adelante, -h))
		if test_move(sobre, Vector2(0, 0)):
			continue
		# Verifica que delante hay piso a esa altura (no un hueco): lanza hacia abajo.
		var hueco := sobre.translated(Vector2(0, -1.0))
		if not test_move(hueco, Vector2(0, 24.0)):
			continue
		# Espacio libre subiendo justo desde la posición actual.
		var vertical := global_transform.translated(Vector2(0, -h))
		if test_move(vertical, Vector2(facing * adelante, 0)):
			continue
		global_position.y -= h
		if h >= 8.0:
			velocity.x = facing * maxf(absf(velocity.x), 140.0)
			_emitir_polvo(0.4)
		_step_up_hecho = true
		_step_up_cd = 0.03 if h >= 8.0 else 0.0
		return


## Forma con la que se puede trepar esa enredadera (`required_form` de la liana; 0 = Humano).
func _forma_requerida_enredadera(e: Node) -> int:
	var v: Variant = e.get("required_form")
	return int(v) if v != null else Form.HUMAN


func _handle_enredadera(delta: float) -> void:
	_salto_enredadera = false
	if _trepado_cooldown > 0.0:
		_trepado_cooldown = maxf(_trepado_cooldown - delta, 0.0)
	if _vine_buffer_timer > 0.0:
		_vine_buffer_timer = maxf(_vine_buffer_timer - delta, 0.0)
	if _vine_particulas_timer > 0.0:
		_vine_particulas_timer = maxf(_vine_particulas_timer - delta, 0.0)
	if Input.is_action_just_pressed("move_up") or Input.is_action_just_pressed("move_down") or Input.is_action_just_pressed("jump"):
		_vine_buffer_timer = VINE_BUFFER_TIME
	if _trepando:
		if _enredadera_actual == null or not is_instance_valid(_enredadera_actual):
			_salir_enredadera()
			return
		if current_form != _forma_requerida_enredadera(_enredadera_actual):
			_salir_enredadera()
			return
		var alto: float = float(_enredadera_actual.get("alto")) if _enredadera_actual.get("alto") != null else 400.0
		var ancho: float = float(_enredadera_actual.get("ancho")) if _enredadera_actual.get("ancho") != null else 32.0
		var top: float = _enredadera_actual.global_position.y - alto * 0.5
		var bot: float = _enredadera_actual.global_position.y + alto * 0.5
		var overlapping: bool = false
		if _enredadera_actual is Area2D:
			overlapping = (_enredadera_actual as Area2D).get_overlapping_bodies().has(self)
		if not overlapping:
			overlapping = absf(global_position.x - _enredadera_actual.global_position.x) < ancho * 0.5 + 48.0 and global_position.y > top - 48.0 and global_position.y < bot + 48.0
		if not overlapping:
			if _vine_coyote_timer > 0.0:
				_vine_coyote_timer = maxf(_vine_coyote_timer - delta, 0.0)
				overlapping = true
			else:
				_salir_enredadera()
				return
		else:
			_vine_coyote_timer = VINE_COYOTE_TIME
		var dir_x := Input.get_axis("move_left", "move_right")
		if absf(dir_x) < 0.5:
			dir_x = 0.0
		var dir_y: int = 0
		if Input.is_action_pressed("move_up"):
			dir_y -= 1
		if Input.is_action_pressed("move_down"):
			dir_y += 1
		if Input.is_action_just_pressed("jump"):
			var vy_prev: float = velocity.y
			_sfx(sonido_liana_soltar, volumen_liana_db, 0.1)
			_salir_enredadera()
			_salto_enredadera = true
			var jump_mult := 1.1 if dir_y < 0 or vy_prev < -40.0 else 1.0
			velocity.y = forms[current_form].jump_velocity * jump_mult + vy_prev * 0.25
			velocity.x = facing * 200.0
			squash_y(0.18, 0.18)
			_emitir_polvo(0.6)
			_emitir_burst_hojas()
			var cam := get_viewport().get_camera_2d()
			if cam != null and cam.has_method("punch"):
				cam.punch(1.04)
			return
		if dir_x != 0.0 and is_on_floor():
			_vine_dir_hold_t += delta
			if _vine_dir_hold_t >= TREPAR_EXIT_HOLD:
				var lateral := test_move(global_transform, Vector2(dir_x * 8.0, 0))
				if not lateral:
					_salir_enredadera()
					velocity.x = dir_x * 140.0
					return
		else:
			_vine_dir_hold_t = 0.0
		if dir_y != 0:
			_trepar_hold_t += delta
		else:
			_trepar_hold_t = 0.0
			_vine_particulas_timer = 0.0
		var cs_base: float = float(_enredadera_actual.get("climb_speed")) if _enredadera_actual.get("climb_speed") != null else 260.0
		var turbo_t: float = clampf((_trepar_hold_t - TREPAR_TURBO_INICIO) / TREPAR_TURBO_RAMP, 0.0, 1.0) if _trepar_hold_t > TREPAR_TURBO_INICIO else 0.0
		var cs: float = cs_base * lerpf(1.0, TREPAR_TURBO_MULT, turbo_t)
		var accel := lerpf(TREPAR_ACCEL, TREPAR_ACCEL_TURBO, turbo_t)
		var meta: float = dir_y * cs
		if dir_y > 0:
			meta *= TREPAR_DOWN_MULT
		var bloqueado_arriba: bool = dir_y < 0 and test_move(global_transform, Vector2(0, -(cs * delta + 1.0)))
		if bloqueado_arriba:
			velocity.y = minf(velocity.y, 0.0)
		elif dir_y != 0:
			velocity.y = move_toward(velocity.y, meta, accel * delta)
		else:
			velocity.y = lerpf(velocity.y, 0.0, TREPAR_STOP_LERP * delta)
		velocity.x = 0.0
		_gravity_override = 0.0
		var dx: float = _enredadera_actual.global_position.x - global_position.x
		if absf(dx) > 1.0:
			var paso := clampf(dx, -260.0 * delta, 260.0 * delta)
			if not test_move(global_transform, Vector2(paso, 0)):
				global_position.x += paso
		_sonido_liana(dir_y, delta)
		if dir_y != 0 and absf(velocity.y) > 20.0:
			visual.skew = lerpf(visual.skew, deg_to_rad(3.0) * -dir_y, 6.0 * delta)
		if dir_y != 0 and absf(velocity.y) > 80.0 and _vine_particulas_timer <= 0.0:
			_emitir_polvo(0.45)
			if _trepar_hold_t > 0.6:
				_emitir_burst_hojas()
				_vine_particulas_timer = 0.55
			else:
				_vine_particulas_timer = 0.9
		return
	if _trepado_cooldown > 0.0:
		return
	var quiere_trepar: bool = Input.is_action_pressed("move_up") or Input.is_action_pressed("move_down")
	if not is_on_floor():
		quiere_trepar = quiere_trepar or Input.is_action_pressed("jump") or _vine_buffer_timer > 0.0
	if not quiere_trepar:
		return
	for e in get_tree().get_nodes_in_group("enredadera"):
		if not is_instance_valid(e):
			continue
		var area := e as Area2D
		var alto2: float = float(area.get("alto")) if area.get("alto") != null else 400.0
		var ancho2: float = float(area.get("ancho")) if area.get("ancho") != null else 32.0
		var top2: float = area.global_position.y - alto2 * 0.5
		var bot2: float = area.global_position.y + alto2 * 0.5
		var is_overlap: bool = false
		if area is Area2D:
			is_overlap = (area as Area2D).get_overlapping_bodies().has(self)
		if not is_overlap:
			is_overlap = absf(global_position.x - area.global_position.x) < ancho2 * 0.5 + 48.0 and global_position.y > top2 - 48.0 and global_position.y < bot2 + 48.0
		if is_overlap and current_form == _forma_requerida_enredadera(area):
			_trepando = true
			_enredadera_actual = area
			_gravity_override = 0.0
			velocity.y = 0.0
			velocity.x = 0.0
			_vine_dir_hold_t = 0.0
			var paso_agarre: float = area.global_position.x - global_position.x
			if not test_move(global_transform, Vector2(paso_agarre, 0)):
				global_position.x = area.global_position.x
			if not is_on_floor():
				squash_y(0.12, 0.12)
				_emitir_burst_hojas()
			_sfx(sonido_liana_agarrar, volumen_liana_db, 0.1)
			break


func _salir_enredadera() -> void:
	if _liana_loop != null:
		_liana_loop.stop()
	if _trepando and not is_on_floor():
		_emitir_burst_hojas()   # al soltar la liana también vuelan hojitas
	_trepando = false
	_enredadera_actual = null
	_gravity_override = -1.0
	_trepado_cooldown = maxf(_trepado_cooldown, TREPAR_SALIR_COOLDOWN)


func _en_combate() -> bool:
	for n in get_tree().get_nodes_in_group("encounter"):
		if int(n.get("estado")) == 1:
			return true
	return false


func _progresion() -> Node:
	return get_node("/root/Progresion")


# ------------------------------------------------------------ audio del jugador

func _sfx(stream: AudioStream, volumen_db: float, variacion_tono: float = 0.0) -> void:
	if stream == null:
		return
	var audio := get_node_or_null("/root/AudioManager")
	if audio != null:
		audio.play_sfx(stream, volumen_db, variacion_tono)


func _sfx_de(lista: Array[AudioStream], volumen_db: float, variacion_tono: float = 0.08) -> void:
	if not lista.is_empty():
		_sfx(lista.pick_random(), volumen_db, variacion_tono)


## Pasos en tiempo real: suenan (y levantan polvo) en los frames de la animación en
## que el pie toca el suelo, así acompañan la velocidad real de la animación.
## Apoya la base visible de cada frame en el piso: los frames de distinto alto ya no hacen flotar ni hundir al personaje.
func _anclar_pies() -> void:
	var aj := _ajuste_frame()
	if not anclar_pies or visual == null or visual.sprite_frames == null:
		if visual != null:
			visual.offset.y = aj.y
		return
	var sf := visual.sprite_frames
	if not sf.has_animation(visual.animation):
		return
	var tex := sf.get_frame_texture(visual.animation, visual.frame)
	if tex == null:
		return
	var s := maxf(absf(_base_sprite_scale.y), 0.01)
	var col_alto: float = collision_shape.shape.size.y
	var falta := col_alto * 0.5 - 7.5 + pies_hundidos
	visual.offset.y = falta / s - (tex.get_height() * 0.5 - Pies.relleno_inferior(tex)) + aj.y


func _ajuste_frame() -> Vector2:
	if ajuste_frames.is_empty() or visual == null:
		return Vector2.ZERO
	var clave := "%s:%d" % [visual.animation, visual.frame]
	if ajuste_frames.has(clave):
		return ajuste_frames[clave]
	var solo_anim := String(visual.animation)
	if ajuste_frames.has(solo_anim):
		return ajuste_frames[solo_anim]
	return Vector2.ZERO


func _on_frame_animacion() -> void:
	_anclar_pies()
	if _trepando:
		return
	var anim := visual.animation
	if anim == "murci_volar" or anim == "murci_run":
		# El Murciélago no pisa: aletea al volar (y en el suelo, al avanzar).
		if visual.frame == 0 and visual.speed_scale > 0.0 and (not is_on_floor() or absf(velocity.x) > 30.0):
			_sfx_de(aleteos, volumen_aleteo_db)
		return
	# Tolerancia de coyote: los micro-despegues por irregularidades del terreno no cortan el paso.
	var apoyado := is_on_floor() or (_t_sin_suelo < 0.25 and velocity.y > -60.0)
	if not apoyado or absf(velocity.x) < 30.0:
		return
	var frames := PackedInt32Array()
	var lista: Array[AudioStream] = []
	var vol := volumen_pasos_db
	var polvo_escala := 0.45
	match anim:
		"run":
			frames = pasos_frames_humano
			lista = pasos_humano
		"lobo_run":
			frames = pasos_frames_lobo
			lista = pasos_lobo
			vol -= 2.0
			polvo_escala = 0.35
		"oso_caminar":
			frames = pasos_frames_oso
			lista = pasos_oso
			vol = volumen_pasos_oso_db
			polvo_escala = 0.7
		_:
			return
	if not frames.has(visual.frame):
		return
	_sfx_de(lista, vol)
	_emitir_polvo(polvo_escala)
	if anim == "oso_caminar" and oso_paso_shake > 0.0:
		var cam := get_viewport().get_camera_2d()
		if cam != null and cam.has_method("shake"):
			cam.shake(oso_paso_shake, 0.08, Vector2(0, 1))


## n = número de salto dentro del aire (1 = desde el suelo, 2 = doble salto).
func _sonido_salto(n: int) -> void:
	match current_form:
		Form.MURCIELAGO:
			_sfx_de(aleteos, volumen_aleteo_db + 4.0)
		Form.LOBO:
			_sfx(sonido_doble_salto if n >= 2 else sonido_salto_lobo, volumen_salto_db, 0.06)
		Form.OSO:
			_sfx(sonido_salto_oso, volumen_salto_db, 0.05)
		_:
			_sfx(sonido_doble_salto if n >= 2 else sonido_salto_humano, volumen_salto_db, 0.06)


## Aterrizaje: más fuerte cuanto más rápido cae; el Oso siempre suena pesado.
func _sonido_aterrizaje(impacto: float) -> void:
	if impacto < aterrizaje_umbral or current_form == Form.MURCIELAGO:
		return
	var t := clampf((impacto - aterrizaje_umbral) / 900.0, 0.0, 1.0)
	var fuerte := t > 0.55 or current_form == Form.OSO
	_sfx(sonido_aterrizaje_fuerte if fuerte else sonido_aterrizaje_suave, lerpf(-18.0, -5.0, t), 0.06)


## Liana: crujidos al trepar y un loop de roce mientras se desliza hacia abajo.
func _sonido_liana(dir_y: int, delta: float) -> void:
	var bajando := dir_y > 0 and velocity.y > 120.0
	if bajando:
		if not _liana_loop.playing:
			_liana_loop.stream = sonido_liana_deslizar
			_liana_loop.play()
		_liana_loop.volume_db = volumen_liana_db + lerpf(-8.0, 2.0, clampf(velocity.y / 700.0, 0.0, 1.0))
		_liana_loop.pitch_scale = lerpf(0.9, 1.2, clampf(velocity.y / 900.0, 0.0, 1.0))
	elif _liana_loop.playing:
		_liana_loop.stop()
	_liana_trepar_t -= delta
	if dir_y < 0 and velocity.y < -60.0 and _liana_trepar_t <= 0.0:
		_liana_trepar_t = liana_trepar_intervalo
		_sfx_de(liana_trepar, volumen_liana_db - 2.0, 0.12)


## Transformación que no se puede hacer (bloqueada, en cooldown, sin espacio).
func _denegar_transformacion() -> void:
	if _denegar_cd > 0.0:
		return
	_denegar_cd = 0.3
	_sfx(sonido_transformacion_bloqueada, volumen_estado_db)
	transformacion_denegada.emit()
