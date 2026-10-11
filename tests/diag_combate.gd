extends SceneTree
## Diag Fase C ("El mundo te siente"): cancelar la recuperación, magnetismo del avance,
## flash blanco + pausa de impacto del enemigo y sus efectos en headless.
## Uso: --headless --script res://tests/diag_combate.gd

var fallos := 0

func _check(c: bool, m: String) -> void:
	print(("[PASS] " if c else "[FAIL] ") + m)
	if not c:
		fallos += 1

func _initialize() -> void:
	var nivel: Node = load("res://scenes/nivel1.tscn").instantiate()
	root.add_child(nivel)
	for n in nivel.get_children():
		if n.get_script() != null and str(n.get_script().resource_path).ends_with("dialog_trigger.gd"):
			n.queue_free()
	await process_frame
	await process_frame
	var p := get_first_node_in_group("player") as CharacterBody2D
	p.set("god_mode", true)
	for i in 60:
		await physics_frame
	# --- Cancelar recuperación: antes de conectar no se puede; conectado o con umbral sí.
	p._procesar_ataque("light", p.forms[0], false)
	_check(bool(p.get("_attacking")), "el golpe activa el ataque")
	p.set("_hit_applied", false)
	p.set("_early_liberado", false)
	_check(not p._cancelar_recuperacion(), "no se cancela en pleno swing (antes de conectar)")
	p.set("_hit_applied", true)
	_check(p._cancelar_recuperacion(), "tras conectar se puede cancelar la recuperación")
	_check(not bool(p.get("_attacking")) and float(p.get("_attack_timer")) == 0.0, "cancelar deja el ataque cerrado")
	# Transformarse cancela siempre.
	p._procesar_ataque("light", p.forms[0], false)
	p.set("_cooldown_transform", 0.0)
	p._transformar(1, true)
	_check(not bool(p.get("_attacking")), "transformarse cancela el ataque en curso")
	# --- Magnetismo: con un enemigo un poco lejos el avance del Lobo se estira.
	var e: CharacterBody2D = (load("res://scenes/enemy.tscn") as PackedScene).instantiate()
	nivel.add_child(e)
	e.enemy_data.poise_max = 0
	await create_timer(0.8).timeout
	p.set("facing", 1)
	p.velocity = Vector2.ZERO
	e.global_position = p.global_position + Vector2(520, 0)
	await physics_frame
	p.set("magnetismo_alcance", 600.0)   # el alcance del Lobo ya supera los 340 px de búsqueda por defecto
	p.set("magnetismo_mult", 1.0)
	p._procesar_ataque("heavy", p.forms[1], false)
	var v_base: float = absf(float(p.get("_lunge_vel")))
	p.end_attack()
	p.set("_heavy_step", 0)
	p.set("magnetismo_mult", 2.0)
	p._procesar_ataque("heavy", p.forms[1], false)
	var v_mag: float = absf(float(p.get("_lunge_vel")))
	print("   lunge base=%.1f magnetismo=%.1f" % [v_base, v_mag])
	_check(v_mag >= v_base and v_base > 0.0, "el magnetismo nunca acorta el avance")
	_check(v_mag > v_base, "el magnetismo estira el avance hacia el enemigo lejano (%.0f > %.0f)" % [v_mag, v_base])
	p.end_attack()
	# --- Enemigo: destello blanco, pausa de impacto y salida despedido.
	e.global_position = p.global_position + Vector2(260, 0)
	await create_timer(0.3).timeout
	var x0: float = e.global_position.x
	e.take_damage(1, 400.0, 1, false)
	_check(e.visual.self_modulate.r > 1.5, "el impacto deja un destello blanco (self_modulate %.2f)" % e.visual.self_modulate.r)
	_check(float(e.get("_pausa_impacto_t")) > 0.0, "queda colgado un instante antes de salir despedido")
	await create_timer(0.4).timeout
	_check(e.visual.self_modulate.r < 1.05, "el destello blanco se apaga (%.2f)" % e.visual.self_modulate.r)
	_check(e.global_position.x - x0 > 15.0, "tras la pausa sale despedido (%.0f px)" % (e.global_position.x - x0))
	# --- Efectos sin ventana no fallan.
	Burst.chispas(e, e.global_position, 1, Color.WHITE)
	_check(true, "Burst.chispas no falla en headless")
	var proj: Area2D = (load("res://scenes/projectile.tscn") as PackedScene).instantiate()
	nivel.add_child(proj)
	await physics_frame
	_check(is_instance_valid(proj), "el proyectil con estela/giro vive en headless")
	e.take_damage(9999, 0.0, 1, false)
	await create_timer(0.5).timeout
	_check(not is_instance_valid(e) or e.health <= 0, "la muerte por peso no falla")
	print("DIAG COMBATE FALLOS = ", fallos)
	quit(1 if fallos > 0 else 0)
