extends SceneTree
## Cinemática del tótem del Lobo (nivel 1). Con ventana: godot --path . --resolution 1920x1080 --script res://tests/diag_unlock_cine.gd -- <dir_capturas> [escena] [nodo] [forma]
func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	var dir: String = args[0]
	var escena: String = args[1] if args.size() > 1 else "res://scenes/nivel1.tscn"
	var nodo: String = args[2] if args.size() > 2 else "UnlockLobo"
	var forma_id: int = int(args[3]) if args.size() > 3 else 1
	DirAccess.make_dir_recursive_absolute(dir)
	var nivel: Node = load(escena).instantiate()
	root.add_child(nivel)
	await physics_frame
	await physics_frame
	for t in get_nodes_in_group("titulo_nivel"):
		t.queue_free()
	for n in nivel.get_children():
		if n is IntroNivel:
			n.queue_free()
	var player := get_first_node_in_group("player") as CharacterBody2D
	player.set("cinematica_activa", false)
	player.set("god_mode", true)
	var u := nivel.get_node(nodo) as Node2D
	for i in 40:
		await physics_frame
	player.global_position = u.global_position + Vector2(-300, 0)
	var cam := nivel.get_node("Camara") as Camera2D
	cam.call("modo_normal", true)
	for i in 60:
		await physics_frame
	player.global_position = u.global_position + Vector2(-40, 0)
	var fallos := 0
	var marcas := [1.8, 3.2, 4.4, 6.0, 7.2]
	var t0 := Time.get_ticks_msec()
	var k := 0
	var congelado := false
	while Time.get_ticks_msec() - t0 < 10000:
		await process_frame
		var dt := (Time.get_ticks_msec() - t0) / 1000.0
		if player.get("cinematica_activa"):
			congelado = true
		if k < marcas.size() and dt >= marcas[k]:
			await RenderingServer.frame_post_draw
			root.get_viewport().get_texture().get_image().save_png("%s/cine_%d.png" % [dir, k])
			k += 1
	var prog := root.get_node("Progresion")
	if not congelado: fallos += 1; print("FAIL: no congeló al jugador")
	if player.get("cinematica_activa"): fallos += 1; print("FAIL: control no devuelto")
	if not prog._extra_formas.has(forma_id): fallos += 1; print("FAIL: Lobo no desbloqueado")
	print("DIAG_UNLOCK_CINE: FALLOS = ", fallos)
	quit()
