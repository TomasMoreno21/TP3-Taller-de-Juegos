extends SceneTree
## Diag: al recibir golpes seguidos el enemigo mantiene la animación viva (no se congela)
## y su visual vuelve a la pose de reposo sin "drift". Uso: --headless --script res://tests/diag_flinch.gd

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
	var e: CharacterBody2D = (load("res://scenes/enemy.tscn") as PackedScene).instantiate()
	nivel.add_child(e)
	e.global_position = Vector2(400, 900)
	await create_timer(1.0).timeout
	var pos0: Vector2 = e.visual.position
	var esc0: Vector2 = e.visual.scale
	for i in 8:
		e.take_damage(1, 200.0, 1, false)
		await create_timer(0.06).timeout
	_check(e._stun_timer > 0.0, "en stun tras ráfaga")
	_check(not e._anim_congelada, "animación NO congelada durante el stun")
	_check(e.animated.is_playing(), "animación sigue reproduciéndose durante el stun")
	await create_timer(1.2).timeout
	_check(e.visual.position.distance_to(pos0) < 0.5, "posición del visual vuelve a la base (drift %s)" % str(e.visual.position - pos0))
	_check(e.visual.scale.distance_to(esc0) < 0.01, "escala del visual vuelve a la base (%s vs %s)" % [str(e.visual.scale), str(esc0)])
	_check(absf(e.visual.rotation) < 0.01, "rotación vuelve a 0")
	print("DIAG FLINCH FALLOS = ", fallos)
	quit(1 if fallos > 0 else 0)
