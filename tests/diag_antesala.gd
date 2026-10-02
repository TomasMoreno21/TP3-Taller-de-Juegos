extends SceneTree
## Diag antesala de combate: al acercarse a una arena el ambiente se calla; al empezar la pelea vuelve.
## Uso: --headless --script res://tests/diag_antesala.gd

var fallos := 0

func _check(c: bool, m: String) -> void:
	print(("[PASS] " if c else "[FAIL] ") + m)
	if not c:
		fallos += 1

func _initialize() -> void:
	var nivel: Node = load("res://scenes/nivel1.tscn").instantiate()
	root.add_child(nivel)
	for n in nivel.get_children():
		if n.get_script() != null and str(n.get_script().resource_path).ends_with("dialog_trigger.gd"):
			n.queue_free()
	await process_frame
	await process_frame
	var p := get_first_node_in_group("player") as CharacterBody2D
	p.set("god_mode", true)
	var amb := get_first_node_in_group("ambiente_sonoro")
	_check(amb != null, "hay ambiente sonoro en el nivel 1")
	var enc: Area2D = nivel.get_node("EncounterA")
	var ant := enc.get_node_or_null("Antesala")
	_check(ant != null, "el Encounter crea su Antesala")
	if amb == null or ant == null:
		print("FALLOS = %d" % fallos)
		quit(fallos)
		return
	var vol0: float = amb._capas[1].volume_db
	# Lejos: sin silencio.
	p.global_position = Vector2(enc.arena_center.x - enc.arena_medio_ancho - 4000.0, enc.arena_center.y)
	for i in 30:
		await process_frame
	_check(ant.k < 0.01, "lejos de la arena no hay antesala (k=%.3f)" % ant.k)
	_check(is_equal_approx(amb._capas[1].volume_db, vol0), "lejos el ambiente suena normal")
	# Cerca: se calla.
	p.global_position = Vector2(enc.arena_center.x - enc.arena_medio_ancho - 100.0, enc.arena_center.y)
	for i in 120:
		await process_frame
	_check(ant.k > 0.6, "cerca de la arena la antesala sube (k=%.2f)" % ant.k)
	_check(amb._capas[1].volume_db < vol0 - 5.0, "cerca el ambiente baja (%.1f < %.1f)" % [amb._capas[1].volume_db, vol0])
	# Empieza la pelea: vuelve a la normalidad.
	enc.empezar()
	for i in 240:
		await process_frame
	_check(ant.k < 0.05, "al empezar la pelea la antesala se apaga (k=%.3f)" % ant.k)
	_check(absf(amb._capas[1].volume_db - vol0) < 0.5, "al empezar la pelea el ambiente vuelve")
	print("FALLOS = %d" % fallos)
	quit(fallos)
