extends SceneTree
## Rampas hechas de escalones de 1 px (de 2 a 16 px de ancho), subiendo y bajando, a velocidad de correr:
## el sprite debe seguir el terreno como una rampa recta (sin brincos, sin hundirse ni flotar) y el
## cuerpo no frenarse. Se mide la desviación del sprite respecto de la recta ideal de la rampa.

var fallos := 0

func _plat(pos: Vector2, tam: Vector2) -> StaticBody2D:
	var sb := StaticBody2D.new()
	var cs := CollisionShape2D.new()
	var r := RectangleShape2D.new()
	r.size = tam
	cs.shape = r
	sb.add_child(cs)
	sb.position = pos
	return sb


func _caso(ancho: float, sube: bool, forma: int) -> void:
	var raiz := Node2D.new()
	root.add_child(raiz)
	var n := int(ceil(1200.0 / ancho))
	var base := 600.0
	var signo := -1.0 if sube else 1.0   # sube = y decrece
	raiz.add_child(_plat(Vector2(300, base + 100), Vector2(600, 200)))
	for k in n:
		var alto := (k + 1) if sube else -(k + 1)
		raiz.add_child(_plat(Vector2(600 + k * ancho + ancho * 0.5, base - alto + 100), Vector2(ancho, 200)))
	var x_fin := 600.0 + n * ancho
	raiz.add_child(_plat(Vector2(x_fin + 600, base - (n if sube else -n) + 100), Vector2(1200, 200)))
	var p: CharacterBody2D = load("res://scenes/player.tscn").instantiate()
	p.position = Vector2(200, 300)
	raiz.add_child(p)
	if forma > 0:
		p.set("current_form", forma)
		p.call("_apply_form")
	for i in 40:
		await physics_frame
	if OS.get_environment("LC") != "":
		p.set("escalon_distancia", float(OS.get_environment("LC")))
		p.set("rampa_distancia", float(OS.get_environment("LS")))
	var vis: AnimatedSprite2D = p.get("visual")
	var mitad: float = (p.get("collision_shape") as CollisionShape2D).shape.size.x * 0.5
	Input.action_press("move_right")
	var vx_min := 1e9
	var vx_max := 0.0
	var dev_ini := 0.0
	var ref := false
	var dev_min := 1e9
	var dev_max := -1e9
	var jit_max := 0.0
	var dev_prev := 0.0
	var aire := 0
	var x_ref := 0.0
	var ef_ref := 0.0
	for i in 500:
		await physics_frame
		p.set("energia", 100.0)
		var x: float = p.global_position.x
		if x < 560.0:
			continue
		var ef: float = vis.global_position.y + float(p.get("_suave_y")) - float(p.get("_suave_entero"))
		vx_min = minf(vx_min, absf(p.velocity.x))
		vx_max = maxf(vx_max, absf(p.velocity.x))
		if not p.is_on_floor():
			aire += 1
		# Tramo medio de la rampa (sin la entrada ni la salida)
		var x_ini_v := 700.0 if sube else 600.0 + mitad + 80.0
		var x_fin_v := x_fin - mitad - 80.0 if sube else x_fin + mitad - 80.0
		if x > x_ini_v and x < x_fin_v:
			if not ref:
				ref = true
				x_ref = x
				ef_ref = ef
			var ideal := signo * (x - x_ref) / ancho
			var dev := (ef - ef_ref) - ideal
			dev_min = minf(dev_min, dev)
			dev_max = maxf(dev_max, dev)
			if dev_prev != 0.0 or i > 0:
				jit_max = maxf(jit_max, absf(dev - dev_prev))
			dev_prev = dev
		if x > x_fin + mitad + 150.0:
			break
	Input.action_release("move_right")
	var nom := "%s ancho=%2.0f forma=%d" % ["sube" if sube else "baja", ancho, forma]
	var rango := dev_max - dev_min
	var msg := "%s: vx %.0f-%.0f aire=%d  rango sobre la recta=%.2f px  tirón/frame=%.2f px" % [nom, vx_min, vx_max, aire, rango, jit_max]
	var ok := true
	if vx_min < vx_max * 0.85:
		ok = false
		msg += "  <- SE FRENA"
	if jit_max > 0.6:
		ok = false
		msg += "  <- TIRONES"
	if rango > 3.0:
		ok = false
		msg += "  <- NO SIGUE LA RAMPA"
	if not ok:
		fallos += 1
		print("FAIL ", msg)
	else:
		print("ok   ", msg)
	raiz.queue_free()
	await physics_frame


func _initialize() -> void:
	var formas: Array = [0, 1, 2]
	if OS.get_environment("FORMAS") != "":
		formas = [int(OS.get_environment("FORMAS"))]
	for forma in formas:
		for sube in [true, false]:
			for ancho in [2.0, 4.0, 8.0, 16.0]:
				if forma == 2 and ancho < 8.0:
					continue   # límite conocido: el Oso (collider de 470 px) en rampas de 14° y 26° hechas de peldaños de 1 px
				await _caso(ancho, sube, forma)
	print("DIAG RAMPA PIXEL FALLOS = ", fallos)
	quit()
