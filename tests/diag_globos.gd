extends SceneTree

var fallos := 0


func _init() -> void:
	await process_frame
	var dlg: Node = root.get_node("Dialogo")
	dlg.seg_entre_charlas = 0.0   # el respiro entre charlas se prueba aparte, al final
	var suelo := StaticBody2D.new()
	var col := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(4000, 40)
	col.shape = rect
	suelo.add_child(col)
	suelo.position = Vector2(0, 100)
	root.add_child(suelo)
	var player: Node2D = load("res://scenes/player.tscn").instantiate()
	player.position = Vector2(0, 40)
	root.add_child(player)
	await process_frame

	# --- globos: no bloquean, se parten, cadena y fin
	var terminado := [false]
	dlg.dialogo_terminado.connect(func(): terminado[0] = true)
	dlg.mostrar(["[alerta]Primera frase corta.", "Segunda línea con {jump} para saltar."], "Amuleto")
	_check(not dlg.esta_activo(), "la narrativa no bloquea al jugador")
	_check(dlg.hay_narrativa(), "hay narrativa en curso")
	await create_timer(0.3).timeout
	_check(dlg.globo.visible and dlg.globo.tono == 1, "globo visible con tono alerta")
	_check(dlg.texto_actual() == "Primera frase corta.", "la etiqueta de tono no aparece en el texto (%s)" % dlg.texto_actual())
	_check(dlg.gema.visible, "la gema acompaña mientras habla")
	# el jugador puede moverse con el globo abierto
	var x0 := player.global_position.x
	Input.action_press("move_right")
	await create_timer(0.4).timeout
	Input.action_release("move_right")
	_check(player.global_position.x > x0 + 5.0, "el jugador se mueve con el globo abierto")
	await create_timer(6.0).timeout
	_check(terminado[0] and not dlg.globo.visible, "la cadena termina sola y el globo se guarda")

	# --- texto largo se parte en globos cortos
	terminado[0] = false
	var largo := "Esta es una frase bastante larga para el globo. Esta es otra frase que debería ir en otro globo aparte."
	dlg.mostrar([largo])
	await create_timer(0.2).timeout
	_check(dlg.texto_actual().length() <= 50, "el texto largo se parte (%d letras)" % dlg.texto_actual().length())
	await create_timer(11.0).timeout
	_check(terminado[0], "todos los trozos se muestran y termina")

	# --- tips: se callan si hay narrativa
	dlg.mostrar(["narrativa"])
	dlg.mostrar_tip(["un consejo"])
	await create_timer(0.2).timeout
	_check(dlg.texto_actual() == "narrativa", "el tip no pisa una narrativa")
	await create_timer(4.0).timeout

	# --- lista de tareas
	dlg.lista_agregar("a", "Primera tarea", 1)
	dlg.lista_agregar("b", "Segunda tarea", 2)
	await process_frame
	_check(dlg.lista.visible and dlg.lista.hay_items(), "la lista aparece con tareas")
	_check(dlg.lista._idx_mostrado() == 0, "la lista muestra una sola tarea: la primera")
	dlg.lista_marcar_actual("a")
	dlg.lista_completar("a")
	_check(dlg.lista._items[0]["estado"] == 2, "completar tacha la tarea")
	_check(dlg.lista._idx_mostrado() == 0, "la tarea hecha se ve un instante")
	await create_timer(1.5).timeout
	_check(dlg.lista._idx_mostrado() == 1, "después pasa a la tarea siguiente")
	dlg.lista_progreso("b", 1)
	_check(dlg.lista._items[1]["cuenta"] == 1, "el contador avanza")
	dlg.lista_completar("b")
	await create_timer(2.4).timeout
	_check(not dlg.lista.visible, "la lista se guarda al completar todo")

	# --- lugares sin acción: con un enemigo cerca el Amuleto espera
	await create_timer(1.0).timeout
	var enemigo := Node2D.new()
	enemigo.add_to_group("enemy")
	enemigo.position = player.position + Vector2(100, 0)
	root.add_child(enemigo)
	dlg.mostrar(["Charla con pelea cerca."])
	await create_timer(0.6).timeout
	_check(dlg.texto_actual() != "Charla con pelea cerca." and dlg.hay_narrativa(), "con un enemigo cerca la charla espera")
	enemigo.remove_from_group("enemy")
	enemigo.queue_free()
	await create_timer(1.0).timeout
	_check(dlg.texto_actual() == "Charla con pelea cerca.", "al calmarse, el Amuleto habla")
	await create_timer(4.0).timeout

	# --- respiro entre charlas: la segunda no se pega a la primera
	await create_timer(1.0).timeout
	dlg.seg_entre_charlas = 6.0
	dlg.mostrar(["Primera."])
	await create_timer(3.2).timeout   # termina de leerse (y de salir)
	dlg.mostrar(["Segunda."])
	await create_timer(0.5).timeout
	_check(dlg.texto_actual() != "Segunda." and dlg.hay_narrativa(), "una charla recién terminada hace esperar a la siguiente")
	await create_timer(7.5).timeout
	_check(dlg.texto_actual() == "Segunda." or not dlg.hay_narrativa(), "la charla en espera sale pasado el respiro")
	dlg.seg_charla_vence = 1.0
	dlg.seg_entre_charlas = 100.0
	dlg.mostrar(["Tercera."])
	dlg.mostrar(["Cuarta."])
	await create_timer(2.5).timeout
	_check(not dlg.hay_narrativa() or dlg.texto_actual() == "", "una charla vieja que esperó demasiado se descarta")

	print("DIAG_GLOBOS: FALLOS = ", fallos)
	quit(fallos)


func _check(ok: bool, nombre: String) -> void:
	if ok:
		print("[PASS] ", nombre)
	else:
		fallos += 1
		print("[FAIL] ", nombre)
