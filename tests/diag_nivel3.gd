extends SceneTree

## Verificación estática de nivel3.tscn (v7, "Las Profundidades"): cueva en ESPIRAL con rampas, cuencos y una chimenea.
## Datos del diseño en tests/nivel3_datos.json (ruta, fosos, muros, arenas, repisas).
## Se valida: que los 4 personajes (Humano 190x318, Lobo 360x160, Oso 470x324, Murciélago 135x133) CABEN en todo el
## camino principal y suben sus rampas, la escalera de saltos, objetos y decoración apoyados, muros de piso a techo,
## cámara sin ver fuera del mapa. El recorrido con Input simulado está en diag_nivel3_recorrido.gd.

const FORMAS := [["Humano", Vector2(190, 318), 48.0], ["Lobo", Vector2(360, 160), 48.0], ["Oso", Vector2(470, 324), 32.0], ["Murciélago", Vector2(135, 133), 16.0]]
const DECO_MAX := 60

var _fallos := 0
var _d: Dictionary
var _nivel: Node


func _check(cond: bool, msg: String) -> void:
	if cond:
		print("[PASS] " + msg)
	else:
		_fallos += 1
		print("[FAIL] " + msg)


func _solido(x: float, y: float) -> bool:
	var params := PhysicsPointQueryParameters2D.new()
	params.position = Vector2(x, y)
	params.collision_mask = 1
	return not root.world_2d.direct_space_state.intersect_point(params).is_empty()


func _piso_bajo(x: float, y: float, arriba := 150.0) -> float:
	var q := PhysicsRayQueryParameters2D.create(Vector2(x, y - arriba), Vector2(x, y + 250.0), 1)
	var hit := root.world_2d.direct_space_state.intersect_ray(q)
	return float(hit.position.y) if not hit.is_empty() else INF


func _init() -> void:
	var f := FileAccess.open("res://tests/nivel3_datos.json", FileAccess.READ)
	_d = JSON.parse_string(f.get_as_text())
	_nivel = load("res://scenes/nivel3.tscn").instantiate()
	root.add_child(_nivel)
	for i in 4:
		await physics_frame
	var nivel := _nivel

	var player: Node2D = nivel.get_node_or_null("Player")
	_check(player != null, "Nivel3: player presente")
	var camara: Camera2D = nivel.get_node_or_null("Camara")
	var tilemap: TileMap = nivel.get_node_or_null("TileMap")
	_check(camara != null and camara.has_method("punch"), "Nivel3: cámara con script")
	_check(tilemap != null and tilemap.get_used_cells(0).size() > 100000, "Nivel3: TileMap con terreno pintado")
	_check(nivel.get_node_or_null("FondoProfundo") != null and nivel.get_node_or_null("NocheProfunda") != null, "Nivel3: fondo y noche de cueva profunda")

	# Cámara: límites dentro del terreno; el fondo cubre toda la altura que ve.
	if camara != null and tilemap != null:
		var rect: Rect2i = tilemap.get_used_rect()
		var ok: bool = camara.limit_left >= rect.position.x * 16 and camara.limit_top >= rect.position.y * 16 \
			and camara.limit_right <= rect.end.x * 16 and camara.limit_bottom <= rect.end.y * 16
		_check(ok, "Nivel3: límites de cámara dentro del terreno (%d,%d)-(%d,%d)" % [camara.limit_left, camara.limit_top, camara.limit_right, camara.limit_bottom])
		var fondo_ok := true
		var fondo: Node = nivel.get_node_or_null("FondoProfundo")
		for capa in fondo.get_children() if fondo != null else []:
			if capa.get("y_techo") != null and (float(capa.y_techo) > camara.limit_top or float(capa.y_fondo) < camara.limit_bottom
					or float(capa.centro_x) - float(capa.ancho_total) * 0.5 > camara.limit_left - 1000.0
					or float(capa.centro_x) + float(capa.ancho_total) * 0.5 < camara.limit_right + 1000.0):
				fondo_ok = false
		_check(fondo_ok, "Nivel3: el fondo de cueva cubre todo el mapa que ve la cámara")

	var setup: Node = nivel.get_node_or_null("SetupProgresion")
	_check(setup != null and Array(setup.formas_forzadas) == [0, 1, 3], "Nivel3: arranca con Humano+Lobo+Murciélago (Oso sin desbloquear)")
	var unlock: Node2D = nivel.get_node_or_null("UnlockOso")
	_check(unlock != null and int(unlock.forma) == 2, "Nivel3: altar desbloquea el Oso (forma=2)")

	# --- Escalera de saltos ---
	var fosos: Array = _d["fosos"]
	var mal_f := 0
	for g in fosos:
		var a: float = g["ancho"]
		if g["req"] == "humano" and a > 420.0:
			mal_f += 1
		if g["req"] == "tablas" and a > 700.0:
			mal_f += 1
		if g["req"] == "lobo" and (a < 560.0 or a > 700.0):
			mal_f += 1
	_check(mal_f == 0, "Saltos: fosos de Humano <= 420 px y fosos de Lobo/planeo entre 560 y 700 px (%d fuera)" % mal_f)
	_check(float(fosos[0]["ancho"]) <= 300.0, "Saltos: el primer foso es fácil (%d px)" % int(fosos[0]["ancho"]))
	var mal_t := 0
	for lista in [_d["torre"], _d["anillo"]]:
		for i in range(lista.size() - 1):
			var a: Dictionary = lista[i]
			var b: Dictionary = lista[i + 1]
			var hueco := maxf(float(b["x0"]) - float(a["x1"]), float(a["x0"]) - float(b["x1"]))
			var alto_dif := absf(float(b["y"]) - float(a["y"]))
			if hueco > 280.0 or alto_dif > 150.0:
				mal_t += 1
				print("  [AVISO] salto exigente entre repisas ", i, "->", i + 1, " hueco=", hueco, " alto=", alto_dif)
	_check(mal_t == 0, "Saltos: repisas con huecos <= 280 y desniveles <= 150 (Humano salta ~470 x 190) (%d malos)" % mal_t)

	# --- Objetos apoyados ---
	var checkpoints := 0
	var encounters := 0
	var enemigos := 0
	var pickups := 0
	var orbes := 0
	var mal_puestos := 0
	for hijo in nivel.get_children():
		var n := String(hijo.name)
		if n.begins_with("Checkpoint"):
			checkpoints += 1
			if _solido(hijo.position.x, hijo.position.y):
				mal_puestos += 1
				print("  [AVISO] checkpoint dentro de terreno: ", n)
		if n.begins_with("Pickup"):
			pickups += 1
			if n.begins_with("PickupVida"):
				orbes += 1
			if _solido(hijo.position.x, hijo.position.y):
				mal_puestos += 1
				print("  [AVISO] pickup dentro de terreno: ", n)
		if n.begins_with("Encounter"):
			encounters += 1
			for sub in hijo.get_children():
				if "tipo" in sub and "ola_asignada" in sub:
					enemigos += 1
					var pos: Vector2 = hijo.position + sub.position
					var pies: float = 29.0 if sub.tipo != "chaman" else 65.4
					var piso: float = _piso_bajo(pos.x, pos.y)
					if absf((pos.y + pies) - piso) > 3.0:
						mal_puestos += 1
						print("  [AVISO] enemigo mal apoyado: ", hijo.name, "/", sub.name, " pies=", pos.y + pies, " piso=", piso)
	_check(mal_puestos == 0, "Nivel3: checkpoints, pickups y enemigos apoyados, sin incrustar (%d mal puestos)" % mal_puestos)
	_check(checkpoints >= 18, "Nivel3: checkpoints frecuentes (hay %d)" % checkpoints)
	_check(encounters == 4 and enemigos == 21, "Nivel3: 4 arenas y 21 enemigos (hay %d / %d)" % [encounters, enemigos])
	_check(pickups >= 30 and orbes >= 8, "Nivel3: almas (%d en total) y orbes de vida (%d)" % [pickups, orbes])

	# --- Decoración mínima y apoyada ---
	var deco_root: Node = nivel.get_node_or_null("Decoracion")
	var n_deco := deco_root.get_child_count() if deco_root != null else 0
	_check(n_deco <= DECO_MAX and n_deco >= 10, "Nivel3: decoración mínima (%d piezas, máx. %d)" % [n_deco, DECO_MAX])
	var flotando := 0
	if deco_root != null:
		for dn in deco_root.get_children():
			var dx: float = dn.position.x
			var dy: float = dn.position.y
			var apoyo := false
			if int(dn.tipo) == 9:
				apoyo = _solido(dx, dy - 8.0) and not _solido(dx, dy + 8.0) and _solido(dx - 40.0, dy - 8.0) and _solido(dx + 40.0, dy - 8.0)
			else:
				apoyo = _solido(dx, dy + 8.0) and not _solido(dx, dy - 8.0) and _solido(dx - 40.0, dy + 8.0) and _solido(dx + 40.0, dy + 8.0)
			if not apoyo:
				flotando += 1
				print("  [AVISO] decoración flotando: ", dn.name, " tipo=", dn.tipo, " en ", dn.position)
	_check(flotando == 0, "Nivel3: ninguna decoración flotando (%d)" % flotando)

	# --- Muros y losas ---
	var muros_mal := 0
	for m in _d["muros"]:
		var nm: Node2D = nivel.get_node_or_null(m["nombre"])
		if nm == null:
			muros_mal += 1
			continue
		var mx: float = m["x"]
		var my: float = m["piso"]
		var alto: float = m["alto"]
		var mitad: float = float(nm.tam.x) * 0.5
		if not (_solido(mx - mitad - 40.0, my + 8.0) and _solido(mx, my - alto - 8.0)):
			muros_mal += 1
			print("  [AVISO] muro que no cierra el pasillo: ", m["nombre"])
	_check(muros_mal == 0, "Nivel3: %d muros cierran el pasillo de piso a techo (%d malos)" % [_d["muros"].size(), muros_mal])
	var puerta_g: Node = nivel.get_node_or_null("PuertaGuardian")
	_check(puerta_g != null and nivel.get_node_or_null("LosaGuardian") != null and nivel.get_node_or_null("LosaPractica") != null, "Nivel3: compuertas con sus losas")

	# --- Dificultad: almas cerca de cada obstáculo del Oso y orbes repartidos ---
	var cerca := 0
	for m in _d["muros"] + _d["losas"]:
		var mx2: float = m["x"]
		var my2: float = m["piso"]
		for hijo in nivel.get_children():
			if String(hijo.name).begins_with("Pickup") and not String(hijo.name).begins_with("PickupVida") and absf(hijo.position.x - mx2) < 1000.0 and absf(hijo.position.y - my2) < 900.0:
				cerca += 1
				break
	_check(cerca == _d["muros"].size() + _d["losas"].size(), "Nivel3: cada obstáculo del Oso tiene almas (energía) cerca (%d)" % cerca)

	# --- Los 4 personajes CABEN en todo el camino principal y las rampas son subibles ---
	for hijo in nivel.get_children():
		if hijo.is_in_group("muro_piedra") or String(hijo.name).begins_with("Muro") or String(hijo.name).begins_with("Puerta"):
			hijo.call("abrir")   # los muros/compuertas son obstáculos pensados: se prueban aparte
	await physics_frame
	await physics_frame
	var probe := CharacterBody2D.new()
	probe.collision_layer = 0
	probe.collision_mask = 1
	var cs := CollisionShape2D.new()
	cs.shape = RectangleShape2D.new()
	probe.add_child(cs)
	nivel.add_child(probe)
	var ruta: Array = _d["ruta"]
	for fm in FORMAS:
		var sz: Vector2 = fm[1]
		var malos := 0
		var primero := ""
		(cs.shape as RectangleShape2D).size = sz
		for r in ruta:
			var x: float = r["x"]
			var hw := sz.x * 0.5 + 24.0
			if x < 300.0 + hw or (r["zona"] == "Z5" and x > 13550.0 - hw) or (r["zona"] == "Z7" and x > 10700.0 - hw):
				continue   # pegado a la pared del extremo del mapa: no es un lugar donde se camine
			# suelo más alto bajo el collider (la parte cuesta arriba) y el resto del apoyo
			var alto := INF
			var xx := x - sz.x * 0.5
			while xx <= x + sz.x * 0.5:
				alto = minf(alto, _piso_bajo(xx, float(r["y"]), 200.0))
				xx += 32.0
			alto = minf(alto, _piso_bajo(x + sz.x * 0.5 - 1.0, float(r["y"]), 200.0))   # el extremo cuesta arriba
			if alto == INF:
				continue
			probe.global_position = Vector2(x, alto - sz.y * 0.5 - 1.0)
			if probe.test_move(probe.global_transform, Vector2.ZERO):
				malos += 1
				if primero == "":
					primero = "x=%d y=%d" % [x, r["y"]]
		_check(malos == 0, "Camino principal: el %s (%dx%d) cabe en todo el trayecto (%d puntos, %d trabados %s)" % [fm[0], sz.x, sz.y, ruta.size(), malos, primero])
	var salto_malo := 0
	for i in range(ruta.size() - 1):
		if ruta[i]["zona"] == ruta[i + 1]["zona"] and absf(float(ruta[i + 1]["x"]) - float(ruta[i]["x"])) <= 64.0:
			if absf(float(ruta[i + 1]["y"]) - float(ruta[i]["y"])) > 32.0:   # escalón/rampa tope = lo que sube el Oso (32 px por paso)
				salto_malo += 1
				print("  [AVISO] pendiente fuerte en x=", ruta[i]["x"])
	_check(salto_malo == 0, "Camino principal: ninguna pendiente exige más que el paso máximo del Oso (%d)" % salto_malo)
	probe.queue_free()

	var santuario: Node2D = nivel.get_node_or_null("Santuario")
	var salida: Node = nivel.get_node_or_null("SalidaNivel")
	_check(santuario != null and salida != null and String(salida.siguiente_escena) == "res://scenes/nivel_jefe.tscn", "Nivel3: el corazón tiene santuario y la salida va a nivel_jefe.tscn")
	var largo := 0.0
	for i in range(ruta.size() - 1):
		largo += Vector2(float(ruta[i + 1]["x"]) - float(ruta[i]["x"]), float(ruta[i + 1]["y"]) - float(ruta[i]["y"])).length()
	_check(largo >= 33000.0, "Nivel3: camino principal de %d px (más largo que antes)" % int(largo))

	for i in 90:
		await physics_frame
	_check(player != null and player.is_on_floor(), "Nivel3: el jugador aterriza en la entrada al spawnear")

	print("[TMP] NIVEL3 DIAG FIN fallos=", _fallos)
	quit(_fallos)
