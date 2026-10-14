extends SceneTree
## Mide el hueco de cada barrera de cristales (a lo largo de su eje largo) y propone tam/centro.

func _initialize() -> void:
	var nivel: Node = load("res://scenes/nivel3.tscn").instantiate()
	root.add_child(nivel)
	await physics_frame
	await physics_frame
	var sp := (nivel as Node2D).get_world_2d().direct_space_state
	for b in nivel.get_children():
		if b.get_script() == null or not str(b.get_script().resource_path).ends_with("barrera_bosque.gd"):
			continue
		var cuerpo: StaticBody2D = b.get_node("Barrera")
		var col: CollisionShape2D = cuerpo.get_node("Collision")
		var tam: Vector2 = (col.shape as RectangleShape2D).size
		var centro: Vector2 = col.global_position
		var eje_y := Vector2(0, 1).rotated(b.global_rotation)   # eje largo
		var eje_x := Vector2(1, 0).rotated(b.global_rotation)
		var arriba := 0.0
		var abajo := 0.0
		var det := []
		for lat in [-tam.x * 0.5 + 8.0, 0.0, tam.x * 0.5 - 8.0]:
			var o: Vector2 = centro + eje_x * lat
			var r1 := _rayo(sp, o, eje_y * 4000.0, cuerpo)
			var r2 := _rayo(sp, o, -eje_y * 4000.0, cuerpo)
			abajo = maxf(abajo, r1)
			arriba = maxf(arriba, r2)
			det.append("%.0f/%.0f" % [r2, r1])
		print("BARRERA ", b.name, " rot=", snappedf(b.global_rotation, 0.01), " tam=", tam, " centro=", centro, " | arriba/abajo=", " ".join(det), " => largo=", arriba + abajo, " desplaz=", (abajo - arriba) * 0.5)
	quit()


func _rayo(sp: PhysicsDirectSpaceState2D, o: Vector2, d: Vector2, cuerpo: CollisionObject2D) -> float:
	var q := PhysicsRayQueryParameters2D.create(o, o + d)
	q.exclude = [cuerpo.get_rid()]
	q.collision_mask = 1
	var h := sp.intersect_ray(q)
	return o.distance_to(h.position) if not h.is_empty() else 9999.0
