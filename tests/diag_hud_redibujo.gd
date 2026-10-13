extends SceneTree
## Comprueba que el HUD redibujado "solo si cambia" (hud_dial.gd, hud_barra_tinta.gd) se ve igual que redibujándolo siempre.
## Mueve el HUD por un guion fijo y guarda recortes en frames fijos. Correr dos veces con --fixed-fps 60 (tiempo determinista)
## y comparar los PNG:  FORZAR=0 (lógica nueva)  vs  FORZAR=1 (invalida la firma en cada frame = redibuja siempre, como antes).
## FORZAR=0|1 OUT=<prefijo> godot --path . --resolution 1920x1080 --fixed-fps 60 --script res://tests/diag_hud_redibujo.gd

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
	var forzar := OS.get_environment("FORZAR") == "1"
	var out := OS.get_environment("OUT")
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
	p.process_mode = Node.PROCESS_MODE_DISABLED   # el jugador no toca el HUD durante la prueba
	var hud: Node = get_first_node_in_group("hud")
	# Solo el HUD a la vista (el mundo no es determinista y ensuciaría la comparación).
	esc.visible = false
	for c in esc.get_children():
		if c is CanvasLayer and c != hud:
			c.visible = false
	var dial: Control = _buscar(hud, "hud_dial.gd")[0]
	var barras := _buscar(hud, "hud_barra_tinta.gd")
	print("HUDTEST dial=", dial.name, " barras=", barras.size(), " forzar=", forzar)
	var capturas := [35, 60, 100, 125, 150, 190, 240, 275, 310, 345, 380]
	for f in range(1, 400):
		await process_frame
		if forzar:   # equivale al código anterior: redibujar en _process de cada frame (antes de que muevan los tweens)
			dial._firma_dibujo = []
			for b in barras:
				b._firma_dibujo = []
		match f:
			40: dial.set_energia(30.0)
			70: dial.fijar_seleccion(1)
			85: dial.pulso_transformacion()
			110:
				dial.forma_actual = 1
				dial.set_energia(60.0)
			140: dial.set_energia(18.0)   # energía baja: el aro pulsa con el tiempo
			180: dial.set_cooldown(2.5)
			215: dial.set_cooldown(0.8)
			235: dial.set_cooldown(0.0)
			260: dial.rechazo()
			290:
				dial.set_energia(100.0)
				dial.forma_actual = 0
				dial.pulso_energia()
			300:
				for b in barras:
					var src := b.get_node_or_null(b.fuente) as ProgressBar
					if src != null:
						src.value = src.max_value * 0.4
					b.pop()
			330:
				for b in barras:
					var src := b.get_node_or_null(b.fuente) as ProgressBar
					if src != null:
						src.value = src.max_value * 0.9
		if capturas.has(f) and out != "":
			var img := get_root().get_viewport().get_texture().get_image()
			img.get_region(Rect2i(0, 0, 520, 190)).save_png("%s_%03d.png" % [out, f])
	quit()
