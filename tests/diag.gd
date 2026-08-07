extends SceneTree


func _init() -> void:
	for action in ["move_left", "move_right", "jump", "attack", "transform", "console_toggle"]:
		var has := InputMap.has_action(action)
		var count := 0
		if has:
			count = InputMap.action_get_events(action).size()
		print("[DIAG] action=%s exists=%s events=%d" % [action, has, count])

	var scene = load("res://scenes/main.tscn").instantiate()
	root.add_child(scene)
	await process_frame
	await process_frame
	var player = scene.get_node("Player")
	print("[DIAG] player=%s form=%d pos=%s" % [player, player.current_form, player.global_position])
	await physics_frame
	await physics_frame
	await physics_frame
	print("[DIAG] pos tras 3 frames fisica=%s" % player.global_position)

	var start_x: float = player.global_position.x
	Input.action_press("move_right")
	for i in range(10):
		await physics_frame
	Input.action_release("move_right")
	print("[DIAG] pos X inicio=%.1f -> fin=%.1f (movimiento horizontal: %s)" % [start_x, player.global_position.x, "OK" if player.global_position.x > start_x else "FALLO"])

	Input.action_press("attack")
	await physics_frame
	Input.action_release("attack")
	print("[DIAG] attack procesado sin error")
	quit(0)
