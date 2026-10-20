extends SceneTree
## Capturas del jefe en su arena (con ventana): godot --path . --resolution 1920x1080 --script res://tests/captura_jefe.gd -- <dir>
func _initialize() -> void:
	var a := OS.get_cmdline_user_args()
	var nivel: Node = load("res://scenes/nivel_jefe.tscn").instantiate()
	root.add_child(nivel)
	await physics_frame
	await physics_frame
	var player := get_first_node_in_group("player") as CharacterBody2D
	player.set("god_mode", true)
	for o in ["Oleada1", "Oleada2", "Oleada3", "DialogoIntro"]:
		if nivel.has_node(o):
			nivel.get_node(o).queue_free()  # sin oleadas previas ni diálogo
	var enc = get_first_node_in_group("encounter")
	player.global_position = Vector2(enc.arena_center.x - 500.0, 827.0)
	enc.empezar()
	DirAccess.make_dir_recursive_absolute(a[0])
	for i in 10:
		for k in 200:
			await physics_frame
		await RenderingServer.frame_post_draw
		root.get_viewport().get_texture().get_image().save_png("%s/j%d.png" % [a[0], i])
	quit()
