extends SceneTree
## Diag Fase 0: los pinchos ignoran el bloqueo, transformar limpia la secuencia de combo
## y el hitstop en ráfaga queda acotado. Uso: --headless --script res://tests/diag_fase0.gd

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
	var p := get_first_node_in_group("player") as CharacterBody2D
	# Daño letal del entorno atraviesa el bloqueo.
	p.set("god_mode", false)
	p.set("_invuln_timer", 0.0)
	p.set("blocking", true)
	var vida0: int = p.get("health")
	p.take_damage(10, 0.0, 0, true)
	_check(int(p.get("health")) < vida0, "daño con ignora_bloqueo baja la vida aunque bloquee")
	p.set("_invuln_timer", 0.0)
	p.set("health", 100)
	p.set("blocking", true)
	p.take_damage(10, 0.0, 0)
	_check(int(p.get("health")) == 100, "el daño normal sigue bloqueándose")
	# Transformar limpia la secuencia de combo.
	p.set("blocking", false)
	p.set("_invuln_timer", 0.0)
	p.set("_cooldown_transform", 0.0)
	p.set("_light_step", 2)
	p.get("_seq").append("light")
	p._transformar(1, true)
	_check(int(p.get("_light_step")) == 0 and p.get("_seq").is_empty(), "transformar reinicia pasos y secuencia")
	# Hitstop acotado.
	var hmax: float = p.get("hitstop_max")
	_check(p._limitar_hitstop(5.0) <= hmax + 0.0001, "hitstop nunca supera el tope (%.2f)" % hmax)
	p.set("_ultimo_hitstop_s", -10.0)
	var a: float = p._limitar_hitstop(0.10)
	var b: float = p._limitar_hitstop(0.10)
	_check(b < a or a >= hmax, "segundo golpe en ráfaga dura menos (%.3f < %.3f)" % [b, a])
	print("DIAG FASE0 FALLOS = ", fallos)
	quit(1 if fallos > 0 else 0)
