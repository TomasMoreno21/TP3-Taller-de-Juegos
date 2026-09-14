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

	# La pelea se dispara con la API del encounter (como en el juego).
	encounter.empezar()
	await process_frame
	_check(boss._activo, "La pelea se activa")
	await process_frame
	_check(hud.boss_bar.visible, "La barra del jefe se muestra al activar la pelea")

	# Armadura de fase 1: los golpes flojos no pasan el umbral.
	var hp0: int = boss.health
	boss.take_damage(5, 0, 1, false)
	await process_frame
	_check(boss.health == hp0, "El golpe flojo (5) es absorbido por la armadura")
	_check(hud.boss_bar.visible, "La barra sigue visible tras un golpe absorbido")

	boss.take_damage(30, 0, 1, false)
	await process_frame
	_check(boss.health == hp0 - 30, "El golpe fuerte (30) penetra la armadura")

	# Fase 2: cristales que solo rompe el sónico del Murciélago.
	boss._cambiar_fase(boss.Fase.DOS)
	boss.set("_forzar_aereo", false)  # para el test: el ciclo aéreo no interviene
	boss._invocar_cristales()
	var cristales = get_nodes_in_group("cristal")
	_check(cristales.size() == boss.cristales_por_ciclo, "Invoca %d cristales de escudo" % cristales.size())
	_check(boss._cristales_vivos == cristales.size(), "Cuenta los cristales vivos")

	player.current_form = 0
	cristales[0].take_damage(30)
	await process_frame
	_check(int(cristales[0].get("_golpes")) == 0, "Un cristal ignora golpes sin el sónico")

	player.current_form = 3
	for c in cristales:
		c.take_damage(30)
	await process_frame
	for c in cristales:
		if is_instance_valid(c) and not c.is_queued_for_deletion():
			c.take_damage(30)
	await process_frame
	_check(boss._cristales_vivos == 0, "El Murciélago rompe todos los cristales")

	# Fase 3 y muerte.
	boss._cambiar_fase(boss.Fase.TRES)
	boss.died.connect(_on_boss_died_test)
	boss.set("health", 1)
	boss.take_damage(10, 0, 1, false)
	await _wait_frames(5)
	_check(boss._muerto, "El jefe muere al llegar a 0 de vida")
	_check(_murio, "Se emite la señal died")
	_check(not hud.boss_bar.visible, "La barra del jefe se oculta al morir")

	_fin()


var _murio := false


func _on_boss_died_test() -> void:
	_murio = true


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