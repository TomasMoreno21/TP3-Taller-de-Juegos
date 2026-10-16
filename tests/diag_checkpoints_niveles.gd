extends SceneTree
## Cada checkpoint de los niveles debe tener piso bajo su punto de reaparición y no estar dentro de la roca
## (el rayo de `_hay_piso_bajo` no detecta un punto enterrado: se mira la celda del TileMap y de la capa Profundo).

func _initialize() -> void:
	var fallos := 0
	for esc in ["res://scenes/nivel1.tscn", "res://scenes/nivel2.tscn", "res://scenes/nivel3.tscn", "res://scenes/nivel_jefe.tscn"]:
		var nivel: Node = load(esc).instantiate()
		root.add_child(nivel)
		await physics_frame
		await physics_frame
		var n := 0
		var tm := nivel.get_node_or_null("TileMap") as TileMapLayer
		var pr := nivel.get_node_or_null("TileMap/Profundo") as TileMapLayer
		for c in nivel.find_children("*", "Area2D", true, false):
			if c.get_script() != null and str(c.get_script().resource_path).ends_with("checkpoint.gd"):
				n += 1
				var r: Vector2 = c.global_position + c.offset_respawn
				if not c.call("_hay_piso_bajo", r):
					fallos += 1
					print("FAIL sin piso: ", esc, " ", c.name, " ", c.global_position)
				if tm != null:
					var cel := tm.local_to_map(tm.to_local(r))
					if tm.get_cell_source_id(cel) != -1 or (pr != null and pr.get_cell_source_id(Vector2i(floori(cel.x / 4.0), floori(cel.y / 4.0))) != -1):
						fallos += 1
						print("FAIL dentro de la roca: ", esc, " ", c.name, " ", c.global_position)
		if n == 0:
			fallos += 1
			print("FAIL sin checkpoints: ", esc)
		nivel.queue_free()
		await process_frame
	print("DIAG CHECKPOINTS NIVELES FALLOS = ", fallos)
	quit()
