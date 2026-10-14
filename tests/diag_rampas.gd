extends SceneTree
## Compara correr por una pendiente en escalera con y sin RampasSuaves: saltos de altura por frame y inclinación del sprite.

func _correr(con_rampas: bool, x0: float, y0: float, dir: int, forma: int, x_min: float, x_max: float) -> Dictionary:
	var nivel: Node = load("res://scenes/nivel3.tscn").instantiate()
	(nivel.get_node("RampasSuaves") as Node).set("activo", con_rampas)
	root.add_child(nivel)
	await physics_frame
	await physics_frame
	for t in get_nodes_in_group("titulo_nivel"):
		t.queue_free()
	for n in nivel.get_children():
		if n is IntroNivel:
			n.queue_free()
	var player := get_first_node_in_group("player") as CharacterBody2D
	player.set("god_mode", true)
	player.set("cinematica_activa", false)
	if forma != 0:
		player.call("_transformar", forma, true)
	player.global_position = Vector2(x0, y0)
	player.velocity = Vector2.ZERO
	for k in 40:
		await physics_frame
	var accion := "move_right" if dir > 0 else "move_left"
	Input.action_press(accion)
	var prev_y: float = player.global_position.y
	var prev_dy := 0.0
	var aire := 0
	var jerk_max := 0.0
	var jerk_gt4 := 0
	var rot_max := 0.0
	var frames := 0
	var gaps := []
	var x_mid := (x_min + x_max) * 0.5
	var space := player.get_world_2d().direct_space_state
	for k in 220:
		await physics_frame
		var px: float = player.global_position.x
		var y: float = player.global_position.y
		var dy := y - prev_y
		if gaps.is_empty() and px >= x_mid - 5.0 and px <= x_mid + 15.0 and player.is_on_floor():
			for dx in [-120.0, 0.0, 120.0]:
				var q := PhysicsRayQueryParameters2D.create(player.global_position + Vector2(dx, 142.5 - 60.0), player.global_position + Vector2(dx, 142.5 + 80.0))
				q.collision_mask = 1
				var h := space.intersect_ray(q)
				gaps.append(snappedf(h.position.y - (player.global_position.y + 142.5), 0.1) if not h.is_empty() else -1.0)
		if px >= x_min and px <= x_max:
			frames += 1
			if not player.is_on_floor():
				aire += 1
			var jerk := absf(dy - prev_dy)
			jerk_max = maxf(jerk_max, jerk)
			if jerk > 4.0:
				jerk_gt4 += 1
			rot_max = maxf(rot_max, absf(rad_to_deg((player.get("visual") as Node2D).rotation)))
		if false and k % 6 == 0:
			print("  x=%d y=%d dy=%.1f suelo=%s vx=%d" % [px, y, dy, str(player.is_on_floor()), int(player.velocity.x)])
		prev_dy = dy
		prev_y = y
	Input.action_release(accion)
	var r := {"hueco_pies(-120,0,+120)": gaps, "frames": frames, "aire": aire, "jerk_max": snappedf(jerk_max, 0.1), "jerk>4": jerk_gt4, "rot_max": snappedf(rot_max, 0.1)}
	nivel.queue_free()
	await process_frame
	return r


func _initialize() -> void:
	# Busca una cadena de rampas en el nivel con rampas activas.
	var nivel: Node = load("res://scenes/nivel3.tscn").instantiate()
	root.add_child(nivel)
	await physics_frame
	var cuerpo := nivel.get_node("RampasSuaves/Rampas") as StaticBody2D
	var tris: Array = []
	for o in cuerpo.get_shape_owners():
		for i in cuerpo.shape_owner_get_shape_count(o):
			var f := cuerpo.shape_owner_get_shape(o, i) as ConvexPolygonShape2D
			var c := Vector2.ZERO
			var xmin := 1e9
			var xmax := -1e9
			var ymin := 1e9
			var ymax := -1e9
			for p in f.points:
				c += p
				xmin = minf(xmin, p.x)
				xmax = maxf(xmax, p.x)
				ymin = minf(ymin, p.y)
				ymax = maxf(ymax, p.y)
			if rad_to_deg(atan2(ymax - ymin, xmax - xmin)) <= 35.0 and xmax - xmin >= 32.0:
				tris.append(c / 3.0)
	tris.sort_custom(func(a, b): return a.x < b.x)
	var mejor := []
	var cur := []
	var cadenas: Array = []
	for t in tris:
		if cur.is_empty() or (absf(t.x - cur[cur.size() - 1].x) < 140.0 and absf(t.y - cur[cur.size() - 1].y) < 40.0):
			cur.append(t)
		else:
			cadenas.append(cur)
			cur = [t]
	cadenas.append(cur)
	for ch in cadenas:
		if ch.size() < 6:
			continue
		var ang := rad_to_deg(atan2(absf(ch[ch.size() - 1].y - ch[0].y), absf(ch[ch.size() - 1].x - ch[0].x)))
		if ang >= 10.0 and ang <= 28.0 and ch.size() > mejor.size():
			mejor = ch
	print("RAMPAS total=", tris.size(), " cadena mas larga=", mejor.size())
	nivel.queue_free()
	await process_frame
	if mejor.size() < 4:
		print("DIAG RAMPAS: sin cadena util")
		quit()
		return
	var a: Vector2 = mejor[0]
	var b: Vector2 = mejor[mejor.size() - 1]
	var dir := 1 if b.x > a.x else -1
	var sube := b.y < a.y
	print("cadena desde ", a, " hasta ", b, " (", "sube" if sube else "baja", " a la derecha)")
	for forma in [0, 1]:
		var sin_r := await _correr(false, a.x - dir * 220.0, a.y - 260.0, dir, forma, minf(a.x, b.x), maxf(a.x, b.x))
		var con_r := await _correr(true, a.x - dir * 220.0, a.y - 260.0, dir, forma, minf(a.x, b.x), maxf(a.x, b.x))
		print("FORMA ", forma, " SIN rampas ", sin_r)
		print("FORMA ", forma, " CON rampas ", con_r)
		var sin_u := await _correr(false, b.x + dir * 220.0, b.y - 260.0, -dir, forma, minf(a.x, b.x), maxf(a.x, b.x))
		var con_u := await _correr(true, b.x + dir * 220.0, b.y - 260.0, -dir, forma, minf(a.x, b.x), maxf(a.x, b.x))
		print("SUBIDA SIN ", sin_u)
		print("SUBIDA CON ", con_u)
	quit()
