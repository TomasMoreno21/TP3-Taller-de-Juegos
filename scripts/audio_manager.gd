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
