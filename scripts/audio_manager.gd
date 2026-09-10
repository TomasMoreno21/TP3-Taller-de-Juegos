extends Node
## Autoload mínimo para reproducir efectos de sonido puntuales (golpes,
## transformación, etc.) sin tener que crear y limpiar un AudioStreamPlayer
## a mano en cada script. Los sonidos en sí se configuran por @export en
## cada escena (player, enemy, ...), esto solo los reproduce.


func play_sfx(stream: AudioStream, volume_db: float = 0.0) -> void:
	if stream == null:
		return
	var player := AudioStreamPlayer.new()
	player.stream = stream
	player.volume_db = volume_db
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
	if hs == null or not hs.has_signal("descongelado"):
		play_sfx(stream, volume_db)
		return
	await hs.descongelado
	play_sfx(stream, volume_db)
