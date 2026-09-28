extends SceneTree
## Diag: reaparición automática al morir + plataformas frágiles que vuelven.
## Uso: godot --headless --path . --script res://tests/diag_reaparicion.gd

var _fallos := 0


func _check(cond: bool, msg: String) -> void:
	if cond:
		print("[PASS] " + msg)
	else:
		_fallos += 1
		print("[FAIL] " + msg)


func _init() -> void:
	var nivel: Node = load("res://scenes/nivel2.tscn").instantiate()
	root.add_child(nivel)
	current_scene = nivel
	await process_frame
	await process_frame
	var player: CharacterBody2D = nivel.get_node("Player")
	var pf: Node = nivel.get_node("PlataformaFragil")
	var origen: Vector2 = pf.position

	# --- Plataforma frágil: se rompe y vuelve por tiempo ---
	pf.tiempo_reaparicion = 0.5
	pf.call("_romper")
	await process_frame
	_check(pf._fase == 3 or pf._fase == 2, "Frágil: se rompió")
	for i in 60:
		await physics_frame
	# Debería haber vuelto (0.5 s ≈ 30 frames a 60 Hz) salvo que el jugador esté encima.
	_check(pf._fase == 0, "Frágil: reapareció por tiempo (fase=%d)" % pf._fase)
	_check(pf.position.is_equal_approx(origen), "Frágil: vuelve a su posición original")
	_check(not pf._shape.disabled, "Frágil: collider reactivado")

	# --- Frágil: vuelve al reaparecer en checkpoint (tiempo = 0 → solo por checkpoint) ---
	pf.tiempo_reaparicion = 0.0
	pf.call("_romper")
	for i in 20:
		await physics_frame
	_check(pf._fase != 0, "Frágil (solo checkpoint): sigue rota sin checkpoint")
	player.set("_tiene_checkpoint", true)
	player.set("_spawn_position", player.global_position + Vector2(300, 0))
	player.god_mode = false
	player.health = 0
	player.call("_handle_death")
	for i in 5:
		await physics_frame
		await process_frame
	var derrota := nivel.get_node_or_null("Derrota")
	_check(derrota == null, "Muerte: NO aparece el panel de derrota")
	_check(player.health > 0, "Muerte: reaparece con vida")
	_check(not get_first_node_in_group("player").get("_derrota_activa"), "Muerte: flag de derrota limpio")
	_check(not paused, "Muerte: árbol no queda pausado")
	_check(pf._fase == 0, "Frágil: reapareció al reaparecer en el checkpoint (fase=%d, pos=%s, spawn=%s)" % [pf._fase, str(player.global_position), str(player.get("_spawn_position"))])

	print("DIAG REAPARICION FALLOS = ", _fallos)
	quit(_fallos)
