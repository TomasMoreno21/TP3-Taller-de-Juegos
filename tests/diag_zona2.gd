extends SceneTree

var _fallos := 0


func _check(cond: bool, msg: String) -> void:
	if cond:
		print("[PASS] " + msg)
	else:
		_fallos += 1
		print("[FAIL] " + msg)


func _init() -> void:
	var zona: Node = load("res://scenes/nivel2.tscn").instantiate()
	root.add_child(zona)
	await process_frame
	await process_frame
	await process_frame

	var player: Node2D = zona.get_node_or_null("Player")
	_check(player != null, "Zona2: player presente")
	var camara: Camera2D = zona.get_node_or_null("Camara")
	_check(camara != null and camara.has_method("punch"), "Zona2: cámara con script nuevo")

	var total_enemigos := 0
	var arenas := 0
	for hijo in zona.get_children():
		if String(hijo.name).begins_with("Encounter"):
			arenas += 1
			var en_arena := 0
			for sub in hijo.get_children():
				if "tipo" in sub and "ola_asignada" in sub:
					en_arena += 1
					total_enemigos += 1
			print("  [INFO] ", hijo.name, ": estado=", hijo.estado,
				" enemigos=", en_arena,
				" arena_center=", hijo.arena_center,
				" medio_ancho=", snappedf(hijo.arena_medio_ancho, 0.1))
	_check(arenas == 4, "Zona2: 4 arenas (hay %d)" % arenas)
	_check(total_enemigos == 12, "Zona2: 12 enemigos (hay %d)" % total_enemigos)

	var santuario := zona.get_node_or_null("Santuario")
	_check(santuario != null, "Zona2: santuario presente")
	var salida := zona.get_node_or_null("SalidaNivel")
	_check(salida != null and salida.siguiente_escena == "res://scenes/nivel3.tscn",
		"Zona2: salida encadena a nivel3")
	var consola := zona.get_node_or_null("Consola")
	_check(consola != null, "Zona2: consola instanciada")

	var rompibles := 0
	var pickups := 0
	var dialogos := 0
	var pickups_flotando := 0
	for hijo in zona.get_children():
		if hijo.is_in_group("rompible"):
			rompibles += 1
		elif String(hijo.name).begins_with("Pickup"):
			pickups += 1
			# check: el pickup debe estar apoyado (piso a < 140px debajo).
			# Máscara total: las mesetas del nivel viven en capa 2.
			var q := PhysicsRayQueryParameters2D.create(
				hijo.global_position, hijo.global_position + Vector2(0, 140), 0xFFFFFFFF, [hijo])
			if zona.get_world_2d().direct_space_state.intersect_ray(q).is_empty():
				pickups_flotando += 1
				print("  [AVISO] pickup flotando: ", hijo.name, " en ", hijo.global_position)
		elif String(hijo.name).begins_with("Dialogo"):
			dialogos += 1
	_check(rompibles == 6, "Zona2: 6 rompibles (hay %d)" % rompibles)
	_check(pickups >= 7, "Zona2: 7+ pickups (hay %d)" % pickups)
	_check(dialogos == 4, "Zona2: 4 diálogos (hay %d)" % dialogos)
	_check(pickups_flotando == 0, "Zona2: 0 pickups flotando (hay %d)" % pickups_flotando)

	# Los pozos con pinchos forman parte del diseño (se saltan), no se exige piso
	# continuo. Solo se informa.
	var huecos := 0
	var x := -500.0
	while x <= 10900.0:
		var params := PhysicsPointQueryParameters2D.new()
		params.position = Vector2(x, 1003.0)
		params.collision_mask = 1
		var hits := root.world_2d.direct_space_state.intersect_point(params)
		if hits.is_empty():
			huecos += 1
		x += 250.0
	print("  [INFO] huecos de piso en línea y=1003: ", huecos, " (por diseño: pozos con pinchos)")

	await create_timer(1.5).timeout
	print("[TMP] ZONA2 DIAG FIN fallos=", _fallos)
	quit(_fallos)
