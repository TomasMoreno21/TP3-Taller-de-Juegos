extends SceneTree

## Verificación estructural de nivel3.tscn ("Cantera del Silencio", forma Oso).
## Piso continuo (sin BFS de saltos: el desafío de Oso es de peso/combate, no de
## precisión), checkpoints presentes, encuentros con enemigos, tronco/salida OK.

var _fallos := 0


func _check(cond: bool, msg: String) -> void:
	if cond:
		print("[PASS] " + msg)
	else:
		_fallos += 1
		print("[FAIL] " + msg)


func _init() -> void:
	var nivel: Node = load("res://scenes/nivel3.tscn").instantiate()
	root.add_child(nivel)
	await process_frame
	await process_frame
	await process_frame

	var player: Node2D = nivel.get_node_or_null("Player")
	_check(player != null, "Nivel3: player presente")

	var camara: Camera2D = nivel.get_node_or_null("Camara")
	_check(camara != null and camara.has_method("punch"), "Nivel3: cámara con script")
	_check(camara != null and camara.limit_right < 100000000 and camara.limit_right > 0, "Nivel3: cámara con límites seteados")

	var setup: Node = nivel.get_node_or_null("SetupProgresion")
	_check(setup != null and int(setup.nivel_minimo) == 3, "Nivel3: SetupProgresion fuerza nivel_minimo=3 (Oso desbloqueado)")

	var tronco := nivel.get_node_or_null("Tronco")
	_check(tronco != null and int(tronco.required_form) == 2, "Nivel3: Tronco exige Oso (required_form=2)")

	var checkpoints := 0
	var encounters := 0
	var enemigos := 0
	var pickups := 0
	var pinchos := 0
	var fragiles := 0
	for hijo in nivel.get_children():
		if String(hijo.name).begins_with("Checkpoint"):
			checkpoints += 1
		if String(hijo.name).begins_with("Encounter"):
			encounters += 1
			for sub in hijo.get_children():
				if "tipo" in sub and "ola_asignada" in sub:
					enemigos += 1
		if String(hijo.name).begins_with("Pickup"):
			pickups += 1
		if String(hijo.name).begins_with("Pinchos"):
			pinchos += 1
		if String(hijo.name).begins_with("PlataformaFragil"):
			fragiles += 1
	_check(checkpoints == 4, "Nivel3: 4 checkpoints (hay %d)" % checkpoints)
	_check(encounters == 3, "Nivel3: 3 encuentros (2 combates + guardián) (hay %d)" % encounters)
	_check(enemigos == 8, "Nivel3: 8 enemigos en total (hay %d)" % enemigos)
	_check(pickups == 7, "Nivel3: 7 pickups (hay %d)" % pickups)
	_check(pinchos == 1, "Nivel3: 1 grupo de pinchos, corto (hay %d)" % pinchos)
	_check(fragiles == 3, "Nivel3: 3 plataformas frágiles opcionales (hay %d)" % fragiles)

	var santuario := nivel.get_node_or_null("Santuario")
	_check(santuario != null, "Nivel3: santuario final presente")

	var salida := nivel.get_node_or_null("SalidaNivel")
	_check(salida != null and String(salida.siguiente_escena) == "res://scenes/nivel4.tscn", "Nivel3: salida apunta a nivel4.tscn")

	var consola := nivel.get_node_or_null("Consola")
	_check(consola != null, "Nivel3: consola instanciada")

	# Piso continuo: ningún hueco entre el spawn y la salida (el desafío de Oso
	# es de combate/peso, no de precisión: nunca debe poder caer al vacío).
	var huecos := 0
	var x := -250.0
	while x <= 9650.0:
		var params := PhysicsPointQueryParameters2D.new()
		params.position = Vector2(x, 1000.0)
		params.collision_mask = 1
		var hits := root.world_2d.direct_space_state.intersect_point(params)
		if hits.is_empty():
			huecos += 1
			print("  [AVISO] sin suelo en x=", x)
		x += 100.0
	_check(huecos == 0, "Nivel3: piso continuo de punta a punta (%d huecos inesperados)" % huecos)

	await create_timer(1.0).timeout
	print("[TMP] NIVEL3 DIAG FIN fallos=", _fallos)
	quit(_fallos)
