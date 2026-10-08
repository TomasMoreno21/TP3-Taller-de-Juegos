extends SceneTree
## Diag intro del nivel 3: camina por el tramo llano inicial mientras conversan el Humano y el Amuleto; se omite si el jugador aparece lejos del inicio. Uso: --headless --script res://tests/diag_intro_nivel3.gd

var fallos := 0

func _check(c: bool, m: String) -> void:
	print(("[PASS] " if c else "[FAIL] ") + m)
	if not c:
		fallos += 1

func _initialize() -> void:
	var dialogo := root.get_node("Dialogo")
	var it: Array = dialogo._armar("[humano][susurro] hola", "Amuleto", false, false)
	_check(it.size() == 1 and it[0]["hablante"] == "Humano" and it[0]["tono"] == 3, "las etiquetas [humano][susurro] se combinan")

	# 1) Aparece lejos del inicio (como al probar otro tramo): no interviene.
	var lejos: Node = load("res://scenes/nivel3.tscn").instantiate()
	lejos.get_node("Player").position = Vector2(12000, 3000)
	lejos.get_node("IntroNivel").set("probar_en_headless", true)
	lejos.get_node("IntroNivel").set("id_visto", "diag3_lejos")
	root.add_child(lejos)
	await process_frame
	_check(not bool(get_first_node_in_group("player").get("cinematica_activa")), "lejos del inicio la intro se omite")
	lejos.queue_free()
	await process_frame

	# 2) En el inicio real: corre completa.
	var nivel: Node = load("res://scenes/nivel3.tscn").instantiate()
	nivel.get_node("Player").position = Vector2(900, 630)
	var intro: Node = nivel.get_node("IntroNivel")
	var vis_antes := true   # hud.gd se muestra solo en _ready
	intro.set("probar_en_headless", true)
	intro.set("id_visto", "diag3_%d" % Time.get_ticks_msec())
	root.add_child(nivel)
	await process_frame
	var jug := get_first_node_in_group("player")
	_check(bool(jug.get("cinematica_activa")), "en el inicio la intro bloquea al jugador")
	var hecho := [false]
	intro.terminada.connect(func(): hecho[0] = true)
	var x0: float = jug.global_position.x
	var hablantes := {}
	var t0 := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < 13000 and not hecho[0]:
		await process_frame
		hablantes[str(dialogo._item.get("hablante", ""))] = true
	var seg := (Time.get_ticks_msec() - t0) / 1000.0
	_check(seg <= 12.0, "dura como mucho 12 s (%.1f s)" % seg)
	_check(jug.global_position.x > x0 + 400.0, "camina solo (%.0f px)" % (jug.global_position.x - x0))
	_check(not (jug as CharacterBody2D).test_move(jug.global_transform, Vector2(0, 2)) or (jug as CharacterBody2D).is_on_floor(), "no quedó dentro del terreno")
	_check(jug.global_position.x < 1400.0, "no llega al primer pickup (x=%.0f)" % jug.global_position.x)
	_check(hablantes.has("Humano") and hablantes.has("Amuleto"), "conversan el Humano y el Amuleto")
	_check(hecho[0] and not bool(jug.get("cinematica_activa")), "termina y devuelve el control")
	_check(get_first_node_in_group("hud").visible == vis_antes, "el HUD queda como estaba")
	print("DIAG_INTRO_NIVEL3: FALLOS = ", fallos)
	quit(fallos)
