extends SceneTree
## Diag título de nivel + intro (niveles 1 y 3): el globo no arranca mientras el título se desvanece, el jugador
## nunca queda con control a mitad de la secuencia ni sin él para siempre, saltear y la red de seguridad funcionan,
## y el título se repite al empezar una partida nueva (Progresion.reset). Dura ~60 s (usa tiempo real).
## Uso: --headless --script res://tests/diag_intro_titulo.gd

var fallos := 0

func _check(c: bool, m: String) -> void:
	print(("[PASS] " if c else "[FAIL] ") + m)
	if not c:
		fallos += 1


func _cargar(ruta: String, spawn: Variant, titulo: String, seg_maximos := -1.0) -> Node:
	var nivel: Node = load(ruta).instantiate()
	if spawn != null:
		nivel.get_node("Player").position = spawn
	var intro: Node = nivel.get_node("IntroNivel")
	intro.set("probar_en_headless", true)
	intro.set("id_visto", "diag_titulo_%d" % Time.get_ticks_msec())
	if seg_maximos > 0.0:
		intro.set("seg_maximos", seg_maximos)
	var ti: Node = nivel.get_node("TituloNivel")
	ti.set("probar_en_headless", true)
	ti.set("titulo", titulo)
	root.add_child(nivel)
	return nivel


func _secuencia(ruta: String, spawn: Variant, x_tope: float) -> void:
	var nombre := ruta.get_file()
	var nivel := _cargar(ruta, spawn, "Diag %s %d" % [nombre, Time.get_ticks_msec()])
	await process_frame
	var jug := get_first_node_in_group("player")
	var ti: Node = nivel.get_node("TituloNivel")
	var intro: Node = nivel.get_node("IntroNivel")
	var dlg := root.get_node("Dialogo")
	var t0 := Time.get_ticks_msec()
	var e := {"listo": -1.0, "titulo_fin": -1.0, "intro_fin": -1.0}   # las lambdas no modifican locales: se usa un diccionario
	var t_globo := -1.0
	ti.listo.connect(func(): e["listo"] = (Time.get_ticks_msec() - t0) / 1000.0)
	ti.terminado.connect(func(): e["titulo_fin"] = (Time.get_ticks_msec() - t0) / 1000.0)
	intro.terminada.connect(func(): e["intro_fin"] = (Time.get_ticks_msec() - t0) / 1000.0)
	var hueco := false          # el jugador tuvo control antes de que terminara la secuencia
	var x0: float = jug.global_position.x
	while (Time.get_ticks_msec() - t0) < 30000 and float(e["intro_fin"]) < 0.0:
		await process_frame
		var ahora := (Time.get_ticks_msec() - t0) / 1000.0
		if t_globo < 0.0 and str(dlg.texto_actual()) != "":
			t_globo = ahora
		if float(e["intro_fin"]) < 0.0 and not bool(jug.get("cinematica_activa")):
			hueco = true
	await create_timer(1.0).timeout
	var t_listo: float = e["listo"]
	var t_titulo_fin: float = e["titulo_fin"]
	var t_intro_fin: float = e["intro_fin"]
	_check(t_listo > 0.0 and t_titulo_fin > t_listo, "%s: el título corre (listo %.1f s, fin %.1f s)" % [nombre, t_listo, t_titulo_fin])
	_check(t_globo > t_titulo_fin, "%s: el primer globo (%.1f s) llega después de que el título termina (%.1f s)" % [nombre, t_globo, t_titulo_fin])
	_check(not hueco, "%s: el jugador no tiene control en medio de la secuencia" % nombre)
	_check(t_intro_fin > 0.0, "%s: la intro termina (%.1f s)" % [nombre, t_intro_fin])
	_check(t_intro_fin - t_listo <= 12.0, "%s: la intro dura ≤ 12 s desde que se va el título (%.1f s)" % [nombre, t_intro_fin - t_listo])
	_check(not bool(jug.get("cinematica_activa")), "%s: el jugador queda con control" % nombre)
	_check(jug.global_position.x > x0 + 400.0 and jug.global_position.x < x_tope, "%s: camina solo y se detiene antes del primer elemento (x %.0f → %.0f)" % [nombre, x0, jug.global_position.x])
	nivel.queue_free()
	await process_frame


func _initialize() -> void:
	await _secuencia("res://scenes/nivel1.tscn", Vector2(-717, 802), 87.0)
	await _secuencia("res://scenes/nivel3.tscn", null, 1400.0)

	# Saltear manteniendo dialog_skip desde el cartel: la intro corta apenas termina de mostrarse el título.
	var n := _cargar("res://scenes/nivel3.tscn", null, "Diag skip %d" % Time.get_ticks_msec())
	await process_frame
	var jug := get_first_node_in_group("player")
	var intro: Node = n.get_node("IntroNivel")
	var t0 := Time.get_ticks_msec()
	var fin := [-1.0]
	var libre_antes := false   # el jugador no debe moverse a ciegas detrás del cartel negro
	intro.terminada.connect(func(): fin[0] = (Time.get_ticks_msec() - t0) / 1000.0)
	Input.action_press("dialog_skip")
	while (Time.get_ticks_msec() - t0) < 12000 and fin[0] < 0.0:
		await process_frame
		if fin[0] < 0.0 and (Time.get_ticks_msec() - t0) < 3500 and not bool(jug.get("cinematica_activa")):
			libre_antes = true
	Input.action_release("dialog_skip")
	_check(not libre_antes, "saltear con el cartel en pantalla: el jugador sigue bloqueado mientras el cartel está en negro")
	_check(fin[0] > 3.0 and fin[0] < 6.5, "saltear: la intro termina apenas el cartel empieza a irse (%.1f s)" % fin[0])
	_check(not bool(jug.get("cinematica_activa")), "saltear: el jugador recupera el control")
	n.queue_free()
	await process_frame

	# Red de seguridad: si algo la cuelga, a los seg_maximos se corta y devuelve el control.
	n = _cargar("res://scenes/nivel3.tscn", null, "Diag max %d" % Time.get_ticks_msec(), 7.0)
	await process_frame
	jug = get_first_node_in_group("player")
	intro = n.get_node("IntroNivel")
	t0 = Time.get_ticks_msec()
	fin = [-1.0]
	intro.terminada.connect(func(): fin[0] = (Time.get_ticks_msec() - t0) / 1000.0)
	while (Time.get_ticks_msec() - t0) < 14000 and fin[0] < 0.0:
		await process_frame
	_check(fin[0] > 0.0 and fin[0] < 9.0, "seg_maximos corta la intro y devuelve el control (%.1f s)" % fin[0])
	_check(not bool(jug.get("cinematica_activa")), "seg_maximos: el jugador no queda bloqueado")
	n.queue_free()
	await process_frame

	# El título se muestra una vez por partida: recargar no lo repite, Progresion.reset sí.
	var titulo := "Diag reset %d" % Time.get_ticks_msec()
	var a := _cargar("res://scenes/nivel3.tscn", null, titulo)
	await process_frame
	_check(bool(a.get_node("TituloNivel").get("activo")), "el título aparece la primera vez")
	a.queue_free()
	await process_frame
	var b := _cargar("res://scenes/nivel3.tscn", null, titulo)
	await process_frame
	_check(not bool(b.get_node("TituloNivel").get("activo")), "recargar el nivel (morir) no repite el título")
	b.queue_free()
	await process_frame
	root.get_node("Progresion").reset()
	var c := _cargar("res://scenes/nivel3.tscn", null, titulo)
	await process_frame
	_check(bool(c.get_node("TituloNivel").get("activo")), "tras una partida nueva (reset) el título vuelve a aparecer")
	c.queue_free()
	await process_frame
	print("DIAG_INTRO_TITULO: FALLOS = ", fallos)
	quit(fallos)
