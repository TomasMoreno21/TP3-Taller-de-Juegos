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


## Terreno = celda del tilemap (el interior enterrado no tiene colisión, ver terreno.gd) o cualquier colisión.
func _solido(x: float, y: float) -> bool:
	var tm := _nivel.get_node_or_null("TileMap") as TileMapLayer
	if tm != null and tm.get_cell_source_id(tm.local_to_map(tm.to_local(Vector2(x, y)))) != -1:
		return true
	var params := PhysicsPointQueryParameters2D.new()
	params.position = Vector2(x, y)
	params.collision_mask = 1
	return not root.world_2d.direct_space_state.intersect_point(params).is_empty()


func _piso_bajo(x: float, y: float, arriba := 150.0) -> float:
	var q := PhysicsRayQueryParameters2D.create(Vector2(x, y - arriba), Vector2(x, y + 250.0), 1)
	var hit := root.world_2d.direct_space_state.intersect_ray(q)
	return float(hit.position.y) if not hit.is_empty() else INF


func _con_script(nivel: Node, fin: String) -> Array:
	var r := []
	for n in nivel.get_children():
		if n.get_script() != null and str(n.get_script().resource_path).ends_with(fin):
			r.append(n)
	return r


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
	var tilemap: TileMapLayer = nivel.get_node_or_null("TileMap")
	_check(camara != null and camara.has_method("punch"), "Nivel3: cámara con script")
	_check(tilemap != null and tilemap.get_used_cells().size() > 100000, "Nivel3: TileMap con terreno pintado")
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
		if g["req"] == "ala" and (a < 600.0 or a > 680.0):   # islas del mirador: el Humano (470) no llega; Lobo y planeo sí
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
	_check(encounters == 5 and enemigos == 30, "Nivel3: 5 arenas y 30 enemigos (hay %d / %d)" % [encounters, enemigos])
	_check(pickups >= 45 and orbes >= 11, "Nivel3: almas (%d en total) y orbes de vida (%d)" % [pickups, orbes])

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
			if [9, 6, 14, 15, 19].has(int(dn.tipo)):   # colgantes: estalactita, rama, estandarte, cadenas, jaula
				apoyo = _solido(dx, dy - 8.0) and not _solido(dx, dy + 8.0) and _solido(dx - 40.0, dy - 8.0) and _solido(dx + 40.0, dy - 8.0)
			else:
				apoyo = _solido(dx, dy + 8.0) and not _solido(dx, dy - 8.0) and _solido(dx - 40.0, dy + 8.0) and _solido(dx + 40.0, dy + 8.0)
			if not apoyo:
				flotando += 1
				print("  [AVISO] decoración flotando: ", dn.name, " tipo=", dn.tipo, " en ", dn.position)
	_check(flotando == 0, "Nivel3: ninguna decoración flotando (%d)" % flotando)

	# --- Muros, losas, barreras y muro del Lobo: se leen de la ESCENA (el nivel se edita a mano; nivel3_datos.json ya no manda) ---
	var muros: Array = _con_script(nivel, "muro_piedra.gd")
	var losas: Array = _con_script(nivel, "losa_peso.gd")
	var barreras: Array = _con_script(nivel, "barrera_bosque.gd")
	var trepas: Array = _con_script(nivel, "muro_lobo.gd")
	var muros_mal := 0
	for nm in muros:
		var mx: float = nm.position.x
		var my: float = nm.position.y   # la base del muro
		var alto: float = float(nm.tam.y)
		var mitad: float = float(nm.tam.x) * 0.5
		# el techo puede quedar a lo sumo a 120 px sobre el muro (menos que el collider más chico, 133): nadie pasa por ahí
		var hueco := 0.0
		while hueco <= 400.0 and not _solido(mx, my - alto - 8.0 - hueco):
			hueco += 8.0
		if not (_solido(mx, my + 8.0) and hueco <= 120.0):   # apoyado en el piso (un muro puede estar en el borde de una repisa)
			muros_mal += 1
			print("  [AVISO] muro que no cierra el pasillo: ", nm.name, " base=", nm.position, " alto=", alto, " hueco arriba=", hueco)
	_check(muros_mal == 0, "Nivel3: %d muros cierran el pasillo de piso a techo (%d malos)" % [muros.size(), muros_mal])
	var losas_mal := 0
	for l in losas:
		var n_obj := 0
		for np in l.objetivos:
			if not np.is_empty() and l.get_node_or_null(np) != null:
				n_obj += 1
		if n_obj == 0:
			print("  [AVISO] losa sin compuerta (¿intencional?): ", l.name, " en ", l.position)
	_check(nivel.get_node_or_null("PuertaGuardian") != null and nivel.get_node_or_null("LosaGuardian") != null, "Nivel3: la compuerta del Guardián tiene su losa (%d losas en total)" % losas.size())

	# --- Dificultad: almas cerca de cada obstáculo del Oso ---
	var cerca := 0
	var obstaculos: Array = muros + losas
	for o in obstaculos:
		for hijo in nivel.get_children():
			if String(hijo.name).begins_with("Pickup") and not String(hijo.name).begins_with("PickupVida") and absf(hijo.position.x - o.position.x) < 1000.0 and absf(hijo.position.y - o.position.y) < 900.0:
				cerca += 1
				break
	_check(cerca == obstaculos.size(), "Nivel3: cada obstáculo del Oso tiene almas (energía) cerca (%d de %d)" % [cerca, obstaculos.size()])

	# --- Barreras de energía (cristales del Murciélago): base sobre el piso, 3 cristales en el aire a la vista ---
	var bar_mal := 0
	for nb in barreras:
		var bx: float = nb.global_position.x
		var base: float = nb.global_position.y + 160.0   # la colisión de la barrera baja 160 px bajo su origen
		var cuerpo: RID = (nb.get_node("Barrera") as CollisionObject2D).get_rid()
		if not (_solido(bx - 170.0, base + 40.0) and _solido(bx + 170.0, base + 40.0) and not _solido(bx - 170.0, base - 40.0)):   # piso a menos de 40 px bajo cada lado (puede apoyar en una pendiente suave)
			bar_mal += 1
			print("  [AVISO] barrera mal apoyada: ", nb.name, " base=", base)
		var cr := 0
		for c in nb.get_children():
			if c.is_in_group("cristal"):
				cr += 1
				var pq := PhysicsPointQueryParameters2D.new()
				pq.position = c.global_position
				pq.collision_mask = 1
				pq.exclude = [cuerpo]
				var en_roca := not root.world_2d.direct_space_state.intersect_point(pq).is_empty()
				if en_roca or absf(c.global_position.x - bx) > 700.0 or c.global_position.y > base:
					bar_mal += 1
					print("  [AVISO] cristal mal puesto: ", nb.name, "/", c.name, " ", c.global_position, " en_roca=", en_roca)
		if cr != 3:
			bar_mal += 1
			print("  [AVISO] la barrera ", nb.name, " tiene ", cr, " cristales")
	_check(bar_mal == 0, "Nivel3: %d barreras con 3 cristales en el aire (alcanzables) y apoyadas en el piso (%d malas)" % [barreras.size(), bar_mal])
	var trepa_mal := 0
	for nt in trepas:
		var tx: float = nt.global_position.x
		var ty: float = nt.global_position.y + 125.0   # la base (el muro mide 250 y su origen es el centro)
		# 250 de alto: más que el salto del Humano (~194) y menos que el del Lobo con doble salto (~380)
		if not _solido(tx - 120.0, ty + 8.0) or _solido(tx, ty - 250.0 - 200.0):
			trepa_mal += 1
			print("  [AVISO] muro del Lobo mal puesto: ", nt.name, " ", nt.global_position)
	_check(trepa_mal == 0, "Nivel3: %d muro(s) del Lobo bien apoyados" % trepas.size())

	# --- Los 4 personajes CABEN en todo el camino principal y las rampas son subibles ---
	for hijo in nivel.get_children():
		if String(hijo.name).begins_with("Barrera") or String(hijo.name).begins_with("Trepa"):
			hijo.queue_free()   # obstáculos pensados: se prueban en el recorrido
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
	var ruta: Array = (_d["ruta"] as Array) + (_d["ruta_alas"] as Array)
	for fm in FORMAS:
		var sz: Vector2 = fm[1]
		var malos := 0
		var primero := ""
		(cs.shape as RectangleShape2D).size = sz
		for r in ruta:
			var x: float = r["x"]
			var hw := sz.x * 0.5 + 24.0
			if x < 300.0 + hw or (r["zona"] == "Z5" and x > 13550.0 - hw) or (r["zona"] == "Z7" and x > 10700.0 - hw) 					or (r["zona"] == "Z8" and x > 16100.0 - hw) or (r["zona"] == "Z4b" and (x < 13550.0 + hw or x > 14380.0)):
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

	# --- Madriguera del Lobo: el túnel (200 de alto) solo lo cruzan el Lobo y el Murciélago; Humano y Oso no caben ---
	var mad: Dictionary = _d["madriguera"]
	for fm in FORMAS:
		var szm: Vector2 = fm[1]
		(cs.shape as RectangleShape2D).size = szm
		var traba_tunel := 0
		for r in mad["tunel"]:
			probe.global_position = Vector2(float(r["x"]), float(r["y"]) - szm.y * 0.5 - 1.0)
			if probe.test_move(probe.global_transform, Vector2.ZERO):
				traba_tunel += 1
		var cabe_camara := true
		for r in mad["camara"]:
			probe.global_position = Vector2(float(r["x"]), float(r["y"]) - szm.y * 0.5 - 1.0)
			if probe.test_move(probe.global_transform, Vector2.ZERO):
				cabe_camara = false
		var debe_pasar: bool = fm[0] == "Lobo" or fm[0] == "Murciélago"
		_check((traba_tunel == 0) == debe_pasar and (not debe_pasar or cabe_camara), "Madriguera: el %s %s por el túnel bajo (%d puntos trabados)" % [fm[0], "pasa" if debe_pasar else "NO pasa", traba_tunel])
	var esc: Array = mad["escalones"]
	var alto_ok := true
	var piso_prev := 3888.0
	for e in esc:
		if piso_prev - float(e["y"]) > 170.0:
			alto_ok = false
		piso_prev = float(e["y"])
	_check(alto_ok, "Madriguera: los escalones de la cámara suben <= 170 px (alcanza el salto del Lobo)")
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
