extends SceneTree
## Agrupa el terreno enterrado de un nivel en bloques de 4x4 celdas (una sola celda de 64 px por bloque) para que el
## TileMap tenga muchísimas menos celdas. Solo reemplaza bloques ALINEADOS donde las 16 celdas son el mismo tile ya
## enterrado (alternativo 1, sin colisión): el dibujo queda idéntico (el bloque es ese tile repetido 4x4) y la física no cambia.
##
## Uso (dos fases, con un import en el medio para que Godot registre el PNG nuevo):
##   godot --headless --path . --script tools/hornear_bloques.gd -- 1 res://scenes/nivel1.tscn n1
##   godot --headless --path . --import
##   godot --headless --path . --script tools/hornear_bloques.gd -- 2 res://scenes/nivel1.tscn n1 <salida.json>
## La fase 2 deja en <salida.json> el `tile_map_data` (base64) del TileMap y de la capa Profundo, listos para pegar en el .tscn.

const BLOQUE := 4
const TILE := 16
const ALT_ENTERRADO := 1


func _init() -> void:
	var a := OS.get_cmdline_user_args()
	if a.size() < 3:
		push_error("faltan argumentos")
		quit(1)
		return
	await process_frame
	var nivel: Node = (load(a[1]) as PackedScene).instantiate()
	root.add_child(nivel)
	await process_frame
	var capa: TileMapLayer = nivel.get_node("TileMap")
	var tipos := _bloques_uniformes(capa)   # Dictionary: Vector2i(bloque) -> Vector2i(atlas)
	var lista: Array = []
	for b in tipos:
		if not lista.has(tipos[b]):
			lista.append(tipos[b])
	lista.sort()
	print("bloques uniformes: %d (%d celdas), tipos de tile: %s" % [tipos.size(), tipos.size() * BLOQUE * BLOQUE, str(lista)])
	if a[0] == "1":
		_fase1(capa, lista, a[2])
	else:
		await _fase2(nivel, capa, tipos, lista, a[2], a[3])
	quit()


## Bloques alineados a la grilla de 4 donde las 16 celdas son el mismo tile enterrado.
func _bloques_uniformes(capa: TileMapLayer) -> Dictionary:
	var celdas := {}
	for v in capa.get_used_cells():
		if capa.get_cell_source_id(v) == 0 and capa.get_cell_alternative_tile(v) == ALT_ENTERRADO:
			celdas[v] = capa.get_cell_atlas_coords(v)
	var res := {}
	var vistos := {}
	for v in celdas:
		var b := Vector2i(floori(v.x / float(BLOQUE)), floori(v.y / float(BLOQUE)))
		if vistos.has(b):
			continue
		vistos[b] = true
		var ref: Vector2i = celdas.get(b * BLOQUE, Vector2i(-1, -1))
		if ref == Vector2i(-1, -1):
			continue
		var ok := true
		for dy in BLOQUE:
			for dx in BLOQUE:
				if celdas.get(b * BLOQUE + Vector2i(dx, dy), Vector2i(-2, -2)) != ref:
					ok = false
					break
			if not ok:
				break
		if ok:
			res[b] = ref
	return res


func _fase1(capa: TileMapLayer, lista: Array, nombre: String) -> void:
	var src := capa.tile_set.get_source(0) as TileSetAtlasSource
	var img := src.texture.get_image()
	if img.is_compressed():
		img.decompress()
	img.convert(Image.FORMAT_RGBA8)
	var px := TILE * BLOQUE
	var out := Image.create(px * lista.size(), px, false, Image.FORMAT_RGBA8)
	for i in lista.size():
		var at: Vector2i = lista[i]
		var reg := Rect2i(at * TILE, Vector2i(TILE, TILE))
		for dy in BLOQUE:
			for dx in BLOQUE:
				out.blit_rect(img, reg, Vector2i(i * px + dx * TILE, dy * TILE))
	var png := "res://resources/tile_bloques_%s.png" % nombre
	out.save_png(ProjectSettings.globalize_path(png))
	# Si el nivel ya tiene una capa Profundo (bloques planos y oscuros), el tileset nuevo la conserva como fuente 0 y
	# agrega los bloques como fuente 1; si no, los bloques son la fuente 0 y se crea la escena de la capa.
	var con_plano := capa.get_node_or_null("Profundo") != null
	var ts := "[gd_resource type=\"TileSet\" format=3]\n\n[ext_resource type=\"Texture2D\" path=\"%s\" id=\"1_tex\"]\n" % png
	if con_plano:
		ts += "[ext_resource type=\"Texture2D\" path=\"res://resources/tile_profundo.png\" id=\"2_plano\"]\n"
		ts += "\n[sub_resource type=\"TileSetAtlasSource\" id=\"TileSetAtlasSource_plano\"]\ntexture = ExtResource(\"2_plano\")\ntexture_region_size = Vector2i(%d, %d)\n0:0/0 = 0\n" % [px, px]
	ts += "\n[sub_resource type=\"TileSetAtlasSource\" id=\"TileSetAtlasSource_bloques\"]\ntexture = ExtResource(\"1_tex\")\ntexture_region_size = Vector2i(%d, %d)\n" % [px, px]
	for i in lista.size():
		ts += "%d:0/0 = 0\n" % i
	ts += "\n[resource]\ntile_size = Vector2i(%d, %d)\n" % [px, px]
	if con_plano:
		ts += "sources/0 = SubResource(\"TileSetAtlasSource_plano\")\nsources/1 = SubResource(\"TileSetAtlasSource_bloques\")\n"
	else:
		ts += "sources/0 = SubResource(\"TileSetAtlasSource_bloques\")\n"
	_escribir("res://resources/tileset_bloques_%s.tres" % nombre, ts)
	if not con_plano:
		var sc := "[gd_scene format=3]\n\n[ext_resource type=\"TileSet\" path=\"res://resources/tileset_bloques_%s.tres\" id=\"1_ts\"]\n\n[node name=\"Profundo\" type=\"TileMapLayer\"]\nuse_parent_material = true\ntile_set = ExtResource(\"1_ts\")\n" % nombre
		_escribir("res://scenes/terreno_bloques_%s.tscn" % nombre, sc)
	print("Fase 1 lista: %s y tileset creados%s. Corré el import y luego la fase 2." % [png, "" if con_plano else " (+ escena de la capa)"])


func _fase2(_nivel: Node, capa: TileMapLayer, tipos: Dictionary, lista: Array, nombre: String, salida: String) -> void:
	var prof := capa.get_node_or_null("Profundo") as TileMapLayer
	var fuente := 0
	if prof != null:
		# Capa Profundo existente: pasa al tileset con los bloques nuevos (fuente 1); sus celdas planas (fuente 0) no cambian.
		prof.tile_set = load("res://resources/tileset_bloques_%s.tres" % nombre)
		fuente = 1
	else:
		prof = (load("res://scenes/terreno_bloques_%s.tscn" % nombre) as PackedScene).instantiate()
		capa.add_child(prof)
	for b in tipos:
		if prof.get_cell_source_id(b) != -1:
			push_error("el bloque %s ya está ocupado en Profundo" % str(b))
			return
		for dy in BLOQUE:
			for dx in BLOQUE:
				capa.erase_cell(b * BLOQUE + Vector2i(dx, dy))
		prof.set_cell(b, fuente, Vector2i(lista.find(tipos[b]), 0))
	await process_frame   # aplica los cambios pendientes de las capas antes de leer su data
	await process_frame
	print("bytes tile_map_data: terreno=%d profundo=%d" % [capa.tile_map_data.size(), prof.tile_map_data.size()])
	var datos := {
		"terreno": Marshalls.raw_to_base64(capa.tile_map_data),
		"profundo": Marshalls.raw_to_base64(prof.tile_map_data),
		"celdas_terreno": capa.get_used_cells().size(),
		"celdas_bloques": prof.get_used_cells().size(),
	}
	var f := FileAccess.open(salida, FileAccess.WRITE)
	f.store_string(JSON.stringify(datos))
	f.close()
	print("Fase 2 lista: terreno %d celdas, bloques %d -> %s" % [datos["celdas_terreno"], datos["celdas_bloques"], salida])


func _escribir(ruta: String, texto: String) -> void:
	var f := FileAccess.open(ruta, FileAccess.WRITE)
	f.store_string(texto)
	f.close()
