extends SceneTree

## Nivel 3: PARTIDA COMPLETA con un bot (Input simulado, sin teletransportes): de la entrada a la salida resolviendo cada
## obstáculo con la forma que corresponde (cristales→Murciélago, salto ancho/muro alto→Lobo, losas/muros→Oso, vides→Humano),
## con transformaciones reales (energía y espacio) y las 4+ arenas. Invulnerable (god_mode): prueba el recorrido, no el combate.
## Imprime la energía en cada transformación para ver si el ritmo la sostiene.

var _fallos := 0
var _nivel: Node
var _player: CharacterBody2D
var _off := -142.5
var _t0 := 0


func _check(cond: bool, msg: String) -> void:
	if cond:
		print("[PASS] " + msg)
	else:
		_fallos += 1
		print("[FAIL] " + msg)


func _frames(n: int) -> void:
	for i in n:
		Engine.time_scale = 1.0
		await physics_frame


func _soltar() -> void:
	for a in ["move_left", "move_right", "move_up", "move_down", "jump", "attack", "heavy", "special"]:
		Input.action_release(a)


func _x() -> float:
	return _player.global_position.x


func _forma(f: int) -> bool:
	if int(_player.get("current_form")) == f:
		return true
	var en0: float = _player.get("energia")
	for i in 8:
		_player.call("_transformar", f)
		await _frames(10)
		if int(_player.get("current_form")) == f:
			print("[INFO] forma %d en x=%.0f (energía %.0f)" % [f, _x(), en0])
			return true
		await _frames(40)
	_check(false, "no se pudo transformar a la forma %d en x=%.0f (energía %.0f, cooldown?)" % [f, _x(), en0])
	return false


func _hacia(dir: int, x_meta: float, max_frames := 3000) -> bool:
	var a := "move_right" if dir > 0 else "move_left"
	Input.action_press(a)
	var ok := false
	for i in max_frames:
		Engine.time_scale = 1.0
		await physics_frame
		if (_x() - x_meta) * dir >= 0.0:
			ok = true
			break
	Input.action_release(a)
	await _frames(15)
	return ok


## Corre hasta que el borde delantero llegue a `borde_x`, salta (mantenido `hold`) y sigue `espera` frames en el aire/suelo.
func _saltar_borde(dir: int, borde_x: float, hold: int, medio: float, espera := 90) -> void:
	var a := "move_right" if dir > 0 else "move_left"
	Input.action_press(a)
	for i in 600:
		Engine.time_scale = 1.0
		await physics_frame
		if (_x() + dir * medio) * dir >= borde_x * dir - 6.0:
			break
	Input.action_press("jump")
	await _frames(hold)
	Input.action_release("jump")
	await _frames(espera)
	Input.action_release(a)
	await _frames(25)


func _matar_arena(nombre: String) -> void:
	var enc: Node = _nivel.get_node(nombre)
	var hecho := [false]
	enc.completado.connect(func(): hecho[0] = true)
	var vistos := 0
	for i in 4000:
		await physics_frame
		Engine.time_scale = 1.0
		if i % 10 == 0:
			for e in get_nodes_in_group("enemy"):
				if not is_instance_valid(e) or e.get_parent() != enc or float(e.get("health")) <= 0.0:
					continue
				vistos += 1
				if e.get("_activo") == true:
					if e.get("flotante") == true:
						e.set("golpe_proyectil", true)
					e.call("take_damage", 9999, 0, 1, false)
		if hecho[0]:
			break
	_check(hecho[0], "%s: arena superada (x=%.0f)" % [nombre, _x()])
	var cam: Node = _nivel.get_node_or_null("Camara")
	if cam != null and cam.has_method("modo_normal"):
		cam.call("modo_normal")
	await _frames(40)


func _romper(nombre: String, x_golpe: float) -> void:
	var nm: Node = _nivel.get_node_or_null(nombre)
	if nm == null:
		_check(false, "%s existe" % nombre)
		return
	await _hacia(1, x_golpe)
	_player.facing = 1
	var n := 0
	while is_instance_valid(nm) and not bool(nm.abierto) and n < 14:
		Input.action_press("heavy")
		await _frames(3)
		Input.action_release("heavy")
		await _frames(50)
		n += 1
	_check((not is_instance_valid(nm)) or bool(nm.abierto), "%s: roto con golpes del Oso (%d)" % [nombre, n])
	await _frames(40)


func _losa(nombre: String, puerta: String) -> void:
	var l: Node2D = _nivel.get_node(nombre)
	await _hacia(1 if _x() < l.position.x else -1, l.position.x)
	Input.action_press("special")
	await _frames(4)
	Input.action_release("special")
	await _frames(50)
	var p: Node = _nivel.get_node_or_null(puerta)
	_check(bool(l._activa) and ((not is_instance_valid(p)) or bool(p.abierto)), "%s abre %s" % [nombre, puerta])


func _cristales(nombre: String, desde_x: float) -> void:
	var nb: Node2D = _nivel.get_node(nombre)
	var cam: Camera2D = _nivel.get_node("Camara")
	cam.position_smoothing_enabled = false
	_player.facing = 1
	var d := 0
	while not bool(nb._abierta) and d < 40:
		cam.global_position = _player.global_position
		_player.fire_projectile()
		d += 1
		for i in 26:
			cam.global_position = _player.global_position
			Engine.time_scale = 1.0
			await physics_frame
	_check(bool(nb._abierta), "%s: abierta con %d disparos del sónico (energía %.0f)" % [nombre, d, float(_player.get("energia"))])
	cam.position_smoothing_enabled = true


func _init() -> void:
	_nivel = load("res://scenes/nivel3.tscn").instantiate()
	root.add_child(_nivel)
	_player = _nivel.get_node("Player")
	_player.set("god_mode", true)
	var lu: Node = _nivel.get_node_or_null("LevelUp")
	if lu != null:
		lu.set("pausar_al_abrir", false)
	await _frames(120)
	_t0 = Time.get_ticks_msec()
	_check(_player.is_on_floor(), "arranca en la entrada (x=%.0f)" % _x())

	# ---- Z1 Entrada Honda
	_check(await _hacia(1, 2450.0), "Z1: baja suave hasta el primer foso")
	await _saltar_borde(1, 2620.0, 24, 95.0)
	_check(_x() > 2900.0 and _player.is_on_floor(), "Z1: primer salto (x=%.0f)" % _x())
	_check(await _hacia(1, 3950.0), "Z1: sigue hasta el segundo foso")
	await _saltar_borde(1, 4250.0, 26, 95.0)
	_check(_x() > 4580.0 and _player.is_on_floor(), "Z1: segundo salto (x=%.0f)" % _x())
	_check(await _hacia(1, 5800.0), "Z1->Z2: entra al cuenco")

	# ---- Z2 arena A
	await _hacia(1, 7500.0)
	await _matar_arena("EncounterA")
	_check(await _hacia(1, 9000.0), "Z2: sale del cuenco hacia el santuario")

	# ---- Z3 barrera de energía (Murciélago)
	if await _forma(3):
		await _cristales("BarreraEntrada", _x())
	_check(await _hacia(1, 9900.0), "Z3: atraviesa la barrera abierta (x=%.0f)" % _x())
	await _hacia(1, 10020.0)   # altar: se gana el Oso
	await _frames(120)
	_check(true, "Z3: altar (formas desbloqueadas: oso=%s)" % str(_player.forms[2] != null))
	if await _forma(2):
		await _losa("LosaPractica", "PuertaAltar")
		_check(await _hacia(1, 10700.0), "Z3: pasa la puerta del altar (x=%.0f)" % _x())
		await _romper("MuroTutorial", 10850.0)
		_check(await _hacia(1, 11500.0), "Z3: pasa el muro tutorial (x=%.0f)" % _x())

	# ---- Z4 descenso y caída al lago
	_check(await _hacia(1, 12850.0), "Z4: baja la rampa hasta el borde (x=%.0f)" % _x())
	await _forma(0)
	await _hacia(1, 13300.0, 600)
	await _frames(240)
	_check(_player.is_on_floor() and _player.global_position.y > 3500.0, "Z4: cae al tiro y llega al lago (y=%.0f)" % _player.global_position.y)

	# ---- Z5 lago (hacia el oeste)
	_check(await _hacia(-1, 12200.0), "Z5: sube la rampa de la orilla (x=%.0f)" % _x())
	_check(await _hacia(-1, 10300.0), "Z5: cruza las tablas y llega al llano antes del salto ancho (x=%.0f)" % _x())
	if await _forma(1):
		await _saltar_borde(-1, 9950.0, 40, 180.0)
		_check(_x() < 9300.0 and _player.is_on_floor(), "Z5: salto ancho con el Lobo (x=%.0f)" % _x())
	_check(await _hacia(-1, 6700.0), "Z5: llega a la cueva del Guardián (x=%.0f)" % _x())
	await _matar_arena("EncounterGuardian")
	_check(await _hacia(-1, 6000.0), "Z5: cruza la cueva")
	if await _forma(2):
		await _losa("LosaGuardian", "PuertaGuardian")
		_check(await _hacia(-1, 5300.0), "Z5: pasa la puerta del Guardián (x=%.0f)" % _x())
	await _forma(0)
	_check(await _hacia(-1, 4700.0), "Z5: corredor")
	await _saltar_borde(-1, 4300.0, 28, 95.0)
	_check(_x() < 3900.0 and _player.is_on_floor(), "Z5: salto del corredor (x=%.0f)" % _x())
	_check(await _hacia(-1, 1450.0), "Z6: sube la rampa de la gran subida (x=%.0f)" % _x())

	# ---- Z6 chimenea (vides, Humano)
	_check(await _hacia(-1, 1010.0), "Z6: llega al pie de la primera vid (x=%.0f)" % _x())
	Input.action_press("move_up")
	for i in 900:
		await physics_frame
		Engine.time_scale = 1.0
		if _player.global_position.y - _off <= 3385.0:
			break
	Input.action_release("move_up")
	await _frames(5)
	Input.action_press("move_right")
	Input.action_press("jump")
	await _frames(14)
	Input.action_release("jump")
	await _frames(30)
	Input.action_release("move_right")
	await _frames(25)
	_check(_player.is_on_floor() and absf(_player.global_position.y - (3360.0 + _off)) < 16.0, "Z6: primera vid -> repisa intermedia (x=%.0f y=%.0f)" % [_x(), _player.global_position.y])
	await _hacia(1, 1400.0)
	Input.action_press("move_up")
	for i in 900:
		await physics_frame
		Engine.time_scale = 1.0
		if _player.global_position.y - _off <= 2865.0:
			break
	Input.action_release("move_up")
	await _frames(5)
	Input.action_press("move_right")
	Input.action_press("jump")
	await _frames(14)
	Input.action_release("jump")
	await _frames(40)
	Input.action_release("move_right")
	await _frames(25)
	_check(_player.is_on_floor() and _x() > 1500.0 and absf(_player.global_position.y - (2840.0 + _off)) < 16.0, "Z6: segunda vid -> el Corazón (x=%.0f y=%.0f)" % [_x(), _player.global_position.y])

	# ---- Z7 sala de las 3 formas
	await _hacia(1, 1620.0)
	if await _forma(3):
		await _cristales("BarreraSala", _x())
	if await _forma(1):
		await _hacia(1, 2050.0)
		var a := "move_right"
		Input.action_press(a)
		for i in 400:
			await physics_frame
			Engine.time_scale = 1.0
			if _x() + 180.0 >= 2350.0 - 20.0 - 80.0:
				break
		Input.action_press("jump")
		await _frames(20)
		Input.action_release("jump")
		await _frames(6)
		Input.action_press("jump")
		await _frames(20)
		Input.action_release("jump")
		await _frames(150)
		Input.action_release(a)
		await _frames(25)
		_check(_x() > 2410.0 and _player.is_on_floor(), "Sala: el Lobo supera el muro alto (x=%.0f)" % _x())
	await _hacia(1 if _x() < 2800.0 else -1, 2800.0)
	if await _forma(2):
		await _losa("LosaSala", "PuertaSala")
		_check(await _hacia(1, 3500.0), "Sala: pasa la puerta (x=%.0f)" % _x())
	await _hacia(1, 4000.0)
	await _matar_arena("EncounterB")
	_check(await _hacia(1, 5450.0), "Z7: llega al puente roto (x=%.0f)" % _x())
	if await _forma(1):
		await _saltar_borde(1, 5600.0, 40, 180.0)
		_check(_x() > 6250.0 and _player.is_on_floor(), "Z7: puente roto con el Lobo (x=%.0f)" % _x())
	_check(await _hacia(1 if _x() < 6600.0 else -1, 6600.0), "Z7: llega al derrumbe")
	if await _forma(2):
		await _romper("MuroDerrumbe", 6690.0)
		_check(await _hacia(1, 7700.0), "Z7: pasa el derrumbe (x=%.0f)" % _x())
	await _hacia(1, 8000.0)
	await _matar_arena("EncounterFinal")
	_check(await _hacia(1, 8960.0), "Z7: llega al sello (x=%.0f)" % _x())
	if int(_player.get("current_form")) != 2:
		await _forma(2)
	await _romper("MuroSello", 9000.0)
	_check(await _hacia(1, 10450.0), "Z7: pasa el sello y llega al santuario/umbral (x=%.0f)" % _x())
	_check(_x() > 10400.0, "FIN: llegó a la salida en %.0f s de bot" % ((Time.get_ticks_msec() - _t0) / 1000.0))
	print("[TMP] NIVEL3 PARTIDA FIN fallos=", _fallos)
	_soltar()
	quit(_fallos)
