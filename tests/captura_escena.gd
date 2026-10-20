extends SceneTree
## Captura de una escena suelta (menús, cómic, créditos). Uso (con ventana):
## godot --path . --resolution 1920x1080 --script res://tests/captura_escena.gd -- <escena> <png> [frames] [avanzar]
## avanzar = clics simulados al cómic (comic.avanzar()) antes de capturar.

func _initialize() -> void:
	var a := OS.get_cmdline_user_args()
	if root.has_node("ModoPrueba"):
		root.get_node("ModoPrueba").set("habilitado", false)  # sin botones de prueba en las capturas
	var n: Node = load(a[0]).instantiate()
	if "cambiar_escena_al_terminar" in n:
		n.cambiar_escena_al_terminar = false
	root.add_child(n)
	var frames := int(a[2]) if a.size() > 2 else 90
	for i in frames:
		await process_frame
	if a.size() > 3 and n.has_method("avanzar"):
		for i in int(a[3]):
			n.avanzar()
			for k in 20:
				await process_frame
		for k in 120:
			await process_frame
	await RenderingServer.frame_post_draw
	root.get_viewport().get_texture().get_image().save_png(a[1])
	quit()
