extends SceneTree
## Diag "El mundo te siente" (Fase A): el resorte del cuerpo vuelve a su forma sin divergir,
## los impulsos se suman y la respiración/cansancio no rompen la escala.
## Uso: --headless --script res://tests/diag_feel.gd

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
	for i in 90:
		await physics_frame
	var base_y: float = p.visual.scale.y
	# Un squash desplaza la escala y el resorte la devuelve.
	p.squash_y(0.3, 0.1)
	await physics_frame
	_check(p.visual.scale.y < base_y * 0.9, "squash_y encoge la escala (%.3f < %.3f)" % [p.visual.scale.y, base_y])
	for i in 90:
		await physics_frame
	_check(absf(p.visual.scale.y - base_y) < base_y * 0.03, "el resorte vuelve a la escala base (%.3f vs %.3f)" % [p.visual.scale.y, base_y])
	# Los impulsos se suman en vez de pisarse.
	p.squash_y(0.1, 0.1)
	p.squash_y(0.1, 0.1)
	_check(p.get("_esc_off").y < -0.15, "dos squash seguidos se acumulan (%.3f)" % p.get("_esc_off").y)
	# Tope: nunca diverge.
	for i in 20:
		p.stretch_y(0.5, 0.1)
	_check(p.get("_esc_off").y <= 0.6001, "el desvío está acotado (%.3f)" % p.get("_esc_off").y)
	for i in 240:
		await physics_frame
	var v: Vector2 = p.visual.scale
	_check(is_finite(v.x) and is_finite(v.y) and absf(v.y - base_y) < base_y * 0.03, "sin NaN y estable tras el abuso (%s)" % str(v))
	# Cansancio: con vida baja sube el factor y la escala sigue finita.
	p.set("health", 10)
	_check(p._factor_cansancio() > 0.9, "vida baja → cansancio alto (%.2f)" % p._factor_cansancio())
	for i in 30:
		await physics_frame
	_check(is_finite(p.visual.scale.y) and absf(p.visual.scale.y / base_y - 1.0) < 0.1, "respiración pesada acotada (%.3f)" % (p.visual.scale.y / base_y))
	p.set("health", 100)
	_check(p._factor_cansancio() == 0.0, "vida llena → sin cansancio")
	# Los ecos no rompen en headless.
	p.emitir_eco()
	_check(true, "emitir_eco no falla en headless")
	# Girar quieto aplasta lateralmente.
	p.set("facing", 1)
	await physics_frame
	p.set("velocity", Vector2.ZERO)
	p.set("facing", -1)
	p._aplicar_facing()
	_check(p.get("_esc_off").x < -0.02, "girar quieto da un aplaste lateral (%.3f)" % p.get("_esc_off").x)
	print("DIAG FEEL FALLOS = ", fallos)
	quit(1 if fallos > 0 else 0)
