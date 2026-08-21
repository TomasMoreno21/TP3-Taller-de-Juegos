extends SceneTree

var _fallos := 0


func _check(cond: bool, msg: String) -> void:
	if cond:
		print("[PASS] " + msg)
	else:
		_fallos += 1
		print("[FAIL] " + msg)


func _init() -> void:
	# --- Caso 1: muerte por daño ---
	var nivel: Node = load("res://scenes/main.tscn").instantiate()
	root.add_child(nivel)
	current_scene = nivel
	await process_frame
	await process_frame

	var player: Node2D = nivel.get_node("Player")
	player.god_mode = false
	player.health = 5
	player.take_damage(10)
	await process_frame
	await process_frame

	var derrota := nivel.get_node_or_null("Derrota")
	_check(derrota != null, "Daño letal: overlay instanciado en el nivel")
	_check(derrota != null and paused, "Daño letal: árbol pausado")
	if derrota != null:
		_check(derrota.get_node_or_null("UIRoot/Center/VBox/Panel/Opciones/BotonReintentar") != null,
			"Daño letal: botón Reintentar presente")

	# --- Caso 2: caída al vacío ---
	paused = false
	nivel.queue_free()
	await process_frame
	await process_frame

	var nivel2: Node = load("res://scenes/nivel_2.tscn").instantiate()
	root.add_child(nivel2)
	current_scene = nivel2
	await process_frame
	var player2: Node2D = nivel2.get_node("Player")
	player2.god_mode = false
	player2.global_position = Vector2(0, 5000)
	for i in 3:
		await physics_frame
	await process_frame

	var derrota2 := nivel2.get_node_or_null("Derrota")
	_check(player2.health <= 0, "Caída: vida en 0 al superar limite_caida")
	_check(derrota2 != null and paused, "Caída: overlay de derrota mostrado")

	print("[TMP] DERROTA DIAG FIN fallos=", _fallos)
	quit(_fallos)
