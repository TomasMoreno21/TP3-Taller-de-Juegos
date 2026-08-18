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
	# este diag prueba la mecánica de selección Q/T en sí, no el desbloqueo
	# progresivo por nivel (eso ya lo cubre autotest.gd) -> todas las formas abiertas
	prog.set_nivel(4)

	_check(player.current_form == 0 and player.forma_seleccionada == 0,
		"Inicio: Humano seleccionado. Es: " + str(player.forma_seleccionada))

	# T de entrada, SIN haber tocado Q nunca, tiene que transformar (no quedarse sin hacer nada)
	Input.action_press("transform")
	await physics_frame
	await physics_frame
	Input.action_release("transform")
	_check(player.current_form == 1,
		"T sin usar Q antes transforma directo a Lobo. Es: " + str(player.current_form))
	Input.action_press("transform")
	await physics_frame
	await physics_frame
	Input.action_release("transform")
	_check(player.current_form == 0,
		"T de nuevo revierte a Humano. Es: " + str(player.current_form))

	Input.action_press("form_next")
	await physics_frame
	await physics_frame
	Input.action_release("form_next")
	_check(player.forma_seleccionada == 1,
		"Q preselecciona Lobo. Es: " + str(player.forma_seleccionada))

	_write_formas(player)

	Input.action_press("transform")
	await physics_frame
	await physics_frame
	Input.action_release("transform")
	_check(player.current_form == 1,
		"T confirma y transforma a Lobo. Es: " + str(player.current_form))

	# T de nuevo ya transformado en la forma preseleccionada = revertir a Humano al toque
	Input.action_press("transform")
	await physics_frame
	await physics_frame
	Input.action_release("transform")
	_check(player.current_form == 0 and player.forma_seleccionada == 0,
		"T de nuevo revierte a Humano sin pasar por Q. Es: " + str(player.current_form))

	# transformar directo entre dos formas no-Humano (sin pasar por el revert)
	Input.action_press("form_next")
	await physics_frame
	await physics_frame
	Input.action_release("form_next")
	Input.action_press("transform")
	await physics_frame
	await physics_frame
	Input.action_release("transform")
	Input.action_press("form_next")
	await physics_frame
	await physics_frame
	Input.action_release("form_next")
	Input.action_press("transform")
	await physics_frame
	await physics_frame
	Input.action_release("transform")
	_check(player.current_form == 2,
		"T transforma directo de Lobo a Oso. Es: " + str(player.current_form))

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