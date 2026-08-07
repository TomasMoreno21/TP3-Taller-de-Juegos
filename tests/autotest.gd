extends SceneTree

var _failures := 0
var _console: Node


func _init() -> void:
	var scene = load("res://scenes/main.tscn").instantiate()
	root.add_child(scene)
	await process_frame
	await process_frame

	var player = scene.get_node("Player")
	var enemy = scene.get_node("Level/Enemy")
	var console = scene.get_node("UI/Console")
	_console = console

	_check(player.current_form == 0, "Forma inicial = Guardabosques (0). Es: " + str(player.current_form))

	Input.action_press("transform")
	await physics_frame
	await physics_frame
	Input.action_release("transform")
	_check(player.current_form == 1, "Transformar cicla a Oso (1). Es: " + str(player.current_form))

	console._execute("form", PackedStringArray(["buho"]))
	_check(player.current_form == 3, "Consola 'form buho' -> (3). Es: " + str(player.current_form))

	console._execute("god", PackedStringArray())
	_check(player.god_mode == true, "Consola 'god' activa invencibilidad")

	console._execute("form", PackedStringArray(["humano"]))
	player.global_position = enemy.global_position - Vector2(30, 0)
	player.facing = 1
	await physics_frame
	var hp_before: int = enemy.health
	Input.action_press("attack")
	await physics_frame
	await physics_frame
	await physics_frame
	Input.action_release("attack")
	_check(enemy.health < hp_before, "Ataque melee daña al enemigo (%d -> %d)" % [hp_before, enemy.health])

	var enemies_before: int = get_nodes_in_group("enemy").size()
	console._execute("spawn_enemy", PackedStringArray())
	await physics_frame
	_check(get_nodes_in_group("enemy").size() == enemies_before + 1, "spawn_enemy suma un enemigo")

	console._execute("kill_enemies", PackedStringArray())
	await physics_frame
	_check(get_nodes_in_group("enemy").size() == 0, "kill_enemies elimina todos los enemigos")

	# --- Lote 1: combate fiel al original ---
	console._execute("form", PackedStringArray(["humano"]))
	await _wait_frames(3)

	# Light combo: la repetición de J escala el daño (humano: 10 -> 15)
	var e_light: Node2D = await _spawn_enemy_near(player)
	var full_hp: int = e_light.health
	Input.action_press("attack")
	await physics_frame
	await physics_frame
	Input.action_release("attack")
	await physics_frame
	var dmg_one: int = full_hp - e_light.health
	await _wait_frames(24)
	Input.action_press("attack")
	await physics_frame
	await physics_frame
	Input.action_release("attack")
	await physics_frame
	Input.action_press("attack")
	await physics_frame
	await physics_frame
	Input.action_release("attack")
	await physics_frame
	await physics_frame
	var dmg_two: int = (full_hp - e_light.health) - dmg_one
	_check(dmg_one == 10, "Light combo: golpe 1 hace 10 dmg (es %d)" % dmg_one)
	_check(dmg_two == 25, "Light combo: J J rápidos hacen 25 dmg (es %d)" % dmg_two)
	_check(dmg_two > dmg_one * 2, "Light combo: la repetición escala el daño")

	# Heavy combo: K daña y aplica knockback
	var e_heavy: Node2D = await _spawn_enemy_near(player)
	var heavy_before: int = e_heavy.health
	Input.action_press("heavy")
	await physics_frame
	await physics_frame
	Input.action_release("heavy")
	await _wait_frames(3)
	_check(e_heavy.health < heavy_before, "Heavy combo: K daña al enemigo")

	# Especial: L hace el ataque especial de la forma (barrido del humano)
	var e_special: Node2D = await _spawn_enemy_near(player)
	var spec_before: int = e_special.health
	Input.action_press("special")
	await physics_frame
	await physics_frame
	Input.action_release("special")
	await _wait_frames(3)
	_check(e_special.health < spec_before, "Especial: L daña al enemigo")

	# Block: reduce el daño al 25%
	var hp_block: int = player.health
	Input.action_press("block")
	await physics_frame
	await physics_frame
	player.take_damage(20)
	await physics_frame
	_check(hp_block - player.health <= 5, "Block: reduce el daño al 25%%")
	Input.action_release("block")
	await physics_frame
	player.heal_full()

	# Jump attack: golpe en el aire
	var e_jump: Node2D = await _spawn_enemy_near(player)
	var jump_before: int = e_jump.health
	player.global_position = e_jump.global_position - Vector2(30, 10)
	player.facing = 1
	player.velocity = Vector2.ZERO
	await physics_frame
	Input.action_press("attack")
	await physics_frame
	await physics_frame
	Input.action_release("attack")
	await _wait_frames(3)
	_check(e_jump.health < jump_before, "Jump attack: golpe en el aire daña")
	await _wait_frames(25)

	# Lobo: light = dash (asegurarse de estar en el suelo)
	console._execute("form", PackedStringArray(["lobo"]))
	player.global_position = Vector2(400, 540)
	player.velocity = Vector2.ZERO
	await _wait_frames(10)
	_check(player.forms[2].is_dashing() == false, "Lobo: en reposo no dash")
	Input.action_press("attack")
	await physics_frame
	await physics_frame
	Input.action_release("attack")
	await physics_frame
	_check(player.forms[2].is_dashing(), "Lobo: light activa el dash")
	await _wait_frames(30)

	# Búho: special dispara proyectil
	console._execute("kill_enemies", PackedStringArray())
	await _wait_frames(5)
	console._execute("form", PackedStringArray(["buho"]))
	await _wait_frames(3)
	var proj_before := _count_projectiles(scene)
	Input.action_press("special")
	await physics_frame
	await physics_frame
	Input.action_release("special")
	await physics_frame
	_check(_count_projectiles(scene) > proj_before, "Búho: special dispara proyectil")
	await _wait_frames(20)

	# Feedback visual: el efecto de ataque aparece al golpear
	console._execute("form", PackedStringArray(["humano"]))
	await _wait_frames(3)
	var e_fx: Node2D = await _spawn_enemy_near(player)
	var fx: Polygon2D = player.get_node("AttackEffect")
	var av: Polygon2D = player.get_node("AttackAreaVisual")
	_check(fx.visible == false, "Feedback: efecto oculto en reposo")
	_check(av.visible == false, "Feedback: área oculta en reposo")
	Input.action_press("attack")
	await physics_frame
	await physics_frame
	Input.action_release("attack")
	await physics_frame
	_check(fx.visible == true, "Feedback: slash visible al atacar")
	_check(av.visible == true, "Feedback: área visible al atacar")
	_check(av.polygon.size() == 4, "Feedback: el área refleja el hitbox rectangular")
	await _wait_frames(25)
	_check(av.visible == false, "Feedback: el área se oculta tras el ataque")

	# Interact: el tronco solo lo rompe el Oso
	var tronco: Node2D = scene.get_node_or_null("Level/Tronco")
	_check(tronco != null, "Tronco presente en el nivel")
	if tronco != null:
		console._execute("form", PackedStringArray(["humano"]))
		await _wait_frames(3)
		player.global_position = tronco.global_position + Vector2(-30, 10)
		player.facing = 1
		player.velocity = Vector2.ZERO
		await physics_frame
		Input.action_press("special")
		await physics_frame
		await physics_frame
		Input.action_release("special")
		await _wait_frames(3)
		_check(is_instance_valid(tronco), "Interact: humano NO rompe el tronco")

		console._execute("form", PackedStringArray(["oso"]))
		await _wait_frames(3)
		player.global_position = tronco.global_position + Vector2(-30, 10)
		player.facing = 1
		player.velocity = Vector2.ZERO
		await physics_frame
		Input.action_press("special")
		await physics_frame
		await physics_frame
		Input.action_release("special")
		await _wait_frames(20)
		_check(not is_instance_valid(tronco), "Interact: oso rompe el tronco")

	# La base de formas expone el combo por repetición
	_check(player.forms[0].has_method("perform_light"), "Forma base: perform_light")
	_check(player.forms[0].has_method("perform_heavy"), "Forma base: perform_heavy")
	_check(player.forms[0].has_method("perform_special"), "Forma base: perform_special")
	_check(player.forms[0].light_combo_steps >= 2, "Forma base: light_combo_steps configurado")
	_check(player.forms[3].has_method("perform_special"), "Búho: perform_special")

	console._execute("kill_enemies", PackedStringArray())
	await physics_frame

	console._toggle()
	_check(paused == true, "Abrir consola pausa el juego")
	console._toggle()
	_check(paused == false, "Cerrar consola reanuda el juego")

	var encounter = scene.get_node("Level/Encounter")
	encounter.debug_activate()
	await physics_frame
	await physics_frame
	_check(encounter.state == 1, "Encuentro: activado (RUNNING)")
	_check(encounter.gate.get_node("Collision").disabled == false, "Encuentro: portón cerrado durante pelea")

	for i in range(60):
		await physics_frame
		if get_nodes_in_group("enemy").size() >= 1:
			break
	_check(get_nodes_in_group("enemy").size() >= 1, "Encuentro: spawnea enemigos tras telegrafiado")

	for i in range(10):
		if encounter.state == 2:
			break
		console._execute("kill_enemies", PackedStringArray())
		for j in range(30):
			await physics_frame
			if encounter.state == 2:
				break
	_check(encounter.state == 2, "Encuentro: completado tras eliminar todas las olas")
	_check(encounter.gate.get_node("Collision").disabled == true, "Encuentro: portón abierto al completar")

	print("AUTOTEST: FALLOS = " + str(_failures))
	if _failures == 0:
		print("AUTOTEST: TODOS LOS TESTS PASARON")
		quit(0)
	else:
		print("AUTOTEST: " + str(_failures) + " TEST(S) FALLARON")
		quit(1)


func _check(cond: bool, msg: String) -> void:
	if cond:
		print("[PASS] " + msg)
	else:
		print("[FAIL] " + msg)
		_failures += 1


func _wait_frames(n: int) -> void:
	for i in range(n):
		await physics_frame


func _spawn_enemy_near(player: Node2D) -> Node2D:
	_console._execute("spawn_enemy", PackedStringArray())
	await physics_frame
	await physics_frame
	var enemy := get_nodes_in_group("enemy")[0]
	player.global_position = enemy.global_position - Vector2(30, 0)
	player.facing = 1
	player.velocity = Vector2.ZERO
	await physics_frame
	return enemy


func _count_projectiles(scene: Node) -> int:
	var count := 0
	for child in scene.get_children():
		if child.name.begins_with("Projectile"):
			count += 1
	return count
