extends SceneTree

func _init() -> void:
	var res_path: String = "res://resources/jugador_frames.tres"
	var sf: SpriteFrames = load(res_path)
	if sf == null:
		print("ERROR: no se pudo cargar ", res_path)
		quit(1)
		return

	var texturas: Array[Texture2D] = [
		load("res://Sprites/Jugador y Transformaciones/ccorrer1.png"),
		load("res://Sprites/Jugador y Transformaciones/ccorrer2.png"),
		load("res://Sprites/Jugador y Transformaciones/ccorrer3.png"),
		load("res://Sprites/Jugador y Transformaciones/ccorrer4.png"),
	]

	for i in texturas.size():
		if texturas[i] == null:
			print("ERROR: fallo carga ccorrer", i + 1)
			quit(1)
			return

	sf.remove_animation("run")
	sf.add_animation("run")
	sf.set_animation_loop("run", true)
	sf.set_animation_speed("run", 12.0)
	for t in texturas:
		sf.add_frame("run", t, 1.0)

	var err: Error = ResourceSaver.save(sf, res_path)
	if err != OK:
		print("ERROR al guardar: ", err)
		quit(1)
		return
	print("OK: animacion 'run' = ", sf.get_frame_count("run"), " frames nativos (", texturas[0].get_width(), "x", texturas[0].get_height(), ")")
	quit(0)