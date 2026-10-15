extends Node2D
## Derrumbes del nivel. Fuera de la zona la cueva solo se queja de vez en cuando (vibración leve + alguna piedra);
## entre `inicio` y `fin` (en x) el techo se viene abajo de verdad: shake constante y fuerte, lluvia de escombros y
## rocas con aviso (una sombra en el piso) que caen sobre la posición del jugador y hacen daño: quedarse quieto
## no es opción, hay que avanzar. `fin` es el nodo donde se corta; el arranque lo da un `derrumbe_disparador`
## (Area2D que llama a `iniciar()`). Si se asigna `inicio`, arranca al pasar por su x. Antes del disparo la cueva no tiembla.

@export var inicio: Node2D                          ## (opcional) arranca al pasar por la x de este nodo; vacío = lo dispara `iniciar()`
@export var fin: Node2D                             ## y se corta al llegar a la x de este nodo (o a su y si `fin_por_altura`)
@export var fin_por_altura := false                 ## cortar por altura: dura hasta llegar a la y de `fin`, en la dirección en que queda respecto del punto de arranque (bajadas por lianas: el final está abajo; trepadas: arriba)

@export_group("Zona de derrumbe")
@export var pausa_min := 0.8                        ## s entre oleadas de escombros
@export var pausa_max := 1.5
@export var primera_espera := 0.6                   ## s hasta la primera oleada tras entrar
@export var fuerza_shake := 30.0                    ## shake constante mientras dura la zona (>= 6 desprende polvo del techo)
@export var intervalo_shake := 0.18                 ## s entre sacudidas (cada una dura un poco más, así no hay huecos)
@export var duracion_oleada := 1.4                  ## s en que se reparten los escombros de cada oleada
@export var escombros_por_oleada := Vector2i(32, 48)
@export var dispersion := Vector2(-950.0, 300.0)    ## x relativa al jugador donde caen, en sentido de avance (negativo = detrás: casi todo cae atrás, quedarse o retroceder castiga)
@export var color_escombro := Color(0.28, 0.29, 0.36)

@export_group("Rocas que persiguen")
@export var rocas_dirigidas := true                 ## cae una roca con aviso sobre donde estás: hay que seguir avanzando
@export var pausa_roca_min := 0.8                   ## s entre rocas dirigidas
@export var pausa_roca_max := 1.3
@export var aviso_s := 0.9                          ## s que dura la sombra de aviso antes del impacto
@export var anticipo := 0.35                        ## s de velocidad del jugador que se adelanta al apuntar
@export var dano_roca := 12
@export var radio_dano := 80.0                      ## px de ancho (a cada lado) del impacto que hacen daño

@export_group("Ambiente (fuera de la zona)")
@export var ambiente_activo := true
@export var ambiente_pausa_min := 9.0               ## s entre vibraciones leves
@export var ambiente_pausa_max := 20.0
@export var ambiente_fuerza := 3.5
@export var ambiente_duracion := 0.6
@export var ambiente_piedras := Vector2i(1, 3)      ## piedritas que caen con cada vibración

@export_group("Ritmo del shake")
@export var shake_valle := 0.7                     ## fracción de `fuerza_shake` entre oleadas (1 = shake constante como antes)
@export var shake_pico := 1.6                      ## múltiplo de `fuerza_shake` en el pico de cada oleada
@export var subida_s := 1.5                         ## s en llegar a la intensidad plena al entrar (0 = de golpe)
@export var aviso_oleada := 0.4                     ## s antes de cada oleada: crujido y polvo del techo (la señal de que viene)

@export_group("Sonido")
@export var sonido_retumbo: AudioStream = preload("res://assets/audio/ambiente_nivel2/cueva_rumor.wav")
@export var sonido_aviso: AudioStream = preload("res://assets/audio/sfx/gen/fragil_crujir.wav")
@export var sonido_impacto: AudioStream = preload("res://assets/audio/sfx/gen/aterrizaje_fuerte.wav")
@export var sonido_piedra: AudioStream = preload("res://assets/audio/sfx/gen/proyectil_impacto.wav")
@export var volumen_retumbo_db := -4.0
@export var volumen_aviso_db := -2.0
@export var volumen_impacto_db := 4.0
@export var volumen_piedra_db := -8.0
## Multiplica el tono de las piedras que caen y chocan: más bajo = más grave y pesado (1 = tono original).
@export_range(0.3, 1.2, 0.05) var tono_graves := 0.6

@export_group("Final")
@export var final_fuerza := 2.0                     ## múltiplo de `fuerza_shake` del último retumbo al terminar
@export var final_fade := 1.6                       ## s en apagarse el retumbo y el polvo al terminar

@export_group("Atmósfera y feedback")
@export var polvo_suspension := true                ## polvo fino que flota en el aire mientras dura el derrumbe
@export var oscurecer_oleada := 0.28                ## cuánto se oscurece la pantalla al caer cada oleada (0 = nada)
@export var oscurecer_impacto := 0.18               ## y al impactar una roca grande
@export var empuje_roca := 280.0                    ## px/s con que una roca que te golpea te empuja lejos del impacto (0 = sin empuje)
@export var casi_golpe_ancho := 2.4                 ## múltiplo de `radio_dano` dentro del cual una roca que cae "casi te da" (sacudida + polvo)
@export_group("Presión (obligar a avanzar)")
@export var presion_activa := true
@export var presion_vel_min := 90.0                 ## px/s de avance (en x, o de trepada en y) por debajo de los cuales sube la presión
@export var presion_sube := 0.8                     ## por segundo mientras te frenas (retroceder sube el doble)
@export var presion_baja := 1.8                     ## por segundo mientras avanzas
@export var presion_sonido_db := 9.0                ## dB extra del retumbo con presión máxima
@export var presion_sombra_base := 0.22             ## opacidad de la penumbra de atrás al avanzar
@export var presion_sombra_max := 0.7               ## y con presión máxima
@export var presion_sombra_ancho := 760.0           ## px de pantalla que cubre la penumbra
@export var max_escombros := 170                     ## tope de escombros sueltos vivos a la vez (0 = sin tope; las rocas dirigidas no cuentan)

var _activo := false
var _disparado := false
var _terminado := false                             # al llegar a `fin` el evento se apaga para siempre (no vuelve a vibrar al saltar)
var _espera := 0.0
var _t_shake := 0.0
var _t_roca := 0.0
var _t_amb := 8.0
var _jugador: Node2D
var _t_activo := 0.0                                # s desde que arrancó el derrumbe fuerte (para la subida de intensidad)
var _pico := 0.0                                    # 1 al empezar una oleada y decae: marca los picos del shake
var _avisada := false                               # ya sonó el aviso de la próxima oleada
var _retumbo: AudioStreamPlayer
var _retumbo_vivo := false                          # el retumbo de fondo debe seguir sonando
var _t_ult_piedra := 0                              # ms del último sonido de piedra (para no saturar)
var _y_arranque := INF                              # y del jugador al arrancar (decide si `fin_por_altura` es bajada o trepada)
var _vivos := 0                                     # escombros sueltos vivos ahora mismo (para el tope)
var _dim := 0.0                                     # oscurecimiento actual de la pantalla (decae solo)
var _velo: ColorRect
var _polvo: CPUParticles2D
var _sombra: TextureRect                            # penumbra del lado de atrás: el derrumbe que te persigue
var _dir := 1.0                                     # sentido de avance en x (hacia `fin`)
var _presion := 0.0                                 # 0..1: sube si el jugador se frena o retrocede, baja al avanzar


func _ready() -> void:
	set_physics_process(true)
	# Retumbo de fondo: un reproductor propio que se repite mientras dura el derrumbe fuerte.
	_retumbo = AudioStreamPlayer.new()
	_retumbo.stream = sonido_retumbo
	_retumbo.bus = &"SFX"
	_retumbo.volume_db = -80.0
	add_child(_retumbo)
	_retumbo.finished.connect(func() -> void:
		if _retumbo_vivo:
			_retumbo.play())
	# Velo negro bajo el HUD (capa 5 < 10): se oscurece un instante con cada oleada o impacto fuerte.
	var capa := CanvasLayer.new()
	capa.layer = 5
	add_child(capa)
	_velo = ColorRect.new()
	_velo.color = Color(0, 0, 0, 0)
	_velo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_velo.set_anchors_preset(Control.PRESET_FULL_RECT)
	capa.add_child(_velo)
	# Penumbra del lado de atrás (degradado negro → transparente): se ve por dónde viene el derrumbe.
	var grad := Gradient.new()
	grad.set_color(0, Color(0, 0, 0, 1))
	grad.set_color(1, Color(0, 0, 0, 0))
	var gt := GradientTexture2D.new()
	gt.gradient = grad
	gt.fill_from = Vector2(0.0, 0.5)
	gt.fill_to = Vector2(1.0, 0.5)
	gt.width = 256
	gt.height = 4
	_sombra = TextureRect.new()
	_sombra.texture = gt
	_sombra.stretch_mode = TextureRect.STRETCH_SCALE
	_sombra.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_sombra.modulate.a = 0.0
	capa.add_child(_sombra)
	# Polvo fino en suspensión alrededor del jugador (solo mientras dura el derrumbe fuerte).
	_polvo = CPUParticles2D.new()
	_polvo.emitting = false
	_polvo.amount = 70
	_polvo.lifetime = 3.2
	_polvo.local_coords = false
	_polvo.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	_polvo.emission_rect_extents = Vector2(760.0, 320.0)
	_polvo.direction = Vector2(0.3, 1.0)
	_polvo.spread = 40.0
	_polvo.gravity = Vector2(0.0, 14.0)
	_polvo.initial_velocity_min = 6.0
	_polvo.initial_velocity_max = 28.0
	_polvo.scale_amount_min = 2.0
	_polvo.scale_amount_max = 5.5
	_polvo.color = Color(0.78, 0.74, 0.7, 0.16)
	_polvo.z_index = 6
	add_child(_polvo)


## Lo llama el `derrumbe_disparador`: el derrumbe fuerte arranca ya y dura hasta la x de `fin`.
func iniciar() -> void:
	_disparado = true
	var j := get_tree().get_first_node_in_group("player") as Node2D
	if j != null:
		_y_arranque = j.global_position.y


## Con `fin_por_altura`: ¿el jugador todavía no llegó a la y de `fin`? Si el final queda más abajo que el punto de
## arranque se baja (dura mientras y < fin.y); si queda más arriba se trepa (dura mientras y > fin.y).
func _antes_del_fin_por_altura() -> bool:
	if _y_arranque == INF:
		_y_arranque = _jugador.global_position.y
	var y := _jugador.global_position.y
	return y > fin.global_position.y if fin.global_position.y < _y_arranque else y < fin.global_position.y


## Pulso suelto (lo usa la cinemática del disparador): una sacudida y `piedras` escombros alrededor del jugador.
func pulso(fuerza: float, duracion: float, piedras: int, r_min := 4.0, r_max := 10.0) -> void:
	if _terminado:
		return
	if not is_instance_valid(_jugador):
		_jugador = get_tree().get_first_node_in_group("player") as Node2D
	_sacudir(fuerza, duracion)
	_sfx(sonido_retumbo, volumen_retumbo_db - 6.0 + clampf(fuerza - 3.0, 0.0, 14.0) * 0.6, 0.05, 1.0)
	for i in piedras:
		get_tree().create_timer(randf_range(0.05, duracion), false).timeout.connect(_soltar_escombro.bind(r_min, r_max, true))


func _physics_process(delta: float) -> void:
	if fin == null or _terminado:
		return
	if not is_instance_valid(_jugador):
		_jugador = get_tree().get_first_node_in_group("player") as Node2D
		if _jugador == null:
			return
	var x := _jugador.global_position.x
	if _polvo != null:
		_polvo.global_position = _jugador.global_position + Vector2(0.0, -120.0)
	if _dim > 0.0:
		_dim = maxf(_dim - delta * 0.55, 0.0)
		if _velo != null:
			_velo.color.a = _dim
	var antes_del_fin := _antes_del_fin_por_altura() if fin_por_altura else x < fin.global_position.x
	var dentro := antes_del_fin and (x >= inicio.global_position.x if inicio != null else _disparado)
	if dentro and not _activo:
		_activo = true
		_espera = primera_espera
		_t_shake = 0.0
		_t_roca = pausa_roca_max
		_t_activo = 0.0
		_pico = 0.0
		_avisada = false
		_retumbo_vivo = true
		_presion = 0.0
		var d := fin.global_position.x - _jugador.global_position.x
		_dir = -1.0 if d < 0.0 else 1.0
		_colocar_sombra()
		if _polvo != null:
			_polvo.emitting = polvo_suspension
		if _retumbo != null:
			_retumbo.volume_db = -80.0
			_retumbo.play()
	elif not dentro and _activo:
		_activo = false
		_terminado = true   # llegó a las lianas: se acabó, ni zona ni ambiente
		_final()
		return
	if not _activo:
		if inicio != null or _disparado:
			_ambiente(delta)
		return
	# Ritmo del shake: sube al entrar, valle entre oleadas y pico cuando cae cada una.
	_t_activo += delta
	_pico = maxf(_pico - delta * 1.6, 0.0)
	var subida := clampf(0.35 + 0.65 * _t_activo / subida_s, 0.0, 1.0) if subida_s > 0.0 else 1.0
	var nivel := lerpf(shake_valle, shake_pico, _pico)
	_t_shake -= delta
	if _t_shake <= 0.0:
		_t_shake = intervalo_shake
		_sacudir(fuerza_shake * subida * nivel, intervalo_shake * 1.8)
	if _retumbo != null:
		_retumbo.volume_db = volumen_retumbo_db + 6.0 * _pico + (subida - 1.0) * 12.0 + presion_sonido_db * _presion
	_actualizar_presion(delta, subida)
	_espera -= delta
	if not _avisada and _espera <= aviso_oleada:
		_avisada = true
		_aviso_oleada()
	if _espera <= 0.0:
		_espera = randf_range(pausa_min, pausa_max)
		_avisada = false
		_pico = 1.0
		_oleada()
	if rocas_dirigidas:
		_t_roca -= delta
		if _t_roca <= 0.0:
			_t_roca = randf_range(pausa_roca_min, pausa_roca_max)
			_roca_dirigida()


## Coloca la penumbra del lado contrario al avance (izquierda si se avanza hacia la derecha).
func _colocar_sombra() -> void:
	if _sombra == null:
		return
	var atras_izq := _dir > 0.0
	_sombra.set_anchors_preset(Control.PRESET_LEFT_WIDE if atras_izq else Control.PRESET_RIGHT_WIDE)
	if atras_izq:
		_sombra.offset_left = 0.0
		_sombra.offset_right = presion_sombra_ancho
	else:
		_sombra.offset_right = 0.0
		_sombra.offset_left = -presion_sombra_ancho
	_sombra.flip_h = not atras_izq


## Presión: sube si el jugador se frena o retrocede, baja al avanzar. Refuerza el retumbo y la penumbra de atrás.
func _actualizar_presion(delta: float, subida: float) -> void:
	if not presion_activa:
		return
	var vx := 0.0
	var vy := 0.0
	if "velocity" in _jugador:
		vx = float(_jugador.velocity.x) * _dir
		vy = absf(float(_jugador.velocity.y))
	var avanza := vx > presion_vel_min or vy > presion_vel_min
	if avanza:
		_presion = maxf(_presion - presion_baja * delta, 0.0)
	else:
		_presion = minf(_presion + presion_sube * (2.0 if vx < -presion_vel_min * 0.3 else 1.0) * delta, 1.0)
	if _sombra != null:
		_sombra.modulate.a = lerpf(presion_sombra_base, presion_sombra_max, _presion) * subida


func _sacudir(fuerza: float, duracion: float) -> void:
	var cam := get_viewport().get_camera_2d()
	if cam != null and cam.has_method("shake"):
		cam.shake(fuerza, duracion)


## Reproduce un sonido puntual por el AudioManager (si no está, no suena).
func _sfx(stream: AudioStream, db: float, variacion := 0.0, tono := 1.0) -> void:
	var am := get_node_or_null("/root/AudioManager")
	if am != null and stream != null:
		am.play_sfx(stream, db, variacion, tono)


## Sonido de un impacto en `pos`: más débil cuanto más lejos del jugador; las piedras chicas se espacian.
func sonar_impacto(pos: Vector2, grande: bool) -> void:
	var lejos := 0.0
	if is_instance_valid(_jugador):
		lejos = pos.distance_to(_jugador.global_position)
	var atenuar := -clampf(lejos / 220.0, 0.0, 12.0)
	if grande:
		_oscurecer(oscurecer_impacto * clampf(1.2 - lejos / 900.0, 0.0, 1.0))
		_sfx(sonido_impacto, volumen_impacto_db + 2.0 + atenuar, 0.08, randf_range(0.78, 0.95) * tono_graves)
		_sfx(sonido_retumbo, volumen_impacto_db - 2.0 + atenuar, 0.05, randf_range(0.6, 0.75) * minf(tono_graves * 1.4, 1.0))   # capa grave que le da peso
		return
	var ahora := Time.get_ticks_msec()
	if ahora - _t_ult_piedra < 70:
		return
	_t_ult_piedra = ahora
	_sfx(sonido_piedra, volumen_piedra_db + 3.0 + atenuar, 0.1, randf_range(0.8, 1.1) * tono_graves)   # grave suena más flojo: se sube un poco


## Oscurece la pantalla un instante (el velo decae solo); nunca baja un oscurecimiento mayor en curso.
func _oscurecer(cantidad: float) -> void:
	_dim = maxf(_dim, cantidad)


## Una roca cayó cerca del jugador sin tocarlo: sacudida extra, polvo y un sonido seco ("casi me da").
func casi_golpe(pos: Vector2, fuerza: float) -> void:
	_sacudir(fuerza, 0.3)
	_sfx(sonido_piedra, volumen_piedra_db + 11.0, 0.1, randf_range(0.7, 0.9) * tono_graves)
	if is_instance_valid(_jugador):
		Burst.emitir(self, _jugador.global_position + Vector2(0.0, -60.0), color_escombro.lightened(0.3), 12, 1.1)
	_oscurecer(oscurecer_impacto * 0.6)


## Contador de escombros sueltos vivos (lo llaman ellos al nacer y morir).
func registrar_escombro(delta: int) -> void:
	_vivos = maxi(_vivos + delta, 0)


## Señal de la próxima oleada: crujido, un retumbo corto y polvo que se desprende del techo.
func _aviso_oleada() -> void:
	_sacudir(fuerza_shake * shake_pico * 0.8, maxf(aviso_oleada, 0.15))
	_sfx(sonido_aviso, volumen_aviso_db, 0.1, randf_range(0.85, 1.0))
	for i in 6:
		get_tree().create_timer(randf_range(0.0, maxf(aviso_oleada, 0.1)), false).timeout.connect(_soltar_escombro.bind(2.5, 5.0, true))


## Cierre del derrumbe: un último retumbo grande, nube de polvo y escombros inofensivos; el retumbo y la
## sacudida se apagan solos en `final_fade` s. (No hace daño: es solo despedida.)
func _final() -> void:
	_sacudir(fuerza_shake * final_fuerza, 0.9)
	_sfx(sonido_impacto, volumen_impacto_db + 4.0, 0.0, 0.7 * tono_graves)
	_retumbo_vivo = false
	_oscurecer(oscurecer_oleada * 1.4)   # el último golpe del derrumbe
	if _sombra != null:
		create_tween().tween_property(_sombra, "modulate:a", 0.0, maxf(final_fade, 0.1))
	if _polvo != null:
		_polvo.emitting = false   # el polvo que ya flota se asienta solo
	if _retumbo != null and _retumbo.playing:
		var tw := create_tween()
		tw.tween_property(_retumbo, "volume_db", -60.0, maxf(final_fade, 0.1))
		tw.tween_callback(_retumbo.stop)
	if not is_instance_valid(_jugador):
		return
	var c := color_escombro.lightened(0.25)
	for i in 4:
		var p := _jugador.global_position + Vector2(randf_range(-420.0, 420.0), randf_range(-260.0, -60.0))
		get_tree().create_timer(i * 0.18, false).timeout.connect(func() -> void:
			if is_instance_valid(self) and is_inside_tree():   # el nivel puede cambiar antes de que dispare
				Burst.emitir(self, p, c, 26, 2.0))
	Burst.onda(self, _jugador.global_position + Vector2(0, -80), c, 280.0, 1.0, 6.0)
	for i in 10:
		get_tree().create_timer(randf_range(0.1, final_fade), false).timeout.connect(_soltar_escombro.bind(7.0, 18.0, true))


## Fuera de la zona: de vez en cuando una vibración leve y alguna piedra.
func _ambiente(delta: float) -> void:
	if not ambiente_activo:
		return
	_t_amb -= delta
	if _t_amb > 0.0:
		return
	_t_amb = randf_range(ambiente_pausa_min, ambiente_pausa_max)
	_sacudir(ambiente_fuerza, ambiente_duracion)
	_sfx(sonido_retumbo, volumen_retumbo_db - 8.0, 0.05, 1.15)   # la cueva se queja a lo lejos
	var n := randi_range(ambiente_piedras.x, ambiente_piedras.y)
	for i in n:
		get_tree().create_timer(randf_range(0.1, ambiente_duracion + 0.4), false).timeout.connect(_soltar_escombro.bind(4.0, 10.0, true))


func _oleada() -> void:
	_oscurecer(oscurecer_oleada)
	var n := randi_range(escombros_por_oleada.x, escombros_por_oleada.y)
	for i in n:
		get_tree().create_timer(randf_range(0.0, duracion_oleada), false).timeout.connect(_soltar_escombro.bind(9.0, 26.0, false))


func _soltar_escombro(r_min: float, r_max: float, ambiente: bool) -> void:
	if not is_instance_valid(_jugador) or (not ambiente and not _activo):
		return
	if max_escombros > 0 and _vivos >= max_escombros:
		return
	var x := _jugador.global_position.x + (randf_range(-450.0, 450.0) if ambiente else randf_range(dispersion.x, dispersion.y) * _dir)
	var techo := _techo_sobre(Vector2(x, _jugador.global_position.y))
	if techo == INF:
		return   # sin techo sobre esa x: no cae nada
	var e := _Escombro.new()
	e.radio = randf_range(r_min, r_max)
	e.color = color_escombro.lightened(randf_range(-0.05, 0.12))
	e.global_position = Vector2(x, techo + 26.0)
	e.vel = Vector2(randf_range(-40.0, 40.0), 0.0)
	e.giro = randf_range(-6.0, 6.0)
	e.evento = self
	get_parent().add_child(e)


func _techo_sobre(desde: Vector2) -> float:
	var q := PhysicsRayQueryParameters2D.create(desde, desde + Vector2(0, -1600), 1)
	var h := get_world_2d().direct_space_state.intersect_ray(q)
	return INF if h.is_empty() else float((h.position as Vector2).y)


## Roca grande con sombra de aviso sobre la posición (adelantada) del jugador.
func _roca_dirigida() -> void:
	if not is_instance_valid(_jugador):
		return
	var vx := 0.0
	if "velocity" in _jugador:
		vx = float(_jugador.velocity.x)
	var x := _jugador.global_position.x + vx * anticipo
	var espacio := get_world_2d().direct_space_state
	var arriba := Vector2(x, _jugador.global_position.y - 60.0)
	var piso := espacio.intersect_ray(PhysicsRayQueryParameters2D.create(arriba, arriba + Vector2(0, 900), 1))
	if piso.is_empty():
		return
	var techo := _techo_sobre(arriba)
	if techo == INF:
		return
	var a := _Aviso.new()
	a.global_position = piso.position as Vector2
	a.duracion = aviso_s
	a.ancho = radio_dano
	get_parent().add_child(a)
	_sfx(sonido_aviso, volumen_aviso_db, 0.1, randf_range(0.9, 1.1))
	var grieta := _Grieta.new()
	grieta.global_position = Vector2(x, techo)
	grieta.duracion = aviso_s
	get_parent().add_child(grieta)
	var n_polvo := maxi(int(aviso_s / 0.07), 1)
	for i in n_polvo:
		get_tree().create_timer(aviso_s * float(i) / float(n_polvo), false).timeout.connect(_caer_polvo.bind(x, techo))
	var cuerpo := {"x": x, "techo": techo}
	get_tree().create_timer(aviso_s, false).timeout.connect(_caer_roca_dirigida.bind(cuerpo))


func _caer_roca_dirigida(d: Dictionary) -> void:
	var e := _Escombro.new()
	e.radio = 30.0
	e.color = color_escombro.lightened(0.06)
	e.global_position = Vector2(float(d["x"]), float(d["techo"]) + 30.0)
	e.vel = Vector2(0.0, 900.0)
	e.giro = randf_range(-4.0, 4.0)
	e.dano = dano_roca
	e.radio_dano = radio_dano
	e.sacudir = fuerza_shake * 0.5
	e.evento = self
	get_parent().add_child(e)


## Sombra de aviso en el piso: crece y pulsa hasta el impacto.
class _Aviso extends Node2D:
	var duracion := 0.9
	var ancho := 80.0
	var _t := 0.0

	func _ready() -> void:
		z_index = 3

	func _process(delta: float) -> void:
		_t += delta
		queue_redraw()
		if _t >= duracion + 0.1:
			queue_free()

	func _draw() -> void:
		var k := clampf(_t / maxf(duracion, 0.01), 0.0, 1.0)
		var pulso := 0.5 + 0.5 * sin(_t * 22.0)
		var rx := ancho * (0.4 + 0.6 * k)
		var pts := PackedVector2Array()
		for i in 20:
			var a := TAU * float(i) / 20.0
			pts.append(Vector2(cos(a) * rx, sin(a) * rx * 0.18 - 3.0))
		draw_colored_polygon(pts, Color(0.05, 0.03, 0.04, 0.55 * k))
		draw_polyline(pts + PackedVector2Array([pts[0]]), Color(0.95, 0.35, 0.2, (0.35 + 0.5 * pulso) * k), 2.5)


## Polvo y piedritas que se sueltan del techo en el punto donde va a caer una roca (señal de que se afloja).
func _caer_polvo(x: float, techo: float) -> void:
	if max_escombros > 0 and _vivos >= max_escombros + 30:
		return
	var e := _Escombro.new()
	e.radio = randf_range(2.2, 4.2)
	e.color = color_escombro.lightened(randf_range(0.05, 0.2))
	e.global_position = Vector2(x + randf_range(-26.0, 26.0), techo + 6.0)
	e.vel = Vector2(randf_range(-25.0, 25.0), randf_range(20.0, 90.0))
	e.giro = randf_range(-8.0, 8.0)
	get_parent().add_child(e)


## Grieta en el techo sobre la roca que va a caer: se abre durante el aviso.
class _Grieta extends Node2D:
	var duracion := 0.9
	var _t := 0.0
	var _zig := PackedFloat32Array()

	func _ready() -> void:
		z_index = 3
		for i in 6:
			_zig.append(randf_range(-12.0, 12.0))

	func _process(delta: float) -> void:
		_t += delta
		queue_redraw()
		if _t >= duracion + 0.25:
			queue_free()

	func _draw() -> void:
		var k := clampf(_t / maxf(duracion, 0.01), 0.0, 1.0)
		var largo := 70.0 * k
		var a := clampf(1.0 - maxf(_t - duracion, 0.0) / 0.25, 0.0, 1.0)
		var pts := PackedVector2Array([Vector2.ZERO])
		for i in _zig.size():
			var f := float(i + 1) / float(_zig.size())
			pts.append(Vector2(_zig[i] * f, largo * f))
		draw_polyline(pts, Color(0.02, 0.02, 0.03, 0.85 * a), 5.0)
		draw_polyline(pts, Color(0.95, 0.5, 0.3, 0.45 * a * k), 1.6)


## Anillo de polvo aplastado contra el piso en un impacto fuerte.
class _Onda extends Node2D:
	var radio := 110.0
	var color := Color(0.5, 0.5, 0.55)
	var _t := 0.0
	const DUR := 0.4

	func _ready() -> void:
		z_index = 5

	func _process(delta: float) -> void:
		_t += delta
		queue_redraw()
		if _t >= DUR:
			queue_free()

	func _draw() -> void:
		var k := clampf(_t / DUR, 0.0, 1.0)
		var r := radio * (1.0 - pow(1.0 - k, 3.0))
		var a := 1.0 - k
		var pts := PackedVector2Array()
		for i in 24:
			var an := TAU * float(i) / 24.0
			pts.append(Vector2(cos(an) * r, sin(an) * r * 0.16 - 4.0))
		draw_colored_polygon(pts, Color(color.r, color.g, color.b, 0.18 * a))
		draw_polyline(pts + PackedVector2Array([pts[0]]), Color(color.r, color.g, color.b, 0.7 * a), 3.0)


## Pedazo de roca que salta del impacto, rebota una vez y se desvanece.
class _Pedazo extends Node2D:
	var radio := 6.0
	var color := Color(0.3, 0.3, 0.38)
	var vel := Vector2.ZERO
	var _t := 0.0
	var _rebotes := 0
	var _giro := randf_range(-9.0, 9.0)
	var _puntos := PackedVector2Array()

	func _ready() -> void:
		z_index = 5
		for i in 5:
			var an := TAU * float(i) / 5.0
			_puntos.append(Vector2(cos(an), sin(an)) * radio * randf_range(0.6, 1.1))
		queue_redraw()

	func _draw() -> void:
		draw_colored_polygon(_puntos, color)

	func _physics_process(delta: float) -> void:
		_t += delta
		if _t >= 0.75:
			queue_free()
			return
		modulate.a = clampf(1.0 - (_t - 0.4) / 0.35, 0.0, 1.0)
		vel.y += 1500.0 * delta
		rotation += _giro * delta
		var paso := vel * delta
		var q := PhysicsRayQueryParameters2D.create(global_position, global_position + paso + Vector2(0, radio), 1)
		var h := get_world_2d().direct_space_state.intersect_ray(q)
		if h.is_empty():
			global_position += paso
			return
		if _rebotes == 0 and vel.y > 150.0:
			_rebotes = 1
			global_position.y = (h.position as Vector2).y - radio
			vel = Vector2(vel.x * 0.6, -vel.y * 0.35)
		else:
			vel = Vector2.ZERO


## Roca que cae del techo y se deshace en polvo contra el piso. Las dirigidas (`dano` > 0) lastiman si caen sobre el jugador.
class _Escombro extends Node2D:
	var radio := 12.0
	var color := Color(0.3, 0.3, 0.38)
	var vel := Vector2.ZERO
	var giro := 0.0
	var dano := 0
	var radio_dano := 80.0
	var sacudir := 0.0
	var evento: Node                                   # el `derrumbe_evento` (para el sonido de los impactos)
	var _puntos := PackedVector2Array()
	var _faceta := PackedVector2Array()                # polígono más claro sobre la roca
	var _estela := PackedVector2Array()                # últimas posiciones (globales) de las rocas grandes: dejan estela

	func _ready() -> void:
		z_index = 4
		# Cada roca es distinta: 5 a 9 vértices, algo achatada o alargada y con una faceta clara (volumen).
		var n := randi_range(5, 9)
		var achata := Vector2(randf_range(0.8, 1.3), randf_range(0.75, 1.0))
		for i in n:
			var a := TAU * i / n
			_puntos.append(Vector2(cos(a), sin(a)) * achata * radio * randf_range(0.6, 1.12))
			_faceta.append(_puntos[i] * 0.5 + Vector2(-0.18, -0.22) * radio)
		if dano <= 0 and evento != null:
			evento.registrar_escombro(1)
		queue_redraw()

	func _exit_tree() -> void:
		if dano <= 0 and evento != null and is_instance_valid(evento):
			evento.registrar_escombro(-1)

	func _draw() -> void:
		var m := _estela.size()
		for i in range(m - 1):
			var k := float(i + 1) / float(m)
			var c := Color(0.62, 0.58, 0.52, 0.32 * k)
			draw_line(to_local(_estela[i]), to_local(_estela[i + 1]), c, radio * 0.9 * k)
		draw_colored_polygon(_puntos, color)
		if _faceta.size() >= 3 and radio >= 8.0:
			draw_colored_polygon(_faceta, color.lightened(0.16))
		draw_polyline(_puntos + PackedVector2Array([_puntos[0]]), color.darkened(0.45), 2.0)

	func _physics_process(delta: float) -> void:
		vel.y += 1900.0 * delta
		rotation += giro * delta
		var paso := vel * delta
		var q := PhysicsRayQueryParameters2D.create(global_position, global_position + paso + Vector2(0, radio), 1)
		var h := get_world_2d().direct_space_state.intersect_ray(q)
		if not h.is_empty():
			_impacto(h.position as Vector2)
			queue_free()
			return
		global_position += paso
		if dano > 0:
			_estela.append(global_position)
			if _estela.size() > 7:
				_estela.remove_at(0)
			queue_redraw()
		if vel.y > 2600.0 and dano <= 0:
			queue_free()

	func _impacto(p: Vector2) -> void:
		Burst.emitir(self, p, color.lightened(0.2), 10 if dano <= 0 else 26, 0.8 if dano <= 0 else 1.6)
		if evento != null and is_instance_valid(evento) and (dano > 0 or radio >= 12.0):
			evento.sonar_impacto(p, dano > 0)
		if dano <= 0:
			return
		var padre := get_parent()
		var onda := _Onda.new()
		onda.global_position = p
		onda.radio = radio_dano * 1.5
		onda.color = color.lightened(0.3)
		padre.add_child(onda)
		for i in 5:
			var pz := _Pedazo.new()
			pz.global_position = p + Vector2(randf_range(-14.0, 14.0), -6.0)
			pz.vel = Vector2(randf_range(-380.0, 380.0), randf_range(-540.0, -240.0))
			pz.radio = randf_range(4.0, 9.0)
			pz.color = color.lightened(randf_range(-0.03, 0.12))
			padre.add_child(pz)
		var cam := get_viewport().get_camera_2d()
		if cam != null and cam.has_method("shake") and sacudir > 0.0:
			cam.shake(sacudir, 0.25)
		var j := get_tree().get_first_node_in_group("player") as Node2D
		if j == null:
			return
		var dx := j.global_position.x - p.x
		var dy := j.global_position.y - p.y
		var a_la_altura := dy > -260.0 and dy < 80.0
		if absf(dx) <= radio_dano and a_la_altura and j.has_method("take_damage"):
			# Te empuja lejos del impacto (sin tocar el daño).
			var lado := 1 if dx >= 0.0 else -1
			j.take_damage(dano, evento.empuje_roca if evento != null else 0.0, lado, true)
		elif evento != null and a_la_altura and absf(dx) <= radio_dano * evento.casi_golpe_ancho:
			evento.casi_golpe(p, maxf(sacudir * 1.5, 8.0))
