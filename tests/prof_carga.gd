extends SceneTree
## Desglose del tiempo de carga de un nivel (NIVEL=2): load, instanciar, add_child y partes conocidas.
func _init() -> void:
	await process_frame
	var nivel := OS.get_environment("NIVEL")
	var t0 := Time.get_ticks_usec()
	var ps := load("res://scenes/nivel%s.tscn" % nivel) as PackedScene
	var t1 := Time.get_ticks_usec()
	print("CARGA load() ", (t1 - t0) / 1000, " ms")
	var esc := ps.instantiate()
	var t2 := Time.get_ticks_usec()
	print("CARGA instantiate ", (t2 - t1) / 1000, " ms")
	root.add_child(esc)
	var t3 := Time.get_ticks_usec()
	print("CARGA add_child ", (t3 - t2) / 1000, " ms")
	var tm := esc.get_node("TileMap") as TileMapLayer
	print("CARGA celdas=", tm.get_used_cells().size(), " rect=", tm.get_used_rect())
	var tmundo := esc.get_node_or_null("TerrenoMundo")
	if tmundo != null:
		var ta := Time.get_ticks_usec()
		tmundo._generar_campo()
		print("CARGA terreno_mundo._generar_campo ", (Time.get_ticks_usec() - ta) / 1000, " ms")
	await process_frame
	var t4 := Time.get_ticks_usec()
	print("CARGA frame1 ", (t4 - t3) / 1000, " ms (incluye _generar_campo)")
	quit()
