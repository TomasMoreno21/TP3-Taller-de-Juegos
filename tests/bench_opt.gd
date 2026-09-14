extends SceneTree

## Bench temporal de optimización: mide el frame de física con N enemigos activos
## persiguiendo al player. Correr con: godot --headless --path . --script res://tests/bench_opt.gd
## Resultados en microsegundos promedio por physics tick.

const ENEMIGO_PATH := "res://scenes/enemy.tscn"

var _scene: Node


func _init() -> void:
	_scene = load("res://scenes/main.tscn").instantiate()
	for d in _scene.get_children():
		if d.name.begins_with("Dialog") or d is Node and "dialog" in str(d.name).to_lower():
			d.queue_free()
	root.add_child(_scene)
	_scene.get_node("LevelUp").set("pausar_al_abrir", false)
	await process_frame
	await process_frame

	var player: Node2D = _scene.get_node("Player")
	player.set("god_mode", true)

	var base_ms := await _medir(0, player)
	print("BENCH_OPT  baseline (enemigos del nivel): %.3f ms/fisica" % base_ms)

	var ms25 := await _medir(25, player, base_ms)
	print("BENCH_OPT  +25 enemigos: %.3f ms/fisica" % ms25)

	var ms50 := await _medir(50, player, ms25)
	print("BENCH_OPT  +50 enemigos: %.3f ms/fisica" % ms50)

	print("BENCH_OPT RESULTADO: baseline=%.3f +25=%.3f +50=%.3f" % [base_ms, ms25, ms50])
	quit()


func _spawn_enemigos(cantidad: int, player: Node2D) -> Array:
	var prefab: PackedScene = load(ENEMIGO_PATH)
	var lista: Array = []
	for i in range(cantidad):
		var e: Node = prefab.instantiate()
		e.set("tipo", "cultista")
		var base := player.global_position + Vector2(260 + (i % 5) * 70, 0)
		e.global_position = base if i % 2 == 0 else Vector2(base.x, base.y - 40)
		_scene.add_child(e)
		if e.has_method("activar"):
			e.activar()
		lista.append(e)
	return lista


func _medir(extra: int, player: Node2D, _prev_ms: float = 0.0) -> float:
	var agregados: Array = []
	if extra > 0:
		agregados = _spawn_enemigos(extra, player)
		await physics_frame
		await physics_frame

	for i in range(600):
		await physics_frame
	var ms := Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS)
	var vivos := 0
	for e in get_nodes_in_group("enemy"):
		if is_instance_valid(e):
			vivos += 1
	print("BENCH_OPT  enemigos vivos en escena: %d" % vivos)

	for e in agregados:
		if is_instance_valid(e):
			e.queue_free()
	await physics_frame
	return ms