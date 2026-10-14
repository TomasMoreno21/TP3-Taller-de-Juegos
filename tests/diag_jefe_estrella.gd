extends SceneTree
## Diag del jefe final (Estrella): vida en el cuerpo (puntas, sin barra del HUD), ojos por tandas
## (franjas de altura por forma), rayo de un solo ojo + parry, F1 (llaves → nudo del Oso → castigo),
## F2 (foso, torretas con coraza, barrido, ventana aérea), tope de daño por fase, reinicio y muerte.
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
	var hud = scene.get_node("Hud")
	_check(boss != null and encounter != null and boss.has_method("golpe_ojo"), "La arena carga la Estrella y el encuentro")
	if boss == null or encounter == null:
		_fin()
		return
	boss.semilla = 1234
	boss._sembrar()
	var piso_y: float = boss.global_position.y

	# --- Estático: vida, cuerpo, puntos de aparición por franja ---
	_check(boss.health == 600, "Vida inicial 600: %d" % boss.health)
	_check(absf(piso_y - 1000.0) < 2.0, "El origen de la Estrella está en el piso (y=%.0f)" % piso_y)
	_check(boss._puntas.size() == 8, "La Estrella tiene 8 puntas")
	var franjas := [0, 0, 0, 0]
	for m in boss.puntos_raiz.get_children():
		franjas[boss._franja(m.position)] += 1
		_check(absf(m.position.x) < encounter.arena_medio_ancho - 60.0, "Punto %s dentro de la arena" % m.name)
	_check(franjas.all(func(c: int) -> bool: return c >= 2), "Hay puntos en las 4 franjas de altura %s" % str(franjas))
	_check(boss.ojos_raiz.get_child_count() == 0, "Antes de la pelea no hay ojos en pantalla")

	# --- Arranca: barra del HUD oculta, primera tanda de llaves ---
	player.global_position = Vector2(encounter.arena_center.x - 500.0, piso_y - 143.0)
	boss.intervalo_lanza = 1000.0   # aislar el rayo de la lanza en las mediciones de daño
	encounter.empezar()
	await _esperar_estado(boss, "llaves", 400)
	await _wait_frames(3)
	_check(not hud.boss_bar.visible, "La barra de vida del jefe no se muestra")
	var tanda: Array = boss._ojos()
	_check(tanda.size() >= 3 and tanda.size() <= 4, "La tanda tiene 3-4 ojos (%d)" % tanda.size())
	var fr := tanda.map(func(o) -> int: return boss._franja(o.position))
	_check(fr.has(0) and fr.has(1) and (fr.has(2) or fr.has(3)), "Llaves: una baja, una media y una alta %s" % str(fr))
	_check(tanda.all(func(o) -> bool: return o.abierto), "Los ojos de la tanda se abren")
	var blanco = tanda[0]
	blanco.golpe_proyectil = true
	blanco.take_damage(15, 120.0, 1, false)
	_check(blanco.abierto, "El sónico no cierra los ojos")
	_check(not blanco.is_in_group("cristal"), "El sónico no persigue a los ojos")
	var hp0: int = boss.health
	boss.golpe_ojo(50, 1, false)
	_check(boss.health == hp0, "Fuera de la ventana de castigo el ojo no recibe daño")

	# --- Rayo: un solo ojo a la vez, aviso, 10 de daño ---
	boss._lanza_t = 1000.0
	var rayo = await _esperar_rayo(400)
	_check(rayo != null, "Un ojo dispara un rayo")
	if rayo != null:
		_check(_rayos().size() == 1, "Nunca hay dos rayos a la vez")
		_check(is_instance_valid(rayo.fuente) and tanda.has(rayo.fuente) and rayo.fuente._aviso_t > 0.0, "El ojo que dispara avisa con la pupila")
		player.god_mode = false
		player._invuln_timer = 0.0
		var vida0: int = player.health
		await _wait_frames(70)
		_check(player.health == vida0 - 10, "El rayo hace 10 de daño (%d -> %d)" % [vida0, player.health])
		player.god_mode = true
		player.curar(100)
	# Parry del rayo (Humano, de frente) → -30 al ojo central y la primera punta se agrieta.
	var rayo2 = await _esperar_rayo(400)
	if rayo2 != null:
		var hp_r: int = boss.health
		player.god_mode = false
		player._invuln_timer = 0.0
		player.facing = 1 if rayo2.desde.x > player.global_position.x else -1
		player.blocking = true
		player._parry_t = 0.16
		rayo2._golpear(player)
		player.blocking = false
		player.god_mode = true
		_check(boss.health == hp_r - 30, "El parry devuelve el rayo al ojo central: -30 (%d -> %d)" % [hp_r, boss.health])
		var primera = boss._puntas[boss.orden_puntas[0]]
		_check(not primera.rota and absf(primera.dano - 0.4) < 0.01, "La primera punta se agrieta (dano %.2f)" % primera.dano)
	rayo2 = null

	# --- Llaves: la baja se cierra con el melee real y da energía; llegan 2 tandas ---
	tanda = boss._ojos()
	var baja = tanda[0]
	for o in tanda:
		if -o.position.y < -baja.position.y:
			baja = o
	player.energia = 0.0
	await _golpear(player, "attack", baja.global_position, 1)
	_check(not is_instance_valid(baja) or not baja.abierto, "La llave baja se cierra con el golpe del Humano")
	_check(player.energia >= 12.0, "Cerrar un ojo con el golpe da energía (%.1f)" % player.energia)
	await _cerrar_tanda(boss)
	await _wait_frames(5)
	_check(boss._estado == "llaves" and boss._ojos().size() >= 3, "Al cerrar la tanda aparece la siguiente")
	await _cerrar_tanda(boss)
	await _esperar_estado(boss, "nudo", 60)
	_check(boss._estado == "nudo", "Con las 2 tandas cerradas se pasa al nudo")
	await _wait_frames(30)
	_check(boss.ojos_raiz.get_child_count() == 0, "Los ojos cerrados se desvanecen")

	# --- Nudo: el Humano no lo rompe, el Oso sí ---
	var nudo_pos: Vector2 = boss.nudo.global_position + Vector2(0, -100)
	await _golpear(player, "heavy", nudo_pos, -1)
	_check(boss.nudo.golpes == 0, "El golpe fuerte del Humano no daña el nudo")
	player.energia = 100.0
	player._transformar(2, true)
	await _wait_frames(30)
	for _i in 8:
		if boss.nudo.esta_roto():
			break
		await _golpear(player, "heavy", nudo_pos, -1)
	_check(boss.nudo.esta_roto(), "El Oso rompe el nudo a golpes fuertes (%d golpes)" % boss.nudo.golpes)
	if not boss.nudo.esta_roto():
		boss.nudo.romper_forzado()

	# --- Castigo: se inclina, el ojo baja y recibe daño; tope de fase y puntas rotas ---
	await _esperar_estado(boss, "castigo", 60)
	await _wait_frames(60)
	_check(absf(boss.cuerpo.position.y + boss.altura_ojo_castigo) < 2.0, "La Estrella se inclina: el ojo baja a %.0f px" % -boss.cuerpo.position.y)
	var hp1: int = boss.health
	await _golpear(player, "attack", boss.hurtbox.global_position, 1)
	_check(boss.health < hp1, "El Oso le pega al ojo en la ventana (%d -> %d)" % [hp1, boss.health])
	boss.hurtbox.take_damage(1000, 0.0, 1, false)
	_check(boss.health == 396, "El daño se frena en el umbral de la F2 (vida %d)" % boss.health)
	_check(boss._puntas_rotas == 2 and boss._puntas_sanas().size() == 6, "Con 204 de daño caen 2 puntas (rotas %d)" % boss._puntas_rotas)

	# --- F2: orbe, piso roto, tandas de torretas ---
	await _esperar_estado(boss, "torretas", 900)
	await _wait_frames(3)
	_check(boss.fase == 1 and boss._estado == "torretas", "Pasa a la fase 2 con torretas (fase=%d)" % boss.fase)
	_check(_hay_orbe_vida(), "Al cambiar de fase aparece un orbe de vida")
	_check(boss.foso.activo and boss.losa.get_node("Collision").disabled, "El piso central se rompe y queda el foso")
	var cam = scene.get_node("Camara")
	_check(absf(cam._escala_arena - boss.escala_arena_f2) < 0.01, "La cámara se aleja en la F2 (escala %.2f)" % cam._escala_arena)
	_check(cam._fija_pos.distance_to(boss.global_position + boss.centro_camara_f2) < 1.0, "La cámara sube al centro de la sala grande")
	_check(absf(boss.techo.position.y - (boss._techo_y0 - boss.subida_techo)) < 1.0, "El techo sube %.0f px" % boss.subida_techo)
	_check(absf(boss.cuerpo.scale.x - boss.escala_jefe_f2) < 0.01, "La Estrella crece (escala %.2f)" % boss.cuerpo.scale.x)
	var plats: Array = boss.plataformas_raiz.get_children()
	_check(plats.size() == 4 and plats.all(func(pl) -> bool: return pl.visible and not pl.get_node("Collision").disabled and pl.get_node("Collision").one_way_collision), "Aparecen 4 plataformas que se atraviesan desde abajo")
	var mitad_vista: float = 960.0 / (0.93 * boss.escala_arena_f2)
	for m in boss.puntos_f2.get_children():
		_check(absf(m.position.x) < mitad_vista - 60.0 and -m.position.y < boss.subida_techo + 940.0 - 60.0, "Punto F2 %s dentro de la sala grande" % m.name)
	var plat_max := 0.0
	for pl in plats:
		plat_max = maxf(plat_max, -pl.position.y)
	var alcance_lobo := plat_max + 354.0 + 185.0
	_check(boss.altura_ojo_aerea - 100.0 * boss.escala_jefe_f2 > alcance_lobo, "La ventana aérea queda fuera del Lobo desde la plataforma más alta (%.0f > %.0f)" % [boss.altura_ojo_aerea - 100.0 * boss.escala_jefe_f2, alcance_lobo])
	var torres: Array = boss._ojos()
	_check(torres.size() >= 3 and torres.size() <= 4, "Tanda de 3-4 torretas (%d)" % torres.size())
	var corazas := torres.filter(func(o) -> bool: return o.acorazado)
	_check(corazas.size() == 1 and boss._franja(corazas[0].position) == 0, "Una torreta baja acorazada")
	_check(torres.any(func(o) -> bool: return o.position.x < -300.0) and torres.any(func(o) -> bool: return o.position.x > 300.0), "Torretas a los dos lados del foso")

	# Foso: caer pincha (10) y devuelve al borde.
	player._transformar(0, true)
	await _wait_frames(10)
	player._invuln_timer = 0.0
	player.god_mode = false
	player.curar(100)
	var vida_f: int = player.health
	player.global_position = Vector2(boss.global_position.x - 120.0, piso_y - 300.0)
	player.velocity = Vector2.ZERO
	await _wait_frames(40)
	_check(player.health <= vida_f - 10, "Caer al foso hace daño (%d -> %d)" % [vida_f, player.health])
	_check(absf(player.global_position.x - boss.global_position.x) > 300.0, "Caer al foso devuelve al jugador al borde")
	player.god_mode = true

	# Barrido de luz desde el ojo hacia los dos lados.
	for _i in 300:
		if _barridos().size() >= 2:
			break
		await physics_frame
	var barr := _barridos()
	_check(barr.size() == 2 and barr[0].dir != barr[1].dir, "El barrido sale del ojo hacia los dos lados")

	# Coraza: el Humano rebota; el golpe fuerte del Oso la cierra.
	var coraza = corazas[0]
	if is_instance_valid(coraza):
		coraza.take_damage(18, 0.0, 1, false)
		_check(coraza.abierto, "La torreta acorazada no se cierra con el golpe del Humano")
		player.energia = 100.0
		player._transformar(2, true)
		await _wait_frames(30)
		for _i in 4:
			if not is_instance_valid(coraza) or not coraza.abierto:
				break
			await _golpear(player, "heavy", coraza.global_position, -1 if coraza.position.x > 0 else 1)
		_check(not is_instance_valid(coraza) or not coraza.abierto, "El golpe fuerte del Oso cierra la torreta acorazada")
	await _cerrar_tanda(boss)
	await _wait_frames(5)
	await _cerrar_tanda(boss)

	# Ventana aérea.
	await _esperar_estado(boss, "ventana_aerea", 120)
	await _wait_frames(60)
	_check(absf(boss.cuerpo.position.y + boss.altura_ojo_aerea) < 2.0, "El ojo se eleva a %.0f px" % -boss.cuerpo.position.y)
	var hp_a: int = boss.health
	boss.hurtbox.take_damage(20, 0.0, 1, false)
	_check(boss.health == hp_a - 20, "En la ventana aérea el ojo recibe daño (%d -> %d)" % [hp_a, boss.health])

	# --- Reinicio: vida, puntas, ojos y piso vuelven ---
	encounter.reiniciar()
	await _wait_frames(5)
	_check(boss.health == 600 and boss.fase == 0 and not boss._activo, "Al reiniciar la arena la Estrella vuelve a cero")
	_check(boss._puntas_rotas == 0 and boss._puntas.all(func(pt) -> bool: return pt.visible and not pt.rota and pt.dano == 0.0), "Al reiniciar vuelven las 8 puntas")
	_check(boss._ojos().is_empty(), "Al reiniciar no quedan ojos")
	_check(not boss.foso.activo and not boss.losa.get_node("Collision").disabled and boss.nudo.visible, "Al reiniciar el piso central vuelve")
	_check(absf(boss.techo.position.y - boss._techo_y0) < 1.0 and absf(boss.cuerpo.scale.x - 1.0) < 0.01 and boss.plataformas_raiz.get_children().all(func(pl) -> bool: return not pl.visible), "Al reiniciar la sala vuelve a la F1")
	_check(absf(scene.get_node("Camara")._escala_arena - 1.0) < 0.01, "Al reiniciar la cámara vuelve al zoom normal")
	player._transformar(0, true)

	# --- Muerte: la última punta cae y emite died ---
	boss.died.connect(func() -> void: _murio = true)
	encounter.empezar()
	await _esperar_estado(boss, "llaves", 400)
	boss.fase = 2
	boss.health = 50
	await _cerrar_tanda(boss)
	await _wait_frames(5)
	await _cerrar_tanda(boss)
	await _esperar_estado(boss, "nudo", 60)
	boss.nudo.activar()
	boss.nudo.romper_forzado()
	await _esperar_estado(boss, "castigo", 60)
	await _wait_frames(60)
	boss.hurtbox.take_damage(100, 0.0, 1, false)
	await _wait_frames(2)
	_check(_murio and boss.health == 0, "En la fase 3 el golpe final la mata y emite died")
	_check(boss._puntas.all(func(pt) -> bool: return pt.rota), "Al morir caen todas las puntas")
	_fin()


## Cierra todos los ojos abiertos de la tanda actual (la coraza se saltea en el test).
func _cerrar_tanda(boss: Node) -> void:
	for _i in 60:
		var abiertos: Array = boss._ojos().filter(func(o) -> bool: return o.abierto)
		if not abiertos.is_empty() or boss._llaves_vivas == 0:
			break
		await physics_frame
	for o in boss._ojos():
		if o.abierto:
			o.acorazado = false
			o.take_damage(10, 0.0, 1, false)
	await _wait_frames(3)


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


func _rayos() -> Array:
	return get_nodes_in_group("ataque_jefe").filter(func(n) -> bool: return n.get("rayo") == true and not n.is_queued_for_deletion())


func _esperar_rayo(frames: int) -> Variant:
	for _i in frames:
		var r := _rayos()
		if not r.is_empty():
			return r[0]
		await physics_frame
	return null


func _barridos() -> Array:
	return get_nodes_in_group("ataque_jefe").filter(func(n) -> bool:
		return n.get_script() != null and n.get_script().resource_path == "res://scripts/ataque_jefe.gd")


func _hay_orbe_vida() -> bool:
	var pila: Array = [root]
	while not pila.is_empty():
		var n: Node = pila.pop_back()
		var s: Script = n.get_script()
		if s != null and s.resource_path == "res://scripts/pickup_vida.gd":
			return true
		pila.append_array(n.get_children())
	return false


func _esperar_estado(boss: Node, estado: String, frames: int) -> void:
	for _i in frames:
		if boss._estado == estado:
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
