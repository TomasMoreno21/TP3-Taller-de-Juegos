extends SceneTree
## Verifica el terreno del nivel 1: toda celda sin colisión está rodeada (8 vecinas) de tiles sólidos,
## y todas las celdas con colisión son cuadrados completos de 16 px (así lo enterrado no se puede tocar).
## godot --headless --path . --script res://tests/diag_colision_enterrada.gd

var fallos := 0


func _check(ok: bool, msg: String) -> void:
	if not ok:
		fallos += 1
		print("[FAIL] ", msg)
	else:
		print("[ OK ] ", msg)


func _init() -> void:
	await process_frame
	var esc = (load("res://scenes/nivel1.tscn") as PackedScene).instantiate()
	var tm: TileMapLayer = esc.get_node("TileMap")
	var solidas := {}
	var con_col := {}
	for c in tm.get_used_cells():
		var td := tm.get_cell_tile_data(c)
		var tiene := td != null and td.get_collision_polygons_count(0) > 0
		if tiene:
			con_col[c] = true
		if tm.get_cell_source_id(c) == 0 and Rect2i(1, 1, 4, 4).has_point(tm.get_cell_atlas_coords(c)):
			solidas[c] = true
	var sin_col_expuestas := 0
	for c in solidas:
		if con_col.has(c):
			continue
		for dy in range(-1, 2):
			for dx in range(-1, 2):
				if not solidas.has(c + Vector2i(dx, dy)):
					sin_col_expuestas += 1
	_check(sin_col_expuestas == 0, "ninguna celda sólida sin colisión toca un hueco (%d expuestas)" % sin_col_expuestas)
	var con_col_no_solidas := 0
	for c in con_col:
		if not solidas.has(c):
			con_col_no_solidas += 1
	_check(con_col_no_solidas == 0, "toda celda con colisión es un tile sólido del atlas (%d fuera)" % con_col_no_solidas)
	var interiores_con_col := 0
	for c in con_col:
		var enterrada := true
		for dy in range(-1, 2):
			for dx in range(-1, 2):
				if not solidas.has(c + Vector2i(dx, dy)):
					enterrada = false
		if enterrada:
			interiores_con_col += 1
	_check(interiores_con_col == 0, "no quedan celdas interiores con colisión (%d)" % interiores_con_col)
	print("celdas sólidas=%d con colisión=%d" % [solidas.size(), con_col.size()])
	print("DIAG COLISION ENTERRADA: FALLOS = ", fallos)
	esc.free()
	quit(1 if fallos > 0 else 0)
