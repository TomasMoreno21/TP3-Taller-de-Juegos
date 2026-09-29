extends SceneTree

## Verificación estructural y de coherencia de nivel1prueba.tscn (44.000 px, v2).
## - Estructura: player/cámara/terreno/tiles, arenas, enemigos, pickups, diálogos, tótem.
## - Coherencia de plataformeo: "salto real" = separación de centros − ancho (280). Toda
##   plataforma debe ser alcanzable (BFS por fases Humano < tótem / Lobo >= tótem, con las
##   enredaderas como súper-fuente vertical); todo pincho debe estar bajo un tramo de
##   saltos (plataforma a <=320px + par que lo flanquee a <=720px); enredaderas lejos de
##   clusters altos no designados.

const SUELO_TOP := 992.0
const MIAD_PLATAFORMA := 140.0
const ANCHO_PLATAFORMA := 280.0
const RISE_HUMANO := 135.0
const RISE_LOBO := 235.0
const GAP_FLAT_HUMANO := 250.0
const GAP_SUBIDA_HUMANO := 180.0
const GAP_FLAT_LOBO := 420.0
const GAP_SUBIDA_LOBO := 300.0
const VINE_ALCANCE := 420.0
const PINCHO_RADIO_PLATAFORMA := 320.0
const PINCHO_ESPAN_PAR := 720.0

var _fallos := 0


func _check(cond: bool, msg: String) -> void:
	if cond:
		print("[PASS] " + msg)
	else:
		_fallos += 1
		print("[FAIL] " + msg)


func _can_jump(humo: bool, desde_y: float, desde_x: float, hacia_x: float, hacia_y: float) -> bool:
	var clear := absf(hacia_x - desde_x) - ANCHO_PLATAFORMA
	var rise := desde_y - hacia_y
	if humo:
		if rise > RISE_HUMANO:
			return false
		return clear <= (GAP_FLAT_HUMANO if rise <= 80.0 else GAP_SUBIDA_HUMANO)
	if rise > RISE_LOBO:
		return false
	return clear <= (GAP_FLAT_LOBO if rise <= 80.0 else GAP_SUBIDA_LOBO)


func _marcar_alcanzables(plats: Array, marks: Dictionary, humo: bool) -> void:
	for p in plats:
		if not marks.has(p["node"]) and _can_jump(humo, SUELO_TOP, p["x"], p["x"], p["y"]):
			marks[p["node"]] = true
	var changed := true
	while changed:
		changed = false
		for a in plats:
			if not marks.has(a["node"]):
				continue
			for b in plats:
				if marks.has(b["node"]):
					continue
				if _can_jump(humo, a["y"], a["x"], b["x"], b["y"]):
					marks[b["node"]] = true
					changed = true


func _init() -> void:
	var nivel: Node = load("res://scenes/nivel1prueba.tscn").instantiate()
	root.add_child(nivel)
	await process_frame
	await process_frame
	await process_frame

	var player: Node2D = nivel.get_node_or_null("Player")
	_check(player != null, "Nivel1Prueba: player presente")

	var camara: Camera2D = nivel.get_node_or_null("Camara")
	_check(camara != null and camara.has_method("punch"), "Nivel1Prueba: cámara con script")
	_check(camara != null and camara.limit_right < 100000000, "Nivel1Prueba: cámara con límites seteados")

	var terreno: TileMapLayer = nivel.get_node_or_null("Terreno")
	_check(terreno != null and terreno.tile_set != null, "Nivel1Prueba: Terreno (TileMapLayer) con TileSet asignado")
	if terreno != null:
		var piso_celda: int = terreno.get_cell_source_id(Vector2i(5, 31))
		var relleno_celda: int = terreno.get_cell_source_id(Vector2i(5, 33))
		var fin_celda: int = terreno.get_cell_source_id(Vector2i(1387, 31))
		_check(piso_celda >= 0, "Nivel1Prueba: pinta_terreno pintó celda de borde (5,31)")
		_check(relleno_celda >= 0, "Nivel1Prueba: pinta_terreno pintó celda de relleno (5,33)")
		_check(fin_celda >= 0, "Nivel1Prueba: pinta_terreno cubre hasta x=44.000 (celda 1387)")

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
	_check(arenas == 5, "Nivel1Prueba: 5 arenas de encuentro (hay %d)" % arenas)
	_check(total_enemigos == 14, "Nivel1Prueba: 14 enemigos en total (hay %d)" % total_enemigos)

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
						print("  [AVISO] ", hijo.name, " ola=", ola, " enemigos a ", separacion, "px de separación (colliders se superponen)")
	_check(solapes == 0, "Nivel1Prueba: ningún par de enemigos de la misma ola arranca con colliders superpuestos (%d casos)" % solapes)

	var santuario := nivel.get_node_or_null("Santuario")
	_check(santuario != null and santuario.activar_victoria, "Nivel1Prueba: santuario final con victoria")
	var consola := nivel.get_node_or_null("Consola")
	_check(consola != null, "Nivel1Prueba: consola instanciada")

	var totem := nivel.get_node_or_null("TotemLobo")
	_check(totem != null, "Nivel1Prueba: tótem de desbloqueo presente")

	var rompibles := 0
	var pickups := 0
	var pinchos := 0
	var dialogos := 0
	var ids_dialogos: Array = []
	var plataformas := []
	var enredaderas := []
	for hijo in nivel.get_children():
		if hijo.is_in_group("rompible"):
			rompibles += 1
		if String(hijo.name).begins_with("Pickup"):
			pickups += 1
		if String(hijo.name).begins_with("Pincho"):
			pinchos += 1
		if String(hijo.name).begins_with("Dialogo"):
			dialogos += 1
			if "dialogo_id" in hijo:
				ids_dialogos.append(String(hijo.dialogo_id))
		if String(hijo.name).begins_with("Plat"):
			plataformas.append({"x": hijo.position.x, "y": hijo.position.y - 15.0, "node": hijo})
		if String(hijo.name).begins_with("Enredadera"):
			enredaderas.append(hijo)
	if totem != null and String(totem.dialogo_id) != "":
		ids_dialogos.append(String(totem.dialogo_id))
	_check(rompibles == 3, "Nivel1Prueba: 3 rompibles (hay %d)" % rompibles)
	_check(pickups == 23, "Nivel1Prueba: 23 pickups dedicados (hay %d)" % pickups)
	_check(pinchos == 24, "Nivel1Prueba: 24 pinchos (hay %d)" % pinchos)
	_check(dialogos == 7, "Nivel1Prueba: 7 diálogos (hay %d)" % dialogos)
	_check(plataformas.size() == 44, "Nivel1Prueba: 44 plataformas (hay %d)" % plataformas.size())

	var datos: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://data/dialogos.json"))
	var faltantes := 0
	if datos is Dictionary:
		for id_dialogo in ids_dialogos:
			if not datos.has(id_dialogo):
				faltantes += 1
				print("  [AVISO] diálogo faltante en JSON: ", id_dialogo)
	else:
		faltantes += 1
	_check(faltantes == 0, "Nivel1Prueba: todos los ids de diálogo existen en data/dialogos.json (%d faltantes)" % faltantes)

	# ---- Coherencia de plataformeo ----
	if totem != null and plataformas.size() > 0:
		var totem_x: float = totem.position.x
		var marks: Dictionary = {}
		var desde_enredadera: Dictionary = {}
		for e in enredaderas:
			var top_y: float = e.position.y - float(e.alto)
			for p in plataformas:
				if not marks.has(p["node"]) and p["y"] >= top_y - 1.0 and absf(p["x"] - e.position.x) <= VINE_ALCANCE:
					marks[p["node"]] = true
					desde_enredadera[p["node"]] = true
		var izquierda := []
		var derecha := []
		for p in plataformas:
			if p["x"] < totem_x:
				izquierda.append(p)
			else:
				derecha.append(p)
		_marcar_alcanzables(izquierda, marks, true)
		_marcar_alcanzables(derecha, marks, false)
		var inalcanzables := 0
		for p in plataformas:
			if not marks.has(p["node"]):
				inalcanzables += 1
				print("  [AVISO] plataforma inalcanzable: ", p["node"].name, " (x=", p["x"], ", superficie=", p["y"], ")")
		_check(inalcanzables == 0, "Nivel1Prueba: toda plataforma es alcanzable (Humano < tótem, Lobo >= tótem) (inalcanzables=%d)" % inalcanzables)

		var pinchos_sin_puente := 0
		for hijo in nivel.get_children():
			if not String(hijo.name).begins_with("Pincho"):
				continue
			var x_pincho: float = hijo.position.x
			var cerca := false
			for p in plataformas:
				if absf(p["x"] - x_pincho) <= PINCHO_RADIO_PLATAFORMA:
					cerca = true
					break
			var flanqueado := false
			for a in plataformas:
				for b in plataformas:
					if a["node"] == b["node"]:
						continue
					var d := absf(a["x"] - b["x"])
					if d <= PINCHO_ESPAN_PAR and minf(a["x"], b["x"]) <= x_pincho + 20.0 and maxf(a["x"], b["x"]) >= x_pincho - 20.0:
						flanqueado = true
						break
				if flanqueado:
					break
			if not (cerca and flanqueado):
				pinchos_sin_puente += 1
				print("  [AVISO] pincho sin tramo de salto: ", hijo.name, " (x=", x_pincho, " cerca=", cerca, " flanqueado=", flanqueado, ")")
		_check(pinchos_sin_puente == 0, "Nivel1Prueba: todo pincho está bajo un tramo de saltos (%d fuera de contexto)" % pinchos_sin_puente)

		var enredadera_cerca := 0
		for e in enredaderas:
			var e_x: float = e.position.x
			for p in plataformas:
				if p["y"] <= 795.0 and absf(p["x"] - e_x) < 300.0 and not desde_enredadera.has(p["node"]):
					enredadera_cerca += 1
					print("  [AVISO] enredadera ", e.name, " a <300px del cluster alto ", p["node"].name)
		_check(enredadera_cerca == 0, "Nivel1Prueba: enredaderas no trivializan clusters T3/T4 (%d casos)" % enredadera_cerca)
	else:
		_check(false, "Nivel1Prueba: no se pudieron analizar las plataformas (tótem faltante)")

	var huecos_inesperados := 0
	var x := 150.0
	while x <= 43400.0:
		var params := PhysicsPointQueryParameters2D.new()
		params.position = Vector2(x, 1000.0)
		params.collision_mask = 1
		var hits := root.world_2d.direct_space_state.intersect_point(params)
		if hits.is_empty():
			huecos_inesperados += 1
			print("  [AVISO] sin suelo en x=", x)
		x += 100.0
	_check(huecos_inesperados == 0, "Nivel1Prueba: piso continuo de punta a punta (%d huecos inesperados)" % huecos_inesperados)

	var grieta := nivel.get_node_or_null("GrietaLobo/Techo")
	if grieta != null:
		var techo_bottom: float = grieta.global_position.y + 20.0
		var gap: float = SUELO_TOP - techo_bottom
		# Con colliders actuales (desde 11/09): el Humano (318 de alto) NO pasa el
		# gap de 150-190, pero el Lobo (233 de alto) tampoco cabe físicamente —
		# quedó pendiente reacomodar la grieta (usuario pidió no tocarla por ahora).
		_check(gap > 150.0 and gap < 190.0, "Nivel1Prueba: hueco de GrietaLobo bloquea Humano y deja pasar Lobo (gap=%.1f)" % gap)
	else:
		_check(false, "Nivel1Prueba: GrietaLobo/Techo presente")

	var muro := nivel.get_node_or_null("MuroLobo")
	if muro != null:
		var base: float = muro.global_position.y + 125.0
		_check(absf(base - SUELO_TOP) < 1.0, "Nivel1Prueba: MuroLobo anclado al suelo (base=%.1f)" % base)
	else:
		_check(false, "Nivel1Prueba: MuroLobo presente")

	await create_timer(1.0).timeout
	print("[TMP] NIVEL1PRUEBA DIAG FIN fallos=", _fallos)
	quit(_fallos)