extends SceneTree

var _fallos := 0


func _check(cond: bool, msg: String) -> void:
	if cond:
		print("[PASS] " + msg)
	else:
		_fallos += 1
		print("[FAIL] " + msg)


func _crear_caja(pos: Vector2, size: Vector2, n: String) -> StaticBody2D:
	var body := StaticBody2D.new()
	body.name = n
	body.position = pos + Vector2(0, size.y * 0.5)
	body.collision_layer = 1
	var shape := CollisionShape2D.new()
	var rs := RectangleShape2D.new()
	rs.size = size
	shape.shape = rs
	body.add_child(shape)
	return body


# Cada escenario: piso_izq (top y=0, x -1000..0) + piso_der (top=-salto, x 0..1600).
func _correr(salto: float) -> void:
	root.add_child(_crear_caja(Vector2(-1000, 0), Vector2(1000, 60), "PisoIzq"))
	root.add_child(_crear_caja(Vector2(0, -salto), Vector2(1600, 60), "PisoDer"))
	var player: CharacterBody2D = load("res://scenes/player.tscn").instantiate()
	root.add_child(player)
	await physics_frame
	player.position = Vector2(-600, -200)
	for i in 100:
		await physics_frame

	# Borde inferior del collider = y + (pos.y + 159). El shape runtime es (-2,-16.5).
	var y_init: float = player.global_position.y
	player.facing = 1
	Input.action_press("move_right")
	for i in 90:
		await physics_frame
	Input.action_release("move_right")
	var y_fin: float = player.global_position.y
	var x_fin: float = player.global_position.x
	var offset_y: float = player.get_node("Collision").position.y + 159.0
	var b_inf: float = y_fin + offset_y  # debe ser ≈ top del piso_der (-salto)
	print("[INFO] salto=%s y_init=%s y_fin=%s x_fin=%s b_inf=%s top_piso_der=%s floor=%s" % [
		salto, snappedf(y_init, 0.001), snappedf(y_fin, 0.001), snappedf(x_fin, 0.1),
		snappedf(b_inf, 0.001), -salto, player.is_on_floor()])
	var cruzado: bool = x_fin > 50.0
	var apoyado: bool = player.is_on_floor() and absf(b_inf - (-salto)) < 6.0
	_check(cruzado, "salto=%s: superó la cara (x_fin=%s)" % [salto, snappedf(x_fin, 0.1)])
	_check(apoyado, "salto=%s: apoyado sobre piso_der (b_inf=%s top=%s)" % [
		salto, snappedf(b_inf, 0.001), -salto])

	for hijo in root.get_children():
		hijo.queue_free()
	await physics_frame
	await physics_frame


# Escalera: 3 peldaños de 1px consecutivos para probar fluidez (subir varios segudo).
func _correr_escalera() -> void:
	var peldaños: int = 3
	var caj := _crear_caja(Vector2(-1000, 0), Vector2(1000, 60), "PisoBase")  # x -1000..0
	root.add_child(caj)
	for i in range(peldaños):
		root.add_child(_crear_caja(
			Vector2(0 + i * 60.0, -float(i + 1)),
			Vector2(60, 60), "Peld" + str(i)))
	root.add_child(_crear_caja(Vector2(peldaños * 60.0, -float(peldaños)), Vector2(1600, 60), "PisoCima"))
	var player: CharacterBody2D = load("res://scenes/player.tscn").instantiate()
	root.add_child(player)
	await physics_frame
	player.position = Vector2(-600, -200)
	for i in 100:
		await physics_frame
	var y0: float = player.global_position.y
	player.facing = 1
	Input.action_press("move_right")
	var cont_frames := 0
	var max_x_pre: float = -1e9
	for i in 120:
		await physics_frame
		cont_frames += 1
		max_x_pre = maxf(max_x_pre, player.global_position.x)
	Input.action_release("move_right")
	var x_fin: float = player.global_position.x
	var y_fin: float = player.global_position.y
	var offset_y: float = player.get_node("Collision").position.y + 159.0
	var b_inf_fin: float = y_fin + offset_y  # borde inf debe apoyar en top de la cima (-3)
	print("[INFO] escalera x_fin=%s y0=%s y_fin=%s b_inf=%s top_cima=%s frames=%s" % [
		snappedf(x_fin, 0.1), snappedf(y0, 0.001), snappedf(y_fin, 0.001),
		snappedf(b_inf_fin, 0.001), -float(peldaños), cont_frames])
	# Debe cruzar los 3 peldaños (x > 3*60+60) y quedar apoyado en la cima.
	_check(x_fin > 240.0, "escalera: cruzó los 3 peldaños (x_fin=%s)" % snappedf(x_fin, 0.1))
	_check(absf(b_inf_fin - (-float(peldaños))) < 1.0, "escalera: apoyado en la cima (b_inf=%s top=%s)" % [
		snappedf(b_inf_fin, 0.001), -float(peldaños)])
	for hijo in root.get_children():
		hijo.queue_free()
	await physics_frame
	await physics_frame


func _init() -> void:
	for salto in [1.0, 2.0, 4.0]:
		await _correr(salto)
	await _correr_escalera()
	print("STEPUP-FALLOS=" + str(_fallos))
	quit(_fallos)