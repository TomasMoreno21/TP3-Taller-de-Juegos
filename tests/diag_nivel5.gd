extends SceneTree

## Verificación estructural de nivel5.tscn ("Umbral del Arzobispo", las 4 formas).
## Piso continuo (el examen es de swap de formas y combate, no de precisión nueva),
## sala de pruebas con las 4 mecánicas, combates grandes y salida a nivel_jefe.tscn.

var _fallos := 0


func _check(cond: bool, msg: String) -> void:
	if cond:
		print("[PASS] " + msg)
	else:
		_fallos += 1
		print("[FAIL] " + msg)


func _init() -> void:
	var nivel: Node = load("res://scenes/nivel5.tscn").instantiate()
	root.add_child(nivel)
	await process_frame
	await process_frame
	await process_frame

	var player: Node2D = nivel.get_node_or_null("Player")
	_check(player != null, "Nivel5: player presente")

	var setup: Node = nivel.get_node_or_null("SetupProgresion")
	_check(setup != null and int(setup.nivel_minimo) == 4, "Nivel5: SetupProgresion fuerza nivel_minimo=4 (las 4 formas desbloqueadas)")

	var checkpoints := 0
	var encounters := 0
	var enemigos := 0
	var troncos := 0
	var cristales := 0
	var fragiles := 0
	var rompibles := 0
	var pickups := 0
	for hijo in nivel.get_children():
		var n := String(hijo.name)
		if n.begins_with("Checkpoint"):
			checkpoints += 1
		if n.begins_with("Encounter"):
			encounters += 1
			for sub in hijo.get_children():
				if "tipo" in sub and "ola_asignada" in sub:
					enemigos += 1
		if n.begins_with("Tronco"):
			troncos += 1
		if n.begins_with("Cristal"):
			cristales += 1
		if n.begins_with("PlataformaFragil"):
			fragiles += 1
		if n.begins_with("Pickup"):
			pickups += 1
		if hijo.is_in_group("rompible"):
			rompibles += 1
	_check(checkpoints == 5, "Nivel5: 5 checkpoints (hay %d)" % checkpoints)
	_check(encounters == 2, "Nivel5: 2 combates grandes (hay %d)" % encounters)
	_check(enemigos == 9, "Nivel5: 9 enemigos en total, cultista+arquero+chamán mezclados (hay %d)" % enemigos)
	_check(troncos == 2, "Nivel5: 2 troncos (sala de pruebas + combinado) (hay %d)" % troncos)
	_check(cristales == 2, "Nivel5: 2 cristales (sala de pruebas + combinado) (hay %d)" % cristales)
	_check(fragiles == 2, "Nivel5: 2 plataformas frágiles (tramo combinado) (hay %d)" % fragiles)
	_check(rompibles == 1, "Nivel5: 1 rompible (sala de pruebas, forma Humano) (hay %d)" % rompibles)
	_check(pickups == 3, "Nivel5: 3 pickups (hay %d)" % pickups)

	# Que aparezcan cultista + arquero + chamán juntos en el mismo combate (por
	# primera vez fuera del jefe, según el diseño).
	var g2: Node = nivel.get_node_or_null("EncounterGrande2")
	var tipos_g2: Dictionary = {}
	if g2 != null:
		for sub in g2.get_children():
			if "tipo" in sub:
				tipos_g2[String(sub.tipo)] = true
	_check(tipos_g2.size() >= 3, "Nivel5: EncounterGrande2 mezcla cultista+arquero+chamán (%d tipos distintos)" % tipos_g2.size())

	var santuario := nivel.get_node_or_null("Santuario")
	_check(santuario != null, "Nivel5: santuario final presente")

	var salida := nivel.get_node_or_null("SalidaNivel")
	_check(salida != null and String(salida.siguiente_escena) == "res://scenes/nivel_jefe.tscn", "Nivel5: salida apunta a nivel_jefe.tscn")

	var huecos := 0
	var x := -250.0
	while x <= 10250.0:
		var params := PhysicsPointQueryParameters2D.new()
		params.position = Vector2(x, 1000.0)
		params.collision_mask = 1
		var hits := root.world_2d.direct_space_state.intersect_point(params)
		if hits.is_empty():
			huecos += 1
			print("  [AVISO] sin suelo en x=", x)
		x += 100.0
	_check(huecos == 0, "Nivel5: piso continuo de punta a punta (%d huecos inesperados)" % huecos)

	await create_timer(1.0).timeout
	print("[TMP] NIVEL5 DIAG FIN fallos=", _fallos)
	quit(_fallos)
