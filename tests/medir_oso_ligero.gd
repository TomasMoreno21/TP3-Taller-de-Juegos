extends SceneTree
## Medición: Oso quieto contra un cultista activo; aprieta ligero cada 0.6 s y registra si cada golpe conectó,
## a qué distancia (borde a borde) estaba el enemigo y en qué estado. Uso: --script res://tests/medir_oso_ligero.gd

func _initialize() -> void:
	await process_frame
	var raiz := Node2D.new()
	root.add_child(raiz)
	var suelo := StaticBody2D.new()
	var cs := CollisionShape2D.new()
	var r := RectangleShape2D.new()
	r.size = Vector2(6000, 200)
	cs.shape = r
	suelo.add_child(cs)
	suelo.position = Vector2(0, 700)
	raiz.add_child(suelo)
	var p: CharacterBody2D = load("res://scenes/player.tscn").instantiate()
	p.position = Vector2(0, 400)
	raiz.add_child(p)
	p.set("current_form", 2)
	p.call("_apply_form")
	p.set("god_mode", true)
	for i in 40:
		await physics_frame
	var e = load("res://scenes/enemy.tscn").instantiate()
	e.tipo = "cultista"
	e.position = Vector2(600, 400)
	raiz.add_child(e)
	if e.has_method("activar"):
		e.activar()
	var medio_p: float = (p.get("collision_shape").shape as RectangleShape2D).size.x * 0.5
	var golpes := 0
	var conectados := 0
	for intento in 14:
		for i in 36:
			await physics_frame
			p.set("energia", 100.0)
			p.set("health", 100)
		if not is_instance_valid(e) or e.health <= 0:
			break
		p.facing = 1 if e.global_position.x > p.global_position.x else -1
		var medio_e: float = (e.collide_shape.shape as RectangleShape2D).size.x * 0.5
		var gap := absf(e.global_position.x - p.global_position.x) - medio_p - medio_e
		var hp0: int = e.health
		Input.action_press("attack")
		await physics_frame
		await physics_frame
		Input.action_release("attack")
		var gap_imp := gap
		for i in 24:
			await physics_frame
			if not p.get("attack_hitbox").disabled:
				gap_imp = absf(e.global_position.x - p.global_position.x) - medio_p - medio_e
		golpes += 1
		var ok: bool = is_instance_valid(e) and e.health < hp0
		if ok:
			conectados += 1
		print("golpe %2d gap_al_apretar=%4.0f gap_en_golpe=%4.0f %s hp %d" % [intento, gap, gap_imp, "PEGA " if ok else "FALLA", e.health if is_instance_valid(e) else -1])
	print("OSO LIGERO: %d/%d conectaron" % [conectados, golpes])
	quit()
