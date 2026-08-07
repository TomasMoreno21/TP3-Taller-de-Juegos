extends SceneTree


func _init() -> void:
	var img := Image.load_from_file("res://tests/prueba.png")
	print("PRUEBA leída: %dx%d color=%s" % [img.get_width(), img.get_height(), img.get_pixel(32, 32).to_html(false)])
	quit(0)
