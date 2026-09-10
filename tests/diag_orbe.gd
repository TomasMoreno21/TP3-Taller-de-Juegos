extends SceneTree

## Verifica el orbe rojo de vida: se suelta con 55% al morir, cura al jugador.
## Se testea de forma aislada (sin cargar main.tscn, que tiene encounters).

var _fallos := 0


func _check(cond: bool, msg: String) -> void:
	if cond:
		print("[PASS] " + msg)
	else:
		_fallos += 1
		print("[FAIL] " + msg)


func _init() -> void:
	# --- Caso 1: método de cura del player (aislado) ---
	var player: CharacterBody2D = preload("res://scenes/player.tscn").instantiate()
	root.add_child(player)
	await process_frame
	player.health = 50
	player.curar(30)
	_check(player.health == 80, "curar(30) sube la vida (50 -> 80)")
	player.curar(9999)
	_check(player.health == player.VIDA_MAX, "curar no supera la vida máxima")

	# --- Caso 2: al morir un enemigo se suelta el orbe (55%, probamos varias muertes) ---
	var solto := false
	for i in 40:
		if solto:
			break
		var en: Node2D = preload("res://scenes/enemy.tscn").instantiate()
		root.add_child(en)
		en.health = 1
		en._activo = true
		en.spawn_telegrafiado = false
		en.take_damage(1)
		for j in 15:
			await process_frame
		if _primero_orbe() != null:
			solto = true
	_check(solto, "Matar enemigos puede soltar el orbe rojo (55%) en 40 intentos")

	var orbe: Node2D = _primero_orbe()
	_check(orbe != null, "El orbe rojo quedó en la escena")

	# --- Caso 3: el orbe rojo cura al jugador al tocarlo ---
	if orbe != null:
			player.health = 50
			orbe.global_position = player.global_position
			orbe._on_body_entered(player)
			await process_frame
			_check(player.health > 50, "Tocar el orbe rojo cura al jugador (50 -> >50)")

	print("[TMP] ORBE DIAG FIN fallos=", _fallos)
	quit(_fallos)


func _primero_orbe() -> Node2D:
	for child in root.get_children():
		if child.name == "PickupVida":
			return child
	return null