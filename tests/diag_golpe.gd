extends SceneTree

var _failures := 0


func _init() -> void:
	var scene = load("res://scenes/main.tscn").instantiate()
	root.add_child(scene)
	await process_frame
	await process_frame
	var player = scene.get_node("Player")
	var enemy = scene.get_node("Cultista1")

	player.global_position = enemy.global_position - Vector2(30, 0)
	player.facing = 1
	await physics_frame
	Input.action_press("attack")
	await physics_frame
	await physics_frame
	Input.action_release("attack")

	var vio_danio := false
	var vio_rojo := false
	for i in range(12):
		await process_frame
		if enemy.health < 40:
			vio_danio = true
		if enemy.visual.modulate != Color(1, 1, 1):
			vio_rojo = true
	_check(vio_danio, "Enemigo recibió daño: " + str(enemy.health))
	_check(vio_rojo, "Enemigo se tiñe de rojo al ser golpeado")

	print("DIAG GOLPE: FALLOS = " + str(_failures))
	if _failures == 0:
		print("DIAG GOLPE: OK")
		quit(0)
	else:
		quit(1)


func _check(cond: bool, msg: String) -> void:
	if cond:
		print("[PASS] " + msg)
	else:
		print("[FAIL] " + msg)
		_failures += 1
