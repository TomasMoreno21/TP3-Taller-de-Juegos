extends SceneTree
## Compara el primer plano del nivel 1 con y sin hornear (captura a captura) y cuenta nodos / llamadas de dibujo.
## godot --path . --resolution 1920x1080 --script res://tests/diag_primer_plano_horneado.gd   (variables: HORNEAR=0|1, OUT=prefijo de PNG)

func _init() -> void:
	await process_frame
	root.get_node("Progresion").marcar_dialogo_visto("intro_nivel1")
	var esc = (load("res://scenes/nivel1.tscn") as PackedScene).instantiate()
	esc.get_node("TituloNivel").free()
	var hornear := OS.get_environment("HORNEAR") != "0"
	var grupos := []
	for c in esc.get_node("PrimerPlano").get_children():
		if c is PrimerPlano:
			c.hornear_poligonos = hornear
			grupos.append(c)
	var anclas := []
	for g in grupos:
		anclas.append(g.global_position)
		for d in g.find_children("*", "Node2D", true, false):
			if d.get("viento") != null:
				d.set("viento", false)    # sin viento: la captura es determinista
				d.set("parpadeo", false)
	root.add_child(esc)
	current_scene = esc
	var p: Node2D = esc.get_node("Player")
	p.set("god_mode", true)
	esc.get_node("SalidaNivel").process_mode = Node.PROCESS_MODE_DISABLED
	var out := OS.get_environment("OUT")
	var nodos_pp := 0
	for i in grupos.size():
		var a: Vector2 = anclas[i]
		p.global_position = Vector2(a.x, 900)
		p.visible = false
		for n in esc.get_children():
			if n.name == "Noche":
				n.queue_free()   # luciérnagas al azar: la captura debe ser determinista
			elif n.name != "PrimerPlano" and n.name != "Player" and not (n is Camera2D) and n.name != "StreamingZonas":
				if "visible" in n:
					n.visible = false
				n.process_mode = Node.PROCESS_MODE_DISABLED   # que ningún script los vuelva a mostrar
		for n in root.get_children():
			if n != esc and n is CanvasLayer:
				n.visible = false   # globos del Amuleto, etc.
		for k in 300:
			await process_frame
		var img := root.get_viewport().get_texture().get_image()
		img.save_png("%s_%d.png" % [out, i])
		print("PP grupo ", i, " ancla=", a, " draw=", int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)))
	var total := 0
	for g in grupos:
		total += 1 + g.find_children("*", "", true, false).size()
	print("PP hornear=", hornear, " nodos del primer plano=", total)
	quit()
