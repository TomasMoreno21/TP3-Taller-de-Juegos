extends SceneTree
## Simula mando en los menús: stick abajo, A confirmar, B volver (pipeline real vía Input.parse_input_event).

var fallos := 0


func _boton(i: int, pressed: bool) -> void:
	var e := InputEventJoypadButton.new()
	e.button_index = i
	e.pressed = pressed
	Input.parse_input_event(e)


func _stick(y: float) -> void:
	var e := InputEventJoypadMotion.new()
	e.axis = JOY_AXIS_LEFT_Y
	e.axis_value = y
	Input.parse_input_event(e)


func _tap(i: int) -> void:
	_boton(i, true)
	await process_frame
	_boton(i, false)
	await process_frame
	await process_frame


func _empujar(y: float) -> void:
	_stick(y)
	await process_frame
	await process_frame
	await process_frame
	_stick(0.0)
	await process_frame
	await process_frame


func _check(ok: bool, msg: String) -> void:
	if not ok:
		fallos += 1
	print(("OK   " if ok else "FAIL ") + msg)


func _init() -> void:
	await process_frame
	change_scene_to_file("res://scenes/main_menu.tscn")
	for _i in 6:
		await process_frame
	var menu: Node = current_scene
	var f0 := root.gui_get_focus_owner()
	_check(f0 != null and f0.name == &"Jugar", "foco inicial en Jugar (%s)" % [f0])
	await _empujar(1.0)
	var f1 := root.gui_get_focus_owner()
	_check(f1 != null and f1 != f0, "stick abajo mueve el foco (%s)" % [f1.name if f1 else null])
	await _tap(JOY_BUTTON_DPAD_DOWN)
	var f2 := root.gui_get_focus_owner()
	_check(f2 != null and f2 != f1, "cruceta abajo mueve el foco (%s)" % [f2.name if f2 else null])
	# ir a Opciones y abrirlo con A
	while root.gui_get_focus_owner() == null or root.gui_get_focus_owner().name != &"Opciones":
		await _tap(JOY_BUTTON_DPAD_DOWN)
	await _tap(JOY_BUTTON_A)
	for _i in 8:
		await process_frame
	var fo := root.gui_get_focus_owner()
	_check(fo != null and fo.name == &"Controles", "A abre Opciones; foco en Controles (%s)" % [fo.name if fo else null])
	await _tap(JOY_BUTTON_B)
	await create_timer(0.5).timeout
	for _i in 3:
		await process_frame
	_check(not is_instance_valid(menu.get("_controls")) or menu.get("_controls") == null, "B cierra Opciones")
	var fo2 := root.gui_get_focus_owner()
	_check(fo2 != null, "tras cerrar, el menú tiene foco (%s)" % [fo2])
	print("FALLOS: %d" % fallos)
	quit()
