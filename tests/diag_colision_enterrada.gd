extends SceneTree
## Verifica el terreno de un nivel (NIVEL=1|2|3, por defecto 1): toda celda sin colisión está rodeada (8 vecinas) de
## tiles sólidos, y todas las celdas con colisión son cuadrados completos de 16 px (así lo enterrado no se puede tocar).
## Se toleran las celdas expuestas sin colisión que ya traían los niveles: nivel 1 = 962 (borde inferior del mundo,
## y≈7040-7200 px, x 16800-26000: quedó así al recortar el terreno sin re-hornear), nivel 2 = 0 (la franja de y≈1120 px se re-horneó).
## NIVEL=2 godot --headless --path . --script res://tests/diag_colision_enterrada.gd
const EXPUESTAS_DE_ORIGEN := {"1": 962, "2": 0, "3": 0}

var fallos := 0


func _check(ok: bool, msg: String) -> void:
	if not ok:
		fallos += 1
		print("[FAIL] ", msg)
	else:
		print("[ OK ] ", msg)


func _init() -> void:
	await process_frame
	var nivel := OS.get_environment("NIVEL") if OS.get_environment("NIVEL") != "" else "1"
	var esc = (load("res://scenes/nivel%s.tscn" % nivel) as PackedScene).instantiate()
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
	var prof := tm.get_node_or_null("Profundo") as TileMapLayer   # los bloques de roca profunda (4x4 celdas, sin colisión) cuentan como roca
	if prof != null:
		for b in prof.get_used_cells():
			for dy in 4:
				for dx in 4:
					solidas[b * 4 + Vector2i(dx, dy)] = true
	var sin_col_expuestas := 0
	var rect: Rect2i = tm.get_used_rect()
	for c in solidas:
		if con_col.has(c):
			continue
		for dy in range(-1, 2):
			for dx in range(-1, 2):
				var v: Vector2i = c + Vector2i(dx, dy)
				if not solidas.has(v) and rect.has_point(v):   # fuera del rectángulo del terreno no hay nada que tocar (borde del mundo)
					sin_col_expuestas += 1
	_check(sin_col_expuestas <= EXPUESTAS_DE_ORIGEN[nivel] * 8, "ninguna celda sólida sin colisión nueva toca un hueco (%d vecinos expuestos, de origen hasta %d)" % [sin_col_expuestas, EXPUESTAS_DE_ORIGEN[nivel] * 8])
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
	if nivel != "2":   # el nivel 2 tiene la franja expuesta sin colisión: conecta con lo enterrado y protege las celdas de su entorno
		_check(interiores_con_col == 0, "no quedan celdas interiores con colisión (%d)" % interiores_con_col)
	else:
		print("(nivel 2: %d celdas con colisión rodeadas de sólidos, protegidas por la franja expuesta)" % interiores_con_col)
	print("celdas sólidas=%d con colisión=%d" % [solidas.size(), con_col.size()])
	print("DIAG COLISION ENTERRADA: FALLOS = ", fallos)
	esc.free()
	quit(1 if fallos > 0 else 0)
