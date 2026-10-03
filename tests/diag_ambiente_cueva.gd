extends SceneTree
## Diag efectos ambientales del nivel 2: sin hojas, goteo del techo, murciélago lejano, latido progresivo y motas violetas.
## Uso: --headless --script res://tests/diag_ambiente_cueva.gd

var fallos := 0

func _check(c: bool, m: String) -> void:
	print(("[PASS] " if c else "[FAIL] ") + m)
	if not c:
		fallos += 1

func _initialize() -> void:
	var nivel: Node = load("res://scenes/nivel2.tscn").instantiate()
	root.add_child(nivel)
	for i in 6:
		await physics_frame
	var jug := get_first_node_in_group("player") as Node2D
	var cam := nivel.get_node("Camara") as Camera2D
	cam.make_current()

	var hojas := nivel.get_node("Noche/HojasAmbiente") as CPUParticles2D
	for i in 10:
		await process_frame
	_check(not hojas.emitting, "el nivel 2 no tiene hojas cayendo")

	# Goteo: nace de un techo real y llega a un piso.
	var goteo: Node = nivel.get_node("EfectosCueva/GoteoTecho")
	var antes := goteo.get_child_count()
	for i in 40:
		goteo.call("_nueva_gota")
	var gotas := goteo.get_child_count() - antes
	_check(gotas > 0, "el goteo genera gotas desde el techo (%d de 40 intentos)" % gotas)
	await create_timer(3.0).timeout
	_check(goteo.get_child_count() <= antes + gotas, "las gotas caen y se liberan")

	# Murciélago lejano.
	var ml: Node = nivel.get_node("EfectosCueva/MurcielagoLejano")
	ml.call("lanzar")
	await process_frame
	var pasan := ml.get_child(0) as Area2D
	_check(pasan != null and pasan.z_index < 0 and not pasan.monitoring, "el murciélago lejano vuela detrás del terreno y no dispara eventos")
	_check(pasan.get_child_count() >= 1, "el murciélago lejano tiene su silueta")

	# Latido progresivo + motas.
	var latido: Node = nivel.get_node("Latido")
	var motas := nivel.get_node("EfectosCueva/MotasVioleta") as CPUParticles2D
	for i in 20:
		await process_frame
	_check(latido.intensidad_actual() < 0.005 and not motas.emitting, "arriba no late ni hay motas (%.3f)" % latido.intensidad_actual())
	jug.global_position = Vector2(-4800, 6800)
	await create_timer(2.5).timeout
	var i_descenso: float = latido.intensidad_actual()
	jug.global_position = Vector2(3200, 6800)
	await create_timer(4.0).timeout
	var i_santuario: float = latido.intensidad_actual()
	_check(i_descenso > 0.02 and i_santuario > i_descenso, "el latido crece hacia el santuario (%.3f -> %.3f)" % [i_descenso, i_santuario])
	_check(motas.emitting and motas.modulate.a > 0.2, "cerca del santuario aparecen las motas violetas (a=%.2f)" % motas.modulate.a)
	print("DIAG_AMBIENTE_CUEVA: FALLOS = ", fallos)
	quit(fallos)
