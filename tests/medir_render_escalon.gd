extends SceneTree
## Herramienta manual (necesita ventana, sin --headless). Mide en el render REAL cómo decae el desfase
## de 1 px del sprite (centroide ponderado por color, en px): con suavizado sub-píxel debe bajar en
## muchos pasos chicos, no de golpe.
## godot --path . --resolution 1920x1080 --script res://tests/medir_render_escalon.gd

func _centroide(img: Image, fondo: Color) -> float:
	var suma := 0.0
	var peso := 0.0
	for y in range(0, img.get_height()):
		for x in range(200, 1000, 2):
			var c := img.get_pixel(x, y)
			var w := absf(c.r - fondo.r) + absf(c.g - fondo.g) + absf(c.b - fondo.b)
			suma += y * w
			peso += w
	return suma / maxf(peso, 0.0001)


func _initialize() -> void:
	var fondo := Color(0.4588, 0.498, 0.3804)
	var player: CharacterBody2D = load("res://scenes/player.tscn").instantiate()
	player.position = Vector2(500, 600)
	root.add_child(player)
	for i in 30:
		await process_frame
	player.set_physics_process(false)
	player.set("respiracion_amp", 0.0)
	var vis: AnimatedSprite2D = player.get("visual")
	vis.pause()
	vis.speed_scale = 0.0
	await process_frame
	await process_frame
	var base := _centroide(root.get_texture().get_image(), fondo)
	player.set("_suave_y", 1.0)
	var serie: Array = []
	for i in 22:
		player.call("_suavizar_desnivel", 0.0, true, 1.0 / 60.0)
		await process_frame
		await process_frame
		serie.append(_centroide(root.get_texture().get_image(), fondo) - base)
	var txt := ""
	var cambios := 0
	for i in serie.size():
		txt += " %.2f" % serie[i]
		if i > 0 and absf(float(serie[i]) - float(serie[i - 1])) > 0.03:
			cambios += 1
	print("desfase del centroide por frame (px):", txt)
	print("pasos distintos: ", cambios)
	quit()
