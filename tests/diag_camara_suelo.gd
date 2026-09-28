extends SceneTree
## Diag: el suelo bajo el jugador queda visible (margen) en varios puntos de nivel1/nivel2.
## Uso: godot --headless --path . --script res://tests/diag_camara_suelo.gd

var fallos := 0


func _initialize() -> void:
	for ruta in ["res://scenes/nivel1.tscn", "res://scenes/nivel2.tscn"]:
		await _probar(ruta)
	print("DIAG_CAMARA_SUELO FALLOS = ", fallos)
	quit(1 if fallos > 0 else 0)


func _probar(ruta: String) -> void:
	var nivel: Node = load(ruta).instantiate()
	root.add_child(nivel)
	for n in nivel.get_children():
		if n.is_in_group("dialog_trigger") or n.get_script() != null and str(n.get_script().resource_path).ends_with("dialog_trigger.gd"):
			n.queue_free()
	await physics_frame
	await physics_frame
	var player := get_first_node_in_group("player") as CharacterBody2D
	var cam := nivel.get_node("Camara") as Camera2D
	player.set("god_mode", true)
	var space := player.get_world_2d().direct_space_state
	var xs := [player.global_position.x]
	for i in range(1, 8):
		xs.append(player.global_position.x + i * 1500.0)
	var probados := 0
	for x in xs:
		var q := PhysicsRayQueryParameters2D.create(Vector2(x, cam.limit_top + 10.0), Vector2(x, cam.limit_bottom))
		q.collision_mask = 1
		var h := space.intersect_ray(q)
		if h.is_empty():
			continue
		player.global_position = Vector2(x, h.position.y - 143.0)
		player.velocity = Vector2.ZERO
		cam.modo_normal(true)
		for i in 150:
			await physics_frame
		var pies := Vector2(player.global_position.x, player.global_position.y + cam.pies_offset)
		var q2 := PhysicsRayQueryParameters2D.create(pies + Vector2(0, -8), pies + Vector2(0, 1100))
		q2.collision_mask = 1
		var h2 := space.intersect_ray(q2)
		if h2.is_empty():
			continue
		probados += 1
		var centro := cam.get_screen_center_position()
		var libre: float = (centro.y + 540.0 / cam.zoom.y) - h2.position.y
		var ok: bool = libre >= cam.margen_piso * 0.6 or cam.global_position.y >= cam.limit_bottom - 540.0
		print("  ", ruta.get_file(), " x=", int(x), " piso a ", int(libre), "px del borde inferior ", "OK" if ok else "FALLA")
		if not ok:
			fallos += 1
	print(ruta.get_file(), " puntos probados: ", probados)
	nivel.queue_free()
	await process_frame
