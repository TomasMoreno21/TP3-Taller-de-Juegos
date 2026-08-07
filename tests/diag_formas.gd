extends SceneTree

var _failures := 0


func _init() -> void:
	var scene = load("res://scenes/main.tscn").instantiate()
	root.add_child(scene)
	await process_frame
	await process_frame
	var player = scene.get_node("Player")

	player.set_form(2)
	_check(player.get_form_name() == "Espíritu del Lobo", "set_form(2) -> Lobo: " + player.get_form_name())
	_check(player.forms[2].dash_speed() > player.forms[2].speed, "Lobo: dash_speed > speed")
	player.global_position = Vector2(400, 100)
	player.velocity = Vector2.ZERO
	Input.action_press("attack")
	await physics_frame
	await physics_frame
	_check(player.forms[2].is_dashing(), "Lobo: atacar activa dash")
	Input.action_release("attack")

	player.set_form(3)
	_check(player.forms[3].is_gliding(player) == false, "Búho: no planea en el suelo")
	player.global_position = Vector2(400, 80)
	player.velocity = Vector2.ZERO
	await physics_frame
	await physics_frame
	_check(player.forms[3]._double_jump_available, "Búho: doble salto disponible en aire")
	Input.action_press("jump")
	await physics_frame
	await physics_frame
	_check(player.forms[3]._double_jump_available == false, "Búho: doble salto consumido tras usarlo")
	Input.action_release("jump")

	print("DIAG FORMAS: FALLOS = " + str(_failures))
	if _failures == 0:
		print("DIAG FORMAS: OK")
		quit(0)
	else:
		quit(1)


func _check(cond: bool, msg: String) -> void:
	if cond:
		print("[PASS] " + msg)
	else:
		print("[FAIL] " + msg)
		_failures += 1
