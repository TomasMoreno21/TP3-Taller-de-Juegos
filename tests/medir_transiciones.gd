extends SceneTree
## Herramienta manual (necesita ventana, sin --headless). Mide ANTES/DESPUÉS de las mejoras de animación:
##  D1) salida del golpe: cuánto cambia la imagen del personaje de un frame a otro al terminar el ataque.
##  D2) piernas al arrancar: diferencia entre la velocidad de las piernas y la del cuerpo (patinaje).
##  E)  recibir daño en pleno avance del golpe: hacia dónde va el cuerpo.
## godot --path . --resolution 1280x720 --script res://tests/medir_transiciones.gd

func _suelo(raiz: Node) -> void:
	var s := StaticBody2D.new()
	var cs := CollisionShape2D.new()
	var r := RectangleShape2D.new()
	r.size = Vector2(6000, 200)
	cs.shape = r
	s.add_child(cs)
	s.position = Vector2(640, 700)
	raiz.add_child(s)


func _jugador(raiz: Node, forma: int) -> CharacterBody2D:
	var p: CharacterBody2D = load("res://scenes/player.tscn").instantiate()
	p.position = Vector2(400, 400)
	raiz.add_child(p)
	if forma > 0:
		p.set("current_form", forma)
		p.call("_apply_form")
	return p


func _dif(a: Image, b: Image) -> float:
	var suma := 0.0
	var n := 0
	for y in range(0, a.get_height(), 2):
		for x in range(150, 700, 2):
			var ca := a.get_pixel(x, y)
			var cb := b.get_pixel(x, y)
			suma += absf(ca.r - cb.r) + absf(ca.g - cb.g) + absf(ca.b - cb.b)
			n += 1
	return suma / float(n)


func _salida_ataque(dur: float) -> String:
	var raiz := Node2D.new()
	root.add_child(raiz)
	_suelo(raiz)
	var p := _jugador(raiz, 0)
	p.set("transicion_salida_ataque", dur)
	for i in 40:
		await physics_frame
	Input.action_press("attack")
	await physics_frame
	await physics_frame
	Input.action_release("attack")
	var prev: Image = root.get_texture().get_image()
	var difs: Array[float] = []
	var fin := -1
	for i in 60:
		await process_frame
		var im: Image = root.get_texture().get_image()
		var cola: Array = p.get("_attack_anim_cola")
		if fin < 0 and cola.is_empty():
			fin = i
		if fin >= 0 and i >= fin - 1 and difs.size() < 8:
			difs.append(_dif(prev, im))
		prev = im
	raiz.queue_free()
	await process_frame
	var txt := ""
	var pico := 0.0
	for d in difs:
		txt += " %.4f" % d
		pico = maxf(pico, d)
	return "pico=%.4f  diferencia por frame al salir:%s" % [pico, txt]


func _arranque(piso: float) -> String:
	var raiz := Node2D.new()
	root.add_child(raiz)
	_suelo(raiz)
	var p := _jugador(raiz, 0)
	p.set("piernas_vel_min", piso)
	for i in 40:
		await physics_frame
	var vis: AnimatedSprite2D = p.get("visual")
	Input.action_press("move_right")
	var desv := 0.0
	var n := 0
	for i in 40:
		await physics_frame
		var r := absf(p.velocity.x) / maxf(float(p.get("forms")[0].speed), 1.0)
		if r > 0.02 and r < 0.35 and vis.animation == "run":
			desv += absf(vis.speed_scale - r)
			n += 1
	Input.action_release("move_right")
	raiz.queue_free()
	await process_frame
	return "frames con arranque lento=%d  desajuste medio piernas/cuerpo=%.3f" % [n, desv / maxf(float(n), 1.0)]


func _dano(en_ataque: bool) -> String:
	var raiz := Node2D.new()
	root.add_child(raiz)
	_suelo(raiz)
	var p := _jugador(raiz, 1)   # Lobo: tiene avance (lunge) al golpear
	p.set("reaccion_dano_en_ataque", en_ataque)
	for i in 40:
		await physics_frame
	var x0: float = p.global_position.x
	Input.action_press("attack")
	await physics_frame
	await physics_frame
	Input.action_release("attack")
	await physics_frame
	var lunge: float = p.get("_lunge_t")
	p.call("take_damage", 5, 420.0, -1)
	var vs := ""
	var xmax := p.global_position.x
	for i in 10:
		await physics_frame
		vs += " %.0f" % p.velocity.x
		xmax = maxf(xmax, p.global_position.x)
	var dx: float = p.global_position.x - x0
	raiz.queue_free()
	await process_frame
	return "avance activo al recibir=%.2fs  velocidad.x frame a frame:%s  desplazamiento neto=%.0f px (negativo = lo empuja hacia atrás)" % [lunge, vs, dx]


func _initialize() -> void:
	print("== D1 salida del golpe (Humano, ataque ligero)")
	print("  ANTES   (corte seco):  ", await _salida_ataque(0.0))
	print("  DESPUÉS (disolución):  ", await _salida_ataque(0.12))
	print("== D2 piernas al arrancar")
	print("  ANTES   (piso 0.35):   ", await _arranque(0.35))
	print("  DESPUÉS (piso 0.15):   ", await _arranque(0.15))
	print("== E daño en pleno golpe (Lobo)")
	print("  ANTES:   ", await _dano(false))
	print("  DESPUÉS: ", await _dano(true))
	quit()
