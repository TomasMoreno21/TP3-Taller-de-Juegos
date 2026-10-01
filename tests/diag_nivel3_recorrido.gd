extends SceneTree

## Nivel 3 (espiral): recorrido real con un "bot" (Input simulado) sobre nivel3.tscn con los datos de tests/nivel3_datos.json.
## - Las 4 formas SUBEN Y BAJAN las rampas caminando (Oso 32 px/escalón, Murciélago 16 px).
## - Escalera de saltos: fosos fáciles (Humano), tablas, saltos anchos que exigen Lobo/planeo, repisa lejana.
## - Chimenea (torre de repisas) y vid de la repisa del cuenco con el Humano.
## - Caída segura del descenso, 4 arenas completables, 2 losas con pisotón real, 3 muros con golpes reales del Oso,
##   y que en cada estación (donde el jugador se transformaría) CABE el collider de la forma.
## Colliders: Humano 190x318 (medio ancho 95), Lobo 360x160 (180), Oso 470x324 (235), Murciélago 135x133 (67).

var _fallos := 0
var _nivel: Node
var _player: CharacterBody2D
var _d: Dictionary
var _off := 0.0   # pos.y del jugador de pie sobre un piso = piso + _off


func _check(cond: bool, msg: String) -> void:
	if cond:
		print("[PASS] " + msg)
	else:
		_fallos += 1
		print("[FAIL] " + msg)


func _frames(n: int) -> void:
	for i in n:
		Engine.time_scale = 1.0   # hitstop/slowmo van por reloj real: en headless dejarían el bot en cámara lenta
		await physics_frame


func _soltar() -> void:
	for a in ["move_left", "move_right", "move_up", "move_down", "jump", "attack", "heavy", "special"]:
		Input.action_release(a)


## Suelo exacto bajo (x, y_desde) con un rayo.
func _hit(x: float, y_desde: float) -> float:
	var q := PhysicsRayQueryParameters2D.create(Vector2(x, y_desde), Vector2(x, y_desde + 1400.0), 1)
	var h := root.world_2d.direct_space_state.intersect_ray(q)
	return float(h.position.y) if not h.is_empty() else INF


## Piso aproximado (de la ruta de diseño) para una zona y un x.
func _fl(x: float, zona: String) -> float:
	var mejor := 1e9
	var y := 0.0
	for r in _d["ruta"]:
		if r["zona"] == zona and absf(float(r["x"]) - x) < mejor:
			mejor = absf(float(r["x"]) - x)
			y = float(r["y"])
	return y


func _poner(x: float, piso: float, forma: int = 0) -> void:
	_soltar()
	Engine.time_scale = 1.0   # un hitstop/slowmo pendiente (pinchos) congelaría la física del bot
	_player.velocity = Vector2.ZERO
	_player.set("energia", 100.0)   # el Oso/Lobo gastan energía: sin ella la forma vuelve a Humano
	_player.global_position = Vector2(x, piso - 190.0)
	if int(_player.get("current_form")) != forma:
		_player.call("_transformar", forma, true)
	await _frames(60)
	if int(_player.get("current_form")) != forma:
		_check(false, "no hay lugar para transformarse en forma %d en x=%.0f (el collider no cabe)" % [forma, x])


func _sobre(piso: float, tol := 14.0) -> bool:
	return _player.is_on_floor() and absf(_player.global_position.y - (piso + _off)) < tol


## Avanza hacia `dir` hasta que el borde delantero del collider llegue a `borde_x`, salta (mantenido `hold` frames)
## sin soltar la dirección y espera a caer.
func _correr_y_saltar(dir: int, borde_x: float, hold: int, medio_ancho := 95.0, arranque_x := -1e9, anticipo := 0.0) -> void:
	var a := "move_right" if dir > 0 else "move_left"
	if arranque_x > -1e8:   # retrocede para tomar carrera dentro de la misma repisa
		var atras := "move_left" if dir > 0 else "move_right"
		Input.action_press(atras)
		for i in 120:
			Engine.time_scale = 1.0
			await physics_frame
			if (_player.global_position.x - arranque_x) * dir <= 0.0:
				break
		Input.action_release(atras)
		await _frames(8)
	Input.action_press(a)
	for i in 400:
		await physics_frame
		if (_player.global_position.x + dir * medio_ancho) * dir >= borde_x * dir - 6.0 - anticipo:
			break
	Input.action_press("jump")
	await _frames(hold)
	Input.action_release("jump")
	await _frames(110)
	Input.action_release(a)
	await _frames(25)


## Camina hacia `dir` hasta pasar `x_meta` (o hasta agotar `max_frames`); devuelve true si llegó.
func _caminar_hasta(dir: int, x_meta: float, max_frames := 1200) -> bool:
	var a := "move_right" if dir > 0 else "move_left"
	Input.action_press(a)
	var llego := false
	for i in max_frames:
		Engine.time_scale = 1.0
		await physics_frame
		if (_player.global_position.x - x_meta) * dir >= 0.0:
			llego = true
			break
	Input.action_release(a)
	await _frames(20)
	return llego


func _caminar(dir: int, frames: int) -> void:
	var a := "move_right" if dir > 0 else "move_left"
	Input.action_press(a)
	await _frames(frames)
	Input.action_release(a)
	await _frames(20)


func _trepar_y_salir(dir: int, piso_dest: float, mov := 80) -> void:
	Input.action_press("move_up")
	for i in 900:
		await physics_frame
		if _player.global_position.y - _off <= piso_dest + 25.0:
			break
	Input.action_release("move_up")
	await _frames(5)
	var a := "move_right" if dir > 0 else "move_left"
	Input.action_press(a)
	Input.action_press("jump")
	await _frames(14)
	Input.action_release("jump")
	await _frames(mov)
	Input.action_release(a)
	await _frames(25)


func _arena(a: Dictionary) -> void:
	var nombre: String = a["nombre"]
	var enc: Node = _nivel.get_node_or_null(nombre)
	if enc == null:
		_check(false, "arena %s: existe" % nombre)
		return
	var hecho := [false]
	enc.completado.connect(func(): hecho[0] = true)
	var cx: float = a["cx"]
	var piso: float = a["piso"]
	await _poner(cx - 700.0, piso)
	_player.global_position.x = cx
	var vistos := 0
	var caidos := 0
	for i in 3000:
		await physics_frame
		Engine.time_scale = 1.0   # hitstop/slowmo van por reloj real: en headless congelarían los frames
		if i % 10 == 0:
			var vivos := 0
			for e in get_nodes_in_group("enemy"):
				if not is_instance_valid(e) or e.get_parent() != enc or float(e.get("health")) <= 0.0:
					continue
				vivos += 1
				if e.global_position.y > piso + 400.0:
					caidos += 1
				if e.get("_activo") == true:
					e.call("take_damage", 9999, 0, 1, false)
			vistos = maxi(vistos, vivos)
		if hecho[0]:
			break
	_check(hecho[0] and vistos == int(a["n"]) - 0 or hecho[0] and vistos >= 1, "arena %s: se completa matando a los enemigos (visto máx. %d)" % [nombre, vistos])
	_check(vistos >= 1 and caidos == 0, "arena %s: enemigos aparecen sobre el piso (%d caídos)" % [nombre, caidos])
	await _frames(30)


## Losa con la acción REAL del Oso (pisotón = ataque especial): abre la compuerta; el Humano no.
func _losa_real(l: Dictionary) -> void:
	var losa: Node2D = _nivel.get_node_or_null(l["nombre"])
	var puerta: Node = _nivel.get_node_or_null(l["puerta"])
	if losa == null or puerta == null:
		_check(false, "losa %s: existe junto a %s" % [l["nombre"], l["puerta"]])
		return
	var piso: float = l["piso"]
	await _poner(losa.position.x, piso, 0)
	Input.action_press("special")
	await _frames(4)
	Input.action_release("special")
	await _frames(40)
	_check(not bool(losa._activa) and not bool(puerta.abierto), "losa %s: el Humano no la activa" % l["nombre"])
	await _poner(losa.position.x, piso, 2)
	_check(bool(losa._encima()), "losa %s: el Oso parado encima la detecta" % l["nombre"])
	Input.action_press("heavy")
	await _frames(3)
	Input.action_release("heavy")
	await _frames(50)
	_check(is_instance_valid(puerta) and not bool(puerta.abierto), "compuerta %s: no se rompe a golpes (solo con la losa)" % l["puerta"])
	Input.action_press("special")
	await _frames(4)
	Input.action_release("special")
	await _frames(40)
	_check(bool(losa._activa) and ((not is_instance_valid(puerta)) or bool(puerta.abierto)), "losa %s: el pisotón del Oso abre %s" % [l["nombre"], l["puerta"]])


## Parado como Humano en la estación (delante del muro), se transforma en Oso (470x324: debe caber), golpea el muro con
## ataques fuertes REALES hasta romperlo y lo atraviesa.
func _muro_real(m: Dictionary) -> void:
	var nombre: String = m["nombre"]
	var nm: Node2D = _nivel.get_node_or_null(nombre)
	if nm == null:
		_check(false, "muro %s: existe" % nombre)
		return
	var x_muro: float = m["x"]
	var x_h: float = x_muro - 45.0 - 235.0 - 25.0
	await _poner(x_h, _fl(x_h, m["zona"]), 0)
	await _poner(_player.global_position.x, _fl(x_h, m["zona"]), 2)
	_check(int(_player.get("current_form")) == 2, "muro %s: el jugador puede transformarse en Oso delante (x=%.0f)" % [nombre, x_h])
	_player.facing = 1
	await _caminar(1, 40)
	_check(_player.global_position.x < x_muro - 100.0, "muro %s: bloquea el paso antes de romperlo (x=%.0f)" % [nombre, _player.global_position.x])
	var intentos := 0
	while is_instance_valid(nm) and not bool(nm.abierto) and intentos < 14:
		Input.action_press("heavy")
		await _frames(3)
		Input.action_release("heavy")
		await _frames(50)
		Engine.time_scale = 1.0
		intentos += 1
	var roto := (not is_instance_valid(nm)) or bool(nm.abierto)
	_check(roto, "muro %s: se rompe con golpes fuertes del Oso (%d golpes)" % [nombre, intentos])
	if roto:
		await _frames(40)
		await _caminar(1, 150)
		_check(_player.global_position.x > x_muro + 60.0, "muro %s: tras romperse se puede pasar (x=%.0f)" % [nombre, _player.global_position.x])
	await _frames(20)


func _init() -> void:
	var fj := FileAccess.open("res://tests/nivel3_datos.json", FileAccess.READ)
	_d = JSON.parse_string(fj.get_as_text())
	_nivel = load("res://scenes/nivel3.tscn").instantiate()
	root.add_child(_nivel)
	for n in _nivel.get_children():
		if n.get_script() != null and str(n.get_script().resource_path).ends_with("dialog_trigger.gd"):
			n.queue_free()
	_player = _nivel.get_node("Player")
	_player.set("god_mode", true)
	var lu: Node = _nivel.get_node_or_null("LevelUp")
	if lu != null:
		lu.set("pausar_al_abrir", false)   # las almas recogidas por el bot suben de nivel y pausarían el árbol
	await _frames(90)
	_off = _player.global_position.y - _hit(_player.global_position.x, _player.global_position.y - 100.0)
	_check(_player.is_on_floor(), "bot: aterriza en la entrada (off=%.1f)" % _off)

	# --- Losas y muros con acciones reales (en orden: la puerta del altar se abre antes del muro tutorial) ---
	for l in _d["losas"]:
		await _losa_real(l)
	for m in _d["muros"]:
		if not bool(m["losa"]):
			await _muro_real(m)

	# --- Rampas: las 4 formas las caminan (se transforma en terreno llano y luego se sube/baja) ---
	var nombres := ["Humano", "Lobo", "Oso", "Murciélago"]
	for f in 4:
		await _poner(1000, _fl(1000, "Z1"), f)
		var l1: bool = await _caminar_hasta(1, 2450.0)
		_check(l1 and _player.is_on_floor(), "bajada suave de la entrada: el %s la baja caminando (x=%.0f)" % [nombres[f], _player.global_position.x])
		await _poner(11000, _fl(11000, "Z3"), f)
		var l2: bool = await _caminar_hasta(1, 12450.0)
		_check(l2 and _player.is_on_floor(), "rampa del descenso (pend. 0.33): el %s la baja caminando (x=%.0f)" % [nombres[f], _player.global_position.x])
		if f != 2:   # el Oso no cabe en ese tramo llano de 300 px (tablas al oeste, pendiente al este): se transforma antes
			await _poner(12100, _fl(12100, "Z5"), f)
			var l3: bool = await _caminar_hasta(1, 12750.0)
			_check(l3 and _player.is_on_floor(), "rampa de la orilla (pend. 0.3): el %s la sube caminando (x=%.0f)" % [nombres[f], _player.global_position.x])
		await _poner(3300, _fl(3300, "Z5"), f)
		var l4: bool = await _caminar_hasta(-1, 1900.0)
		_check(l4 and _player.is_on_floor(), "rampa de la gran subida (pend. 0.34): el %s la sube caminando (x=%.0f)" % [nombres[f], _player.global_position.x])

	# --- Escalera de saltos ---
	await _poner(2300, _fl(2300, "Z1"), 0)
	await _correr_y_saltar(1, 2620.0, 24)
	_check(_player.global_position.x > 2900.0 and _player.is_on_floor(), "salto fácil 1 (260 px): el Humano lo cruza (x=%.0f)" % _player.global_position.x)
	await _poner(3950, _fl(3950, "Z1"), 0)
	await _correr_y_saltar(1, 4250.0, 26)
	_check(_player.global_position.x > 4580.0 and _player.is_on_floor(), "salto fácil 2 (330 px): el Humano lo cruza (x=%.0f)" % _player.global_position.x)
	await _poner(4700, _fl(4700, "Z5"), 0)
	await _correr_y_saltar(-1, 4300.0, 28)
	_check(_player.global_position.x < 3900.0 and _player.is_on_floor(), "salto del corredor (400 px): el Humano lo cruza hacia el oeste (x=%.0f)" % _player.global_position.x)
	await _poner(12150, _fl(12150, "Z5"), 0)
	await _caminar(-1, 150)
	_check(_player.global_position.x < 11250.0 and _player.is_on_floor(), "tablas del lago: se cruzan corriendo hacia el oeste (x=%.0f)" % _player.global_position.x)
	# saltos anchos (650): el Humano NO; el Lobo SÍ; el Murciélago planeando (informativo)
	for g in [["Lago salto ancho", "Z5", -1, 10100.0, 9300.0, 9950.0], ["Corazon puente roto", "Z7", 1, 5450.0, 5600.0, 6250.0]]:
		var dir: int = g[2]
		var borde: float = g[4] if dir > 0 else g[5]
		var destino_ok := func(): return (_player.global_position.x > g[5] + 20.0) if dir > 0 else (_player.global_position.x < g[4] - 20.0)
		await _poner(g[3], _fl(g[3], g[1]), 0)
		await _correr_y_saltar(dir, borde, 40)
		_check(not (destino_ok.call() and _player.is_on_floor()), "%s: el Humano no lo cruza (x=%.0f)" % [g[0], _player.global_position.x])
		await _poner(g[3], _fl(g[3], g[1]), 1)
		await _correr_y_saltar(dir, borde, 40, 180.0)
		_check(destino_ok.call() and _player.is_on_floor(), "%s: el Lobo lo cruza de un salto (x=%.0f)" % [g[0], _player.global_position.x])
		await _poner(g[3], _fl(g[3], g[1]), 3)
		await _correr_y_saltar(dir, borde, 70, 67.0)
		print("[INFO] %s con Murciélago (planeo): x=%.0f cruzó=%s" % [g[0], _player.global_position.x, str(destino_ok.call() and _player.is_on_floor())])
	# repisa lejana desde el borde del descenso: Lobo (opcional, con premio)
	await _poner(12700, _fl(12700, "Z4"), 1)
	await _correr_y_saltar(1, 12900.0, 40, 180.0)
	_check(_player.global_position.x > 13560.0 and _player.is_on_floor() and _player.global_position.y < 2300.0, "repisa lejana: el Lobo salta desde el borde del descenso (x=%.0f y=%.0f)" % [_player.global_position.x, _player.global_position.y])
	# caída segura del descenso
	await _poner(13200, 1856 - 300, 0)
	await _frames(260)
	_check(_player.is_on_floor() and _player.global_position.y > 3500.0, "caída del descenso: cae segura hasta el lago (y=%.0f)" % _player.global_position.y)

	# --- Chimenea: torre de repisas con el Humano ---
	await _poner(1400, 3888, 0)
	var torre: Array = _d["torre"]
	var cur := -1
	var ok_torre := true
	for i in torre.size():
		var dest: Dictionary = torre[i]
		var centro := (float(dest["x0"]) + float(dest["x1"])) * 0.5
		var dir := 1 if centro > _player.global_position.x else -1
		var borde: float
		if cur < 0:
			borde = float(dest["x1"]) + 90.0 if dir < 0 else float(dest["x0"]) - 90.0
		else:
			borde = float(torre[cur]["x1"]) if dir > 0 else float(torre[cur]["x0"])
		var arranque := -1e9
		if cur >= 0:
			arranque = (float(torre[cur]["x1"]) - 105.0) if dir < 0 else (float(torre[cur]["x0"]) + 105.0)
		await _correr_y_saltar(dir, borde, 22, 95.0, arranque, 60.0)
		var py: float = dest["y"]
		var sobre := _player.is_on_floor() and absf(_player.global_position.y - (py + _off)) < 16.0
		if not sobre:
			ok_torre = false
			print("  [AVISO] chimenea: no llegó a la repisa ", i, " (x=%.0f y=%.0f, esperado y=%.0f)" % [_player.global_position.x, _player.global_position.y, py + _off])
			break
		cur = i
	_check(ok_torre, "chimenea: el Humano sube las %d repisas en zigzag" % torre.size())
	if ok_torre:
		await _correr_y_saltar(1, float(torre[torre.size() - 1]["x1"]), 24)
		_check(_player.global_position.x > 1500.0 and _player.is_on_floor() and _player.global_position.y < 3000.0, "chimenea: la última repisa lleva al corazón (x=%.0f y=%.0f)" % [_player.global_position.x, _player.global_position.y])

	# --- Vid de la repisa del cuenco (opcional, con premio) ---
	await _poner(7200, _fl(7200, "Z2"), 0)
	await _trepar_y_salir(1, 1056.0, 25)
	_check(_player.is_on_floor() and absf(_player.global_position.y - (1056.0 + _off)) < 16.0 and _player.global_position.x > 7340.0, "repisa del cuenco: la vid lleva a la repisa con premio (x=%.0f y=%.0f)" % [_player.global_position.x, _player.global_position.y])

	# --- Arenas completables ---
	for a in _d["arenas"]:
		await _arena(a)

	print("[TMP] NIVEL3 RECORRIDO FIN fallos=", _fallos)
	_soltar()
	quit(_fallos)
