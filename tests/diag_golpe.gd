extends SceneTree

var _failures := 0


func _init() -> void:
	var scene = load("res://scenes/main.tscn").instantiate()
	_quitar_dialogos_automaticos(scene)
	root.add_child(scene)
	await process_frame
	await process_frame
	var player = scene.get_node("Player")
	var enemy = preload("res://scenes/enemy.tscn").instantiate()
	enemy.tipo = "cultista"
	scene.add_child(enemy)
	enemy.global_position = player.global_position + Vector2(60, 0)
	await _wait_frames(20)
	player.global_position = enemy.global_position - Vector2(25, 0)
	player.facing = 1
	await physics_frame
	var hp0: int = enemy.health
	Input.action_press("attack")
	await physics_frame
	await physics_frame
	Input.action_release("attack")

	var vio_danio := false
	var vio_rojo := false
	for i in range(12):
		await process_frame
		if enemy.health < hp0:
			vio_danio = true
		if enemy.visual.modulate != Color(1, 1, 1):
			vio_rojo = true
	_check(vio_danio, "Enemigo recibió daño: %d -> %d" % [hp0, enemy.health])
	_check(vio_rojo, "Enemigo se tiñe de rojo al ser golpeado")

	print("DIAG GOLPE: FALLOS = " + str(_failures))
	if _failures == 0:
		print("DIAG GOLPE: OK")
		quit(0)
	else:
		quit(1)


func _wait_frames(n: int) -> void:
	for i in range(n):
		await physics_frame


func _quitar_dialogos_automaticos(nodo: Node) -> void:
	# el amuleto pausa el juego y consume input al hablar; interfiere con la
	# simulación de Input.action_press de las pruebas aisladas
	for hijo in nodo.get_children():
		_quitar_dialogos_automaticos(hijo)
	var script: Script = nodo.get_script()
	if script != null and script.resource_path == "res://scripts/dialog_trigger.gd":
		nodo.get_parent().remove_child(nodo)
		nodo.free()


func _check(cond: bool, msg: String) -> void:
	if cond:
		print("[PASS] " + msg)
	else:
		print("[FAIL] " + msg)
		_failures += 1