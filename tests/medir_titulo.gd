extends SceneTree
## Manual (con ventana): capturas del cartel de nivel en user://titulo_*.png
## godot --path . --resolution 1920x1080 --script res://tests/medir_titulo.gd
func _initialize() -> void:
	var nivel: Node = load("res://scenes/nivel2.tscn").instantiate()
	nivel.get_node("IntroNivel").free()
	root.add_child(nivel)
	current_scene = nivel
	for i in 7:
		await create_timer(1.0, true, false, true).timeout
		root.get_viewport().get_texture().get_image().save_png("user://titulo_%d.png" % i)
	print("OK")
	quit()
