extends SceneTree

var _failures := 0
var _console: Node
var _player: Node2D
var _scene: Node


func _init() -> void:
	_scene = load("res://scenes/main.tscn").instantiate()
	root.add_child(_scene)
	_scene.get_node("LevelUp").set("pausar_al_abrir", false)  # no congelar el árbol durante los tests
	_console = load("res://scenes/console.tscn").instantiate()
	_scene.add_child(_console)
	await process_frame
	await process_frame

	_player = _scene.get_node("Player")
	# los enemigos del nivel inicial interfieren con las pruebas aisladas
	_limpiar_enemigos()
	await process_frame

	# --- Formas cargadas y stats del concepto ---
	_check(_player.forms.size() == 4, "4 formas cargadas. Es: " + str(_player.forms.size()))
	_check(_player.current_form == 0, "Forma inicial = Humano (0). Es: " + str(_player.current_form))
	_check(_player.forms[0].form_name == "Humano", "Forma 0 es Humano")
	_check(_player.forms[1].form_name == "Lobo", "Forma 1 es Lobo")
	_check(_player.forms[2].form_name == "Oso", "Forma 2 es Oso")
	_check(_player.forms[3].form_name == "Murciélago", "Forma 3 es Murciélago")
	_check(_player.forms[1].speed > _player.forms[2].speed, "Lobo es más rápido que el Oso")
	_check(_player.forms[2].attack_damage > _player.forms[1].attack_damage, "Oso pega más fuerte que el Lobo")
	_check(_player.forms[1].jump_velocity < _player.forms[2].jump_velocity, "Lobo salta más alto que el Oso")

	# --- Vida compartida: transformar NO resetea la vida ---
	_player.take_damage(30)
	await process_frame
	var hp_antes: int = _player.health
	_console._ejecutar(PackedStringArray(["form", "lobo"]))
	await process_frame
	_check(_player.current_form == 1, "Consola 'form lobo' -> 1")
	_check(_player.health == hp_antes, "Vida compartida: transformar no resetea la vida")
	_console._ejecutar(PackedStringArray(["form", "oso"]))
	await process_frame
	_check(_player.current_form == 2, "Consola 'form oso' -> 2")
	_check(_player.health == hp_antes, "Vida compartida: Oso hereda la vida del Lobo")
	_console._ejecutar(PackedStringArray(["form", "murcielago"]))
	await process_frame
	_check(_player.current_form == 3, "Consola 'form murcielago' -> 3")

	# --- Progresión: todas las formas desbloqueadas desde el inicio (16/08) ---
	_progresion().reset()
	_check(_progresion().forma_desbloqueada(1) == true, "Inicio: Lobo desbloqueado")
	Input.action_press("transform")
	await physics_frame
	await physics_frame
	Input.action_release("transform")
	_check(_player.current_form == 0, "Nivel 1: transformar no cambia (sigue Humano)")
	_progresion().add_fragmentos(3)
	_check(int(_progresion().nivel) == 2, "3 fragmentos suben a nivel 2")
	_check(_progresion().forma_desbloqueada(1) == true, "Nivel 2: Lobo desbloqueado")
	_progresion().add_fragmentos(3)
	_progresion().add_fragmentos(3)
	_check(_progresion().forma_desbloqueada(3) == true, "Nivel 4: Murciélago desbloqueado")

	# --- Melee: el humano daña al dummy ---
	_progresion().set_nivel(4)
	_console._ejecutar(PackedStringArray(["form", "humano"]))
	await process_frame
	var dummy := _spawn_dummy(Vector2(60, 0))
	_player.facing = 1
	_player.velocity = Vector2.ZERO
	await physics_frame
	var hp_dummy: int = dummy.health
	Input.action_press("attack")
	await physics_frame
	await physics_frame
	Input.action_release("attack")
	await _esperar_recuperacion("light")
	_check(dummy.health < hp_dummy, "Melee humano daña al dummy (%d -> %d)" % [hp_dummy, dummy.health])
	_limpiar_dummies()

	# --- Combo por secuencia J→K = Remate (42) ---
	_progresion().elegir_mejora(0)
	_check(_progresion().combos_desbloqueados_forma(0) == 1, "elegir_mejora(0) desbloquea el combo del humano")
	var e_combo := _spawn_dummy(Vector2(40, 0))
	_player.facing = 1
	await physics_frame
	Input.action_press("attack")
	await physics_frame
	await physics_frame
	await physics_frame
	Input.action_release("attack")
	await _esperar_recuperacion("light")
	var hp_tras_j: int = e_combo.health
	Input.action_press("heavy")
	await physics_frame
	await physics_frame
	await physics_frame
	Input.action_release("heavy")
	await physics_frame
	var remate_dmg: int = hp_tras_j - e_combo.health
	_check(remate_dmg == 42, "J→K ejecuta el Remate (42 dmg, fue %d)" % remate_dmg)
	await _esperar_recuperacion("combo")
	_limpiar_dummies()

	# --- Block: reduce el daño (take_damage ignora en bloqueo) ---
	var hp_block: int = _player.health
	Input.action_press("block")
	await physics_frame
	_player.take_damage(20)
	await physics_frame
	_check(_player.health == hp_block, "Block: bloquea el daño")
	Input.action_release("block")
	await physics_frame

	# --- Murciélago: special dispara proyectil sónico ---
	_console._ejecutar(PackedStringArray(["form", "murcielago"]))
	await process_frame
	var proj_before := _count_projectiles()
	Input.action_press("special")
	await physics_frame
	await physics_frame
	_check(_count_projectiles() > proj_before, "Murciélago: special dispara proyectil sónico")
	Input.action_release("special")
	await _esperar_recuperacion("special")
	_limpiar_dummies()

	# --- Planeo del Murciélago en el aire ---
	_player.global_position = Vector2(200, 100)
	_player.velocity = Vector2(0, 50)
	await physics_frame
	Input.action_press("jump")
	await physics_frame
	_check(_player.forms[3].is_gliding(_player), "Murciélago: planea en el aire con J sostenido")
	Input.action_release("jump")

	# --- Enemigos: el melee daña y mueren; tipos cargan ---
	_console._ejecutar(PackedStringArray(["form", "humano"]))
	await _wait_frames(40)
	_player.velocity = Vector2.ZERO
	var enemy_script := preload("res://scripts/enemy.gd")
	var cult: Enemigo = enemy_script.config_por_tipo("cultista")
	var ark: Enemigo = enemy_script.config_por_tipo("arquero")
	var cham: Enemigo = enemy_script.config_por_tipo("chaman")
	_check(cult != null and ark != null and cham != null, "Enemigos: config de los 3 tipos")
	_check(ark.projectile == true, "Enemigos: arquero dispara proyectil")
	_check(cham.max_health > cult.max_health, "Enemigos: chamán resistente tiene más vida que el cultista")

	var en := preload("res://scenes/enemy.tscn").instantiate()
	en.tipo = "cultista"
	_scene.add_child(en)
	en.global_position = _player.global_position + Vector2(60, 0)
	await _wait_frames(30)
	_player.facing = 1
	_player.velocity = Vector2.ZERO
	await physics_frame
	var hp_en: int = en.health
	Input.action_press("attack")
	await physics_frame
	await physics_frame
	Input.action_release("attack")
	await _esperar_recuperacion("light")
	_check(en.health < hp_en, "Enemigos: el melee del humano daña al sectario (%d -> %d)" % [hp_en, en.health])
	_limpiar_enemigos()

	# --- Enemigos: muerte recarga energía (Documento: golpes en combate) ---
	_player.energia = 40.0
	await process_frame
	var en2 := preload("res://scenes/enemy.tscn").instantiate()
	en2.tipo = "cultista"
	_scene.add_child(en2)
	en2.global_position = _player.global_position + Vector2(60, 40)
	await _wait_frames(3)
	_player.facing = 1
	_player.velocity = Vector2.ZERO
	await physics_frame
	var energia_antes: float = _player.energia
	for i in range(10):
		if not is_instance_valid(en2):
			break
		_player.global_position = en2.global_position - Vector2(20, 0)
		_player.facing = 1
		_player.velocity = Vector2.ZERO
		await physics_frame
		Input.action_press("attack")
		await physics_frame
		await physics_frame
		Input.action_release("attack")
		await _esperar_recuperacion("light")
	_check(not is_instance_valid(en2), "Enemigos: muere al recibir daño")
	_check(_player.energia > energia_antes, "Enemigos: matar recarga energía (%.1f -> %.1f)" % [energia_antes, _player.energia])
	_limpiar_enemigos()

	# --- Interact: el tronco solo lo rompe el Oso ---
	await _funcion_tronco()

	# --- Rompibles: 3 golpes + fragmento ---
	_console._ejecutar(PackedStringArray(["form", "humano"]))
	await process_frame
	var crate: Node2D = preload("res://scenes/rompible.tscn").instantiate()
	_scene.add_child(crate)
	crate.global_position = _player.global_position + Vector2(40, 0)
	await _wait_frames(3)
	_player.facing = 1
	var frag_antes: int = int(_progresion().fragmentos)
	for i in range(3):
		Input.action_press("attack")
		await physics_frame
		await physics_frame
		Input.action_release("attack")
		await _wait_frames(3)
		await _esperar_recuperacion("light")
	_check(not is_instance_valid(crate), "Rompible: se rompe al 3er golpe")
	_check(int(_progresion().fragmentos) > frag_antes, "Rompible: otorga un fragmento al romperse")

	# --- Pickup: recarga la energía ---
	_player.energia = 20.0
	await process_frame
	var pickup: Node2D = preload("res://scenes/pickup.tscn").instantiate()
	_scene.add_child(pickup)
	pickup.global_position = _player.global_position
	await _wait_frames(6)
	_check(_player.energia > 20.0, "Pickup: recarga la energía del espíritu")

	# --- Consola: god y mv ---
	_console._ejecutar(PackedStringArray(["god"]))
	_check(_player.god_mode == true, "Consola 'god' activa invencibilidad")
	_console._ejecutar(PackedStringArray(["god"]))
	_check(_player.god_mode == false, "Consola 'god' desactiva invencibilidad")
	_player.take_damage(50)
	_console._ejecutar(PackedStringArray(["mv"]))
	_check(_player.health == 100, "Consola 'mv' restaura la vida")

	# --- Consola: toggle alterna la visibilidad (sin pausa en este diseño) ---
	_console.toggle()
	_check(_console.panel.visible == true, "Consola: toggle abre el panel")

	# --- LevelUp: subir nivel abre el menú y elegir desbloquea el combo (J+K) ---
	_console.toggle()
	_progresion().reset()
	var lvl: CanvasLayer = _scene.get_node("LevelUp")
	lvl.call("cerrar")
	await process_frame
	var desbloqueos: Array[String] = []
	_progresion().combo_desbloqueado.connect(func(_f: int, nombre: String) -> void:
		desbloqueos.append(nombre)
	)
	_check(lvl.get("panel").visible == false, "LevelUp: menú cerrado al inicio")
	_progresion().add_fragmentos(3)
	await process_frame
	_check(lvl.get("panel").visible == true, "LevelUp: subir nivel abre el menú")
	_check(int(lvl.get("_opciones").size()) == 4, "LevelUp: ofrece las 4 transformaciones desbloqueadas")
	lvl.call("_confirmar")
	await process_frame
	_check(lvl.get("panel").visible == false, "LevelUp: confirmar cierra el menú")
	_check(desbloqueos.size() == 1 and desbloqueos[0] == "Remate", "LevelUp: elegir desbloquea el combo del humano (%s)" % (desbloqueos[0] if not desbloqueos.is_empty() else "-"))
	_check(_progresion().combos_desbloqueados_forma(0) == 1, "LevelUp: combo del humano desbloqueado tras elegir")

	print("AUTOTEST: FALLOS = " + str(_failures))
	if _failures == 0:
		print("AUTOTEST: TODOS LOS TESTS PASARON")
		quit(0)
	else:
		print("AUTOTEST: " + str(_failures) + " TEST(S) FALLARON")
		quit(1)


func _spawn_dummy(offset: Vector2 = Vector2.ZERO) -> Node2D:
	var dummy := StaticBody2D.new()
	var col := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = Vector2(36, 36)
	col.shape = shape
	dummy.add_child(col)
	dummy.set_script(load("res://tests/dummy.gd"))
	_scene.add_child(dummy)
	dummy.global_position = _player.global_position + offset
	return dummy


func _limpiar_dummies() -> void:
	var dummy_script := load("res://tests/dummy.gd")
	for child in _scene.get_children():
		if child.get_script() == dummy_script:
			child.queue_free()
	await physics_frame
	await physics_frame


func _limpiar_enemigos() -> void:
	for child in _scene.get_children():
		if child.is_in_group("enemy"):
			child.queue_free()
	await physics_frame
	await physics_frame


func _check(cond: bool, msg: String) -> void:
	if cond:
		print("[PASS] " + msg)
	else:
		print("[FAIL] " + msg)
		_failures += 1


func _wait_frames(n: int) -> void:
	for i in range(n):
		await physics_frame


func _esperar_recuperacion(ataque: String) -> void:
	var frames := 32
	match ataque:
		"light":
			frames = 32
		"heavy":
			frames = 50
		"special":
			frames = 74
		"combo":
			frames = 92
	await _wait_frames(frames)


func _funcion_tronco() -> void:
	# Plataforma de test: suelo plano a una altura fija para el player
	var plataforma := StaticBody2D.new()
	var pcol := CollisionShape2D.new()
	var pshape := RectangleShape2D.new()
	pshape.size = Vector2(1200, 40)
	pcol.shape = pshape
	plataforma.add_child(pcol)
	_scene.add_child(plataforma)
	plataforma.global_position = Vector2(600, 1000)

	# Tronco fresco sobre la plataforma, a la derecha del player
	_console._ejecutar(PackedStringArray(["form", "humano"]))
	_player.global_position = Vector2(480, 900)
	_player.velocity = Vector2.ZERO
	await _wait_frames(60)
	_check(_player.is_on_floor(), "Interact: el player reposa en el suelo")

	var tronco: Node2D = preload("res://scenes/tronco.tscn").instantiate()
	_scene.add_child(tronco)
	tronco.global_position = _player.global_position + Vector2(130, 0)
	await _wait_frames(3)
	_check(is_instance_valid(tronco), "Tronco presente para la prueba")

	_player.velocity = Vector2.ZERO
	_player.facing = 1
	await physics_frame
	# Humano: el special NO rompe el tronco (requiere Oso)
	Input.action_press("special")
	await physics_frame
	await physics_frame
	Input.action_release("special")
	await _esperar_recuperacion("special")
	_check(is_instance_valid(tronco), "Interact: humano NO rompe el tronco")

	# Oso: el special sí lo rompe
	_console._ejecutar(PackedStringArray(["form", "oso"]))
	_player.velocity = Vector2.ZERO
	_player.facing = 1
	await physics_frame
	Input.action_press("special")
	await physics_frame
	await physics_frame
	Input.action_release("special")
	await _wait_frames(20)
	_check(not is_instance_valid(tronco), "Interact: oso rompe el tronco")

	_console._ejecutar(PackedStringArray(["form", "humano"]))
	await process_frame
	plataforma.queue_free()


func _progresion() -> Node:
	return root.get_node("Progresion")


func _count_projectiles() -> int:
	var count := 0
	for child in _scene.get_children():
		if child.name.begins_with("Projectile"):
			count += 1
	return count

