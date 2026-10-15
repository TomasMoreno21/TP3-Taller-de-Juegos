extends SceneTree
## Compara el dibujo del terreno antes/después de agrupar en bloques. Hay que correrlo CON ventana (no headless).
##   godot --path . --script tests/captura_terreno.gd -- res://scenes/nivel1.tscn <carpeta> antes     (genera posiciones y capturas)
##   godot --path . --script tests/captura_terreno.gd -- res://scenes/nivel1.tscn <carpeta> despues   (mismas posiciones; compara)
## Imprime cuántos píxeles difieren por captura.

func _init() -> void:
	var a := OS.get_cmdline_user_args()
	await process_frame
	var nivel: Node = (load(a[0]) as PackedScene).instantiate()
	root.add_child(nivel)
	for i in 6:
		await process_frame
	for cl in nivel.find_children("*", "CanvasLayer", true, false):
		cl.visible = false   # título, intro en negro, HUD: tapan el terreno
	for dec in nivel.find_children("*", "Polygon2D", true, false):
		if (dec as Polygon2D).z_index >= 50:
			dec.visible = false
	# Solo el terreno: luces, partículas y fondos se mueven solos y ensucian la comparación.
	for hijo in nivel.get_children():
		if hijo is CanvasItem and hijo.name != "TileMap":
			(hijo as CanvasItem).visible = false
	nivel.get_node("Player").process_mode = Node.PROCESS_MODE_DISABLED   # congelado y oculto: solo se compara el terreno
	var carpeta := a[1]
	var fase := a[2]
	var pos_path := carpeta + "/posiciones.json"
	var pos: Array = []
	if fase == "antes":
		var capa: TileMapLayer = nivel.get_node("TileMap")
		var celdas := capa.get_used_cells()
		var vistos := {}
		# puntos repartidos en todo el terreno: celdas con aire cerca (para que se vea el borde y el interior)
		var n := 14
		for i in n:
			var c: Vector2i = celdas[(i * celdas.size()) / n + 137]
			pos.append([c.x * 16 + 8, c.y * 16 + 8])
		var f := FileAccess.open(pos_path, FileAccess.WRITE)
		f.store_string(JSON.stringify(pos))
		f.close()
	else:
		pos = JSON.parse_string(FileAccess.get_file_as_string(pos_path))
	var cam: Camera2D = root.get_viewport().get_camera_2d()
	if cam.has_method("modo_cine"):
		cam.call("modo_cine")
	var j := nivel.get_node("Player")
	j.set("cinematica_activa", true)
	j.set("god_mode", true)
	var total_dif := 0
	for i in pos.size():
		j.global_position = Vector2(pos[i][0], pos[i][1]) + Vector2(0, -3000)   # el jugador queda lejos; solo mueve la cámara
		cam.global_position = Vector2(pos[i][0], pos[i][1])
		cam.zoom = Vector2.ONE
		cam.reset_smoothing()
		for k in 6:
			await process_frame
		var img := root.get_viewport().get_texture().get_image()
		var ruta := "%s/%s_%02d.png" % [carpeta, fase, i]
		img.save_png(ruta)
		if fase == "despues":
			var ant := Image.load_from_file("%s/antes_%02d.png" % [carpeta, i])
			var dif := 0
			for y in range(0, img.get_height(), 2):
				for x in range(0, img.get_width(), 2):
					var p := img.get_pixel(x, y)
					var q := ant.get_pixel(x, y)
					if absf(p.r - q.r) + absf(p.g - q.g) + absf(p.b - q.b) > 0.04:
						dif += 1
			print("captura %02d: píxeles distintos (de %d) = %d" % [i, (img.get_width() / 2) * (img.get_height() / 2), dif])
			total_dif += dif
	print("TOTAL píxeles distintos: %d" % total_dif)
	quit()
