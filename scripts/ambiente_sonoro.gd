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
@export_range(0.0, 0.3, 0.01) var acento_pitch_var := 0.0   ## ±variación de tono por acento (que el mismo sonido no suene idéntico)
## Acentos suaves: detalles chicos y frecuentes (polvo, piedritas, un cristal que resuena). Cada uno baja con un
## poco de azar de volumen y tono, y nunca repite el anterior. Se callan igual en la antesala de combate.
@export var acentos_suaves: Array[AudioStream] = []
@export var suave_intervalo_min := 7.0
@export var suave_intervalo_max := 18.0
@export var suave_volumen_db := -12.0
@export_range(0.0, 0.3, 0.01) var suave_pitch_var := 0.08
@export var suave_volumen_azar_db := 2.5   ## ±dB al azar por sonido
@export var volumen_master_db := 0.0
@export var bus_ambiente := &"Musica"   ## bus de las capas y acentos (si no existe, usa Musica); ambiente_zonas.gd crea uno con eco por zona
@export var silencio_db := 14.0   ## cuánto baja cada capa con el silencio al máximo
@export var silencio_corta_acentos := 0.3   ## con silencio mayor a esto no suenan acentos (búho, aullido)

var _timer_acento: Timer
var _timer_suave: Timer
var _ultimo_acento := -1
var _ultimo_suave := -1
var _capas: Array[AudioStreamPlayer] = []
var _base_db: Array[float] = []
var _silencios := {}   # fuente (instance id) -> k 0..1; se aplica el máximo


func _bus() -> StringName:
	return bus_ambiente if AudioServer.get_bus_index(bus_ambiente) >= 0 else &"Musica"


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
		player.bus = _bus()
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
	if not acentos_suaves.is_empty():
		_timer_suave = Timer.new()
		_timer_suave.one_shot = true
		add_child(_timer_suave)
		_timer_suave.timeout.connect(_reproducir_suave)
		_timer_suave.start(randf_range(suave_intervalo_min * 0.3, suave_intervalo_min))
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
	_ultimo_acento = _elegir(acentos.size(), _ultimo_acento)
	_sonar(acentos[_ultimo_acento], acento_volumen_db, acento_pitch_var)
	_programar_acento()


func _reproducir_suave() -> void:
	if silencio_actual() <= silencio_corta_acentos:
		_ultimo_suave = _elegir(acentos_suaves.size(), _ultimo_suave)
		_sonar(acentos_suaves[_ultimo_suave], suave_volumen_db + randf_range(-suave_volumen_azar_db, suave_volumen_azar_db), suave_pitch_var)
	_timer_suave.start(randf_range(suave_intervalo_min, suave_intervalo_max))


## Índice al azar distinto del anterior (si hay más de uno).
func _elegir(cantidad: int, anterior: int) -> int:
	if cantidad <= 1:
		return 0
	var i := randi() % cantidad
	while i == anterior:
		i = randi() % cantidad
	return i


func _sonar(stream: AudioStream, db: float, pitch_var: float) -> void:
	var player := AudioStreamPlayer.new()
	player.stream = stream
	player.bus = _bus()
	player.volume_db = db + volumen_master_db
	player.pitch_scale = 1.0 + randf_range(-pitch_var, pitch_var)
	add_child(player)
	player.finished.connect(player.queue_free)
	player.play()
