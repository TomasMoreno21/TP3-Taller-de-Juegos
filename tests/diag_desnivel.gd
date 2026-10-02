extends SceneTree
## Desniveles de 1 px: el cuerpo sube/baja de golpe pero el sprite debe moverse suave (sin saltos > 0.6 px por frame).

func _plataforma(pos: Vector2, tam: Vector2) -> StaticBody2D:
	var sb := StaticBody2D.new()
	var cs := CollisionShape2D.new()
	var r := RectangleShape2D.new()
	r.size = tam
	cs.shape = r
	sb.add_child(cs)
	sb.position = pos
	return sb


func _initialize() -> void:
	var fallos := 0
	# Piso a y=500 hasta x=1000; escalón de 1 px hacia arriba (y=499) hasta x=2000; vuelve a 500.
	root.add_child(_plataforma(Vector2(500, 600), Vector2(1000, 200)))
	root.add_child(_plataforma(Vector2(1500, 599), Vector2(1000, 200)))
	root.add_child(_plataforma(Vector2(2500, 600), Vector2(1000, 200)))
	# escalera de 1 px cada 120 px (x 3000-3600) para medir que no se frene
	for k in 5:
		root.add_child(_plataforma(Vector2(3060 + k * 120, 598 - k), Vector2(120, 200)))
	root.add_child(_plataforma(Vector2(3900, 592), Vector2(600, 200)))
	var player: CharacterBody2D = load("res://scenes/player.tscn").instantiate()
	player.position = Vector2(300, 300)
	root.add_child(player)
	for i in 40:
		await physics_frame
	if OS.get_environment("LC") != "":
		player.set("escalon_distancia", float(OS.get_environment("LC")))
		player.set("rampa_distancia", float(OS.get_environment("LS")))
	var visual: AnimatedSprite2D = player.get("visual")
	Input.action_press("move_right")
	var prev_vis := visual.global_position.y + float(player.get("_suave_y")) - float(player.get("_suave_entero"))
	var prev_body := player.global_position.y
	var max_vis := 0.0
	var max_body := 0.0
	var vx_max := 0.0
	var vx_min := 99999.0
	for i in 400:
		await physics_frame
		if player.global_position.x > 4000.0:
			break
		var efectivo := visual.global_position.y + float(player.get("_suave_y")) - float(player.get("_suave_entero"))
		var dv := absf(efectivo - prev_vis)
		if dv > 0.6:
			print("FAIL? frame %d x=%.0f dv=%.2f cuerpo=%.2f suave=%.2f" % [i, player.global_position.x, dv, player.global_position.y - prev_body, player.get("_suave_y")])
		max_vis = maxf(max_vis, dv)
		max_body = maxf(max_body, absf(player.global_position.y - prev_body))
		prev_vis = efectivo
		prev_body = player.global_position.y
		if player.global_position.x > 3100.0 and player.global_position.x < 3700.0:
			vx_min = minf(vx_min, absf(player.velocity.x))
			vx_max = maxf(vx_max, absf(player.velocity.x))
		player.set("energia", 100.0)
	Input.action_release("move_right")
	print("x final: ", player.global_position.x, "  salto máx cuerpo: ", max_body, "  salto máx sprite/frame: ", max_vis)
	if player.global_position.x < 1100.0:
		fallos += 1
		print("FAIL: no cruzó el escalón")
	if max_body < 0.9:
		fallos += 1
		print("FAIL: el cuerpo no subió el escalón (test inválido)")
	if max_vis > 0.5:
		fallos += 1
		print("FAIL: el sprite salta %.2f px en un frame" % max_vis)
	print("velocidad en la escalera: min %.0f  max %.0f" % [vx_min, vx_max])
	if vx_min < vx_max * 0.9:
		fallos += 1
		print("FAIL: se frena en los escalones (min %.0f de %.0f)" % [vx_min, vx_max])
	var suave: float = player.get("_suave_y")
	print("DIAG DESNIVEL FALLOS = ", fallos, " (desfase residual ", suave, ")")
	quit()
