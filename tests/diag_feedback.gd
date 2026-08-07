extends SceneTree

var _failures := 0


func _init() -> void:
	var scene = load("res://scenes/main.tscn").instantiate()
	root.add_child(scene)
	await process_frame
	await process_frame
	var player = scene.get_node("Player")
	var enemy = scene.get_node("Level/Enemy")
	var cam = player.get_node("Camera2D")

	var casos := [
		{"form": 0, "label": "Humano", "shake_max": 7.5, "rotation_max": 9.0},
		{"form": 1, "label": "Oso", "shake_min": 12.0, "rotation_min": 12.0},
		{"form": 2, "label": "Lobo", "shake_max": 6.0, "zoom": true},
		{"form": 3, "label": "Búho", "shake_min": 6.0, "shake_max": 11.0},
	]
	for caso in casos:
		for i in range(20):
			await process_frame
		player.set_form(caso["form"])
		player.global_position = enemy.global_position - Vector2(30, 0)
		player.facing = 1
		await physics_frame
		var max_shake := 0.0
		var max_rot := 0.0
		var vio_zoom := false
		Input.action_press("attack")
		await physics_frame
		await physics_frame
		Input.action_release("attack")
		for i in range(12):
			await process_frame
			max_shake = max(max_shake, cam.offset.length())
			max_rot = max(max_rot, absf(enemy.visual.rotation))
			if cam.zoom.x > 1.01:
				vio_zoom = true
		if caso.has("shake_max"):
			_check(max_shake < caso["shake_max"], "%s: shake acotado (%.2f < %.2f)" % [caso["label"], max_shake, caso["shake_max"]])
		if caso.has("shake_min"):
			_check(max_shake >= caso["shake_min"], "%s: shake suficiente (%.2f >= %.2f)" % [caso["label"], max_shake, caso["shake_min"]])
		if caso.has("rotation_max"):
			_check(max_rot < deg_to_rad(caso["rotation_max"]), "%s: rotación acotada (%.2f°)" % [caso["label"], rad_to_deg(max_rot)])
		if caso.has("rotation_min"):
			_check(max_rot >= deg_to_rad(caso["rotation_min"]), "%s: rotación fuerte (%.2f° >= %.2f°)" % [caso["label"], rad_to_deg(max_rot), caso["rotation_min"]])
		if caso.has("zoom"):
			_check(vio_zoom, "%s: zoom de cámara leve" % caso["label"])
		else:
			_check(not vio_zoom, "%s: sin zoom" % caso["label"])

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
