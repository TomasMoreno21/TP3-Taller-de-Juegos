extends SceneTree
## Modo prueba: salto a cada nivel con el equipo correcto, checkpoints ordenados y teletransporte, práctica,
## paneles (menú y pausa) y línea de ubicación. Imprime el orden de checkpoints de cada nivel (para revisar a ojo).

var fallos := 0


func _chequear(ok: bool, msg: String) -> void:
	if not ok:
		fallos += 1
		print("FAIL ", msg)


func _initialize() -> void:
	await process_frame   # los autoloads recién entran al árbol
	var mp = root.get_node_or_null("ModoPrueba")
	var prog = root.get_node("Progresion")
	_chequear(mp != null, "autoload ModoPrueba")
	if mp == null:
		quit()
		return
	# --- estado inicial de cada nivel
	var niveles_esperados := [1, 2, 3, 5]
	var formas_esperadas := [[0], [0, 1], [0, 1, 3], [0, 1, 2, 3]]
	for i in mp.rutas.size():
		prog.saltar_a_punto(mp.fragmentos_inicio[i], mp.formas_inicio[i])
		_chequear(prog.nivel == niveles_esperados[i], "nivel al llegar a %d = %d (esperado %d)" % [i, prog.nivel, niveles_esperados[i]])
		var f := []
		for k in 4:
			if prog._extra_formas.has(k) or k == 0:
				f.append(k)
		_chequear(f == formas_esperadas[i], "formas al llegar a %d = %s" % [i, str(f)])
		_chequear(prog.combos_desbloqueados.size() == niveles_esperados[i] - 1, "combos al llegar a %d = %d" % [i, prog.combos_desbloqueados.size()])
		_chequear(prog.mejoras_diferidas == 0, "sin mejoras diferidas en %d" % i)
	prog.reset()
	# --- cada nivel: checkpoints, teletransporte, práctica, paneles, ubicación
	for i in mp.rutas.size():
		var nivel: Node = load(mp.rutas[i]).instantiate()
		root.add_child(nivel)
		current_scene = nivel
		await physics_frame
		await physics_frame
		_chequear(mp.indice_de_escena() == i, "indice_de_escena %d" % i)
		var cps: Array = mp.checkpoints()
		var txt := ""
		for c in cps:
			txt += " %s[%s](%d,%d)" % [c.name, mp.nombre_checkpoint(c), int(c.global_position.x), int(c.global_position.y)]
		print("CP ", mp.nombre_nivel(i), ": ", cps.size(), txt)
		_chequear(cps.size() > 0, "checkpoints en %d" % i)
		var p: Node2D = get_first_node_in_group("player")
		_chequear(p != null, "player en %d" % i)
		if p != null and cps.size() > 1:
			var destino: Node2D = cps[cps.size() - 1]
			mp.teletransportar_a(destino)
			await physics_frame
			var d := p.global_position.distance_to(destino.global_position + destino.offset_respawn)
			_chequear(d < 40.0, "teletransporte en %d: dist %.1f" % [i, d])
			_chequear(mp.checkpoint_actual_idx() == cps.size() - 1, "checkpoint actual tras teletransporte en %d: %d" % [i, mp.checkpoint_actual_idx()])
			_chequear(p.tiene_checkpoint(), "checkpoint guardado tras teletransporte en %d" % i)
			p.global_position = cps[0].global_position
			mp.volver_a_checkpoint()
			await physics_frame
			_chequear(p.global_position.distance_to(destino.global_position + destino.offset_respawn) < 40.0, "volver_a_checkpoint en %d" % i)
		# práctica
		mp.fijar_practica(true)
		_chequear(p.god_mode and p.energia_infinita, "práctica activa en %d" % i)
		mp.fijar_practica(false)
		_chequear(not p.god_mode and not p.energia_infinita, "práctica apagada en %d" % i)
		# desbloquear todo (solo una vez)
		if i == 0:
			mp.desbloquear_todo()
			for k in 4:
				_chequear(prog.forma_desbloqueada(k), "forma %d desbloqueada" % k)
				_chequear(prog.combos_desbloqueados_forma(k) >= 1, "combo forma %d" % k)
		# panel en juego
		var panel: CanvasLayer = (load("res://scripts/modo_prueba_panel.gd") as GDScript).new()
		panel.en_juego = true
		nivel.add_child(panel)
		await process_frame
		_chequear(panel._info.text.contains(mp.nombre_nivel(i)), "panel muestra la ubicación en %d: %s" % [i, panel._info.text])
		_chequear(cps.size() == mp.checkpoints().size() and mp.checkpoints()[0] != null, "checkpoints ordenados")
		panel._ir_pagina(&"niveles")
		_chequear(panel._botones_nivel.size() == mp.rutas.size(), "botones de nivel")
		panel._ir_pagina(&"checkpoints")
		_chequear(panel._botones_cp.size() == cps.size(), "botones de checkpoint: %d de %d" % [panel._botones_cp.size(), cps.size()])
		_chequear(panel._mapa.puntos.size() == cps.size(), "mapa con todos los checkpoints")
		panel.queue_free()
		# pausa: línea de ubicación
		var pausa = nivel.get_node_or_null("Pause")
		_chequear(pausa != null, "pausa en %d" % i)
		if pausa != null:
			pausa.abrir()
			var lbl: Label = pausa.get_node("Panel/Margin/VBox/Ubicacion")
			_chequear(lbl.text.begins_with(mp.nombre_nivel(i)), "ubicación en pausa %d: '%s'" % [i, lbl.text])
			pausa.cerrar()
		nivel.queue_free()
		await process_frame
	# --- panel del menú y nuevo tester
	var panel_menu: CanvasLayer = (load("res://scripts/modo_prueba_panel.gd") as GDScript).new()
	panel_menu.en_juego = false
	root.add_child(panel_menu)
	await process_frame
	panel_menu._ir_pagina(&"niveles")
	_chequear(panel_menu._botones_nivel.size() == 4, "panel del menú")
	panel_menu.queue_free()
	mp.visitados[1] = true
	mp.fijar_practica(true)
	mp.nuevo_tester()
	_chequear(mp.visitados.is_empty() and not mp.practica, "nuevo tester limpia")
	_chequear(prog.nivel == 1 and prog.fragmentos == 0, "nuevo tester resetea la progresión")
	print("DIAG MODO PRUEBA FALLOS = ", fallos)
	quit()
