extends SceneTree

func _probe(x0: int, x1: int, paso: int, tag: String) -> void:
	print("--- ", tag, " ---")
	var nivel: Node = load("res://scenes/nivel1.tscn").instantiate()
	root.add_child(nivel)
	await process_frame
	await process_frame
	for x in range(x0, x1 + 1, paso):
		var query := PhysicsRayQueryParameters2D.new()
		query.from = Vector2(x, 400.0)
		query.to = Vector2(x, 1300.0)
		query.collision_mask = 1
		var hit := root.world_2d.direct_space_state.intersect_ray(query)
		if hit.is_empty():
			print("x=", x, "  SIN SUELO")
		else:
			print("x=", x, "  suelo_y=", snappedf(hit.position.y, 1.0))
	nivel.queue_free()

func _init() -> void:
	_probe(14500, 16300, 100, "ZONA WOLF GATE 14500-16300")
	await process_frame
	await process_frame
	_probe(9950, 14000, 100, "FOSO2 9950-14000")
	await process_frame
	await process_frame
	_probe(18800, 21400, 100, "FOSO FINAL 18800-21400")
	await process_frame
	await process_frame
	quit(0)