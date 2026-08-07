extends SceneTree

var _failures := 0


func _init() -> void:
	var scene = load("res://scenes/main.tscn").instantiate()
	root.add_child(scene)
	await process_frame
	await process_frame
	var player = scene.get_node("Player")
	var enemy = scene.get_node("Level/Enemy")
	var cam = player.get_node("Camera2D")
	_check(cam != null, "Player tiene Camera2D")

	player.global_position = enemy.global_position - Vector2(30, 0)
	player.facing = 1
	await physics_frame
	Input.action_press("attack")
	await physics_frame
	await physics_frame
	Input.action_release("attack")
	_check(enemy.health == 90, "Enemigo recibió daño: " + str(enemy.health))

	var vio_rot := false
	var vio_rojo := false
	var vio_shake := false
	for i in range(12):
		await process_frame
		if enemy.visual.rotation != 0.0:
			vio_rot = true
		if enemy.visual.color.r > 0.9:
			vio_rojo = true
		if cam.offset != Vector2.ZERO:
			vio_shake = true
	_check(vio_rot, "Enemigo rota al ser golpeado")
	_check(vio_rojo, "Enemigo se tiñe de rojo")
	_check(vio_shake, "Cámara se sacude")

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
