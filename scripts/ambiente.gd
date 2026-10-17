extends Node
## "El mundo te siente": estado compartido entre el jugador y el ambiente.
## - `tension` (0..1): sube con enemigos cerca, jefe y vida baja; baja sola al despejar la zona.
##   La usan las luciérnagas (se apagan y se dispersan) y las hojas (viento más nervioso).
## - `empujar(pos, fuerza)`: avisa a todo lo del grupo "reactivo" (pasto, luciérnagas, hojas)
##   que hubo un golpe fuerte cerca. `sacudida(fuerza)` lo dispara desde la cámara.

signal sacudida_fuerte(fuerza: float)

@export var radio_enemigos := 1100.0     ## enemigos vivos dentro de este radio suben la tensión
@export var radio_jefe := 2200.0
@export var subida := 0.6                ## tensión/segundo al subir
@export var bajada := 0.3                ## tensión/segundo al bajar (más lento: el bosque tarda en exhalar)
@export var sacudida_polvo_min := 6.0    ## fuerza de shake desde la cual cae polvo del techo / se empuja el entorno

@export var latido_umbral := 0.3         ## fracción de vida desde la cual el corazón late (mismo umbral que la viñeta)
@export var latido_hz_min := 1.2         ## latidos/s justo bajo el umbral
@export var latido_hz_max := 2.6         ## latidos/s con vida casi en cero

var tension := 0.0
var hay_hojas := true   ## false en cuevas: ni hojas cayendo ni hojitas al agarrar lianas (lo fija hojas_ambiente.gd al cargar el nivel)
## Pulso compartido "lub-dub" (0..1) y qué tan herido estás (0..1). Lo leen la viñeta del HUD,
## la respiración del jugador y el orbe de vida: todo late a la vez cuando quedás con poca vida.
var latido := 0.0
var latido_severidad := 0.0
var _objetivo := 0.0
var _sev := 0.0
var _fase_latido := 0.0
var _acum := 0.0


var _escena_vista: Node

@export_group("Audio")
@export var sonido_lub: AudioStream = preload("res://assets/audio/sfx/gen/latido_lub.wav")
@export var sonido_dub: AudioStream = preload("res://assets/audio/sfx/gen/latido_dub.wav")
@export var sonido_tension: AudioStream = preload("res://assets/audio/sfx/gen/tension_loop.wav")   ## drone en loop; su volumen sigue a `tension`
@export var volumen_latido_db := -6.0
@export var volumen_tension_min_db := -42.0   ## con tensión apenas > 0
@export var volumen_tension_max_db := -17.0   ## con tensión 1 (jefe + enemigos + poca vida)
var _drone: AudioStreamPlayer
var _fase_prev := 0.0


func _ready() -> void:
	if DisplayServer.get_name() == "headless" or sonido_tension == null:
		return
	var s := sonido_tension.duplicate() as AudioStreamWAV
	s.loop_mode = AudioStreamWAV.LOOP_FORWARD
	s.loop_end = s.data.size() / 2   # 16 bits mono
	_drone = AudioStreamPlayer.new()
	_drone.stream = s
	_drone.bus = &"SFX"
	_drone.volume_db = -80.0
	add_child(_drone)


func _audio(delta: float) -> void:
	if _drone != null:
		var objetivo_db := lerpf(volumen_tension_min_db, volumen_tension_max_db, tension) if tension > 0.03 else -80.0
		_drone.volume_db = move_toward(_drone.volume_db, objetivo_db, delta * 30.0)
		if _drone.volume_db > -70.0 and not _drone.playing:
			_drone.play()
		elif _drone.volume_db <= -70.0 and _drone.playing:
			_drone.stop()
	if latido_severidad > 0.05 and _drone != null:
		# lub al empezar el ciclo, dub al cruzar 0.24 (mismo pulso que el visual)
		var audio := get_node_or_null("/root/AudioManager")
		if audio != null:
			var vol := volumen_latido_db + linear_to_db(latido_severidad)
			if _fase_latido < _fase_prev:
				audio.play_sfx(sonido_lub, vol)
			elif _fase_prev < 0.24 and _fase_latido >= 0.24:
				audio.play_sfx(sonido_dub, vol - 3.0)
	_fase_prev = _fase_latido


func _process(delta: float) -> void:
	var escena := get_tree().current_scene
	if escena != _escena_vista:   # nivel nuevo o recargado: la tensión de la escena anterior no se arrastra
		_escena_vista = escena
		tension = 0.0
		_objetivo = 0.0
	_acum += delta
	if _acum >= 0.2:
		_acum = 0.0
		_objetivo = _calcular_objetivo()
	tension = move_toward(tension, _objetivo, delta * (subida if _objetivo > tension else bajada))
	latido_severidad = move_toward(latido_severidad, _sev, delta * 2.0)
	if latido_severidad > 0.01:
		_fase_latido = fmod(_fase_latido + delta * lerpf(latido_hz_min, latido_hz_max, latido_severidad), 1.0)
		latido = _pulso(_fase_latido) * latido_severidad
	else:
		latido = 0.0
	_audio(delta)


## Doble golpe "lub-dub" sobre una fase 0..1.
func _pulso(f: float) -> float:
	var a := exp(-pow(f / 0.07, 2.0))
	var b := 0.65 * exp(-pow((f - 0.24) / 0.08, 2.0))
	return clampf(a + b, 0.0, 1.0)


func _calcular_objetivo() -> float:
	var jugador := get_tree().get_first_node_in_group("player") as Node2D
	if jugador == null:
		_sev = 0.0
		return 0.0
	_sev = 0.0
	if "health" in jugador and int(jugador.health) > 0:
		_sev = clampf(inverse_lerp(latido_umbral, latido_umbral * 0.15, float(jugador.health) / 100.0), 0.0, 1.0)
	var pos := jugador.global_position
	var cerca := 0
	for n in get_tree().get_nodes_in_group("enemy"):
		if is_instance_valid(n) and n is Node2D and n.get("_activo") != false and (n as Node2D).global_position.distance_to(pos) < radio_enemigos:   # (los ocultos de olas pendientes no cuentan)
			if not ("health" in n) or int(n.health) > 0:
				cerca += 1
	var t := minf(float(cerca), 4.0) / 4.0 * 0.6
	for b in get_tree().get_nodes_in_group("boss"):
		if is_instance_valid(b) and b is Node2D and (b as Node2D).global_position.distance_to(pos) < radio_jefe:
			if not ("health" in b) or int(b.health) > 0:
				t += 0.5
				break
	if "health" in jugador:
		t += clampf(inverse_lerp(0.5, 0.1, float(jugador.health) / 100.0), 0.0, 1.0) * 0.4
	return clampf(t, 0.0, 1.0)


## Golpe fuerte en `pos` (mundo). fuerza ~0..1.
func empujar(pos: Vector2, fuerza: float) -> void:
	get_tree().call_group("reactivo", "empujar", pos, fuerza)


## Llamado por la cámara en cada shake: empuja el entorno cercano al jugador y, si es fuerte, cae polvo.
func sacudida(fuerza: float) -> void:
	var jugador := get_tree().get_first_node_in_group("player") as Node2D
	if jugador != null and fuerza >= sacudida_polvo_min * 0.5:
		empujar(jugador.global_position, clampf(fuerza / 12.0, 0.0, 1.0))
	if fuerza >= sacudida_polvo_min:
		sacudida_fuerte.emit(fuerza)
