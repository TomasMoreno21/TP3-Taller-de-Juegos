extends SceneTree
## Diag de los créditos del final: el cierre del jefe encadena los créditos; cada integrante aparece
## con su forma y sus datos, y al final sale el cierre y se emite `terminada`.

var _failures := 0
var _termino := false


func _init() -> void:
	var vic = load("res://scenes/victoria_jefe.tscn").instantiate()
	_check(vic.get("escena_siguiente") == "res://scenes/creditos_final.tscn", "El cierre del jefe sigue con los créditos")
	vic.free()
	var cr = load("res://scenes/creditos_final.tscn").instantiate()
	cr.escena_siguiente = ""
	cr.entrada = 0.02
	cr.duracion_tarjeta = 0.1
	cr.salida = 0.02
	cr.pausa_inicial = 0.0
	cr.terminada.connect(func() -> void: _termino = true)
	root.add_child(cr)
	var vistos := {}
	for _i in 600:
		await process_frame
		if cr.tarjeta_actual >= 0 and cr.tarjeta_actual < cr.nombres.size():
			vistos[cr.tarjeta_actual] = [cr.nombre.text, int(cr.icono.forma)]
		if _termino:
			break
	_check(vistos.size() == 3, "Aparecen los 3 integrantes (%d)" % vistos.size())
	_check(vistos.get(0, ["", -1]) == ["Tomás Moreno", 3], "Tomás con el Murciélago")
	_check(vistos.get(1, ["", -1]) == ["Micaela Córdoba", 1], "Micaela con el Lobo")
	_check(vistos.get(2, ["", -1]) == ["Franco Hereñú", 2], "Franco con el Oso")
	_check(_termino and cr.nombre.text == cr.titulo_cierre, "Termina con el cierre y emite terminada")
	print("DIAG CREDITOS: FALLOS = " + str(_failures))
	quit(0 if _failures == 0 else 1)


func _check(cond: bool, msg: String) -> void:
	if cond:
		print("[PASS] " + msg)
	else:
		print("[FAIL] " + msg)
		_failures += 1
