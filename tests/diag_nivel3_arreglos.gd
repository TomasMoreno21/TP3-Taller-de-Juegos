extends SceneTree
## Nivel 3: ids de barrera únicos (no chocan con los de otros niveles) y Encounter D con todas las olas dentro de su arena.
## Uso: godot --headless --script tests/diag_nivel3_arreglos.gd

var fallos := 0

func _chk(nombre: String, ok: bool) -> void:
	print("[%s] %s" % ["OK" if ok else "FAIL", nombre])
	if not ok:
		fallos += 1


func _ids(ruta: String) -> Array:
	var n: Node = load(ruta).instantiate()
	root.add_child(n)
	var ids: Array = []
	for b in n.find_children("*", "Node2D", true, false):
		if b.get_script() != null and b.get_script().resource_path == "res://scripts/barrera_bosque.gd":
			ids.append(b.get("barrera_id"))
	n.queue_free()
	return ids


func _init() -> void:
	await process_frame
	var i2 := _ids("res://scenes/nivel2.tscn")
	var i3 := _ids("res://scenes/nivel3.tscn")
	var todos: Array = i2 + i3
	var vistos := {}
	var dup := false
	for id in todos:
		if vistos.has(id):
			dup = true
		vistos[id] = true
	print("ids nivel2=", i2, " nivel3=", i3)
	_chk("ningún id de barrera se repite entre niveles ni dentro del nivel", not dup)
	var nivel: Node = load("res://scenes/nivel3.tscn").instantiate()
	root.add_child(nivel)
	await physics_frame
	var enc: Node2D = nivel.get_node("Encounter D")
	var lejos := 0
	var olas := {}
	for e in enc.get_children():
		if e.has_method("activar"):
			olas[int(e.get("ola_asignada"))] = true
			if (e as Node2D).position.length() > 1500.0:
				lejos += 1
				print("   lejos: ", e.name, " ", (e as Node2D).position)
	_chk("Encounter D: ningún enemigo de oleada a más de 1500 px de su arena", lejos == 0)
	_chk("Encounter D: olas 0 a 3 con enemigos (%s)" % str(olas.keys()), olas.has(0) and olas.has(1) and olas.has(2) and olas.has(3))
	print("DIAG_NIVEL3_ARREGLOS: FALLOS = %d" % fallos)
	quit()
