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

	var player: Node2D = nivel.get_node_or_null("Player")
	_check(player != null, "Nivel1: player presente")

	var camara: Camera2D = nivel.get_node_or_null("Camara")
	_check(camara != null and camara.has_method("punch"), "Nivel1: cámara con script")
	_check(camara != null and camara.limit_right < 100000000, "Nivel1: cámara con límites seteados")

	var terreno: TileMapLayer = nivel.get_node_or_null("Terreno")
	_check(terreno != null and terreno.tile_set != null, "Nivel1: Terreno (TileMapLayer) con TileSet asignado")

	var total_enemigos := 0
	var arenas := 0
	var arqueros := 0
	var chamanes := 0
	for hijo in nivel.get_children():
		if String(hijo.name).begins_with("Encounter"):
			arenas += 1
			var en_arena := 0
			for sub in hijo.get_children():
				if "tipo" in sub and "ola_asignada" in sub:
					en_arena += 1
					total_enemigos += 1
					match String(sub.tipo):
						"cultista":
							pass
						"arquero":
							arqueros += 1
						"chaman":
							chamanes += 1
			print("  [INFO] ", hijo.name, ": estado=", hijo.estado,
				" enemigos=", en_arena,
				" arena_center=", hijo.arena_center,
				" medio_ancho=", snappedf(hijo.arena_medio_ancho, 0.1))
	_check(arenas == 3, "Nivel1: 3 arenas de encuentro (hay %d)" % arenas)
	_check(total_enemigos == 9, "Nivel1: 9 enemigos en total (hay %d)" % total_enemigos)
	_check(arqueros >= 2, "Nivel1: hay arqueros (flechador) para enseñar proyectiles (%d)" % arqueros)
	_check(chamanes >= 1, "Nivel1: hay un chamán como mini-jefe final (%d)" % chamanes)

	# Enemigos de la misma ola no deben arrancar con colliders superpuestos
	# (bug 27/08: colliders anchos causaban depenetración violenta).
	const ANCHO_COLLIDER_ENEMIGO := 100.0
	var solapes := 0
	for hijo in nivel.get_children():
		if String(hijo.name).begins_with("Encounter"):
			var por_ola: Dictionary = {}
			for sub in hijo.get_children():
				if "tipo" in sub and "ola_asignada" in sub:
					var ola: int = int(sub.ola_asignada)
					if not por_ola.has(ola):
						por_ola[ola] = []
					por_ola[ola].append(sub.position.x)
			for ola in por_ola:
				var xs: Array = por_ola[ola]
				xs.sort()
				for i in range(xs.size() - 1):
					var separacion: float = xs[i + 1] - xs[i]
					if separacion < ANCHO_COLLIDER_ENEMIGO:
						solapes += 1
						print("  [AVISO] ", hijo.name, " ola=", ola, " enemigos a ", separacion, "px de separación (colliders de 175px se superponen)")
	_check(solapes == 0, "Nivel1: ningún par de enemigos de la misma ola arranca con colliders superpuestos (%d casos)" % solapes)

	var santuario := nivel.get_node_or_null("Santuario")
	_check(santuario != null, "Nivel1: santuario final presente")
	var salida := nivel.get_node_or_null("SalidaNivel")
	_check(salida != null and String(salida.siguiente_escena) == "res://scenes/nivel2.tscn", "Nivel1: salida apunta a nivel2.tscn")
	var consola := nivel.get_node_or_null("Consola")
	_check(consola != null, "Nivel1: consola instanciada")

	var rompibles := 0
	var pickups := 0
	var dialogos := 0
	for hijo in nivel.get_children():
		if hijo.is_in_group("rompible"):
			rompibles += 1
		if String(hijo.name).begins_with("Pickup"):
			pickups += 1
		if String(hijo.name).begins_with("Dialogo"):
			dialogos += 1
	_check(rompibles == 6, "Nivel1: 6 rompibles (hay %d)" % rompibles)
	_check(pickups == 17, "Nivel1: 17 pickups dedicados (hay %d)" % pickups)
	_check(dialogos == 9, "Nivel1: 9 diálogos (hay %d)" % dialogos)

	# Suelo continuo, salvo el pozo intencional de la Introducción (x 448-608).
	# Se verifica el rango COMPLETO del nivel (hasta el Santuario / límite de
	# cámara) para detectar huecos físicos accidentales en las zonas finales.
	var huecos_inesperados := 0
	var x := 0.0
	while x <= 25647.0:
		var dentro_del_pozo := x > 428.0 and x < 628.0
		var params := PhysicsPointQueryParameters2D.new()
		params.position = Vector2(x, 1000.0)
		params.collision_mask = 1
		var hits := root.world_2d.direct_space_state.intersect_point(params)
		if hits.is_empty() and not dentro_del_pozo:
			huecos_inesperados += 1
			print("  [AVISO] sin suelo en x=", x)
		x += 100.0
	_check(huecos_inesperados == 0, "Nivel1: piso continuo salvo el pozo de Introducción (%d huecos inesperados)" % huecos_inesperados)

	# Cada trigger de diálogo debe apuntar a un id que exista en dialogos.json:
	# si el id no está, al dispararse el diálogo quedaría en blanco.
	var datos_json := {}
	var f := FileAccess.open("res://data/dialogos.json", FileAccess.READ)
	if f != null:
		datos_json = JSON.parse_string(f.get_as_text())
	var dialogos_rotos := 0
	for hijo in nivel.get_children():
		if String(hijo.name).begins_with("Dialogo"):
			var id_dialogo: String = String(hijo.get("dialogo_id"))
			if id_dialogo.is_empty() or not datos_json.has(id_dialogo):
				dialogos_rotos += 1
				print("  [AVISO] ", hijo.name, " apunta a dialogo_id inexistente: '", id_dialogo, "'")
	_check(dialogos_rotos == 0, "Nivel1: todos los triggers de diálogo apuntan a ids existentes en dialogos.json (%d rotos)" % dialogos_rotos)

	# GrietaLobo: el hueco entre el techo y el piso debe dejar pasar a Lobo
	# agachado (160px). 05/09: al reubicar GrietaLobo cerca del marker de diálogo
	# quedó con más margen (443px) y ya no bloquea a Humano; el equipo lo dejó así
	# a propósito, así que acá solo verificamos que Lobo siga entrando.
	var grieta := nivel.get_node_or_null("GrietaLobo/Techo")
	if grieta != null:
		var techo_bottom: float = grieta.global_position.y + 20.0
		var gap: float = 992.0 - techo_bottom
		_check(gap > 160.0, "Nivel1: hueco de GrietaLobo deja pasar a Lobo (gap=%.1f)" % gap)
	else:
		_check(false, "Nivel1: GrietaLobo/Techo presente")

	await create_timer(1.0).timeout
	print("[TMP] NIVEL1 DIAG FIN fallos=", _fallos)
	quit(_fallos)
