extends SceneTree
## Manual (con ventana): capturas de la intro del nivel 2 en user://intro_n2_*.png (con x del jugador y zoom)
## godot --path . --resolution 1920x1080 --script res://tests/medir_intro_n2.gd
func _initialize() -> void:
	var nivel: Node = load("res://scenes/nivel2.tscn").instantiate()
	nivel.get_node("TituloNivel").free()
	nivel.get_node("IntroNivel").una_vez = false
	root.add_child(nivel)
	current_scene = nivel
	var t0 := Time.get_ticks_msec()
	nivel.get_node("IntroNivel").terminada.connect(func(): print("intro terminada a los %.1f s" % ((Time.get_ticks_msec() - t0) / 1000.0)))
	var p: Node2D = nivel.get_node("Player")
	var cam: Camera2D = nivel.get_node("Camara")
	var t := 0.0
	for i in 8:
		await create_timer(2.0, true, false, true).timeout
		t += 2.0
		root.get_viewport().get_texture().get_image().save_png("user://intro_n2_%02d.png" % int(t))
		print("t=%.0f x=%.0f cam=%.0f zoom=%.2f" % [t, p.global_position.x, cam.get_screen_center_position().x, cam.zoom.x])
	print("OK ", OS.get_user_data_dir())
	quit()
