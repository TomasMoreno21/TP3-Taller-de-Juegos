extends SceneTree


func _init() -> void:
	var scene = load("res://scenes/main.tscn").instantiate()
	root.add_child(scene)
	for i in range(45):
		await process_frame
	await RenderingServer.frame_post_draw
	var img := root.get_texture().get_image()
	img.save_png("res://tests/captura.png")

	var player = root.get_node("Player")
	var cam = root.get_node_or_null("Camera2D")
	var world = root.get_node("World")
	print("CAPTURA GUARDADA")
	print("DIAG player.visible=%s pos=%s scale=%s layer=%s" % [player.visible, player.global_position, player.scale, player.z_index])
	print("DIAG player is_visible_in_tree=%s" % player.is_visible_in_tree())
	print("DIAG cam=%s" % cam)
	print("DIAG world children=%d" % world.get_child_count())
	var suelo = world.get_node_or_null("Suelo")
	if suelo:
		print("DIAG Suelo pos=%s vis=%s" % [suelo.position, suelo.visible])
	quit(0)
