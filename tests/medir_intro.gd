extends SceneTree
## Manual (con ventana): mide y captura la secuencia título + intro de un nivel.
## Capturas en user://intro_<nivel>_NN.png y una línea por evento (título, globos, destello, control).
##   godot --path . --resolution 1920x1080 --script res://tests/medir_intro.gd -- nivel1|nivel3 [x,y]
## Con otro nivel: pasar su nombre de escena (sin .tscn). Los tiempos son desde que carga el nivel.

const CAPTURAS := [0.6, 2.0, 3.6, 4.6, 5.4, 6.3, 7.2, 9.0, 11.0, 13.0, 14.9, 15.6, 17.0]

func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	var nombre: String = args[0] if not args.is_empty() else "nivel1"
	var nivel: Node = load("res://scenes/%s.tscn" % nombre).instantiate()
	var intro: Node = nivel.get_node("IntroNivel")
	intro.set("una_vez", false)
	var ti := nivel.get_node_or_null("TituloNivel")
	if args.size() > 1:   # opcional: posición de arranque "x,y" (p. ej. nivel1 -717,802)
		var xy := args[1].split(",")
		nivel.get_node("Player").position = Vector2(float(xy[0]), float(xy[1]))
	root.add_child(nivel)
	current_scene = nivel
	await process_frame
	var jug := get_first_node_in_group("player") as Node2D
	var dlg := root.get_node("Dialogo")
	var t0 := Time.get_ticks_msec()
	var t := func() -> float: return (Time.get_ticks_msec() - t0) / 1000.0
	if ti != null:
		ti.listo.connect(func(): print("[%.2f] título: listo (empieza el desvanecimiento)" % t.call()))
		ti.terminado.connect(func(): print("[%.2f] título: terminado" % t.call()))
	intro.terminada.connect(func(): print("[%.2f] intro: terminada (control devuelto)" % t.call()))
	var ultimo := ""
	var ctrl_prev := true
	var sig := 0
	var fin := 0.0
	while t.call() < 18.0:
		await process_frame
		var txt := str(dlg.texto_actual())
		if txt != ultimo and txt != "":
			print("[%.2f] globo (%s): %s" % [t.call(), str(dlg._item.get("hablante", "")), txt])
		ultimo = txt
		var ctrl: bool = bool(jug.get("cinematica_activa"))
		if ctrl != ctrl_prev:
			print("[%.2f] jugador %s (x=%.0f)" % [t.call(), "SIN control" if ctrl else "CON control", jug.global_position.x])
			ctrl_prev = ctrl
		if sig < CAPTURAS.size() and t.call() >= CAPTURAS[sig]:
			root.get_viewport().get_texture().get_image().save_png("user://intro_%s_%02d.png" % [nombre, sig])
			sig += 1
	print("OK ", OS.get_user_data_dir())
	quit()
