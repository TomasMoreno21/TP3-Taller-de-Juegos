extends SceneTree
## Diag del jefe final (Estrella), F1: alturas de las llaves por forma, ciclo llaves → nudo (Oso)
## → castigo, lanza, energía por ojo, tope de daño por fase, orbe de vida, reinicio y muerte.
## Los golpes clave se dan con el melee real del jugador (contrato de 4 args, lección 14/09).

var _failures := 0
var _murio := false


func _init() -> void:
	var scene = load("res://scenes/nivel_jefe.tscn").instantiate()
	_quitar_dialogos_automaticos(scene)
	root.add_child(scene)
	await process_frame
	await process_frame

	var player = scene.get_node("Player")
	player.god_mode = true
	var encounter = get_first_node_in_group("encounter")
	var boss = get_first_node_in_group("boss")
	_check(boss != null and encounter != null and boss.has_method("golpe_ojo"), "La arena carga la Estrella y el encuentro")
	if boss == null or encounter == null:
		_fin()
		return
	var piso_y: float = boss.global_position.y

	# --- Estático: vida, ubicación y alturas de las llaves por forma ---
	_check(boss.health == 600, "Vida inicial 600: %d" % boss.health)
	_check(absf(boss.global_position.x - encounter.arena_center.x) < 50.0, "La Estrella está en el centro de la arena")
	_check(absf(piso_y - 1000.0) < 2.0, "El origen de la Estrella está en el piso (y=%.0f)" % piso_y)
	for ciclo in [0, 1]:
		var alturas: Array[float] = []
		for o in boss._ojos():
			if int(o.ciclo_llave) == ciclo:
				alturas.append(-o.position.y)
				_check(absf(o.position.x) < encounter.arena_medio_ancho - 60.0, "Llave %s dentro de la arena (x=%.0f)" % [o.name, o.position.x])
		_check(alturas.size() == 4, "Ciclo %d: 4 llaves" % ciclo)
		_check(alturas.any(func(h: float) -> bool: return h < 220.0), "Ciclo %d: una llave baja (cualquier forma)" % ciclo)
		_check(alturas.any(func(h: float) -> bool: return h >= 420.0 and h < 620.0), "Ciclo %d: una llave alta (Lobo con doble salto o Murciélago)" % ciclo)
		_check(alturas.any(func(h: float) -> bool: return h >= 650.0), "Ciclo %d: una llave muy alta (solo Murciélago)" % ciclo)

	# --- Arranca la pelea ---
	player.global_position = Vector2(encounter.arena_center.x - 500.0, piso_y - 143.0)
	encounter.empezar()
	await _esperar_estado(boss, "llaves", 400)
	_check(boss._estado == "llaves", "La pelea arranca en las llaves")
	var llaves: Array = boss._llaves_del_ciclo()
	_check(llaves.all(func(o) -> bool: return o.abierto), "Las 4 llaves del ciclo 0 se abren")
	var hp0: int = boss.health
	boss.golpe_ojo(50, 1, false)
	_check(boss.health == hp0, "Fuera de la ventana de castigo el ojo no recibe daño")

	# --- Lanza: avisa y pega 15 una vez ---
	await _esperar_lanza(300)
	var lanza = get_first_node_in_group("ataque_jefe")
	_check(lanza != null, "La Estrella lanza una punta contra el jugador")
	if lanza != null:
		_check(absf(lanza.hasta.x - player.global_position.x) < 2.0 and absf(lanza.hasta.y - piso_y) < 2.0, "La lanza apunta al piso bajo el jugador")
		player.god_mode = false
		var vida0: int = player.health
		await _wait_frames(90)
		_check(player.health == vida0 - 15, "La lanza hace 15 de daño una sola vez (%d -> %d)" % [vida0, player.health])
		player.god_mode = true
		player.curar(100)

	# --- Llaves: la baja se cierra con el melee real y da energía ---
	var baja = llaves[0]
	for o in llaves:
		if -o.position.y < -baja.position.y:
			baja = o
	player.energia = 0.0
	await _golpear(player, "attack", baja.global_position, 1)
	_check(not baja.abierto, "La llave baja se cierra con el golpe del Humano")
	_check(player.energia >= 12.0, "Cerrar un ojo con el golpe da energía (%.1f)" % player.energia)
	for o in llaves:
		if o.abierto:
			# Mismo frame: sin la regeneración del Humano en el medio.
			var e0: float = player.energia
			o.take_damage(10, 0.0, 1, false)
			_check(absf(player.energia - e0 - 12.0) < 0.01, "Cerrar un ojo da 12 de energía exactos")
			break
	for o in llaves:
		if o.abierto:
			o.take_damage(10, 0.0, 1, false)
	await _esperar_estado(boss, "nudo", 60)
	_check(boss._estado == "nudo", "Con las 4 llaves cerradas se pasa al nudo")
	_check(boss.nudo.activo, "El nudo del tallo se puede romper")
	await _wait_frames(30)
	_check(boss.ojo.apertura > 0.3, "El ojo central se abre arriba")

	# --- Nudo: el Humano no lo rompe, el Oso sí ---
	var nudo_pos: Vector2 = boss.nudo.global_position + Vector2(0, -100)
	await _golpear(player, "heavy", nudo_pos, -1)
	_check(boss.nudo.golpes == 0, "El golpe fuerte del Humano no daña el nudo")
	player.energia = 100.0
	player._transformar(2, true)
	await _wait_frames(30)
	_check(player.current_form == 2, "El jugador es Oso")
	for _i in 8:
		if boss.nudo.esta_roto():
			break
		await _golpear(player, "heavy", nudo_pos, -1)
	_check(boss.nudo.esta_roto(), "El Oso rompe el nudo a golpes fuertes (%d golpes)" % boss.nudo.golpes)
	if not boss.nudo.esta_roto():
		boss.nudo.romper_forzado()

	# --- Castigo: se inclina, el ojo baja y recibe daño ---
	await _esperar_estado(boss, "castigo", 60)
	await _wait_frames(60)
	_check(absf(boss.cuerpo.position.y + boss.altura_ojo_castigo) < 2.0, "La Estrella se inclina: el ojo baja a %.0f px" % -boss.cuerpo.position.y)
	var hp1: int = boss.health
	await _golpear(player, "attack", boss.hurtbox.global_position, 1)
	_check(boss.health < hp1, "El Oso le pega al ojo en la ventana (%d -> %d)" % [hp1, boss.health])
	boss.hurtbox.take_damage(1000, 0.0, 1, false)
	_check(boss.health == 396, "El daño se frena en el umbral de la F2 (vida %d)" % boss.health)
	_check(boss._estado == "fin_castigo", "Al llegar al umbral la ventana se corta")

	# --- Cambio a la F2: orbe de vida, el piso central se rompe y abren las torretas ---
	await _esperar_estado(boss, "torretas", 900)
	_check(boss.fase == 1 and boss._estado == "torretas", "Pasa a la fase 2 con torretas (fase=%d, %s)" % [boss.fase, boss._estado])
	_check(_hay_orbe_vida(), "Al cambiar de fase aparece un orbe de vida")
	_check(boss.foso.activo and boss.losa.get_node("Collision").disabled, "El piso central se rompe y queda el foso")
	_check(not boss.nudo.visible, "El nudo desaparece con el piso")
	var torres: Array = boss._torretas_del_ciclo()
	_check(torres.size() == 4 and torres.all(func(o) -> bool: return o.abierto and o.torreta), "Se abren 4 torretas")
	_check(torres.filter(func(o) -> bool: return o.acorazado).size() == 1, "Una torreta está acorazada")
	_check(torres.any(func(o) -> bool: return o.position.x < -300.0) and torres.any(func(o) -> bool: return o.position.x > 300.0), "Hay torretas de los dos lados del foso")

	# Foso: cruzarlo a pie pincha (10) y devuelve al borde. (El Oso, de 470 px, casi no entra.)
	player._transformar(0, true)
	await _wait_frames(10)
	player._invuln_timer = 0.0   # la transformación da invulnerabilidad breve
	player.god_mode = false
	player.curar(100)
	var vida_f: int = player.health
	player.global_position = Vector2(boss.global_position.x - 120.0, piso_y - 300.0)
	player.velocity = Vector2.ZERO
	await _wait_frames(60)
	_check(player.health == vida_f - 10, "Caer al foso hace 10 de daño (%d -> %d)" % [vida_f, player.health])
	_check(absf(player.global_position.x - boss.global_position.x) > 300.0, "Caer al foso devuelve al jugador al borde")
	player.god_mode = true

	# Barrido de luz: sale del ojo hacia los dos lados.
	for _i in 300:
		if _barridos().size() >= 2:
			break
		await physics_frame
	var barr := _barridos()
	_check(barr.size() == 2 and barr[0].dir != barr[1].dir, "El barrido sale del ojo hacia los dos lados")

	# Torreta: dispara; el parry devuelve el disparo al ojo central (30).
	for _i in 300:
		if boss._disparos.any(func(d) -> bool: return is_instance_valid(d)):
			break
		await physics_frame
	var disparo = null
	for d in boss._disparos:
		if is_instance_valid(d):
			disparo = d
	_check(disparo != null, "Las torretas disparan")
	if disparo != null:
		var hp_r: int = boss.health
		disparo._reflejar()
		await _wait_frames(120)
		_check(boss.health == hp_r - 30, "El parry devuelve el disparo al ojo central: -30 (%d -> %d)" % [hp_r, boss.health])

	# Coraza: el Humano rebota; el golpe fuerte del Oso la cierra.
	var coraza = torres.filter(func(o) -> bool: return o.acorazado)[0]
	player._transformar(0, true)
	await _wait_frames(20)
	coraza.take_damage(18, 0.0, 1, false)
	_check(coraza.abierto, "La torreta acorazada no se cierra con el golpe del Humano")
	player.energia = 100.0
	player._transformar(2, true)
	await _wait_frames(30)
	for _i in 4:
		if not coraza.abierto:
			break
		await _golpear(player, "heavy", coraza.global_position, -1 if coraza.position.x > 0 else 1)
	_check(not coraza.abierto, "El golpe fuerte del Oso cierra la torreta acorazada")
	for o in torres:
		if o.abierto:
			o.take_damage(10, 0.0, 1, false)

	# Ventana aérea: el ojo sube fuera del alcance del salto y recibe daño.
	await _esperar_estado(boss, "ventana_aerea", 120)
	await _wait_frames(60)
	_check(absf(boss.cuerpo.position.y + boss.altura_ojo_aerea) < 2.0, "El ojo se eleva a %.0f px" % -boss.cuerpo.position.y)
	_check(boss.altura_ojo_aerea - 100.0 > 540.0, "La ventana aérea queda fuera del doble salto del Lobo (~540 px)")
	var hp_a: int = boss.health
	boss.hurtbox.take_damage(20, 0.0, 1, false)
	_check(boss.health == hp_a - 20, "En la ventana aérea el ojo recibe daño (%d -> %d)" % [hp_a, boss.health])

	# --- Reinicio (morir en la pelea): vuelve a vida llena y todo cerrado ---
	encounter.reiniciar()
	await _wait_frames(5)
	_check(boss.health == 600 and boss.fase == 0 and not boss._activo, "Al reiniciar la arena la Estrella vuelve a cero")
	_check(boss._ojos().all(func(o) -> bool: return not o.abierto), "Al reiniciar se cierran todos los ojos")
	await _wait_frames(2)
	_check(not boss.foso.activo and not boss.losa.get_node("Collision").disabled and boss.nudo.visible, "Al reiniciar el piso central vuelve")
	player._transformar(0, true)

	# --- Muerte ---
	boss.died.connect(func() -> void: _murio = true)
	encounter.empezar()
	await _esperar_estado(boss, "llaves", 400)
	boss.fase = 2
	boss.health = 50
	for o in boss._llaves_del_ciclo():
		o.take_damage(10, 0.0, 1, false)
	await _esperar_estado(boss, "nudo", 60)
	boss.nudo.activar()
	boss.nudo.romper_forzado()
	await _esperar_estado(boss, "castigo", 60)
	await _wait_frames(60)
	boss.hurtbox.take_damage(100, 0.0, 1, false)
	await _wait_frames(2)
	_check(_murio and boss.health == 0, "En la fase 3 el golpe final la mata y emite died")
	_fin()


## Pone al jugador junto al objetivo, a la altura del piso, mirando hacia él, y golpea.
func _golpear(player: Node, accion: String, objetivo: Vector2, lado: int) -> void:
	await _wait_frames(30)   # sale de la recuperación del golpe anterior
	player.velocity = Vector2.ZERO
	player.global_position = Vector2(objetivo.x + lado * 90.0, 1000.0 - 143.0)
	player.facing = -lado
	await physics_frame
	Input.action_press(accion)
	await physics_frame
	await physics_frame
	Input.action_release(accion)
	await _wait_frames(30)


func _barridos() -> Array:
	return get_nodes_in_group("ataque_jefe").filter(func(n) -> bool:
		return n.get_script() != null and n.get_script().resource_path == "res://scripts/ataque_jefe.gd")


func _hay_orbe_vida() -> bool:
	for n in current_scene_nodes():
		var s: Script = n.get_script()
		if s != null and s.resource_path == "res://scripts/pickup_vida.gd":
			return true
	return false


func current_scene_nodes() -> Array:
	var lista := []
	var pila: Array = [root]
	while not pila.is_empty():
		var n: Node = pila.pop_back()
		lista.append(n)
		pila.append_array(n.get_children())
	return lista


func _esperar_estado(boss: Node, estado: String, frames: int) -> void:
	for _i in frames:
		if boss._estado == estado:
			return
		await physics_frame


func _esperar_lanza(frames: int) -> void:
	for _i in frames:
		if get_first_node_in_group("ataque_jefe") != null:
			return
		await physics_frame


func _wait_frames(n: int) -> void:
	for _i in n:
		await physics_frame


func _quitar_dialogos_automaticos(nodo: Node) -> void:
	for hijo in nodo.get_children():
		_quitar_dialogos_automaticos(hijo)
	var script: Script = nodo.get_script()
	if script != null and script.resource_path == "res://scripts/dialog_trigger.gd":
		nodo.get_parent().remove_child(nodo)
		nodo.free()


func _check(cond: bool, msg: String) -> void:
	if cond:
		print("[PASS] " + msg)
	else:
		print("[FAIL] " + msg)
		_failures += 1


func _fin() -> void:
	print("DIAG JEFE ESTRELLA: FALLOS = " + str(_failures))
	quit(0 if _failures == 0 else 1)
