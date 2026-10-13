extends SceneTree
## Diag Fase 1: aviso de disparo, límite de atacantes melee y poise anti-stunlock.
## Uso: --headless --script res://tests/diag_fase1.gd

var fallos := 0

func _check(c: bool, m: String) -> void:
	print(("[PASS] " if c else "[FAIL] ") + m)
	if not c:
		fallos += 1

func _enemigo(nivel: Node, tipo: String, pos: Vector2) -> CharacterBody2D:
	var e: CharacterBody2D = (load("res://scenes/enemy.tscn") as PackedScene).instantiate()
	e.set("tipo", tipo)
	nivel.add_child(e)
	e.global_position = pos
	return e

func _initialize() -> void:
	var nivel: Node = load("res://scenes/nivel1.tscn").instantiate()
	root.add_child(nivel)
	await process_frame
	await process_frame
	var p := get_first_node_in_group("player") as CharacterBody2D
	p.set("god_mode", true)
	for n in get_nodes_in_group("enemy"):
		n.queue_free()
	await process_frame
	var base := p.global_position

	# --- Aviso de disparo: el arquero no dispara al instante.
	var a := _enemigo(nivel, "arquero", base + Vector2(500, 0))
	await create_timer(0.8).timeout
	var cuenta0 := get_nodes_in_group("enemy").size()
	var vio_aviso := false
	var proyectil_temprano := false
	var t := 0.0
	while t < 2.5:
		await physics_frame
		t += (1.0 / 60.0)
		if a._windup_disparo > 0.0:
			vio_aviso = true
			# durante el aviso no debe haber proyectiles del enemigo
			for n in nivel.get_children():
				if n is Area2D and n.get("enemy_shot") == true:
					proyectil_temprano = true
	_check(vio_aviso, "el arquero hace un aviso antes de disparar")
	_check(not proyectil_temprano, "no hay proyectil mientras dura el aviso")
	a.queue_free()
	await process_frame

	# --- Tokens: 4 cultistas juntos, a lo sumo 2 atacando a la vez.
	var cult: Array[CharacterBody2D] = []
	for i in 4:
		cult.append(_enemigo(nivel, "cultista", base + Vector2(90 + i * 6, 0)))
	var max_a := 0
	t = 0.0
	while t < 2.5:
		await physics_frame
		t += (1.0 / 60.0)
		var n_at := 0
		for c in cult:
			if is_instance_valid(c) and (c._windup_timer > 0.0 or c._lunge_timer > 0.0):
				n_at += 1
		max_a = maxi(max_a, n_at)
	_check(max_a <= 2, "máximo de atacantes simultáneos <= 2 (visto %d)" % max_a)
	for c in cult:
		c.queue_free()
	await process_frame

	# --- Poise: tras 3 golpes seguidos deja de aturdirse; un golpe fuerte lo rompe.
	var e := _enemigo(nivel, "cultista", base + Vector2(700, 0))
	await create_timer(0.6).timeout
	e.take_damage(1, 0.0, 1, false)
	e.take_damage(1, 0.0, 1, false)
	e.take_damage(1, 0.0, 1, false)
	_check(e._poise_ventana_t > 0.0, "tras 3 golpes abre la ventana de resistencia")
	e._stun_timer = 0.0
	e.take_damage(1, 0.0, 1, false)
	_check(e._stun_timer <= 0.0, "en resistencia el golpe débil no aturde")
	e.take_damage(30, 0.0, 1, false)
	_check(e._stun_timer > 0.0, "un golpe fuerte rompe la resistencia y aturde")
	e.queue_free()
	await process_frame

	# --- Ola mixta: 2 cultistas + 1 arquero en la misma ola.
	var enc: Node = (load("res://scenes/encounter.tscn") as PackedScene).instantiate()
	var ola := WaveOla.new()
	ola.tipo = "cultista"
	ola.cantidad = 2
	ola.tipo_extra = "arquero"
	ola.cantidad_extra = 1
	ola.delay = 0.0
	ola.edge = false
	enc.set("olas", [ola] as Array[WaveOla])
	nivel.add_child(enc)
	enc.global_position = base + Vector2(0, -400)
	await process_frame
	enc.arena_center = base
	enc.espera_inicial = 0.0
	enc.empezar()
	await create_timer(0.3).timeout
	var tipos := {}
	for n in get_nodes_in_group("enemy"):
		if n.get_parent() == enc:
			tipos[n.tipo] = int(tipos.get(n.tipo, 0)) + 1
	_check(int(tipos.get("cultista", 0)) == 2 and int(tipos.get("arquero", 0)) == 1, "ola mixta genera 2 cultistas + 1 arquero (%s)" % str(tipos))
	print("DIAG FASE1 FALLOS = ", fallos)
	quit(1 if fallos > 0 else 0)
