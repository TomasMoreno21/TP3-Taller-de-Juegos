extends SceneTree
## Medición manual (con ventana) del nivel 1: carga, nodos, draw calls y ms/frame en 3 puntos.
## godot --path . --resolution 1920x1080 --disable-vsync --max-fps 0 --script res://tests/medir_nivel1.gd
## Variable de entorno ETQ = etiqueta que se imprime. Los resultados salen con prefijo MEDIDA.

func _init() -> void:
	var etq := OS.get_environment("ETQ")
	await process_frame   # los autoload existen recién tras el primer frame
	# Sin cartel ni intro (tapan el juego y mueven la cámara): se miden el nivel y el jugador reales.
	root.get_node("Progresion").marcar_dialogo_visto("intro_nivel1")
	var t0 := Time.get_ticks_msec()
	var esc = (load("res://scenes/nivel1.tscn") as PackedScene).instantiate()
	var t1 := Time.get_ticks_msec()
	esc.get_node("TituloNivel").free()   # sin cartel (tapa el juego)
	root.add_child(esc)
	current_scene = esc
	esc.get_node("Player").global_position = Vector2(1500, 900)   # el Player de la escena puede estar guardado cerca de la salida
	esc.get_node("Player").set("god_mode", true)                  # que nada lo mate ni lo cambie de escena durante la medición
	esc.get_node("SalidaNivel").process_mode = Node.PROCESS_MODE_DISABLED
	var t2 := Time.get_ticks_msec()
	await process_frame
	var t3 := Time.get_ticks_msec()
	await process_frame
	var t4 := Time.get_ticks_msec()
	for i in 120:
		await process_frame
	var p = esc.get_node("Player")
	var fps_pts := []
	var draws := []
	for x in [1500.0, 9000.0, 20500.0]:
		p.global_position = Vector2(x, 900)
		for i in 60:
			await process_frame
		var ta := Time.get_ticks_usec()
		var n := 240
		for i in n:
			await process_frame
		fps_pts.append(snappedf((Time.get_ticks_usec() - ta) / 1000.0 / n, 0.01))
		draws.append(int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)))
	print("MEDIDA ", etq, " | instanciar=", t1 - t0, "ms add_child=", t2 - t1, "ms frame1=", t3 - t2, "ms frame2=", t4 - t3, "ms | ms/frame=", fps_pts, " draw=", draws,
		" | nodos=", int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT)), " vram_mb=", snappedf(Performance.get_monitor(Performance.RENDER_TEXTURE_MEM_USED) / 1048576.0, 0.1),
		" fisica_ms=", snappedf(Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0, 0.01))
	quit()
