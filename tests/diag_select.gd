extends SceneTree

var _failures := 0


func _init() -> void:
	var scene = load("res://scenes/main.tscn").instantiate()
	root.add_child(scene)
	await process_frame
	await process_frame
	var player = scene.get_node("Player")
	var prog = root.get_node_or_null("Progresion")
	_check(prog != null, "Progresion cargo (autoload)")

	_check(player.current_form == 0 and player.forma_seleccionada == 0,
		"Inicio: Humano seleccionado. Es: " + str(player.forma_seleccionada))

	Input.action_press("move_down")
	await physics_frame
	await physics_frame
	Input.action_release("move_down")
	_check(player.forma_seleccionada == 1,
		"Flecha abajo preselecciona Lobo. Es: " + str(player.forma_seleccionada))

	_write_formas(player)

	Input.action_press("transform")
	await physics_frame
	await physics_frame
	Input.action_release("transform")
	_check(player.current_form == 1,
		"T confirma y transforma a Lobo. Es: " + str(player.current_form))

	Input.action_press("move_up")
	await physics_frame
	await physics_frame
	Input.action_release("move_up")
	_check(player.forma_seleccionada == 0,
		"Flecha arriba vuelve a Humano. Es: " + str(player.forma_seleccionada))

	print("DIAG SELECT: " + ("OK" if _failures == 0 else "FALLOS = " + str(_failures)))
	if _failures == 0:
		quit(0)
	else:
		quit(1)


func _write_formas(player: Node) -> void:
	var partes: Array[String] = []
	for i in range(player.forms.size()):
		partes.append("%s%s=%d" % ["*" if i == player.forma_seleccionada else " ", player.forms[i].form_name, i])
	print("[FORMAS] " + ", ".join(partes))


func _check(cond: bool, msg: String) -> void:
	if cond:
		print("[PASS] " + msg)
	else:
		print("[FAIL] " + msg)
		_failures += 1