extends SceneTree

var _failures := 0


func _init() -> void:
	var scene = load("res://scenes/main.tscn").instantiate()
	root.add_child(scene)
	await process_frame
	await process_frame
	var hud = scene.get_node("Hud")
	var player = scene.get_node("Player")

	var hp_bar = hud.get_node("Bars/Rows/HpRow/HpBar")
	var esp_bar = hud.get_node("Bars/Rows/EspRow/EspBar")

	player.take_damage(30)
	await process_frame
	_check(hp_bar.value == 70, "HUD: barra refleja el daño (70). Es: " + str(hp_bar.value))

	player.heal_full()
	await process_frame
	_check(hp_bar.value == 100, "HUD: heal_full restaura la barra (100). Es: " + str(hp_bar.value))

	# Al transformarse (drena energía) la barra de espíritu baja
	player.current_form = 1
	player._transformar(1)
	await process_frame
	for i in range(40):
		await physics_frame
	_check(esp_bar.value < 99.0, "HUD: barra de espíritu baja al transformarse con drenaje. Es: " + str(esp_bar.value))

	var aviso = hud.get_node("Aviso")
	# Cambio real de forma dispara la señal form_changed -> aviso
	player.current_form = 0
	player._transformar(1)
	await process_frame
	_check(aviso.text.contains("Lobo"), "HUD: aviso muestra el cambio de forma: " + aviso.text)

	print("DIAG HUD: FALLOS = " + str(_failures))
	if _failures == 0:
		print("DIAG HUD: OK")
		quit(0)
	else:
		quit(1)


func _check(cond: bool, msg: String) -> void:
	if cond:
		print("[PASS] " + msg)
	else:
		print("[FAIL] " + msg)
		_failures += 1