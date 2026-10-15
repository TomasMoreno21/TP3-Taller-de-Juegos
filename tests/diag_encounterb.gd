extends SceneTree
## Los enemigos de EncounterB (3 olas) arrancan dormidos: ninguno despierta fuera de la pelea.
## Uso: godot --headless --script tests/diag_encounterb.gd

func _init() -> void:
	await process_frame
	var nivel: Node = load("res://scenes/nivel3.tscn").instantiate()
	root.add_child(nivel)
	for i in 5:
		await physics_frame
	var fallos := 0
	var enc: Node = nivel.get_node("EncounterB")
	var n := 0
	for e in enc.get_children():
		if e.has_method("activar"):
			n += 1
			if e.get("_activo") != false:
				fallos += 1
				print("[FAIL] despierto: ", e.name)
	print("[%s] EncounterB tiene 7 enemigos dormidos (hay %d)" % ["OK" if n == 7 else "FAIL", n])
	if n != 7:
		fallos += 1
	for e in nivel.get_children():
		if e.is_in_group("enemy") and e.get("_activo") == true and (e as Node2D).global_position.distance_to(enc.global_position) < 2500.0:
			fallos += 1
			print("[FAIL] enemigo suelto despierto cerca de EncounterB: ", e.name)
	print("DIAG_ENCOUNTERB: FALLOS = %d" % fallos)
	quit()
