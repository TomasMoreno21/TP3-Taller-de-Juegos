extends SceneTree
## Manual (con ventana): capturas de los globos en user://globo_*.png
## godot --path . --resolution 1920x1080 --script res://tests/medir_globos.gd
func _initialize() -> void:
	var nivel: Node = load("res://scenes/nivel2.tscn").instantiate()
	nivel.get_node("TituloNivel").free()
	nivel.get_node("IntroNivel").free()
	root.add_child(nivel)
	current_scene = nivel
	await create_timer(1.0, true, false, true).timeout
	var d := root.get_node("Dialogo")
	d.mostrar(["Esta cueva es de los cultistas, y hay huellas.", "[alerta]¡Cuidado, algo se mueve!", "[grito]¡Atrás!", "[humano][susurro]¿Y si llegamos tarde?"], "Amuleto")
	var n := 0
	for t in [0.12, 0.2, 0.5, 1.5, 3.2, 5.2, 7.5, 9.5]:
		await create_timer(t if n == 0 else t - [0.12, 0.2, 0.5, 1.5, 3.2, 5.2, 7.5, 9.5][n - 1], true, false, true).timeout
		root.get_viewport().get_texture().get_image().save_png("user://globo_%d.png" % n)
		n += 1
	print("OK")
	quit()
