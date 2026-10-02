extends Node
## Ambientación sonora de fondo: capas en loop (viento, grillos, etc.) más
## acentos puntuales que suenan solos a intervalos aleatorios (búho, aullido).
## Todo configurable desde el editor: no hace falta tocar código para cambiar
## sonidos, volúmenes o frecuencia de los acentos.
## Antesala de combate: cerca de una arena el ambiente se va callando (ver encounters/antesala.gd).

@export var capas_loop: Array[AudioStream] = []
@export var capas_loop_volumen_db: Array[float] = []
@export var capas_silencio_mult: Array[float] = []   ## por capa: cuánto se calla en la antesala (1 = todo, 0.4 = poco; falta = 1)
@export var acentos: Array[AudioStream] = []
@export var acento_intervalo_min := 20.0
@export var acento_intervalo_max := 50.0
@export var acento_volumen_db := 0.0
@export var volumen_master_db := 0.0
@export var silencio_db := 14.0   ## cuánto baja cada capa con el silencio al máximo
@export var silencio_corta_acentos := 0.3   ## con silencio mayor a esto no suenan acentos (búho, aullido)

var _timer_acento: Timer
var _capas: Array[AudioStreamPlayer] = []
var _base_db: Array[float] = []
var _silencios := {}   # fuente (instance id) -> k 0..1; se aplica el máximo


func _ready() -> void:
	add_to_group("ambiente_sonoro")
	for i in capas_loop.size():
		var stream: AudioStream = capas_loop[i]
		if stream == null:
			continue
		if stream is AudioStreamWAV:
			# AudioStreamWAV no expone `loop` (usa loop_mode); sin esto una capa
			# en WAV termina y no cicla como el resto de las capas.
			stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
		elif "loop" in stream:
			stream.loop = true
		var player := AudioStreamPlayer.new()
		player.stream = stream
		var vol: float = capas_loop_volumen_db[i] if i < capas_loop_volumen_db.size() else 0.0
		player.volume_db = vol + volumen_master_db
		add_child(player)
		player.play()
		_capas.append(player)
		_base_db.append(vol + volumen_master_db)
		if i < capas_silencio_mult.size():
			player.set_meta("silencio_mult", capas_silencio_mult[i])
	if not acentos.is_empty():
		_timer_acento = Timer.new()
		_timer_acento.one_shot = true
		add_child(_timer_acento)
		_timer_acento.timeout.connect(_reproducir_acento)
		_programar_acento()
	set_process(false)


## Una fuente (p. ej. una antesala) pide callar el ambiente con intensidad k (0..1). k = 0 la retira.
func pedir_silencio(fuente: Object, k: float) -> void:
	var id := fuente.get_instance_id()
	if k <= 0.001:
		_silencios.erase(id)
	else:
		_silencios[id] = k
	set_process(true)


func silencio_actual() -> float:
	var m := 0.0
	for id in _silencios.keys():
		if not is_instance_id_valid(id):
			_silencios.erase(id)
			continue
		m = maxf(m, _silencios[id])
	return m


func _process(_delta: float) -> void:
	var k := silencio_actual()
	for i in _capas.size():
		var mult: float = _capas[i].get_meta("silencio_mult", 1.0)
		_capas[i].volume_db = _base_db[i] - k * silencio_db * mult
	if _silencios.is_empty():
		set_process(false)


func _programar_acento() -> void:
	_timer_acento.start(randf_range(acento_intervalo_min, acento_intervalo_max))


func _reproducir_acento() -> void:
	if silencio_actual() > silencio_corta_acentos:
		_programar_acento()
		return
	var stream: AudioStream = acentos[randi() % acentos.size()]
	var player := AudioStreamPlayer.new()
	player.stream = stream
	player.volume_db = acento_volumen_db + volumen_master_db
	add_child(player)
	player.finished.connect(player.queue_free)
	player.play()
	_programar_acento()
