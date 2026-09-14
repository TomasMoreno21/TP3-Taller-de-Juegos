extends SceneTree

var _failures := 0


func _init() -> void:
	var scene = load("res://scenes/nivel_jefe.tscn").instantiate()
	_quitar_dialogos_automaticos(scene)
	root.add_child(scene)
	await process_frame
	await process_frame

	var player = scene.get_node("Player")
	player.god_mode = true

	var encounter = get_first_node_in_group("encounter")
	var boss = get_first_node_in_group("boss")
	var hud = scene.get_node("Hud")

	_check(boss != null and encounter != null, "La arena carga jefe y encuentro")
	if boss == null or encounter == null:
		_fin()
		return

	_check(boss.health == boss.vida_max, "El jefe arranca con vida llena: %d" % boss.health)

	# El jefe debe arrancar DENTRO de la arena (las paredes del Encounter
	# encierran al jugador; si el boss quedara fuera sería invisible e inatacable).
	var dentro: bool = absf(boss.global_position.x - encounter.arena_center.x) <= encounter.arena_medio_ancho
	_check(dentro, "El jefe arranca dentro de la arena (llegable y visible)")

	# El jugador se ubica en la arena para que el boss presida cerca del centro.
	player.global_position = Vector2(encounter.arena_center.x + 220, 1000)

	# --- La pelea arranca con el Encounter (como en el juego). ---
	encounter.empezar()
	await _esperar_gate(boss, "legion")
	_check(boss._activo, "La pelea se activa")
	await process_frame
	_check(hud.boss_bar.visible, "La barra del jefe se muestra al activar la pelea")

	# El jefe flota arriba (preside la arena), no en el suelo.
	_check(boss.global_position.y < boss._piso_y - 120.0, "El jefe flota arriba de la arena (y=%.0f)" % boss.global_position.y)

	# --- Barrera 1: Legión de cultistas (escudo = invulnerable). ---
	var tam_legion: int = boss._legion_size()
	_check(boss._shield_active, "El jefe tiene escudo durante la Legión")
	_check(boss._legion_vivos == tam_legion, "La Legión invoca %d cultistas" % tam_legion)
	var hp0: int = boss.health
	boss.take_damage(30, 0, 1, false)
	await process_frame
	_check(boss.health == hp0, "El golpe flojo (30) es absorbido por el escudo de la Legión")

	# Matar la Legión abre la puerta.
	for e in boss._invocados.duplicate():
		e.take_damage(9999, 0, 1, false)
	await _esperar_cond(boss, "_legion_vivos", 0, 200)
	_check(boss._legion_vivos == 0, "La Legión muere entera")

	# --- Barrera 2: cristales de energía (solo sónico del Murciélago). ---
	await _esperar_gate(boss, "cristales")
	_check(boss._cristales_vivos == boss.cristales_por_ciclo, "Invoca %d cristales de escudo" % boss.cristales_por_ciclo)
	_check(boss._shield_active, "Sigue con escudo mientras hay cristales")

	player.current_form = 3
	var intentos := 0
	while boss._cristales_vivos > 0 and intentos < 60:
		for c in get_nodes_in_group("cristal"):
			if is_instance_valid(c) and not c.is_queued_for_deletion():
				c.take_damage(30)
		await _wait_frames(2)
		intentos += 1
	_check(boss._cristales_vivos == 0, "El Murciélago rompe todos los cristales")

	# --- Barrera 3: zona marcada (daño real). ---
	await _esperar_gate(boss, "zona")
	_check(not boss._shield_active, "El escudo cae al romper los cristales")
	_check(boss.zona.visible, "La zona marcada se muestra al alcance del jugador")
	hp0 = boss.health
	boss.zona.take_damage(30, 0, 1, false)
	await process_frame
	_check(boss.health == hp0 - boss.dano_zona, "Un golpe en la zona quita %d de vida" % boss.dano_zona)

	# Muerte: un último golpe en la zona con 1 de vida.
	boss.set("health", 1)
	boss.died.connect(_on_boss_died_test)
	boss.zona.take_damage(30, 0, 1, false)
	await _wait_frames(6)
	_check(boss._muerto, "El jefe muere al llegar a 0 de vida")
	_check(_murio, "Se emite la señal died")
	await process_frame
	_check(not hud.boss_bar.visible, "La barra del jefe se oculta al morir")

	_fin()


var _murio := false


func _on_boss_died_test() -> void:
	_murio = true


func _esperar_gate(boss: Node, gate: String) -> void:
	for i in range(300):
		if boss._gate == gate:
			return
		await physics_frame


func _esperar_cond(boss: Node, prop: String, valor: int, frames: int) -> void:
	for i in range(frames):
		if int(boss.get(prop)) <= valor:
			return
		await physics_frame


func _wait_frames(n: int) -> void:
	for i in range(n):
		await physics_frame


func _quitar_dialogos_automaticos(nodo: Node) -> void:
	for hijo in nodo.get_children():
		_quitar_dialogos_automaticos(hijo)
	var script: Script = nodo.get_script()
	if script != null and script.resource_path == "res://scripts/dialog_trigger.gd":
		nodo.get_parent().remove_child(nodo)
		nodo.free()


func _check(cond: bool, msg: String) -> void:
	if cond:
		print("[PASS] " + msg)
	else:
		print("[FAIL] " + msg)
		_failures += 1


func _fin() -> void:
	print("DIAG JEFE: FALLOS = " + str(_failures))
	if _failures == 0:
		print("DIAG JEFE: OK")
		quit(0)
	else:
		quit(1)