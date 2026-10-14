extends SceneTree
## Mide, para cada muro de piedra, el suelo bajo su base y el techo sobre él (en 3 columnas: centro y bordes).

func _initialize() -> void:
	var nivel: Node = load("res://scenes/nivel3.tscn").instantiate()
	root.add_child(nivel)
	await physics_frame
	await physics_frame
	var sp := (nivel as Node2D).get_world_2d().direct_space_state
	for m in get_nodes_in_group("muro_piedra"):
		var res := []
		var piso := -1e9
		var cielo := 1e9
		for dx in [-m.tam.x * 0.5 + 6.0, 0.0, m.tam.x * 0.5 - 6.0]:
			var o: Vector2 = m.global_position + Vector2(dx, -m.tam.y * 0.5)
			var q := PhysicsRayQueryParameters2D.create(o, o + Vector2(0, 3000))
			q.exclude = [m.get_rid()]
			q.collision_mask = 1
			var down := sp.intersect_ray(q)
			var q2 := PhysicsRayQueryParameters2D.create(o, o - Vector2(0, 3000))
			q2.exclude = [m.get_rid()]
			q2.collision_mask = 1
			var up := sp.intersect_ray(q2)
			var suelo: float = (down.position.y - m.global_position.y) if not down.is_empty() else 9999.0
			var techo: float = (m.global_position.y - m.tam.y - up.position.y) if not up.is_empty() else 9999.0
			if suelo < 9000.0:
				piso = maxf(piso, m.global_position.y + suelo)
			if techo < 9000.0:
				cielo = minf(cielo, m.global_position.y - m.tam.y - techo)
			res.append("suelo=%+.0f techo=%+.0f" % [suelo, techo])
		print("MURO ", m.name, " pos=", m.global_position, " tam=", m.tam, " | ", " | ".join(res), " NUEVO y=", piso, " alto=", piso - cielo)
	quit()
