extends SceneTree

var fallos := 0


func _init() -> void:
	await process_frame
	var dlg: Node = root.get_node("Dialogo")
	var prog: Node = root.get_node("Progresion")
	prog.reset()
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
	await process_frame

	# --- se tacha sola: acción ya hecha → el paso ni aparece
	prog.acciones_hechas["saltar"] = true
	var p2 := _paso("tut_saltar", 1)
	var p1 := _paso("tut_mover", 0)
	p1.paso_siguiente = p1.get_path_to(p2)
	p1.activar(player)
	await process_frame
	_check(dlg.lista_existe("tut_mover") and not dlg.lista_existe("tut_saltar"), "una acción ya hecha no se pide de nuevo")

	# --- pista si se traba
	p1.segundos_pista = 0.4
	await create_timer(0.8).timeout
	_check(dlg.lista._items[0].get("pista", false), "si se traba, la tarea late en la lista")
	_check(dlg.texto_actual().contains("Humano"), "el Amuleto da una pista (%s)" % dlg.texto_actual())
	_check(not prog.ayuda_vista.has(dlg.texto_actual()), "la pista no se guarda como consejo")

	# --- fuera de orden: hacer un paso futuro lo tacha solo
	var p3 := _paso("tut_ligero", 2)
	var p4 := _paso("tut_fuerte", 3)
	p3.paso_siguiente = p3.get_path_to(p4)
	p3.activar(player)
	await process_frame
	_check(dlg.lista_existe("tut_fuerte"), "los pasos siguientes ya están listados")
	dlg.hecho("golpe_fuerte")
	await process_frame
	var estado_fuerte := -1
	for it in dlg.lista._items:
		if it["id"] == "tut_fuerte":
			estado_fuerte = it["estado"]
	_check(estado_fuerte == 2, "hacer un paso antes de su turno lo tacha solo")

	# --- nivel de ayuda
	dlg.nivel_ayuda = 0
	dlg.mostrar_tip(["no debería verse"])
	await create_timer(0.3).timeout
	_check(dlg.texto_actual() != "no debería verse", "con ayuda Ninguna no hay consejos")
	dlg.nivel_ayuda = 2

	# --- ayuda guarda consejos
	await create_timer(5.0).timeout
	dlg.mostrar_tip(["Un consejo de prueba"])
	await create_timer(0.2).timeout
	_check(prog.ayuda_vista.has("Un consejo de prueba"), "los consejos se guardan para releerlos")

	# --- reacciones: una, y la segunda espera (freno anti-molestia)
	await create_timer(5.0).timeout
	var reac: Node = dlg.get_node("Reacciones")
	reac._t = 100.0
	reac._ultimo_comentario = -99.0
	reac._pedir("puas")
	await create_timer(0.2).timeout
	var texto1: String = dlg.texto_actual()
	_check(["Cuidado con las púas.", "Las púas no perdonan, Humano."].has(texto1), "reacciona a las púas (%s)" % texto1)
	reac._pedir("racha")
	_check(reac._pendiente == "racha", "el segundo comentario espera (no habla seguido)")

	print("DIAG_AYUDA: FALLOS = ", fallos)
	quit(fallos)


func _paso(id: String, accion: int) -> Node:
	var n: Node = load("res://scenes/tutorial_paso.tscn").instantiate()
	n.paso_id = id
	n.accion = accion
	n.position = Vector2(5000, 0)
	root.add_child(n)
	return n


func _check(ok: bool, nombre: String) -> void:
	if ok:
		print("[PASS] ", nombre)
	else:
		fallos += 1
		print("[FAIL] ", nombre)
