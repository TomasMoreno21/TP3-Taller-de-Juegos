extends SceneTree

## Verifica el contrato del checkpoint: guarda estado completo y lo restaura
## en el respawn sin recargar el nivel.

var _fallos := 0


func _check(cond: bool, msg: String) -> void:
	if cond:
		print("[PASS] " + msg)
	else:
		_fallos += 1
		print("[FAIL] " + msg)


func _init() -> void:
	var nivel: Node = load("res://scenes/nivel1prueba.tscn").instantiate()
	root.add_child(nivel)
	current_scene = nivel
	for i in 4:
		await process_frame

	var player: Node2D = nivel.get_node_or_null("Player")
	_check(player != null, "Nivel de prueba: Player presente")
	var checkpoint: Node = nivel.get_node_or_null("Checkpoint1")
	_check(checkpoint != null, "Checkpoint1 instanciado en el nivel")

	if player == null or checkpoint == null:
		quit(_fallos)
		return

	_check(not player.tiene_checkpoint(), "Al inicio no hay checkpoint guardado")

	# Activar el checkpoint: ponemos al player encima del Area2D para disparar body_entered.
	checkpoint.global_position = player.global_position
	for i in 3:
		await physics_frame
	_check(player.tiene_checkpoint(), "Al tocar el checkpoint, tiene_checkpoint es true")

	var pos_guardada: Vector2 = player._spawn_position
	_check(pos_guardada != Vector2.ZERO, "Checkpoint guarda posición de respawn")

	# Cambiar estado del player y restaurar.
	player.global_position = Vector2(5000, 800)
	player.health = 5
	player.energia = 2.0
	for i in 2:
		await process_frame
	player.reaparecer_en_checkpoint()
	for i in 2:
		await process_frame

	_check(absf(player.global_position.x - pos_guardada.x) < 1.0 and absf(player.global_position.y - pos_guardada.y) < 3.0,
		"Respawn: vuelve a la posición del checkpoint")
	_check(player.health > 5, "Respawn: vida restaurada a la del checkpoint (> 5)")
	_check(player.energia > 2.0, "Respawn: energía restaurada a la del checkpoint (> 2)")
	_check(player._derrota_activa == false, "Respawn: flag de derrota reiniciado")

	print("[TMP] CHECKPOINT DIAG FIN fallos=", _fallos)
	quit(_fallos)