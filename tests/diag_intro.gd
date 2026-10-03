extends SceneTree
## Diag intro de nivel: en el nivel 1 bloquea al jugador, mueve la cámara por los planos,
## entrega el control y no se repite. Uso: --headless --script res://tests/diag_intro.gd

var fallos := 0

func _check(c: bool, m: String) -> void:
	print(("[PASS] " if c else "[FAIL] ") + m)
	if not c:
		fallos += 1

func _initialize() -> void:
	# 1) En headless sin la bandera la intro se omite (los demás tests dependen de eso).
	var n0: Node = load("res://scenes/nivel1.tscn").instantiate()
	root.add_child(n0)
	await process_frame
	var p0 := get_first_node_in_group("player")
	_check(not bool(p0.get("cinematica_activa")), "headless: la intro se omite y el jugador tiene control")
	n0.queue_free()
	await process_frame

	# 2) Con la bandera: corre completa.
	var prog := root.get_node_or_null("Progresion")
	var nivel: Node = load("res://scenes/nivel1.tscn").instantiate()
	var intro: Node = nivel.get_node("IntroNivel")
	intro.set("probar_en_headless", true)
	var id_test := "diag_intro_%d" % Time.get_ticks_msec()
	intro.set("id_visto", id_test)
	root.add_child(nivel)
	await process_frame
	var jug := get_first_node_in_group("player")
	var cam := nivel.get_node("Camara") as Camera2D
	_check(bool(jug.get("cinematica_activa")), "al empezar el jugador queda bloqueado")
	_check(jug.call("_dialogo_bloquea_input"), "el input del jugador está bloqueado")
	var hud := get_first_node_in_group("hud") as CanvasLayer
	_check(hud != null and not hud.visible, "el HUD se oculta durante la intro")
	_check(absf(cam.zoom.x - 1.15) < 0.01, "plano 1: la cámara arranca sobre el jugador (zoom %.2f)" % cam.zoom.x)
	var hecho := [false]
	intro.terminada.connect(func(): hecho[0] = true)
	var x0: float = jug.global_position.x
	var dialogo := root.get_node("Dialogo")
	var hablantes := {}
	var t0 := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < 13000 and not hecho[0]:
		await process_frame
		hablantes[str(dialogo._item.get("hablante", ""))] = true
	var seg := (Time.get_ticks_msec() - t0) / 1000.0
	_check(seg <= 12.0, "dura como mucho 12 s (%.1f s)" % seg)
	_check(jug.global_position.x > x0 + 50.0, "el jugador camina solo durante la intro (%.0f px)" % (jug.global_position.x - x0))
	_check(jug.global_position.x < 87.0, "no llega al primer tutorial (x=%.0f)" % jug.global_position.x)
	_check(hablantes.has("Humano") and hablantes.has("Amuleto"), "conversan el Humano y el Amuleto")
	_check(hecho[0], "la intro termina y emite terminada")
	_check(not bool(jug.get("cinematica_activa")), "al terminar el jugador recupera el control")
	_check(hud != null and hud.visible, "el HUD vuelve")
	await create_timer(1.0).timeout
	nivel.queue_free()
	await process_frame

	# 3) No se repite.
	if prog != null:
		var n2: Node = load("res://scenes/nivel1.tscn").instantiate()
		var i2: Node = n2.get_node("IntroNivel")
		i2.set("probar_en_headless", true)
		i2.set("id_visto", id_test)
		root.add_child(n2)
		await process_frame
		var j2 := get_first_node_in_group("player")
		_check(not bool(j2.get("cinematica_activa")), "ya vista: no se repite")
	print("DIAG_INTRO: FALLOS = ", fallos)
	quit(fallos)
