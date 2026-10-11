extends SceneTree
## Captura SOLO el fondo procedural (capa_cueva.gd) de un nivel en varios puntos, para comparar antes/después de tocar su dibujo.
## NIVEL=1|3 FONDO=<nodo> OUT=<prefijo> godot --path . --resolution 1920x1080 --script res://tests/diag_fondo_capas.gd
## Imprime FONDO draw=[...] por punto. Los PNG salen con el prefijo OUT.

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
	var nivel := OS.get_environment("NIVEL")
	var fondo := OS.get_environment("FONDO")
	var esc = (load("res://scenes/nivel%s.tscn" % nivel) as PackedScene).instantiate()
	for t in _buscar(esc, "titulo_nivel.gd"):
		t.free()
	for i in _buscar(esc, "intro_nivel.gd"):
		root.get_node("Progresion").marcar_dialogo_visto(i.id_visto)
	var cps := []
	for c in _buscar(esc, "checkpoint.gd"):
		cps.append((c as Node2D).global_position)
	cps.sort_custom(func(a, b): return a.y + a.x * 0.01 < b.y + b.x * 0.01)
	root.add_child(esc)
	current_scene = esc
	var p: Node2D = esc.get_node("Player")
	p.set("god_mode", true)
	p.visible = false
	for s in _buscar(esc, "salida_nivel.gd"):
		s.process_mode = Node.PROCESS_MODE_DISABLED
	for n in esc.get_children():
		if n.name != fondo and n.name != "Player" and not (n is Camera2D) and n.name != "StreamingZonas":
			if "visible" in n:
				n.visible = false
			n.process_mode = Node.PROCESS_MODE_DISABLED
	for n in root.get_children():
		if n != esc and n is CanvasLayer:
			n.visible = false
	var fn := esc.get_node(fondo)
	if fn.has_method("set_process") and _scripts(fn) == "fondo_por_camara.gd":
		fn.process_mode = Node.PROCESS_MODE_DISABLED
		fn.visible = true
	var out := OS.get_environment("OUT")
	var draws := []
	var paso := maxi(cps.size() / 6, 1)
	var k := 0
	var i := 0
	while i < cps.size() and k < 6:
		p.global_position = cps[i] + Vector2(0, -60)
		p.velocity = Vector2.ZERO
		for f in 240:
			await process_frame
		root.get_viewport().get_texture().get_image().save_png("%s_%d.png" % [out, k])
		draws.append(int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)))
		k += 1
		i += paso
	print("FONDO nivel", nivel, " ", fondo, " capturas=", k, " draw=", draws)
	quit()
