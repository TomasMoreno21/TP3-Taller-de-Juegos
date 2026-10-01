extends SceneTree

var fallos := 0


func _init() -> void:
	await process_frame
	var comic: Control = load("res://scenes/comic_intro.tscn").instantiate()
	comic.cambiar_escena_al_terminar = false
	root.add_child(comic)
	var hecho := [false]
	comic.terminado.connect(func(): hecho[0] = true)
	await process_frame

	var v: Array = comic._vinetas
	_check(v.size() == 6, "hay 6 viñetas (son %d)" % v.size())
	var todas_ocultas := true
	for x in v:
		todas_ocultas = todas_ocultas and not x.revelada
	_check(todas_ocultas, "arrancan todas ocultas")

	await create_timer(0.9).timeout
	_check(v[0].revelada and not v[1].revelada, "la primera aparece sola")
	comic.avanzar()   # completa el texto mientras tipea
	_check(not v[0].esta_tipeando() and not v[1].revelada, "un clic mientras escribe solo completa el texto")
	comic.avanzar()
	_check(v[1].revelada and not v[2].revelada, "el siguiente clic revela la viñeta 2")
	for i in 4:
		comic.avanzar()
		comic.avanzar()
	_check(v[5].revelada, "llega a la viñeta 6")
	_check(not hecho[0], "no termina antes de tiempo")
	comic.avanzar()   # completa texto
	comic.avanzar()   # clic final
	_check(hecho[0], "tras la última, un clic emite terminado")

	var c2: Control = load("res://scenes/comic_intro.tscn").instantiate()
	c2.cambiar_escena_al_terminar = false
	root.add_child(c2)
	var h2 := [false]
	c2.terminado.connect(func(): h2[0] = true)
	await process_frame
	c2.omitir()
	var todas := true
	for x in c2._vinetas:
		todas = todas and x.revelada
	_check(h2[0] and todas, "omitir muestra todo y termina")
	print("DIAG_COMIC: FALLOS = ", fallos)
	quit(fallos)


func _check(ok: bool, nombre: String) -> void:
	if ok:
		print("[PASS] ", nombre)
	else:
		fallos += 1
		print("[FAIL] ", nombre)
