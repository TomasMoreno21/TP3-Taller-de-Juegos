extends SceneTree
## Diag del jefe final (Estrella): vida en el cuerpo (puntas, sin barra del HUD), ojos por tandas
## (franjas de altura por forma), rayo de un solo ojo + parry, F1 (llaves → nudo del Oso → castigo),
## F2 (foso, torretas con coraza, rayo grueso, ventana aérea), tope de daño por fase, reinicio y muerte.
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
	_check(boss._puntas.size() == 7, "La Estrella tiene 7 puntas (las del dibujo de Micaela)")
	var cab = boss.cabeza
	_check(cab != null and not cab.visible, "El sprite de la cabeza queda oculto (es la fuente de frames)")
	_check(boss.estrella.visible, "El dibujo de la cabeza (piezas de la Estrella) se ve")
	_check(boss.ojo.position.length() < 2.0 and boss.get_node("Cuerpo/Hurtbox/Collision").position.length() < 2.0, "El ojo y su hurtbox quedan centrados en el núcleo del dibujo")
	if cab != null:
		cab.frame = 2
		var tex2 = cab.sprite_frames.get_frame_texture(cab.animation, 2)
		_check(boss.nucleo.texture == tex2 and boss._puntas.all(func(pt) -> bool: return pt.texture == tex2), "Las piezas usan el frame actual del dibujo")
	_check(boss._puntas.all(func(pt) -> bool: return pt.vertice_local != Vector2.ZERO), "Cada punta tiene su vértice del dibujo")
	_check(not boss.cuerpo.visible, "Antes de la pelea la Estrella está escondida bajo el piso")
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
	_check(boss.cuerpo.visible and absf(boss.cuerpo.position.y + boss._altura_reposo) < 2.0 and not player.cinematica_activa, "La aparición termina: la Estrella arriba y el jugador con control")
	_check(absf(player.mult_energia_externo - boss.drenaje_energia_jefe) < 0.001, "En la pelea la energía gasta %.2f (el amuleto arde)" % player.mult_energia_externo)
	var amb = get_first_node_in_group("ambiente_sonoro")
	_check(amb != null and amb.solo_capas, "En la pelea el ambiente queda sin acentos de suspenso")
	var tanda: Array = boss._ojos()
	_check(tanda.size() >= 3 and tanda.size() <= 4, "La tanda tiene 3-4 ojos (%d)" % tanda.size())
	var fr := tanda.map(func(o) -> int: return boss._franja(o.position))
	_check(fr.has(0) and fr.has(1) and (fr.has(2) or fr.has(3)), "Llaves: una baja, una media y una alta %s" % str(fr))
	_check(tanda.all(func(o) -> bool: return o.abierto), "Los ojos de la tanda se abren")
	var blanco = null
	for o in tanda:
		if boss._franja(o.position) < 2:
			blanco = o
	if blanco != null:
		blanco.golpe_proyectil = true
		blanco.take_damage(15, 120.0, 1, false)
		_check(blanco.abierto, "El sónico no cierra un ojo bajo/medio")
		_check(not blanco.is_in_group("cristal"), "El sónico no persigue a los ojos bajos")
	var alto = null
	for o in tanda:
		if boss._franja(o.position) >= 2:
			alto = o
	if alto != null:
		_check(alto.is_in_group("cristal"), "El sónico persigue a los ojos altos")
		alto.golpe_proyectil = true
		alto.take_damage(15, 120.0, 1, false)
		_check(not is_instance_valid(alto) or not alto.abierto, "El sónico cierra un ojo alto")
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
	# Parry del rayo (Humano, de frente) → -30 al ojo central; la cabeza no se agrieta, el ojo sí.
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
		_check(primera.dano > 0.3 and boss._puntas.all(func(pt) -> bool: return not pt.rota and pt.visible) and boss.ojo.herida > 0.04, "Grietas finas: la primera punta se agrieta sin partirse (dano %.2f, herida %.2f)" % [primera.dano, boss.ojo.herida])
	rayo2 = null

	# --- Sónico del Murciélago: le pega siempre (BlancoSonico); el cuerpo a cuerpo no cuenta ahí ---
	var bs = boss.blanco_sonico
	var hp_s: int = boss.health
	bs.golpe_proyectil = true
	bs.take_damage(15, 120.0, 1)
	_check(boss.health == hp_s - 15, "El sónico le pega fuera de las ventanas (%d -> %d)" % [hp_s, boss.health])
	bs.take_damage(15, 0.0, 1, false)
	_check(boss.health == hp_s - 15 and bs.ignora_melee, "El cuerpo a cuerpo no cuenta en el blanco del sónico")
	_check(bs.apuntable() and bs.is_in_group("blanco_sonico") and not boss.is_in_group("enemy"), "El teledirigido puede apuntarle (sin entrar al grupo enemy)")
	_check(boss.sonido_aparicion != null and boss.sonido_rebote != null, "Hay grito de aparición y sonido de rebote")

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
	_check(boss.marca_nudo.encendida and boss.marca_nudo.visible, "Nudo activo: late la marca de garra del Oso")
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
	var p0 = boss._puntas[boss.orden_puntas[0]]
	var p1 = boss._puntas[boss.orden_puntas[1]]
	var p2 = boss._puntas[boss.orden_puntas[2]]
	_check(p0.dano == 1.0 and p1.dano == 1.0 and p2.dano > 0.3 and p2.dano < 0.45 and boss._puntas.all(func(pt) -> bool: return pt.visible and not pt.rota) and absf(boss.ojo.herida - 204.0 / 600.0) < 0.01, "Con 204 de daño se agrietan 2⅓ puntas sin partirse y el ojo tiene venas")
	_check(not boss.marca_nudo.encendida, "Roto el nudo, la marca se apaga")

	# --- Interludio de la F2: la Estrella se hunde, 2 oleadas y lanzas del pozo (desde la 2) ---
	await _esperar_estado(boss, "interludio", 900)
	_check(boss._estado == "interludio" and not boss.cuerpo.visible, "Al entrar a la F2 la Estrella se hunde y desaparece")
	var hp_i: int = boss.health
	boss.blanco_sonico.golpe_proyectil = true
	boss.blanco_sonico.take_damage(15, 120.0, 1)
	_check(boss.health == hp_i and not boss.blanco_sonico.apuntable(), "Escondida (interludio) el sónico no le pega")
	hp_i = boss.health
	boss.golpe_ojo(50, 1, false)
	_check(boss.health == hp_i, "Escondida no recibe daño")
	await _wait_frames(60)
	var ola1 := _vivos(boss)
	_check(ola1.size() == 3 and ola1.all(func(e) -> bool: return e.tipo == "cultista"), "Oleada 1: 3 cultistas (%d)" % ola1.size())
	_check(ola1.all(func(e) -> bool: return absf(e.global_position.x - boss.global_position.x) > 400.0), "Los enemigos entran lejos del foso")
	_check(ola1.any(func(e) -> bool: return e.global_position.x < boss.global_position.x) and ola1.any(func(e) -> bool: return e.global_position.x > boss.global_position.x), "Los enemigos entran por los dos costados")
	_check(boss.bordes_foso.collision_layer == 4 and boss.bordes_foso.get_children().all(func(c) -> bool: return not c.disabled), "Topes del pozo activos (solo enemigos, capa 3)")
	var hubo_ataque := false
	for _i in 300:
		if not get_nodes_in_group("ataque_jefe").is_empty():
			hubo_ataque = true
			break
		await physics_frame
	_check(not hubo_ataque, "Respiro: en la oleada 1 no hay luces ni lanzas")
	var caido = ola1[0]
	caido.global_position = boss.global_position + Vector2(0, 20)
	await _wait_frames(10)
	_check(caido.health <= 0, "Un enemigo que cae al foso muere")
	for e in _vivos(boss):
		e.take_damage(9999, 0.0, 1, false)
	for _i in 400:
		if _vivos(boss).size() == 4:
			break
		await physics_frame
	await _wait_frames(60)
	var ola2 := _vivos(boss)
	_check(ola2.size() == 4 and ola2.filter(func(e) -> bool: return e.tipo == "arquero").size() == 2, "Oleada 2: 2 cultistas + 2 arqueros (%d)" % ola2.size())
	var hubo_ataque2 := false
	for _i in 300:
		if not get_nodes_in_group("ataque_jefe").is_empty():
			hubo_ataque2 = true
			break
		await physics_frame
	_check(not hubo_ataque2, "Escondida no ataca: la oleada 2 tampoco tiene lanzas")
	for e in ola2:
		e.take_damage(9999, 0.0, 1, false)

	# --- F2: resurge agrandada, orbe, piso roto, tandas de torretas ---
	await _esperar_estado(boss, "torretas", 900)
	_check(boss.cuerpo.visible and absf(boss.cuerpo.position.y + boss.altura_ojo_f2) < 2.0, "La Estrella resurge a %.0f px" % -boss.cuerpo.position.y)
	await _wait_frames(3)
	_check(boss.fase == 1 and boss._estado == "torretas", "Pasa a la fase 2 con torretas (fase=%d)" % boss.fase)
	var zona_l = get_first_node_in_group("latido_jefe")
	_check(zona_l != null and zona_l.color_ambiente == boss.latido_color_fase[1] and absf(zona_l.frecuencia - boss.latido_frec_fase[1]) < 0.001, "El latido de la sala cambia con la F2")
	var luc = get_first_node_in_group("luciernagas_ambiente")
	_check(luc != null and luc.color == boss.luciernagas_color_fase[1], "Las luciérnagas toman el color de la F2")
	_check(_hay_orbe_vida(), "Al cambiar de fase aparece un orbe de vida")
	_check(boss.foso.activo and boss.losa.get_node("Collision").disabled, "El piso central se rompe y queda el foso")
	var d2 := get_nodes_in_group("destruible_f2")
	_check(d2.size() == 5 and d2.all(func(n) -> bool: return not n.visible), "En la F2 se rompen braseros, velas, huesos y la estatua (%d)" % d2.size())
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
	var techo_alto: float = 940.0 + boss.subida_techo
	_check(boss.altura_ojo_aerea + 310.0 * boss.escala_jefe_f2 < techo_alto - 20.0, "En la ventana aérea la Estrella entra completa bajo el techo (%.0f < %.0f)" % [boss.altura_ojo_aerea + 310.0 * boss.escala_jefe_f2, techo_alto])
	var tope_vista: float = -(boss.centro_camara_f2.y - 540.0 / (0.93 * boss.escala_arena_f2))
	_check(tope_vista > techo_alto, "La cámara muestra el techo de la sala grande (%.0f > %.0f)" % [tope_vista, techo_alto])
	var alturas_plat: Array = plats.map(func(pl) -> float: return -pl.position.y)
	alturas_plat.sort()
	_check(alturas_plat[0] <= 170.0 and alturas_plat[-1] - alturas_plat[0] <= 170.0, "El Humano llega a las plataformas (%s)" % str(alturas_plat))
	# Abajo + salto: se baja de la plataforma (solo las del jefe están en el grupo).
	var pl1: Node2D = plats[0]
	player.global_position = pl1.global_position + Vector2(0, -150)
	player.velocity = Vector2.ZERO
	await _wait_frames(20)
	var sobre: bool = player.is_on_floor() and player.global_position.y < pl1.global_position.y
	var bajo: bool = sobre and player._bajar_plataforma()
	await _wait_frames(25)
	_check(pl1.is_in_group("plataforma_bajable") and bajo and player.global_position.y - 143.0 > pl1.global_position.y, "Abajo + salto atraviesa la plataforma hacia abajo (y %.0f vs %.0f)" % [player.global_position.y, pl1.global_position.y])
	_check(boss.altura_ojo_aerea - 100.0 * boss.escala_jefe_f2 > alcance_lobo, "La ventana aérea queda fuera del Lobo desde la plataforma más alta (%.0f > %.0f)" % [boss.altura_ojo_aerea - 100.0 * boss.escala_jefe_f2, alcance_lobo])
	var torres: Array = boss._ojos()
	_check(torres.size() == 3, "Primer ciclo de la F2: tanda de 3 torretas (%d)" % torres.size())
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

	# Transformarse no da invulnerabilidad (con 1-4 se encadenaba).
	player._invuln_timer = 0.0
	player.energia = 100.0
	player._transformar(1, true)
	_check(player._invuln_timer <= 0.0, "Transformarse no da invulnerabilidad (%.2f)" % player._invuln_timer)
	player._transformar(0, true)
	await _wait_frames(10)

	# Rayo grueso del ojo: el ciclo 1 no lo tiene; abre el ojo, avisa con franja ancha y pega 35.
	boss._rayo_t = 1000.0   # aislar de los rayos chicos
	await _wait_frames(240)
	_check(_rayos_gruesos().is_empty(), "En el primer ciclo de la F2 no hay rayo grueso")
	_check(boss._rampa(boss.rampa_tandas, 0) == 1.0 and boss._rampa(boss.rampa_rayo, 0) == 3.0, "Rampa del ciclo 1: 1 tanda, rayo cada 3 s")
	player.global_position = Vector2(boss.global_position.x - 900.0, piso_y - 143.0)
	player.velocity = Vector2.ZERO
	player.god_mode = false
	player._invuln_timer = 0.0
	player.curar(100)
	var vida_g: int = player.health
	boss._rayo_grueso()
	await _wait_frames(30)
	var gruesos := _rayos_gruesos()
	_check(boss.ojo.apertura > 0.5, "El ojo se abre para el rayo grueso")
	_check(gruesos.size() == 1 and gruesos[0].dano == 25 and absf(gruesos[0].ancho - 70.0) < 0.1 and gruesos[0].aviso >= 1.3, "Rayo grueso: 70 de ancho, aviso 1.3 s, 25 de daño")
	_check(_rayos().size() == 1, "Durante el rayo grueso no sale ningún rayo chico")
	await _wait_frames(90)
	_check(player.health == vida_g - 25, "El rayo grueso pega 25 (%d -> %d)" % [vida_g, player.health])
	# Golpe que toca al jugador invulnerable: no se gasta y pega cuando vuelve el daño (dentro de su ventana).
	await _wait_frames(60)
	player.curar(100)
	player._invuln_timer = 0.0
	var vida_i: int = player.health
	boss._grueso_activo = false
	boss._rayo_grueso()
	player._invuln_timer = 1.72   # invulnerable al empezar el golpe (0.3 + 1.3 s), vulnerable a mitad
	await _wait_frames(130)
	_check(player.health == vida_i - 25, "Un golpe que toca invulnerable no se pierde (%d -> %d)" % [vida_i, player.health])
	player.god_mode = true
	player.curar(100)
	boss._rayo_t = 2.0

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
	_check(hud.dial._sug_idx == 3 or player.current_form == 3, "El HUD sugiere el Murciélago en la ventana aérea")
	while boss._estado == "ventana_aerea" and boss._ventana_t > boss.aviso_cierre:
		await physics_frame
	await _wait_frames(6)
	_check(boss._estado != "ventana_aerea" or boss.ojo.apertura < 1.0 or absf(boss.cuerpo.position.x) > 0.0, "En el último segundo el ojo parpadea / la Estrella tiembla")
	_check(boss._tips_dados.has("ojos") and boss._tips_dados.has("coraza") and boss._tips_dados.has("ventana"), "Los 3 tips del Amuleto salen una vez")
	# --- Paso a la F3: se rompe todo, caen las plataformas y el pozo se cierra ---
	boss.hurtbox.take_damage(1000, 0.0, 1, false)
	await _esperar_estado(boss, "transicion", 300)
	await _esperar_estado(boss, "torretas", 600)
	await _wait_frames(3)
	_check(boss.fase == 2, "Pasa a la fase 3 (fase=%d)" % boss.fase)
	_check(boss.absorber_traidor and boss.traidor_frames != null and boss._traidor == null, "Al entrar a la F3 absorbe al traidor (el cultista arrepentido del N3)")
	_check(boss.plataformas_raiz.get_children().all(func(pl) -> bool: return not pl.visible and pl.get_node("Collision").disabled), "En la F3 se caen las plataformas")
	_check(not boss.foso.activo and not boss.losa.get_node("Collision").disabled and boss.losa.visible, "En la F3 el pozo se cierra")
	var d3 := get_nodes_in_group("destruible_f3")
	_check(d3.size() >= 2 and d3.all(func(n) -> bool: return not n.visible), "En la F3 se rompe lo que queda (%d)" % d3.size())

	# --- F3: duelo directo (sin ojos) ---
	await _wait_frames(360)
	_check(boss.ojos_raiz.get_child_count() == 0, "En la F3 no aparecen ojos")
	_check(boss._sin_tallo and not boss.tallo.visible, "En la F3 se arrancó del tallo")
	var clavo := false
	for _i in 1500:
		if boss._estado in ["clavada", "caparazon", "escudo"]:
			clavo = true
			break
		await physics_frame
	_check(clavo, "El combo de la F3 termina con la Estrella clavada en el piso")
	boss._gen += 1   # corta el ciclo para probar cada ataque por separado
	var g: int = boss._gen
	boss._limpiar_lanzas()
	await _wait_frames(2)
	await boss._picada(g)
	_check(_barridos().size() >= 2, "La picada suelta ondas a los dos lados (%d)" % _barridos().size())
	boss._limpiar_lanzas()
	player._transformar(0, true)
	await _wait_frames(5)
	player.global_position = Vector2(boss.global_position.x, piso_y - 143.0)
	player.velocity = Vector2.ZERO
	player.god_mode = false
	player._invuln_timer = 0.0
	player.curar(100)
	var vida_e: int = player.health
	boss.prob_diagonal = 0.0
	await boss._embestida(g, false)
	_check(player.health == vida_e - 18, "La embestida le pega 18 al Humano parado (%d -> %d)" % [vida_e, player.health])
	await _wait_frames(10)
	_check(player.health == vida_e - 18, "Tras el golpe del cuerpo, el rayo del blaster no suma (%d)" % player.health)
	await _wait_frames(int(boss.duracion_rayo_blaster * 60.0) + 5)
	_check(boss._blaster == null, "El rayo de la embestida se apaga")
	player.curar(100)
	player._invuln_timer = 0.0
	var vida_b: int = player.health
	var ini_b: Vector2 = player.global_position + Vector2(-500, 0)
	boss._blaster_iniciar(ini_b, ini_b + Vector2(1000, 0))
	await _wait_frames(3)
	_check(player.health == vida_b - boss.dano_rayo_blaster, "El rayo del blaster daña %d a quien queda en la franja (%d -> %d)" % [boss.dano_rayo_blaster, vida_b, player.health])
	await _wait_frames(int(boss.duracion_rayo_blaster * 60.0) + 5)
	player.curar(100)
	player._invuln_timer = 0.0
	boss._orbes(g)
	await _wait_frames(int(boss.orbes_aviso * 60.0) + 10)
	_check(boss._orbes_nodos.size() == boss.orbes_cantidad and boss._orbes_nodos.all(func(o) -> bool: return o.texture == null), "Rocas en órbita: arranca %d rocas de la cueva (no usa el arte)" % boss._orbes_nodos.size())
	var vida_o: int = player.health
	for _i in 20:
		if boss._orbes_nodos.is_empty() or player.health < vida_o:
			break
		player.global_position = boss._orbes_nodos[0].global_position
		player.velocity = Vector2.ZERO
		await physics_frame
	_check(player.health == vida_o - 12, "Un orbe daña 12 (%d -> %d)" % [vida_o, player.health])
	await _wait_frames(int(boss.orbes_duracion * 60.0) + 10)
	player.curar(100)
	player._invuln_timer = 0.0
	boss._limpiar_lanzas()
	player.global_position = Vector2(boss.global_position.x + 400.0, piso_y - 143.0)
	player.velocity = Vector2.ZERO
	var vida_c: int = player.health
	boss._lluvia_estalactitas(g)
	await _wait_frames(3)
	_check(boss._estalactitas.size() == 3 and boss._estalactitas.all(func(c) -> bool: return c.texture == null), "Estalactitas: 3 tiemblan en el techo")
	await _wait_frames(int((boss.aviso_estalactitas + boss.caida_estalactita) * 60.0) + 20)
	_check(player.health == vida_c - 15, "Una estalactita pega 15 (%d -> %d)" % [vida_c, player.health])
	player.god_mode = true
	player.curar(100)
	await _wait_frames(40)
	# Clavada: la picada final la clava; a veces con el ojo cerrado (solo el Oso lo abre) → ojo a tiro con tope.
	boss.prob_escudo_nino = 0.0
	boss.prob_caparazon = 1.0
	player._transformar(0, true)
	await _wait_frames(5)
	await boss._picada(g, true)
	_check(absf(boss.cuerpo.position.y + boss.altura_agotada) < 2.0, "La picada final la deja clavada con el ojo a %.0f px" % -boss.cuerpo.position.y)
	boss._clavada(g)
	await _wait_frames(5)
	_check(boss._estado == "caparazon" and boss.ojo.apertura < 0.05 and not boss.hurtbox.get_node("Collision").disabled, "Clavada con el ojo cerrado (caparazón)")
	_check(boss.marca_ojo.encendida, "El ojo cerrado muestra la marca de garra del Oso")
	boss.hurtbox.take_damage(30, 0.0, 1, false)
	_check(boss._golpes_cap == 0, "El Humano no abre el ojo cerrado")
	player.energia = 100.0
	player._transformar(2, true)
	await _wait_frames(5)
	for _i in 3:
		boss.hurtbox.take_damage(30, 0.0, 1, false)
	await _wait_frames(15)
	_check(boss._estado == "clavada" and boss.ojo.apertura > 0.95 and not boss.hurtbox.get_node("Collision").disabled and absf(boss.cuerpo.position.y + boss.altura_agotada) < 2.0, "El Oso fuerza el ojo y queda abierto a tiro")
	_check(not boss.marca_ojo.encendida, "Abierto el ojo, la marca se apaga")
	var hp_d: int = boss.health
	boss.hurtbox.take_damage(30, 0.0, 1, false)
	boss.hurtbox.take_damage(30, 0.0, 1, false)
	_check(boss._tips_dados.has("clavada"), "Sale el tip de la clavada")
	_check(boss.health == hp_d - boss.tope_dano_ventana and boss._estado != "clavada", "Tope de %d por ventana (%d -> %d)" % [boss.tope_dano_ventana, hp_d, boss.health])
	# El niño de escudo: el padre no ataca hasta que lo suelta.
	boss._escudo_nino(boss._gen)
	await _wait_frames(3)
	_check(player.ataque_contenido and boss.ojo.nino_escudo > 0.9, "Niño de escudo: el padre no puede atacar")
	await _wait_frames(int(boss.duracion_escudo * 60.0) + 10)
	_check(not player.ataque_contenido, "Al soltar al niño, el padre vuelve a atacar")

	# --- Reinicio: vida, puntas, ojos y piso vuelven ---
	encounter.reiniciar()
	await _wait_frames(5)
	_check(boss.health == 600 and boss.fase == 0 and not boss._activo, "Al reiniciar la arena la Estrella vuelve a cero")
	_check(boss.ojo.herida == 0.0 and boss._puntas.all(func(pt) -> bool: return pt.visible and not pt.rota and pt.dano == 0.0), "Al reiniciar el ojo sana y la cabeza sigue entera")
	_check(boss._ojos().is_empty(), "Al reiniciar no quedan ojos")
	_check(boss._invocados.is_empty() and boss.cuerpo.visible, "Al reiniciar no quedan enemigos invocados y la Estrella se ve (sin repetir la aparición)")
	_check(absf(boss.cuerpo.position.x) < 0.1 and boss._orbes_nodos.is_empty(), "Al reiniciar vuelve el cuerpo al centro")
	_check(get_nodes_in_group("destruible_f2").all(func(n) -> bool: return n.visible) and get_nodes_in_group("destruible_f3").all(func(n) -> bool: return n.visible), "Al reiniciar vuelve la decoración destruida")
	_check(absf(player.mult_energia_externo - 1.0) < 0.001, "Al reiniciar la energía vuelve a gastar normal")
	_check(not get_first_node_in_group("ambiente_sonoro").solo_capas, "Al reiniciar vuelven los acentos del ambiente")
	_check(get_first_node_in_group("latido_jefe").color_ambiente == boss.latido_color_fase[0] and get_first_node_in_group("luciernagas_ambiente").color == boss.luciernagas_color_fase[0], "Al reiniciar el ambiente vuelve a la F1")
	_check(not boss.foso.activo and not boss.losa.get_node("Collision").disabled and not boss.nudo.esta_roto(), "Al reiniciar el piso central vuelve")
	_check(boss.bordes_foso.get_children().all(func(c) -> bool: return c.disabled), "Al reiniciar los topes del pozo se apagan")
	_check(absf(boss.techo.position.y - boss._techo_y0) < 1.0 and absf(boss.cuerpo.scale.x - 1.0) < 0.01 and boss.plataformas_raiz.get_children().all(func(pl) -> bool: return not pl.visible), "Al reiniciar la sala vuelve a la F1")
	_check(absf(scene.get_node("Camara")._escala_arena - 1.0) < 0.01, "Al reiniciar la cámara vuelve al zoom normal")
	player._transformar(0, true)

	# --- Muerte: emite died y la cabeza queda entera ---
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
	_check(boss._puntas.all(func(pt) -> bool: return pt.visible and not pt.rota), "Al morir la cabeza queda entera")
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


func _vivos(boss: Node) -> Array:
	return boss._invocados.filter(func(e) -> bool: return is_instance_valid(e) and e.health > 0)


func _rayos() -> Array:
	return get_nodes_in_group("ataque_jefe").filter(func(n) -> bool: return n.get("rayo") == true and not n.is_queued_for_deletion())


func _esperar_rayo(frames: int) -> Variant:
	for _i in frames:
		var r := _rayos()
		if not r.is_empty():
			return r[0]
		await physics_frame
	return null


func _rayos_gruesos() -> Array:
	return get_nodes_in_group("ataque_jefe").filter(func(n) -> bool: return n.get("rayo") == true and float(n.ancho) >= 60.0 and not n.is_queued_for_deletion())


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
