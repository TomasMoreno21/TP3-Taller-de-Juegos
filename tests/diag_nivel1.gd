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
	for hijo in nivel.get_children():
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
	_check(arenas == 3, "Nivel1: 3 arenas de encuentro (hay %d)" % arenas)
	_check(total_enemigos == 6, "Nivel1: 6 cultistas en total (hay %d)" % total_enemigos)

	# Enemigos de la misma ola no deben arrancar con colliders superpuestos
	# (bug 27/08: 160px de separación vs 175px de ancho de collider -> depenetración
	# violenta al activarse la colisión, eyectaba al jugador fuera del nivel).
	const ANCHO_COLLIDER_ENEMIGO := 175.0
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
	_check(santuario != null and santuario.activar_victoria, "Nivel1: santuario final con victoria")
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
	_check(rompibles == 3, "Nivel1: 3 rompibles (hay %d)" % rompibles)
	_check(pickups == 4, "Nivel1: 4 pickups dedicados (hay %d)" % pickups)
	_check(dialogos == 3, "Nivel1: 3 diálogos (hay %d)" % dialogos)

	# Suelo continuo, salvo el pozo intencional de la Introducción (x 448-608).
	var huecos_inesperados := 0
	var x := 0.0
	while x <= 4750.0:
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

	# GrietaLobo: el hueco entre el techo y el piso debe bloquear a Humano (300px)
	# pero dejar pasar a Lobo agachado (160px).
	var grieta := nivel.get_node_or_null("GrietaLobo/Techo")
	if grieta != null:
		var techo_bottom: float = grieta.global_position.y + 20.0
		var gap: float = 992.0 - techo_bottom
		_check(gap > 160.0 and gap < 300.0, "Nivel1: hueco de GrietaLobo bloquea Humano y deja pasar Lobo (gap=%.1f)" % gap)
	else:
		_check(false, "Nivel1: GrietaLobo/Techo presente")

	await create_timer(1.0).timeout
	print("[TMP] NIVEL1 DIAG FIN fallos=", _fallos)
	quit(_fallos)
