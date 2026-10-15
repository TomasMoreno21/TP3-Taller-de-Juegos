extends SceneTree
## Revisa dónde caen las nieblas violetas de atmosfera_nivel3 respecto a la roca y propone posiciones libres.
## Uso: godot --headless --script tests/diag_nieblas.gd

const MARGEN := Vector2(250, 250)   # los puntos de niebla son grandes: se mide también un margen alrededor de la zona de emisión

func _init() -> void:
	var nivel: Node = load("res://scenes/nivel3.tscn").instantiate()
	root.add_child(nivel)
	await physics_frame
	var capa := nivel.get_node("TileMap") as TileMapLayer
	var celdas := {}
	for c in capa.get_used_cells():
		celdas[c] = true
	var nieblas := nivel.get_node("Atmosfera/Nieblas") if nivel.has_node("Atmosfera/Nieblas") else null
	if nieblas == null:
		for n in nivel.get_children():
			if n.has_node("Nieblas"):
				nieblas = n.get_node("Nieblas")
	var lista: Array = nieblas.get_children()
	var fijas: Array = []
	for n in lista:
		var ext: Vector2 = n.emission_rect_extents
		var p: Vector2 = n.position
		var actual := _roca(celdas, p, ext)
		var mejor := p
		var mejor_s := actual
		# búsqueda en espiral por una grilla de 64 px (hasta 640 px, para no salir del recorrido)
		if actual > 0.02:
			var r := 64
			while r <= 640 and mejor_s > 0.02:
				for dx in range(-r, r + 1, 64):
					for dy in range(-r, r + 1, 64):
						if absi(dx) != r and absi(dy) != r:
							continue
						var q := p + Vector2(dx, dy)
						var s := _roca(celdas, q, ext) + _piso(celdas, q, ext) * 0.5
						var lejos := true
						for f in fijas:
							if (f as Vector2).distance_to(q) < 1800.0:
								lejos = false
						if lejos and s < mejor_s:
							mejor_s = s
							mejor = q
				r += 64
		fijas.append(mejor)
		print("%s  %s roca=%.2f -> %s roca=%.2f" % [n.name, p, actual, mejor, mejor_s])
	quit()


## Fracción de celdas de roca en la zona de emisión + margen.
func _roca(celdas: Dictionary, p: Vector2, ext: Vector2) -> float:
	var e := ext + MARGEN
	var tot := 0
	var roca := 0
	var x := -e.x
	while x <= e.x:
		var y := -e.y
		while y <= e.y:
			tot += 1
			if celdas.has(Vector2i(floori((p.x + x) / 16.0), floori((p.y + y) / 16.0))):
				roca += 1
			y += 32.0
		x += 32.0
	return float(roca) / float(maxi(tot, 1))


## 0 si hay piso bajo la niebla (la niebla rasante pega mejor), 1 si flota sin piso cerca.
func _piso(celdas: Dictionary, p: Vector2, ext: Vector2) -> float:
	var con := 0
	var tot := 0
	var x := -ext.x
	while x <= ext.x:
		tot += 1
		for d in range(int(ext.y), int(ext.y) + 400, 16):
			if celdas.has(Vector2i(floori((p.x + x) / 16.0), floori((p.y + d) / 16.0))):
				con += 1
				break
		x += 100.0
	return 1.0 - float(con) / float(maxi(tot, 1))
