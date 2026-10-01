extends SceneTree

var fallos := 0


func _init() -> void:
	await process_frame
	var dlg: Node = root.get_node_or_null("Dialogo")
	if dlg == null:
		dlg = load("res://scenes/dialog_box.tscn").instantiate()
		dlg.name = "Dialogo"
		root.add_child(dlg)
	var prog: Node = root.get_node("Progresion")
	prog.dialogos_vistos.erase("tut_mover")
	prog.dialogos_vistos.erase("tut_saltar")
	prog.dialogos_vistos.erase("tut_ligero")

	var player: Node2D = load("res://scenes/player.tscn").instantiate()
	root.add_child(player)
	await process_frame

	var p2: Node = _paso("tut_saltar", 1, "")
	var p1: Node = _paso("tut_mover", 0, "")
	p1.paso_siguiente = p1.get_path_to(p2)
	await process_frame

	_check(p1.texto.begins_with("Movete"), "texto del paso sale del JSON")
	p1.activar(player)
	_check(dlg.lista_existe("tut_mover") and dlg.lista_existe("tut_saltar"), "activar agrega el paso y los siguientes a la lista")
	_check(dlg.lista._items[0]["estado"] == 1, "el paso activo queda resaltado")

	Input.action_press("move_right")
	await process_frame
	await process_frame
	Input.action_release("move_right")
	_check(dlg.lista._items[0]["estado"] == 2, "mover tacha el paso")
	_check(prog.dialogo_visto("tut_mover"), "el paso queda marcado como visto")

	await create_timer(1.0).timeout
	_check(dlg.lista._items[1]["estado"] == 1, "pasa al paso siguiente (saltar)")

	dlg.mostrar(["hola"])
	_check(dlg.lista._items[1]["estado"] == 1, "un diálogo narrativo no toca la lista")

	var ev := InputEventAction.new()
	ev.action = "jump"
	ev.pressed = true
	Input.parse_input_event(ev)
	await process_frame
	await process_frame
	_check(dlg.lista._items[1]["estado"] == 2, "saltar tacha el paso")

	await create_timer(2.6).timeout
	_check(not dlg.lista.visible, "la lista se guarda al terminar la cadena")
	p1.activar(player)
	_check(not dlg.lista.visible, "un paso ya visto no se repite")

	print("DIAG_TUTORIAL: FALLOS = ", fallos)
	quit(fallos)


func _paso(id: String, accion: int, _sig: String) -> Node:
	var n: Node = load("res://scenes/tutorial_paso.tscn").instantiate()
	n.paso_id = id
	n.accion = accion
	n.position = Vector2(5000, 0)   # lejos del jugador: solo se activan a mano
	root.add_child(n)
	return n


func _check(ok: bool, nombre: String) -> void:
	if ok:
		print("[PASS] ", nombre)
	else:
		fallos += 1
		print("[FAIL] ", nombre)
