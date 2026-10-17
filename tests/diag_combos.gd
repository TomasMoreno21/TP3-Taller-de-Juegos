extends SceneTree
# Combos de level-up: Embestida del Lobo (atraviesa) y Tajo del Humano (frente y espalda).

var _failures := 0


func _init() -> void:
	var scene = load("res://scenes/nivel1.tscn").instantiate()
	_quitar_dialogos_automaticos(scene)
	root.add_child(scene)
	await process_frame
	await process_frame
	var player = scene.get_node("Player")
	await _embestida_lobo(scene, player)
	await _tajo_humano(scene, player)
	print("DIAG COMBOS: FALLOS = " + str(_failures))
	quit(0 if _failures == 0 else 1)


func _spawn(scene: Node, pos: Vector2) -> Node:
	var e = preload("res://scenes/enemy.tscn").instantiate()
	e.tipo = "cultista"
	scene.add_child(e)
	e.global_position = pos
	return e


func _embestida_lobo(scene: Node, player: Node) -> void:
	player._transformar(1, true)
	await _wait_frames(30)
	var base: Vector2 = player.global_position
	var e1 := _spawn(scene, base + Vector2(220, 0))
	var e2 := _spawn(scene, base + Vector2(380, 0))
	await _wait_frames(40)
	base = player.global_position
	var hp1: int = e1.health
	var hp2: int = e2.health
	player.facing = 1
	player._ejecutar_finisher(player.forms[1], player.forms[1].combos[0])
	await _wait_frames(30)
	_check(player.global_position.x - base.x > 250.0, "Embestida: el Lobo avanza (%.0f px)" % (player.global_position.x - base.x))
	_check(e1.health < hp1, "Embestida: golpea al 1.º enemigo (%d -> %d)" % [hp1, e1.health])
	_check(e2.health < hp2, "Embestida: golpea al 2.º enemigo (%d -> %d)" % [hp2, e2.health])


func _tajo_humano(scene: Node, player: Node) -> void:
	player._transformar(0, true)
	await _wait_frames(30)
	var base: Vector2 = player.global_position
	var delante := _spawn(scene, base + Vector2(120, 0))
	var detras := _spawn(scene, base + Vector2(-150, 0))
	await _wait_frames(40)
	var hpd: int = delante.health
	var hpt: int = detras.health
	player.facing = 1
	player._ejecutar_finisher(player.forms[0], player.forms[0].combos[0])
	await _wait_frames(30)
	_check(delante.health < hpd, "Tajo: golpea al frente (%d -> %d)" % [hpd, delante.health])
	_check(detras.health < hpt, "Tajo: golpea a la espalda (%d -> %d)" % [hpt, detras.health])


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
