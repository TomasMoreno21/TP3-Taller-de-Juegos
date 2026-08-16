extends SceneTree

const INACTIVE := 0
const RUNNING := 1
const COMPLETED := 2

var _failures := 0


func _init() -> void:
	var world := Node2D.new()
	root.add_child(world)

	var enc: Node = load("res://scenes/encounter.tscn").instantiate()
	enc.arena_center = Vector2(400, 0)
	enc.arena_medio_ancho = 200.0
	var ola := WaveOla.new()
	ola.tipo = "cultista"
	ola.cantidad = 2
	ola.delay = 0.0
	enc.olas = [ola] as Array[WaveOla]
	world.add_child(enc)

	await process_frame
	await process_frame
	_check(enc.estado == INACTIVE, "Encounter inicia INACTIVE")

	enc.empezar()
	await process_frame
	await process_frame
	_check(enc.estado == RUNNING, "Encounter pasa a RUNNING al empezar")

	for i in range(50):
		await physics_frame

	var vivos := _enemigos(enc)
	_check(not vivos.is_empty(), "Se spawnearon enemigos de la ola: %d" % vivos.size())
	for e in vivos:
		if is_instance_valid(e) and e.health > 0:
			e.take_damage(9999)

	for i in range(30):
		await physics_frame
	_check(enc.estado == COMPLETED, "Encounter COMPLETED tras matar la ola")

	var muertos := 0
	for e in vivos:
		if not is_instance_valid(e):
			muertos += 1
	_check(muertos == vivos.size(), "Todos los enemigos de la ola murieron/liberados")

	print("DIAG ENCUENTRO: " + ("OK" if _failures == 0 else "FALLOS = " + str(_failures)))
	if _failures == 0:
		quit(0)
	else:
		quit(1)


func _enemigos(enc: Node) -> Array:
	var res: Array = []
	for nodo in enc.get_children():
		if nodo.is_in_group("enemy"):
			res.append(nodo)
	return res


func _check(cond: bool, msg: String) -> void:
	if cond:
		print("[PASS] " + msg)
	else:
		print("[FAIL] " + msg)
		_failures += 1