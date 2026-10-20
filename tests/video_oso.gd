extends SceneTree
## Graba el ataque del Oso (spam ligero + combo Garra): godot --path . --write-movie out.avi --fixed-fps 30 --resolution 1280x720 --script res://tests/video_oso.gd

func _tap(action: String, espera: int = 2) -> void:
	Input.action_press(action)
	for i in 2:
		await physics_frame
	Input.action_release(action)
	for i in espera:
		await physics_frame


func _initialize() -> void:
	var nivel: Node = load("res://scenes/nivel1.tscn").instantiate()
	root.add_child(nivel)
	await physics_frame
	await physics_frame
	for t in get_nodes_in_group("titulo_nivel"):
		t.queue_free()
	for n in nivel.get_children():
		if n is IntroNivel:
			n.queue_free()
		elif n.get_script() != null and str(n.get_script().resource_path).ends_with("dialog_trigger.gd"):
			n.queue_free()
	for e in get_nodes_in_group("enemy"):
		e.queue_free()
	var player := get_first_node_in_group("player") as CharacterBody2D
	player.set("god_mode", true)
	player.set("cinematica_activa", false)
	var prog := root.get_node("Progresion")
	for f in 4:
		prog.desbloquear_forma(f)
		prog.combos_desbloqueados[f] = maxi(player.forms[f].combos.size(), 1)
	player.set("energia", 100.0)
	player._transformar(2, true)
	for i in 70:
		await physics_frame
	# Spam de ataque ligero
	for i in 7:
		await _tap("attack", 5)
	for i in 50:
		await physics_frame
	# Combo Garra: ligero + fuerte
	await _tap("attack", 4)
	await _tap("heavy", 2)
	for i in 150:
		await physics_frame
	quit()
