extends Node
## El corazón de la cueva se oye: cada pulso de latido_cueva.gd dispara un "pum" grave (el segundo golpe del
## doble latido suena más corto y suave) y, bajo el ambiente, un zumbido en bucle crece con la intensidad de la zona.
## Arriba casi no se percibe; cerca del sello es un latido enorme y cercano. Todo editable desde el Inspector.

@export var latido: NodePath
@export var pum_fuerte: AudioStream
@export var pum_suave: AudioStream
@export var capa_grave: AudioStream                 ## bucle de fondo (cueva_pulso_loop.wav)
@export var intensidad_min := 0.01                   ## con menos latido que esto casi no suena
@export var intensidad_max := 0.08                   ## con este latido, volumen máximo (las zonas van de 0.015 a ~0.075)
@export var volumen_min_db := -38.0                  ## volumen del pum con la intensidad mínima
@export var volumen_max_db := -8.0                   ## y con la máxima
@export var capa_min_db := -48.0
@export var capa_max_db := -17.0
@export_range(0.05, 1.0) var umbral := 0.45          ## nivel del pulso (0..~1.6) a partir del cual cuenta como golpe
@export var bus_ambiente := &"AmbienteCueva"

var _latido: Node
var _previo := 0.0
var _golpe := 0
var _jugadores: Array[AudioStreamPlayer] = []
var _capa: AudioStreamPlayer
var _capa_db := -80.0


func _bus() -> StringName:
	return bus_ambiente if AudioServer.get_bus_index(bus_ambiente) >= 0 else &"Musica"


func _ready() -> void:
	_latido = get_node_or_null(latido)
	for i in 3:
		var p := AudioStreamPlayer.new()
		p.bus = _bus()
		add_child(p)
		_jugadores.append(p)
	if capa_grave != null:
		if capa_grave is AudioStreamWAV:
			(capa_grave as AudioStreamWAV).loop_mode = AudioStreamWAV.LOOP_FORWARD
		_capa = AudioStreamPlayer.new()
		_capa.stream = capa_grave
		_capa.bus = _bus()
		_capa.volume_db = _capa_db
		add_child(_capa)
		_capa.play()


func _intensidad_norm() -> float:
	if _latido == null:
		return 0.0
	return clampf((float(_latido.intensidad_actual()) - intensidad_min) / maxf(intensidad_max - intensidad_min, 0.001), 0.0, 1.0)


func _process(delta: float) -> void:
	if _latido == null or not is_instance_valid(_latido):
		return
	var k := _intensidad_norm()
	if _capa != null:
		var obj := lerpf(capa_min_db, capa_max_db, pow(k, 0.8))
		_capa_db = lerpf(_capa_db, obj, 1.0 - exp(-1.5 * delta))
		_capa.volume_db = _capa_db
	var p := float(_latido.pulso_actual())
	if _previo < umbral and p >= umbral and k > 0.0:
		_golpear(k)
	_previo = p


func _golpear(k: float) -> void:
	var fuerte := _golpe % 2 == 0
	_golpe += 1
	var stream := pum_fuerte if fuerte else pum_suave
	if stream == null:
		return
	for jug in _jugadores:
		if not jug.playing:
			jug.stream = stream
			jug.volume_db = lerpf(volumen_min_db, volumen_max_db, pow(k, 0.8)) - (0.0 if fuerte else 4.0)
			jug.pitch_scale = randf_range(0.97, 1.03)
			jug.play()
			return
