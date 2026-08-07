extends SceneTree


func _init() -> void:
	var img := Image.load_from_file("res://tests/captura.png")
	print("[SCREEN] tamaño: %dx%d" % [img.get_width(), img.get_height()])

	var suelo := false
	var plataforma := false
	var jugador := false
	var enemigo := false
	var total := 0
	var muestras := {}
	for y in range(0, img.get_height(), 8):
		for x in range(0, img.get_width(), 8):
			var c := img.get_pixel(x, y)
			if c.a < 0.1:
				continue
			total += 1
			if c.is_equal_approx(Color(0.16, 0.32, 0.18)) or c.is_equal_approx(Color(0.16, 0.32, 0.18, 1)):
				suelo = true
			if c.is_equal_approx(Color(0.34, 0.5, 0.26)) or c.is_equal_approx(Color(0.34, 0.5, 0.26, 1)):
				plataforma = true
			if c.is_equal_approx(Color(0.42, 0.62, 0.36)) or c.is_equal_approx(Color(0.42, 0.62, 0.36, 1)):
				jugador = true
			if c.is_equal_approx(Color(0.65, 0.22, 0.22)) or c.is_equal_approx(Color(0.65, 0.22, 0.22, 1)):
				enemigo = true

	print("[SCREEN] píxeles muestreados: %d" % total)
	print("[SCREEN] suelo presente: %s" % suelo)
	print("[SCREEN] plataforma presente: %s" % plataforma)
	print("[SCREEN] jugador presente: %s" % jugador)
	print("[SCREEN] enemigo presente: %s" % enemigo)

	var n = 0
	for y in range(0, img.get_height(), 48):
		for x in range(0, img.get_width(), 48):
			if n >= 20:
				break
			var c := img.get_pixel(x, y)
			muestras["%d,%d" % [x, y]] = "#%s" % c.to_html(false)
			n += 1
	print("[SCREEN] muestras de color (x,y -> hex): %s" % str(muestras))
	quit(0)
