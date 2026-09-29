extends SceneTree
## Diag Fase 2: Lobo (cadena de mordidas), energía y parry. Uso: --headless --script res://tests/diag_fase2.gd

var fallos := 0

func _check(c: bool, m: String) -> void:
	print(("[PASS] " if c else "[FAIL] ") + m)
	if not c:
		fallos += 1

func _initialize() -> void:
	var nivel: Node = load("res://scenes/nivel1.tscn").instantiate()
	root.add_child(nivel)
	await process_frame
	await process_frame
	for n in nivel.get_children():
		if n.get_script() != null and str(n.get_script().resource_path).ends_with("dialog_trigger.gd"):
			n.queue_free()
	var p := get_first_node_in_group("player") as CharacterBody2D
	p.set("god_mode", true)
	for n in get_nodes_in_group("enemy"):
		n.queue_free()
	await create_timer(0.8).timeout
	p._transformar(1, true)
	await create_timer(0.3).timeout
	var d = p.forms[1]

	# --- Lobo: cada mordida de la cadena es distinta.
	var delays := []
	var recs := []
	var lunges := []
	for paso in [1, 2, 3]:
		p.end_attack()
		p.set("_light_step", paso - 1)
		p.set("_current_attack_type", "light")
		p._light_step = paso
		p.enable_melee(d.attack_size, d.attack_range, 6, 0.0)
		delays.append(p._hit_delay)
		recs.append(p._attack_timer)
		lunges.append(p._lunge_vel)
	_check(delays[1] < delays[0], "2.ª mordida conecta antes que la 1.ª (%.3f < %.3f)" % [delays[1], delays[0]])
	_check(recs[2] > recs[0] * 1.2, "el cierre de la cadena recupera más lento (%.3f vs %.3f)" % [recs[2], recs[0]])
	_check(absf(lunges[2]) > absf(lunges[1]) and absf(lunges[1]) > absf(lunges[0]) and absf(lunges[0]) > 0.0, "el avance crece por paso (%s)" % str(lunges))
	_check(d.anim_frame_inicio("light", 2) == 1 and d.anim_frame_inicio("light", 1) == 0, "la 2.ª mordida saltea el agazapado")
	p.pose_ataque(10.0, 0.1)
	_check(absf(p._pose_rot) > 0.01, "la pose inclina el sprite y luego vuelve")
	await create_timer(0.4).timeout
	_check(absf(p._pose_rot) < 0.01, "la pose vuelve a 0")

	# --- Costo de energía del especial.
	p.end_attack()
	p.set("_special_cooldown", 0.0)
	p.energia = 2.0
	var e0: float = p.energia
	p._procesar_ataque("special", d, false)
	_check(p.energia == e0, "sin energía suficiente el especial no sale ni gasta")
	p.end_attack()
	p.energia = 50.0
	p._procesar_ataque("special", d, false)
	_check(p.energia < 50.0, "el especial del Lobo gasta energía (%.1f)" % p.energia)
	p.end_attack()

	# --- Parry del Humano.
	p._transformar(0, true)
	await create_timer(0.2).timeout
	p.set("_invuln_timer", 0.0)
	p.set("god_mode", false)
	p.set("health", 100)
	p.set("blocking", true)
	p.set("_parry_t", 0.1)
	p.energia = 50.0
	p.take_damage(20, 0.0, 1)
	_check(int(p.get("health")) == 100, "el parry evita todo el daño")
	_check(p.energia > 50.0, "el parry da energía (%.1f)" % p.energia)
	p.set("_invuln_timer", 0.0)
	p.set("_parry_t", 0.0)
	p.take_damage(20, 0.0, 1)
	_check(int(p.get("health")) == 100, "bloqueo normal (fuera de ventana) también evita el daño")
	p.set("blocking", false)

	# --- Proyectil reflejado por parry.
	var proj: Area2D = (load("res://scenes/projectile.tscn") as PackedScene).instantiate()
	proj.set("enemy_shot", true)
	proj.set("direction", Vector2.RIGHT)
	nivel.add_child(proj)
	await process_frame
	p.set("blocking", true)
	p.set("_parry_t", 0.1)
	proj._on_body_entered(p)
	_check(proj.enemy_shot == false and proj.direction.x < 0.0, "el parry refleja el proyectil enemigo")
	p.set("blocking", false)
	proj.queue_free()

	# --- Bonus por cambiar de forma en plena racha.
	p.set("_racha", 3)
	p.set("_racha_timer", 1.0)
	p.set("_cooldown_transform", 0.0)
	p.set("_invuln_timer", 0.0)
	p._transformar(2)
	_check(p._tag_t > 0.0, "cambiar de forma con racha activa da bonus")

	# --- Oso: onda al transformarse y pisotón atrás.
	var en: CharacterBody2D = (load("res://scenes/enemy.tscn") as PackedScene).instantiate()
	en.set("tipo", "cultista")
	nivel.add_child(en)
	en.global_position = p.global_position + Vector2(-150, 0)
	await create_timer(0.6).timeout
	p.facing = 1
	var vida_e: int = en.health
	en.global_position = p.global_position + Vector2(-120, 0)
	var alcanzados: int = p.onda_area(230.0, 14, 300.0, true)
	_check(alcanzados >= 1 and en.health < vida_e, "el pisotón golpea a los enemigos por detrás")
	en.queue_free()

	# --- Murciélago: aleteo.
	p._transformar(3, true)
	await create_timer(0.3).timeout
	p.energia = 60.0
	p.global_position += Vector2(0, -400)
	await create_timer(0.3).timeout
	p.set("_flap_cd", 0.0)
	var d3 = p.forms[3]
	p._aletear(d3)
	_check(p.velocity.y < -200.0 and p.energia < 60.0, "el aleteo impulsa hacia arriba y gasta energía")
	print("DIAG FASE2 FALLOS = ", fallos)
	quit(1 if fallos > 0 else 0)
