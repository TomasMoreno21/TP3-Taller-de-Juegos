extends SceneTree
## Cada checkpoint de nivel2 y nivel_jefe debe tener piso bajo su punto de reaparición.

func _initialize() -> void:
	var fallos := 0
	for esc in ["res://scenes/nivel2.tscn", "res://scenes/nivel_jefe.tscn"]:
		var nivel: Node = load(esc).instantiate()
		root.add_child(nivel)
		await physics_frame
		await physics_frame
		var n := 0
		for c in nivel.get_children():
			if c.get_script() != null and str(c.get_script().resource_path).ends_with("checkpoint.gd"):
				n += 1
				if not c.call("_hay_piso_bajo", c.global_position + c.offset_respawn):
					fallos += 1
					print("FAIL sin piso: ", esc, " ", c.name, " ", c.global_position)
		if n == 0:
			fallos += 1
			print("FAIL sin checkpoints: ", esc)
		nivel.queue_free()
		await process_frame
	print("DIAG CHECKPOINTS NIVELES FALLOS = ", fallos)
	quit()
