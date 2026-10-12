extends SceneTree
## Captura la barrera de energía del nivel 2 con el tiempo congelado, para comparar píxel a píxel contra una versión de referencia.
## BARRERA=0|1 (cuál de las dos) OUT=ruta.png [ORIG=ruta_a_script_de_referencia.gd]
## godot --path . --resolution 1920x1080 --script res://tests/diag_barrera_fx.gd
## También imprime FX: tiempo de _draw medido (ms por frame) con la barrera a la vista.

func _scripts(n: Node) -> String:
	var s := n.get_script() as Script
	return s.resource_path.get_file() if s != null else ""


func _buscar(esc: Node, archivo: String) -> Array:
	var r := []
	var pila := [esc]
	while not pila.is_empty():
		var n: Node = pila.pop_back()
		for c in n.get_children():
			pila.append(c)
		if _scripts(n) == archivo:
			r.append(n)
	return r


func _init() -> void:
	await process_frame
	var esc: Node = (load("res://scenes/nivel2.tscn") as PackedScene).instantiate()
	for t in _buscar(esc, "titulo_nivel.gd"):
		t.free()
	for i in _buscar(esc, "intro_nivel.gd"):
		root.get_node("Progresion").marcar_dialogo_visto(i.id_visto)
	root.add_child(esc)
	current_scene = esc
	for s in _buscar(esc, "salida_nivel.gd"):
		s.process_mode = Node.PROCESS_MODE_DISABLED
	var p: Node2D = esc.get_node("Player")
	p.set("god_mode", true)
	var idx := int(OS.get_environment("BARRERA"))
	var fxs := _buscar(esc, "barrera_energia_fx.gd")
	fxs.sort_custom(func(a, b): return a.global_position.x < b.global_position.x)
	var orig := OS.get_environment("ORIG")
	if orig != "":
		var sc := GDScript.new()
		sc.source_code = FileAccess.get_file_as_string(orig)
		sc.reload()
		for f in fxs:
			f.set_script(sc)
	var fx: Node2D = fxs[idx]
	await process_frame
	# Acerca al jugador (el ajuste al hueco se mide con el jugador a < 1600 px) y deja que mida.
	p.global_position = fx.global_position + Vector2(-420, 250)
	p.velocity = Vector2.ZERO
	for i in 150:
		p.velocity = Vector2.ZERO
		await process_frame
	var t_dibujo := 0.0
	# Congela el efecto (sin chispas) y dibuja un instante fijo.
	fx.process_mode = Node.PROCESS_MODE_DISABLED
	fx.set("_t", 3.0)
	fx.set("_chispa_pts", PackedVector2Array())
	fx.queue_redraw()
	p.global_position = fx.global_position + Vector2(-420, 250)
	for i in 5:
		p.velocity = Vector2.ZERO
		await process_frame
	var out := OS.get_environment("OUT")
	if out != "":
		get_root().get_viewport().get_texture().get_image().save_png(out)
	# Costo: con la barrera a la vista y animándose, ms por frame con y sin ella visible.
	fx.process_mode = Node.PROCESS_MODE_INHERIT
	for i in 30:
		p.velocity = Vector2.ZERO
		await process_frame
	var ta := Time.get_ticks_usec()
	for i in 240:
		p.velocity = Vector2.ZERO
		await process_frame
	var con := (Time.get_ticks_usec() - ta) / 1000.0 / 240.0
	print("FX ms/frame con barrera a la vista=", snappedf(con, 0.01), " draw=", int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)),
		" perfil_px=", (fx.get("_px") as PackedFloat32Array).size(), " ajustado=", fx.get("_ajustado"))
	quit()
