extends SceneTree
## Cierre del juego (victoria_jefe): corre la secuencia completa con tiempos mínimos, sin cambiar de escena.

var fallos := 0


func _init() -> void:
	await process_frame
	var dlg: Node = root.get_node("Dialogo")
	var suelo := StaticBody2D.new()
	var col := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(4000, 40)
	col.shape = rect
	suelo.add_child(col)
	suelo.position = Vector2(0, 100)
	root.add_child(suelo)
	var player: Node2D = load("res://scenes/player.tscn").instantiate()
	player.position = Vector2(0, 40)
	root.add_child(player)
	await process_frame
	await process_frame

	var esc: PackedScene = load("res://scenes/victoria_jefe.tscn")
	_check(esc != null, "Final: la escena carga")
	var v: CanvasLayer = esc.instantiate()
	_check(String(v.escena_siguiente) == "res://scenes/main_menu.tscn", "Final: al terminar vuelve al menú")
	_check(v.lineas.size() == 4 and String(v.lineas[0]).begins_with("[humano]"), "Final: guion A (4 líneas, abre el Humano)")
	_check(String(v.frase).begins_with("Lo que el bosque se llevó"), "Final: frase final del guion A")
	_check(v.textura_hijo == null, "Final: el hijo es placeholder (sin textura)")
	v.escena_siguiente = ""
	v.destello = 0.05
	v.aparicion_hijo = 0.1
	v.pausa_tras_dialogo = 0.05
	v.fundido_negro = 0.05
	v.pausa_negro = 0.05
	v.aparicion_frase = 0.05
	v.duracion_frase = 0.05
	v.desaparicion_frase = 0.05
	var estado := {"fin": false, "vio_narrativa": false}
	v.terminada.connect(func() -> void: estado["fin"] = true)
	root.add_child(v)
	paused = true   # como lo deja nivel_jefe.gd
	var t := 0.0
	while not estado["fin"] and t < 120.0:
		await process_frame
		t += root.get_process_delta_time()
		if dlg.hay_narrativa():
			estado["vio_narrativa"] = true
	paused = false
	_check(bool(estado["vio_narrativa"]), "Final: los globos se muestran (con el árbol pausado)")
	_check(bool(estado["fin"]), "Final: la secuencia termina (%.1f s)" % t)
	_check(not dlg.hay_narrativa(), "Final: no queda diálogo pendiente")
	print("DIAG_FINAL: FALLOS = ", fallos)
	quit(fallos)


func _check(ok: bool, nombre: String) -> void:
	if ok:
		print("[PASS] ", nombre)
	else:
		fallos += 1
		print("[FAIL] ", nombre)
