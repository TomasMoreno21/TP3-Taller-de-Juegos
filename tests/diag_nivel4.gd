extends SceneTree

## Verificación estructural de nivel4.tscn ("Ecos del Abismo", forma Murciélago).
## A diferencia de nivel3, ACÁ el piso tiene un hueco a propósito (el abismo que
## fuerza planear): se valida que haya piso sólido a los dos lados y un hueco real
## en el medio, no que sea continuo.

var _fallos := 0


func _check(cond: bool, msg: String) -> void:
	if cond:
		print("[PASS] " + msg)
	else:
		_fallos += 1
		print("[FAIL] " + msg)


func _tiene_piso(x: float, y: float) -> bool:
	var params := PhysicsPointQueryParameters2D.new()
	params.position = Vector2(x, y)
	params.collision_mask = 1
	return not root.world_2d.direct_space_state.intersect_point(params).is_empty()


func _init() -> void:
	var nivel: Node = load("res://scenes/nivel4.tscn").instantiate()
	root.add_child(nivel)
	await process_frame
	await process_frame
	await process_frame

	var player: Node2D = nivel.get_node_or_null("Player")
	_check(player != null, "Nivel4: player presente")

	var camara: Camera2D = nivel.get_node_or_null("Camara")
	_check(camara != null and camara.has_method("punch"), "Nivel4: cámara con script")

	var setup: Node = nivel.get_node_or_null("SetupProgresion")
	_check(setup != null and int(setup.nivel_minimo) == 4, "Nivel4: SetupProgresion fuerza nivel_minimo=4 (Murciélago desbloqueado)")

	_check(_tiene_piso(1000.0, 1000.0), "Nivel4: piso sólido antes del abismo (x=1000)")
	_check(not _tiene_piso(3300.0, 1000.0) and not _tiene_piso(3300.0, 1700.0), "Nivel4: hueco real en el abismo (x=3300, sin piso)")
	_check(_tiene_piso(6000.0, 1908.0), "Nivel4: piso sólido tras el abismo (x=6000)")

	var checkpoints := 0
	var cristales := 0
	var encounters := 0
	var enemigos := 0
	var pickups := 0
	for hijo in nivel.get_children():
		if String(hijo.name).begins_with("Checkpoint"):
			checkpoints += 1
		if String(hijo.name).begins_with("Cristal"):
			cristales += 1
		if String(hijo.name).begins_with("Encounter"):
			encounters += 1
			for sub in hijo.get_children():
				if "tipo" in sub and "ola_asignada" in sub:
					enemigos += 1
		if String(hijo.name).begins_with("Pickup"):
			pickups += 1
	_check(checkpoints == 5, "Nivel4: 5 checkpoints (hay %d)" % checkpoints)
	_check(cristales == 5, "Nivel4: 5 cristales sónicos (hay %d)" % cristales)
	_check(encounters == 3, "Nivel4: 3 encuentros (hay %d)" % encounters)
	_check(enemigos == 8, "Nivel4: 8 enemigos en total (hay %d)" % enemigos)
	_check(pickups == 4, "Nivel4: 4 pickups (hay %d)" % pickups)

	for hijo in nivel.get_children():
		if String(hijo.name).begins_with("Cristal"):
			_check(bool(hijo.solo_murcielago), "Nivel4: %s exige forma Murciélago" % hijo.name)

	var santuario := nivel.get_node_or_null("Santuario")
	_check(santuario != null, "Nivel4: santuario final presente")

	var salida := nivel.get_node_or_null("SalidaNivel")
	_check(salida != null and String(salida.siguiente_escena) == "res://scenes/nivel5.tscn", "Nivel4: salida apunta a nivel5.tscn")

	await create_timer(1.0).timeout
	print("[TMP] NIVEL4 DIAG FIN fallos=", _fallos)
	quit(_fallos)
