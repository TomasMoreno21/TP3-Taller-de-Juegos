extends SceneTree
## Capturas de un nivel a lo largo del recorrido. Uso (con ventana):
## godot --path . --resolution 1920x1080 --script res://tests/captura_nivel.gd -- <escena> <dir> "x,y;x,y"

func _initialize() -> void:
	var a := OS.get_cmdline_user_args()
	var nivel: Node = load(a[0]).instantiate()
	root.add_child(nivel)
	for n in nivel.get_children():
		if n.get_script() != null and str(n.get_script().resource_path).ends_with("dialog_trigger.gd"):
			n.queue_free()
	await physics_frame
	var player := get_first_node_in_group("player") as CharacterBody2D
	var cam := nivel.get_node("Camara") as Camera2D
	player.set("god_mode", true)
	var space := player.get_world_2d().direct_space_state
	DirAccess.make_dir_recursive_absolute(a[1])
	# a[2] = "x,y;x,y,1;..." (sin 3er valor: y = altura desde donde cae un rayo hacia abajo; con ",1": posición directa)
	var puntos: Array[Vector3] = []
	for t in a[2].split(";"):
		var xy := t.split(",")
		puntos.append(Vector3(float(xy[0]), float(xy[1]), float(xy[2]) if xy.size() > 2 else 0.0))
	for pt in puntos:
		var x: float = pt.x
		if pt.z > 0.0:
			player.global_position = Vector2(x, pt.y)  # colocación directa ("x,y,1")
		else:
			var q := PhysicsRayQueryParameters2D.create(Vector2(x, pt.y), Vector2(x, pt.y + 1500))
			q.collision_mask = 1
			var h := space.intersect_ray(q)
			if h.is_empty():
				continue
			player.global_position = Vector2(x, h.position.y - 143.0)
		player.velocity = Vector2.ZERO
		cam.modo_normal(true)
		for k in 120:
			await physics_frame
		await RenderingServer.frame_post_draw
		get_root().get_viewport().get_texture().get_image().save_png("%s/x%06d_y%06d.png" % [a[1], int(x), int(pt.y)])
	quit()
