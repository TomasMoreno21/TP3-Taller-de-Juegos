extends SceneTree
## Imprime la altura del suelo del subsuelo del nivel1 cada 500 px (rayo hacia abajo desde y=4000).

func _initialize() -> void:
	var nivel: Node = load("res://scenes/nivel1.tscn").instantiate()
	root.add_child(nivel)
	await physics_frame
	await physics_frame
	var space := root.get_world_2d().direct_space_state
	var x := 19000
	while x <= 33500:
		var q := PhysicsRayQueryParameters2D.create(Vector2(x, 4000), Vector2(x, 8000))
		q.collision_mask = 1
		var h := space.intersect_ray(q)
		print("x=%d suelo_y=%s" % [x, str(int(h.position.y)) if not h.is_empty() else "-"])
		x += 500
	quit()
