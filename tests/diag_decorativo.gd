extends SceneTree
## Diag: todos los tipos/variantes de decorativo se construyen y animan sin errores
## (incluye utilería de la secta del nivel 2). Uso: godot --headless --path . --script res://tests/diag_decorativo.gd

func _initialize() -> void:
	var fallos := 0
	var escena := load("res://scenes/decorativo.tscn") as PackedScene
	var nombres := ["ARBOL", "SAUCE", "ARBUSTO", "PASTO", "PIEDRA", "TRONCO_FRENTE", "RAMA_COLGANTE", "PASTO_ALTO", "ESTALAGMITA", "ESTALACTITA", "CRISTAL",
		"ANTORCHA", "BRASERO", "VELAS", "ESTANDARTE", "CADENAS", "HUESOS", "CIRCULO", "GLIFO", "JAULA", "ESTATUA"]
	for t in nombres.size():
		for v in [1, 2, 3, 6, 10]:
			var d := escena.instantiate()
			d.set("tipo", t)
			d.set("variante", v)
			root.add_child(d)
			await process_frame
			var hoja := d.get_node_or_null("Hoja")
			if hoja == null or hoja.get_child_count() == 0 and nombres[t] != "CIRCULO" and nombres[t] != "GLIFO":
				print("FALLO: ", nombres[t], " v", v, " sin silueta")
				fallos += 1
			d.queue_free()
	# fuego: parpadeo mueve las llamas
	var a := escena.instantiate()
	a.set("tipo", nombres.find("ANTORCHA"))
	root.add_child(a)
	await process_frame
	await create_timer(0.2).timeout
	var b := a.get_node_or_null("Brillo")
	if b == null or b.get_child_count() < 3:
		print("FALLO: antorcha sin brillo")
		fallos += 1
	var nivel: Node = load("res://scenes/nivel2.tscn").instantiate()
	root.add_child(nivel)
	await process_frame
	await process_frame
	var n_deco: int = nivel.get_node("Decoracion").get_child_count() + nivel.get_node("DecoracionFrente").get_child_count()
	print("nivel2 decorativos: ", n_deco)
	if n_deco > 130 or n_deco < 40:
		print("FALLO: cantidad de decorativos fuera de rango")
		fallos += 1
	print("DIAG_DECORATIVO FALLOS = ", fallos)
	quit(1 if fallos > 0 else 0)
