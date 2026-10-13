extends SceneTree
## Perfil por apagado: en un punto del nivel mide ms/frame, apaga una categoría de nodos y vuelve a medir.
## MODO=vis (oculta, por defecto) | proc (process_mode DISABLED: sin _process/_physics_process, el dibujo queda).
## NIVEL=2 PUNTO=0|1|2 godot --path . --resolution 1920x1080 --disable-vsync --max-fps 0 --script res://tests/prof_nivel.gd
## Salida con prefijo PROF. No modifica nada en disco.

func _scripts(n: Node) -> String:
	var s := n.get_script() as Script
	return s.resource_path.get_file() if s != null else ""


func _todos(esc: Node) -> Array:
	var r := []
	var pila := [esc]
	while not pila.is_empty():
		var n: Node = pila.pop_back()
		for c in n.get_children():
			pila.append(c)
		r.append(n)
	return r


func _medir(frames := 200) -> float:
	## Mediana de 7 tramos (la máquina es ruidosa: el editor y otros procesos compiten por la GPU).
	for i in 15:
		await process_frame
	var tramos := []
	var n := maxi(frames / 7, 20)
	for k in 7:
		var ta := Time.get_ticks_usec()
		for i in n:
			await process_frame
		tramos.append((Time.get_ticks_usec() - ta) / 1000.0 / n)
	tramos.sort()
	return snappedf(tramos[3], 0.01)


func _init() -> void:
	var nivel := OS.get_environment("NIVEL")
	var punto := int(OS.get_environment("PUNTO"))
	await process_frame
	var esc: Node = (load("res://scenes/nivel%s.tscn" % nivel) as PackedScene).instantiate()
	var todos := _todos(esc)
	for n in todos:
		if _scripts(n) == "titulo_nivel.gd":
			n.free()
	for n in todos:
		if is_instance_valid(n) and _scripts(n) == "intro_nivel.gd":
			root.get_node("Progresion").marcar_dialogo_visto(n.id_visto)
	var puntos := []
	for n in todos:
		if is_instance_valid(n) and _scripts(n) == "checkpoint.gd":
			puntos.append((n as Node2D).global_position)
	puntos.sort_custom(func(a, b): return a.y + a.x * 0.01 < b.y + b.x * 0.01)
	if puntos.size() >= 3:
		puntos = [puntos[0], puntos[puntos.size() / 2], puntos[puntos.size() - 1]]
	root.add_child(esc)
	current_scene = esc
	var p: Node2D = esc.get_node("Player")
	p.set("god_mode", true)
	for n in todos:
		if is_instance_valid(n) and _scripts(n) == "salida_nivel.gd":
			n.process_mode = Node.PROCESS_MODE_DISABLED
	await process_frame
	p.global_position = puntos[punto] + Vector2(0, -60)
	p.velocity = Vector2.ZERO
	for i in 90:
		await process_frame
	for i in 400:
		await process_frame
	print("PROF base ", await _medir(), " draw=", int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)),
		" proc_ms=", snappedf(Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0, 0.01),
		" phys_ms=", snappedf(Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0, 0.01))
	# Agrupa por script / clase de los CanvasItem visibles y los oculta de a una categoría.
	var modo_proc := OS.get_environment("MODO") == "proc"
	var cat := {}
	for n in todos:
		if not is_instance_valid(n) or not (n is Node) or (modo_proc and _scripts(n) == "") or (not modo_proc and not (n is CanvasItem)):
			continue
		var k := _scripts(n)
		if k == "":
			k = "[" + n.get_class() + "]"
		if not cat.has(k):
			cat[k] = []
		cat[k].append(n)
	var res := []
	for k in cat.keys():
		if k == "player.gd" or k == "[Node2D]":
			continue
		var lista: Array = cat[k]
		var vis := []
		for n in lista:
			if modo_proc or n.visible:
				vis.append(n)
		if vis.is_empty():
			continue
		var b0: float = await _medir(120)
		for n in vis:
			if modo_proc:
				n.process_mode = Node.PROCESS_MODE_DISABLED
			else:
				n.visible = false
		var t: float = await _medir(120)
		for n in vis:
			if modo_proc:
				n.process_mode = Node.PROCESS_MODE_INHERIT
			else:
				n.visible = true
		res.append([snappedf(b0 - t, 0.01), k, vis.size()])
	res.sort_custom(func(a, b): return a[0] > b[0])
	for r in res:
		print("PROF ahorro ", r[0], " ms  ", r[1], " x", r[2])
	# Material del terreno
	var tm := esc.get_node_or_null("TileMap") as CanvasItem
	if tm != null:
		var m = tm.material
		tm.material = null
		print("PROF sin shader terreno -> ", await _medir(120))
		tm.material = m
		tm.visible = false
		print("PROF sin TileMap -> ", await _medir(120))
		tm.visible = true
	quit()
