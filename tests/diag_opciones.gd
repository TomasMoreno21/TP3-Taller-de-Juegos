extends SceneTree
## Opciones: buses creados, volumen aplicado, guardado en disco y paneles abren sin errores.
var _f := 0
func _init() -> void:
	await process_frame
	var o = root.get_node("Opciones")
	_c(AudioServer.get_bus_index(&"Musica") >= 0 and AudioServer.get_bus_index(&"SFX") >= 0, "buses Musica y SFX existen")
	o.fijar_musica(0.5)
	_c(absf(AudioServer.get_bus_volume_db(AudioServer.get_bus_index(&"Musica")) - linear_to_db(0.5)) < 0.01, "volumen de música aplicado")
	o.fijar_sfx(0.0)
	_c(AudioServer.is_bus_mute(AudioServer.get_bus_index(&"SFX")), "volumen 0 silencia el bus")
	var cfg := ConfigFile.new()
	_c(cfg.load("user://opciones.cfg") == OK and absf(float(cfg.get_value("audio", "musica", -1.0)) - 0.5) < 0.001, "se guarda en user://opciones.cfg")
	o.fijar_musica(1.0)
	o.fijar_sfx(1.0)
	for ruta in ["res://scenes/opciones.tscn", "res://scenes/creditos.tscn", "res://scenes/main_menu.tscn", "res://scenes/pause.tscn"]:
		var n: Node = load(ruta).instantiate()
		root.add_child(n)
		await process_frame
		_c(is_instance_valid(n), "abre " + ruta)
		n.queue_free()
		await process_frame
	print("DIAG OPCIONES: FALLOS = ", _f)
	quit(1 if _f > 0 else 0)
func _c(ok: bool, m: String) -> void:
	print(("[PASS] " if ok else "[FAIL] ") + m)
	if not ok: _f += 1
