extends SceneTree
## Graba muerte + cierre del jefe (destello, diálogo, frase, créditos): godot --path . --write-movie out.avi --fixed-fps 30 --resolution 1280x720 --script res://tests/video_final.gd

func _initialize() -> void:
	var nivel: Node = load("res://scenes/nivel_jefe.tscn").instantiate()
	root.add_child(nivel)
	await physics_frame
	await physics_frame
	for t in get_nodes_in_group("titulo_nivel"):
		t.queue_free()
	for n in nivel.get_children():
		if n is IntroNivel:
			n.queue_free()
	var boss := get_first_node_in_group("boss")
	var player := get_first_node_in_group("player") as CharacterBody2D
	player.set("god_mode", true)
	player.set("cinematica_activa", false)
	player.global_position = boss.global_position + Vector2(-700, -150)
	for i in 90:
		await physics_frame
	boss.set("_aparicion_vista", true)
	boss.cuerpo.visible = true
	boss.nudo.visible = true
	boss.cuerpo.position.y = -boss._altura_reposo
	for i in 45:
		await physics_frame
	boss.call("_morir")
	for i in 2400:
		await process_frame
	quit()
