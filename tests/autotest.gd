extends SceneTree

var _failures := 0


func _init() -> void:
	var scene = load("res://scenes/main.tscn").instantiate()
	root.add_child(scene)
	await process_frame
	await process_frame

	var player = scene.get_node("Player")
	var enemy = scene.get_node("Level/Enemy")
	var console = scene.get_node("UI/Console")

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
