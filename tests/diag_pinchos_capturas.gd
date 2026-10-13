extends SceneTree
## Capturas deterministas de varios grupos de pinchos del nivel 1 (para comparar antes/después de tocar su dibujo)
## y conteo de llamadas de dibujo. godot --path . --resolution 1920x1080 --script res://tests/diag_pinchos_capturas.gd
## Variable OUT = prefijo de los PNG. Los resultados salen con prefijo PIN.

func _init() -> void:
	await process_frame
	root.get_node("Progresion").marcar_dialogo_visto("intro_nivel1")
	var esc = (load("res://scenes/nivel1.tscn") as PackedScene).instantiate()
	esc.get_node("TituloNivel").free()
	esc.get_node("Noche").free()   # luciérnagas al azar
	for d in esc.get_node("Decoracion").find_children("*", "Node2D", true, false):
		if d.get("viento") != null:
			d.set("viento", false)
			d.set("parpadeo", false)
	root.add_child(esc)
	current_scene = esc
	for n in root.get_children():
		if n != esc and n is CanvasLayer:
			n.visible = false
	var p: Node2D = esc.get_node("Player")
	p.set("god_mode", true)
	p.visible = false
	esc.get_node("SalidaNivel").process_mode = Node.PROCESS_MODE_DISABLED
	if OS.get_environment("SOLO_PINCHOS") != "0":
		# Solo los pinchos sobre el color de fondo: la captura es determinista y compara únicamente su dibujo.
		for n in esc.get_children():
			if n.name != "Pinchos" and n.name != "Player" and not (n is Camera2D) and n.name != "StreamingZonas":
				if "visible" in n:
					n.visible = false
				n.process_mode = Node.PROCESS_MODE_DISABLED
	else:
		esc.get_node("Hud").visible = false
	var todos := get_nodes_in_group("pinchos")
	todos.sort_custom(func(a, b): return a.global_position.x < b.global_position.x)
	var out := OS.get_environment("OUT")
	var paso := maxi(todos.size() / 14, 1)
	var i := 0
	var cap := 0
	var t_draw: Array = []
	while i < todos.size() and cap < 14:
		var g: Node2D = todos[i]
		p.global_position = g.global_position + Vector2(0, -260)
		p.velocity = Vector2.ZERO
		for k in 120:
			await process_frame
		root.get_viewport().get_texture().get_image().save_png("%s_%d.png" % [out, cap])
		t_draw.append(int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)))
		cap += 1
		i += paso
	print("PIN grupos=", todos.size(), " capturas=", cap, " draw=", t_draw)
	quit()
