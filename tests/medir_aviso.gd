extends SceneTree
## Manual (con ventana): captura de un globo y del aviso de HUD en user://globo_estilo.png y user://aviso_hud.png
## godot --path . --resolution 1920x1080 --script res://tests/medir_aviso.gd
func _initialize() -> void:
	var nivel: Node = load("res://scenes/nivel2.tscn").instantiate()
	nivel.get_node("TituloNivel").free()
	nivel.get_node("IntroNivel").free()
	root.add_child(nivel)
	current_scene = nivel
	await create_timer(1.0, true, false, true).timeout
	var d := root.get_node("Dialogo")
	d.mostrar(["[humano][susurro]Mi hijo estuvo en este camino."], "Amuleto", false, true)
	await create_timer(2.0, true, false, true).timeout
	root.get_viewport().get_texture().get_image().save_png("user://globo_estilo.png")
	await create_timer(4.0, true, false, true).timeout
	d.mostrar_tip(["Trepá con {trepar}, soltate con {jump}."])
	await create_timer(1.0, true, false, true).timeout
	root.get_viewport().get_texture().get_image().save_png("user://aviso_hud.png")
	print("OK")
	quit()
