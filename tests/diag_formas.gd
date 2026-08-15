extends SceneTree

var _failures := 0


func _init() -> void:
	var scene = load("res://scenes/main.tscn").instantiate()
	root.add_child(scene)
	await process_frame
	await process_frame
	var player = scene.get_node("Player")

	# Stats del concepto
	_check(player.forms.size() == 4, "4 formas cargadas")
	_check(player.forms[0].form_name == "Humano", "Forma 0 = Humano")
	_check(player.forms[1].form_name == "Lobo", "Forma 1 = Lobo")
	_check(player.forms[2].form_name == "Oso", "Forma 2 = Oso")
	_check(player.forms[3].form_name == "Murciélago", "Forma 3 = Murciélago")
	_check(player.forms[1].speed > player.forms[0].speed, "Lobo más rápido que Humano")
	_check(player.forms[2].speed < player.forms[1].speed, "Oso más lento que Lobo")
	_check(player.forms[1].jump_velocity < player.forms[0].jump_velocity, "Lobo salta más alto")
	_check(player.forms[2].attack_damage > player.forms[1].attack_damage, "Oso pega más fuerte")

	# Vida compartida
	var hp := 100
	player.take_damage(25)
	hp = player.health
	player.current_form = 1
	await process_frame
	_check(player.health == hp, "Vida compartida: no resetea al transformar")

	# Planeo del murciélago
	player.current_form = 3
	player.global_position = Vector2(200, 100)
	player.velocity = Vector2(0, 50)
	await physics_frame
	Input.action_press("jump")
	await physics_frame
	var gliding: bool = player.forms[3].is_gliding(player)
	_check(gliding, "Murciélago planea en el aire con J sostenido")
	Input.action_release("jump")
	player.global_position = Vector2(200, 0)
	player.velocity = Vector2(0, 0)
	await physics_frame
	await physics_frame
	_check(player.forms[3].is_gliding(player) == false, "Murciélago no planea en el suelo")

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