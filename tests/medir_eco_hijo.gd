extends SceneTree
## Manual, con ventana: corre la escena larga del eco del hijo y mide cuánto dura y si devuelve el control.
## godot --path . --script res://tests/medir_eco_hijo.gd
func _initialize() -> void:
	_run.call_deferred()
func _run() -> void:
	var escena: Node = (load("res://scenes/nivel1.tscn") as PackedScene).instantiate()
	root.add_child(escena)
	for i in 30: await process_frame
	root.get_node("Progresion").dialogos_vistos.erase("eco_hijo")
	var eco: Node = escena.get_node("EcoHijo")
	var j: Node = get_first_node_in_group("player")
	var t0 := Time.get_ticks_msec()
	var cont := [0]
	eco.terminado.connect(func() -> void: cont[0] = Time.get_ticks_msec() - t0)
	root.get_node("Dialogo").dialogo_terminado.connect(func() -> void: print("ECO dialogo_terminado a los ms=", Time.get_ticks_msec() - t0))
	eco._on_body_entered(j)
	await process_frame
	print("ECO bloqueado al inicio=", j.get("cinematica_activa"))
	var d: Node = root.get_node("Dialogo")
	while cont[0] == 0 and Time.get_ticks_msec() - t0 < 45000:
		await create_timer(0.3).timeout
	print("ECO duración_ms=", cont[0], " control_devuelto=", j.get("cinematica_activa") != true)
	quit()
