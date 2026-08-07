extends SceneTree


func _init() -> void:
	var img := Image.create(64, 64, false, Image.FORMAT_RGBA8)
	img.fill(Color(1, 0, 0, 1))
	img.save_png("res://tests/prueba.png")
	print("PRUEBA GUARDADA")
	quit(0)
