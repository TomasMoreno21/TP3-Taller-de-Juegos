extends SceneTree
## Medición manual (con ventana) de un nivel: carga, nodos, draw calls y ms/frame en 3 puntos (checkpoints repartidos).
## NIVEL=1|2|3 godot --path . --resolution 1920x1080 --disable-vsync --max-fps 0 --script res://tests/medir_nivel.gd
## Variable ETQ = etiqueta. Los resultados salen con prefijo MEDIDA. Sin cartel, sin intro, jugador inmortal.

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
	var etq := OS.get_environment("ETQ")
	var nivel := OS.get_environment("NIVEL")
	await process_frame
	var t0 := Time.get_ticks_msec()
	var ps := load("res://scenes/nivel%s.tscn" % nivel) as PackedScene
	var t1 := Time.get_ticks_msec()
	var esc = ps.instantiate()
	var t2 := Time.get_ticks_msec()
	for t in _buscar(esc, "titulo_nivel.gd"):
		t.free()
	for i in _buscar(esc, "intro_nivel.gd"):
		root.get_node("Progresion").marcar_dialogo_visto(i.id_visto)
	var puntos := []
	for c in _buscar(esc, "checkpoint.gd"):
		puntos.append((c as Node2D).global_position)
	puntos.sort_custom(func(a, b): return a.y + a.x * 0.01 < b.y + b.x * 0.01)
	if puntos.size() >= 3:
		puntos = [puntos[0], puntos[puntos.size() / 2], puntos[puntos.size() - 1]]
	root.add_child(esc)
	current_scene = esc
	var t3 := Time.get_ticks_msec()
	var p: Node2D = esc.get_node("Player")
	p.set("god_mode", true)
	for s in _buscar(esc, "salida_nivel.gd"):
		s.process_mode = Node.PROCESS_MODE_DISABLED
	await process_frame
	var t4 := Time.get_ticks_msec()
	await process_frame
	var t5 := Time.get_ticks_msec()
	var ms := []
	var draws := []
	for pt in puntos:
		p.global_position = pt + Vector2(0, -60)
		p.velocity = Vector2.ZERO
		for i in 90:
			await process_frame
		var ta := Time.get_ticks_usec()
		for i in 240:
			await process_frame
		ms.append(snappedf((Time.get_ticks_usec() - ta) / 1000.0 / 240.0, 0.01))
		draws.append(int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)))
	print("MEDIDA nivel", nivel, " ", etq, " | load=", t1 - t0, "ms instanciar=", t2 - t1, "ms add_child=", t3 - t2, "ms frame1=", t4 - t3, "ms frame2=", t5 - t4, "ms | puntos=", puntos.size(),
		" ms/frame=", ms, " draw=", draws, " | nodos=", int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT)), " vram_mb=", snappedf(Performance.get_monitor(Performance.RENDER_TEXTURE_MEM_USED) / 1048576.0, 0.1))
	quit()
