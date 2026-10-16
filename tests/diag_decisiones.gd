extends SceneTree
## Decisiones de diseño del 15/10: transformarse en el aire no devuelve los saltos; el parry de proyectiles es solo de frente.
## Uso: godot --headless --path . --script tests/diag_decisiones.gd

var fallos := 0

func _chk(nombre: String, ok: bool) -> void:
	print("[%s] %s" % ["OK" if ok else "FAIL", nombre])
	if not ok:
		fallos += 1


func _init() -> void:
	var nivel: Node = (load("res://scenes/nivel1.tscn") as PackedScene).instantiate()
	root.add_child(nivel)
	await process_frame
	await process_frame
	var prog := root.get_node("Progresion")
	prog.set_nivel(4)
	prog.formas_forzadas = [0, 1, 2, 3]
	var p: CharacterBody2D = nivel.get_node("Player")
	p.set("energia", 100.0)
	for i in 30:
		await physics_frame
	# Saltos: en el aire, la forma nueva hereda los saltos gastados.
	p.forms[0]._jumps_usados = 1
	p.global_position += Vector2(0, -400)
	await physics_frame
	var en_aire := not p.is_on_floor()
	p.call("_transformar", 1, true)
	await physics_frame
	_chk("en el aire (%s): el Lobo hereda el salto gastado" % str(en_aire), (not en_aire) or p.forms[1]._jumps_usados >= 1)
	# Parry de frente.
	p.call("_transformar", 0, true)
	await physics_frame
	p.set("facing", 1)
	p.set("blocking", true)
	p.set("_parry_t", 0.2)
	_chk("proyectil que viene por la espalda (mismo sentido que facing): no se parría", not p.parry_proyectil(1.0))
	p.set("_parry_t", 0.2)
	_chk("proyectil de frente: parry con bonus", p.parry_proyectil(-1.0))
	print("DIAG_DECISIONES: FALLOS = %d" % fallos)
	quit()
