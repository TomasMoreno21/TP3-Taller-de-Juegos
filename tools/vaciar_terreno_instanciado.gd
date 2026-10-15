extends SceneTree
## Vacía las celdas guardadas DENTRO de una escena de terreno instanciada (p. ej. nivel2_terreno.scn) cuando el nivel
## que la instancia ya trae su propia `tile_map_data` (la sobrescribe). Si no, Godot carga 188k celdas de más al
## instanciar (≈0,5 s) solo para tirarlas. Conserva el tileset, el material y los hijos.
## Uso: godot --headless --path . --script tools/vaciar_terreno_instanciado.gd -- res://scenes/nivel2_terreno.scn

func _init() -> void:
	var ruta := OS.get_cmdline_user_args()[0]
	await process_frame
	var raiz := (load(ruta) as PackedScene).instantiate() as TileMapLayer
	var antes := raiz.get_used_cells().size()
	raiz.clear()
	for h in raiz.get_children():
		if h is TileMapLayer:
			(h as TileMapLayer).clear()
	var ps := PackedScene.new()
	var err := ps.pack(raiz)
	if err == OK:
		err = ResourceSaver.save(ps, ruta)
	print("Terreno vaciado (%d celdas antes): %s -> %s" % [antes, ruta, error_string(err)])
	quit()
