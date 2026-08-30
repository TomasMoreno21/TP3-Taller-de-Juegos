extends SceneTree

var _failures := 0


func _init() -> void:
	var scene = load("res://scenes/main.tscn").instantiate()
	root.add_child(scene)
	await process_frame
	await process_frame
	var player = scene.get_node("Player")

	# Feedback real de combate: el ataque dentro del área daña y el área se reactiva por golpe
	var dummy := StaticBody2D.new()
	var col := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = Vector2(36, 36)
	col.shape = shape
	dummy.add_child(col)
	dummy.set_script(load("res://tests/dummy.gd"))
	scene.add_child(dummy)
	dummy.global_position = player.global_position + Vector2(40, 0)
	await _wait_frames(3)
	var dmg_before: int = dummy.health
	player.facing = 1
	player.velocity = Vector2.ZERO
	Input.action_press("attack")
	await physics_frame
	await physics_frame
	Input.action_release("attack")
	await _esperar_recuperacion("light")
	_check(dummy.health < dmg_before, "Feedback: el ataque daña dentro del área (%d -> %d)" % [dmg_before, dummy.health])

	# El área de ataque se habilita al atacar y se desactiva al terminar
	var attack_area: Area2D = player.get_node("AttackArea")
	var hitbox: CollisionShape2D = player.get_node("AttackArea/AttackHitbox")
	_check(attack_area.monitoring == false, "Feedback: área desactivada en reposo")
	_check(hitbox.disabled == true, "Feedback: hitbox desactivado en reposo")
	Input.action_press("attack")
	await physics_frame
	await physics_frame
	Input.action_release("attack")
	await physics_frame
	_check(attack_area.monitoring == true, "Feedback: área activa durante el ataque")
	await _esperar_recuperacion("light")
	_check(attack_area.monitoring == false, "Feedback: área desactivada tras el ataque")

	print("DIAG FEEDBACK: FALLOS = " + str(_failures))
	if _failures == 0:
		print("DIAG FEEDBACK: OK")
		quit(0)
	else:
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


func _esperar_recuperacion(ataque: String) -> void:
	var frames := 20
	match ataque:
		"light":
			frames = 20
	await _wait_frames(frames)
