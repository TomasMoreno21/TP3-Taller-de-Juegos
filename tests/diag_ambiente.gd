extends SceneTree
## Diag Fase B ("El mundo te siente"): tensión ambiental, vegetación reactiva, imán y
## curación del orbe de vida, y pinchos que empalan enemigos lanzados.
## Uso: --headless --script res://tests/diag_ambiente.gd

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
	for i in 30:
		await physics_frame
	var amb: Node = root.get_node_or_null("Ambiente")
	_check(amb != null, "autoload Ambiente presente")
	if amb == null:
		quit(1)
		return
	# --- Tensión: enemigos vivos cerca la suben; sin ellos y sana, baja a 0.
	for n in get_nodes_in_group("enemy"):
		n.queue_free()
	await create_timer(0.5).timeout
	for i in 120:
		await physics_frame
	_check(float(amb.tension) < 0.05, "sin enemigos y con vida llena la tensión es ~0 (%.2f)" % float(amb.tension))
	var enemigos: Array[CharacterBody2D] = []
	for i in 4:
		var e: CharacterBody2D = (load("res://scenes/enemy.tscn") as PackedScene).instantiate()
		nivel.add_child(e)
		e.global_position = p.global_position + Vector2(300 + i * 80, 0)
		enemigos.append(e)
	await create_timer(3.0).timeout
	_check(float(amb.tension) > 0.3 and float(amb.tension) <= 1.0, "4 enemigos cerca suben la tensión (%.2f)" % float(amb.tension))
	for e in enemigos:
		e.queue_free()
	await create_timer(0.3).timeout
	# --- Vegetación reactiva: un arbusto junto al jugador se dobla si corre; empujar() lo sacude.
	var deco: Node2D = (load("res://scenes/decorativo.tscn") as PackedScene).instantiate()
	deco.set("tipo", 2)   # ARBUSTO
	nivel.add_child(deco)
	deco.global_position = p.global_position + Vector2(60, 140)
	await process_frame
	_check(deco.is_in_group("reactivo"), "el arbusto se registra como reactivo")
	p.velocity.x = 320.0
	for i in 20:
		p.velocity.x = 320.0
		await process_frame
	_check(absf(float(deco.get("_rx"))) > 0.02, "el arbusto se dobla al pasar el jugador (%.3f)" % float(deco.get("_rx")))
	deco.set("_rx", 0.0)
	deco.set("_rv", 0.0)
	amb.empujar(p.global_position, 1.0)
	_check(absf(float(deco.get("_rv"))) > 0.5, "empujar() sacude la vegetación cercana (%.2f)" % float(deco.get("_rv")))
	deco.queue_free()
	# --- Orbe de vida: imán hacia el jugador y curación.
	var orbe: Area2D = (load("res://scenes/pickup_vida.tscn") as PackedScene).instantiate()
	nivel.add_child(orbe)
	p.velocity = Vector2.ZERO
	orbe.global_position = p.global_position + Vector2(120, -60)
	p.set("health", 50)
	var d0: float = orbe.global_position.distance_to(p.global_position)
	await physics_frame
	await physics_frame
	_check(not is_instance_valid(orbe) or orbe.global_position.distance_to(p.global_position) < d0, "el orbe vuela hacia el jugador (imán)")
	for i in 60:
		await physics_frame
	_check(int(p.get("health")) > 50, "el orbe cura al llegar (%d)" % int(p.get("health")))
	_check(not is_instance_valid(orbe) or orbe.is_queued_for_deletion(), "el orbe se libera al recogerse")
	# --- Pinchos: un enemigo lanzado (hitstun) queda empalado; uno quieto no muere.
	var pin: Area2D = (load("res://scenes/pinchos.tscn") as PackedScene).instantiate()
	nivel.add_child(pin)
	pin.global_position = Vector2(-3000, 990)
	await process_frame
	var v: CharacterBody2D = (load("res://scenes/enemy.tscn") as PackedScene).instantiate()
	nivel.add_child(v)
	v.global_position = pin.global_position + Vector2(0, -20)
	await create_timer(0.6).timeout
	var hp0: int = int(v.get("health"))
	await create_timer(0.3).timeout
	_check(int(v.get("health")) == hp0 and hp0 > 0, "un enemigo que no está lanzado no muere por los pinchos")
	v.set("_stun_timer", 1.0)
	v.global_position = pin.global_position + Vector2(0, -20)
	for i in 10:
		await physics_frame
	_check(int(v.get("health")) <= 0 or not is_instance_valid(v) or v.is_queued_for_deletion(), "un enemigo en hitstun sobre los pinchos muere")
	print("DIAG AMBIENTE FALLOS = ", fallos)
	quit(1 if fallos > 0 else 0)
