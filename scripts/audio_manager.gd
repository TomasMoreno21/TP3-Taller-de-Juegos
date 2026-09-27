extends Node
## Autoload mínimo para reproducir efectos de sonido puntuales (golpes,
## transformación, etc.) sin tener que crear y limpiar un AudioStreamPlayer
## a mano en cada script. Los sonidos en sí se configuran por @export en
## cada escena (player, enemy, ...), esto solo los reproduce.


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS


## Atajo para UI y sistemas sin exports propios.
func play_ui(nombre: String, volume_db: float = -10.0) -> void:
	var ruta := "res://assets/audio/sfx/gen/%s.wav" % nombre
	if ResourceLoader.exists(ruta):
		play_sfx(load(ruta), volume_db, 0.03)


## variacion_tono: ± al azar sobre el pitch (0.08 = ±8%) para que un sonido repetido
## (pasos, pickups, golpes) no suene idéntico cada vez.
func play_sfx(stream: AudioStream, volume_db: float = 0.0, variacion_tono: float = 0.0) -> void:
	if stream == null:
		return
	var player := AudioStreamPlayer.new()
	player.stream = stream
	player.volume_db = volume_db
	if variacion_tono > 0.0:
		player.pitch_scale = 1.0 + randf_range(-variacion_tono, variacion_tono)
	add_child(player)
	player.finished.connect(player.queue_free)
	player.play()


## Como play_sfx pero sincronizado con la animación: si hay un hitstop activo,
## espera a que se des-congele (señal descongelado) para sonar justo cuando la
## animación retoma el movimiento (el impacto visual). En headless suena directo.
func play_sfx_sincronizado(stream: AudioStream, volume_db: float = 0.0, esperar: bool = true) -> void:
	if stream == null:
		return
	if not esperar or DisplayServer.get_name() == "headless":
		play_sfx(stream, volume_db)
		return
	var hs := get_node_or_null("/root/Hitstop")
	if hs == null or not hs.has_signal("descongelado") or not hs.has_method("esta_congelado") or not hs.esta_congelado():
		play_sfx(stream, volume_db)
		return
	await hs.descongelado
	play_sfx(stream, volume_db)
