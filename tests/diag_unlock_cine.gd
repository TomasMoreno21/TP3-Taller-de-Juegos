extends SceneTree
## Cinemática del tótem del Lobo (nivel 1). Con ventana: godot --path . --resolution 1920x1080 --script res://tests/diag_unlock_cine.gd -- <dir_capturas>
func _initialize() -> void:
	var dir := OS.get_cmdline_user_args()[0]
	DirAccess.make_dir_recursive_absolute(dir)
	var nivel: Node = load("res://scenes/nivel1.tscn").instantiate()
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
	var u := nivel.get_node("UnlockLobo") as Node2D
	for i in 40:
		await physics_frame
	player.global_position = u.global_position + Vector2(-300, 0)
	var cam := nivel.get_node("Camara") as Camera2D
	cam.call("modo_normal", true)
	for i in 60:
		await physics_frame
	player.global_position = u.global_position + Vector2(-40, 0)
	var fallos := 0
	var marcas := [0.5, 1.8, 2.6, 3.2]
	var t0 := Time.get_ticks_msec()
	var k := 0
	var congelado := false
	while Time.get_ticks_msec() - t0 < 6500:
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
	if not prog._extra_formas.has(1): fallos += 1; print("FAIL: Lobo no desbloqueado")
	print("DIAG_UNLOCK_CINE: FALLOS = ", fallos)
	quit()
