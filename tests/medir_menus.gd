extends SceneTree
## Herramienta manual (necesita ventana): captura una escena de menú en user://menu_<nombre>_<ancho>.png.
## godot --path . --resolution 1920x1080 --script res://tests/medir_menus.gd -- main_menu
func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	var nombre: String = args[0] if args.size() > 0 else "main_menu"
	var esc: Node = load("res://scenes/%s.tscn" % nombre).instantiate()
	root.add_child(esc)
	if args.size() > 1 and args[1] == "toggle":
		await create_timer(0.3, true, false, true).timeout
		esc.call("toggle")
	await create_timer(2.5, true, false, true).timeout
	var img := root.get_viewport().get_texture().get_image()
	img.save_png("user://menu_%s_1920.png" % nombre)
	img.resize(1280, 720, Image.INTERPOLATE_LANCZOS)
	img.save_png("user://menu_%s_1280.png" % nombre)
	quit()
