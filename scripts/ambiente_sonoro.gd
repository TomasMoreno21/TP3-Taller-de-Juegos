extends Node
## Ambientación sonora de fondo: capas en loop (viento, grillos, etc.) más
## acentos puntuales que suenan solos a intervalos aleatorios (búho, aullido).
## Todo configurable desde el editor: no hace falta tocar código para cambiar
## sonidos, volúmenes o frecuencia de los acentos.

@export var capas_loop: Array[AudioStream] = []
@export var capas_loop_volumen_db: Array[float] = []
@export var acentos: Array[AudioStream] = []
@export var acento_intervalo_min := 20.0
@export var acento_intervalo_max := 50.0
@export var acento_volumen_db := 0.0
@export var volumen_master_db := 0.0

var _timer_acento: Timer


func _ready() -> void:
	for i in capas_loop.size():
		var stream: AudioStream = capas_loop[i]
		if stream == null:
			continue
		if "loop" in stream:
			stream.loop = true
		var player := AudioStreamPlayer.new()
		player.stream = stream
		var vol: float = capas_loop_volumen_db[i] if i < capas_loop_volumen_db.size() else 0.0
		player.volume_db = vol + volumen_master_db
		add_child(player)
		player.play()
	if not acentos.is_empty():
		_timer_acento = Timer.new()
		_timer_acento.one_shot = true
		add_child(_timer_acento)
		_timer_acento.timeout.connect(_reproducir_acento)
		_programar_acento()


func _programar_acento() -> void:
	_timer_acento.start(randf_range(acento_intervalo_min, acento_intervalo_max))


func _reproducir_acento() -> void:
	var stream: AudioStream = acentos[randi() % acentos.size()]
	var player := AudioStreamPlayer.new()
	player.stream = stream
	player.volume_db = acento_volumen_db + volumen_master_db
	add_child(player)
	player.finished.connect(player.queue_free)
	player.play()
	_programar_acento()
