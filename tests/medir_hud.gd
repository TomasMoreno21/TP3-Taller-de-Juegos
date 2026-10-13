extends SceneTree
## Herramienta manual (necesita ventana): captura el HUD en nivel 1 con daño, fragmentos y combo,
## y la barra del jefe, en user://hud_*.png.
## godot --path . --resolution 1920x1080 --script res://tests/medir_hud.gd

func _initialize() -> void:
	var nivel: Node = load("res://scenes/nivel1.tscn").instantiate()
	root.add_child(nivel)
	for i in 60:
		await physics_frame
	var p: CharacterBody2D = get_first_node_in_group("player")
	var hud: Node = get_first_node_in_group("hud")
	_limpiar(root)
	p.take_damage(28)
	p.call("_transformar", 1, true)
	hud._on_racha_changed(7)
	hud.get_node("Derecha/ProgBar").max_value = 25
	hud.get_node("Derecha/ProgBar").value = 14
	hud.visible = true
	await create_timer(1.0, true, false, true).timeout
	hud.visible = true
	root.get_viewport().get_texture().get_image().save_png("user://hud_juego.png")
	var im2 := root.get_viewport().get_texture().get_image()
	im2.resize(1280, 720, Image.INTERPOLATE_LANCZOS)
	im2.save_png("user://hud_juego_1280.png")
	var b = hud.get_node("BossBar")
	hud.visible = true
	b.visible = true
	hud.get_node("BossBar/Panel/Col/Envoltura/Fill").value = 0.6
	hud.get_node("BossBar/Panel/Col/Envoltura/FillEco").value = 0.72
	await create_timer(0.3, true, false, true).timeout
	root.get_viewport().get_texture().get_image().save_png("user://hud_jefe.png")
	print("OK ", OS.get_user_data_dir())
	quit()


func _limpiar(n: Node) -> void:
	for c in n.get_children():
		var sc: Script = c.get_script()
		if sc != null and (sc.resource_path.ends_with("titulo_nivel.gd") or sc.resource_path.ends_with("intro_nivel.gd") or sc.resource_path.contains("dialog")):
			c.queue_free()
		else:
			_limpiar(c)
