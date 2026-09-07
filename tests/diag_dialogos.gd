extends SceneTree

var fallos := 0


func _init() -> void:
	var trigger: Node = preload("res://scenes/dialog_trigger.tscn").instantiate()
	trigger.set("dialogo_id", "n1_intro")
	root.add_child(trigger)
	await process_frame
	var lineas: PackedStringArray = trigger.lineas
	_check(lineas.size() == 7, "n1_intro carga 7 líneas (es %d)" % lineas.size())
	_check(String(trigger.hablante) == "Amuleto", "hablante Amuleto")
	_check(String(trigger.modo) == "Automatico", "modo Automatico")
	_check(trigger.una_vez == false, "una_vez false")
	_check(lineas[0].begins_with("Humano..."), "primera línea correcta")

	var desconocido: Node = preload("res://scenes/dialog_trigger.tscn").instantiate()
	desconocido.set("dialogo_id", "no_existe")
	root.add_child(desconocido)
	await process_frame
	_check(desconocido.lineas.is_empty(), "id inexistente deja líneas vacías")

	print("DIAG_DIALOGOS: FALLOS = ", fallos)
	quit(fallos == 0)


func _check(condicion: bool, nombre: String) -> void:
	if condicion:
		print("[PASS] ", nombre)
	else:
		fallos += 1
		print("[FAIL] ", nombre)