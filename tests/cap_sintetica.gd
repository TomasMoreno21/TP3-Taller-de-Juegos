extends SceneTree


func _init() -> void:
	var canvas := Node2D.new()
	var poly := Polygon2D.new()
	poly.color = Color(1, 0, 0, 1)
	poly.polygon = PackedVector2Array([Vector2(0, 0), Vector2(200, 0), Vector2(200, 200), Vector2(0, 200)])
	canvas.add_child(poly)
	root.add_child(canvas)
	for i in range(10):
		await process_frame
	await RenderingServer.frame_post_draw
	var img := root.get_texture().get_image()
	img.save_png("res://tests/captura_sintetica.png")
	print("SINTETICA GUARDADA")
	quit(0)
