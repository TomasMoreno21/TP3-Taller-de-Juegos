extends SceneTree

var tipo_prueba := "sombra"


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		tipo_prueba = args[0]
	var capa: ParallaxLayer = ParallaxLayer.new()
	capa.set_script(load("res://scripts/capa_cueva.gd"))
	capa.motion_scale = Vector2(0.5, 1)
	capa.set("tipo", tipo_prueba)
	capa.set("ancho_total", 22000.0)
	capa.set("centro_x", 6200.0)
	capa.set("y_base", 1000.0)
	capa.set("densidad", 1.15)
	capa.set("semilla", 7)
	root.add_child(capa)
	await process_frame
	await process_frame
	await process_frame
	print("DIAG_CUEVA tipo=", tipo_prueba, " OK")
	quit()