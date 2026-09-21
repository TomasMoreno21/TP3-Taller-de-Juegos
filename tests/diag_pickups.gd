extends SceneTree

var _fallos := 0


func _check(cond: bool, msg: String) -> void:
	if cond:
		print("[PASS] " + msg)
	else:
		_fallos += 1
		print("[FAIL] " + msg)


func _init() -> void:
	var nivel: Node = load("res://scenes/nivel1.tscn").instantiate()
	root.add_child(nivel)
	await process_frame
	await process_frame
	await process_frame

	# Salto máximo de Humano desde el suelo: ~183px. Un pickup a más de
	# 200px de su soporte más cercano no se puede agarrar ni saltando ni
	# cayendo desde abajo -> solo tiene sentido si pega al lobo en pleno
	# doble salto (ruta de recompensa). A golpe de vista esto es un AVISO.
	const MAX_GAP := 200.0

	var incrustados: Array = []
	var flotantes: Array = []
	for hijo in nivel.get_children():
		if not String(hijo.name).begins_with("Pickup"):
			continue
		var from: Vector2 = hijo.global_position
		var params := PhysicsRayQueryParameters2D.create(from, Vector2(from.x, 2000.0), 1)
		var hit := root.world_2d.direct_space_state.intersect_ray(params)
		if hit.is_empty():
			flotantes.append([hijo.name, "sin soporte debajo"])
			print("  [INFO] ", hijo.name, " en ", from, " -> posicionado sobre vacío (solo alcanzable desde plataforma lateral)")
			continue
		var soporte_y: float = hit["position"].y
		var gap: float = soporte_y - from.y
		print("  [INFO] ", hijo.name, " en (", snappedi(from.x, 1), ", ", snappedi(from.y, 1),
			") -> soporte en y=", snappedi(soporte_y, 1), " gap=", snappedi(gap, 1), "px")
		if gap < -30.0:
			incrustados.append([hijo.name, snappedi(gap, 1)])
		elif gap > MAX_GAP:
			flotantes.append([hijo.name, "gap=%dpx" % snappedi(gap, 1)])

	_check(incrustados.size() == 0, "Pickups: ninguno metido dentro de la geometría (imposible de agarrar; %d)" % incrustados.size())
	if flotantes.size() > 0:
		print("  [AVISO] Pickups en el aire sin soporte directo: ", flotantes, " (solo válido si son recompensa de lobo en doble salto)")

	await create_timer(0.5).timeout
	print("[TMP] PICKUPS DIAG FIN fallos=", _fallos)
	quit(_fallos)