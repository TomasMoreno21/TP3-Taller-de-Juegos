extends Node
## Stick izquierdo en menús: traduce el stick a UN paso ui_* por empujón (con repetición lenta al mantener)
## en vez de disparar la acción en cada evento de movimiento (que saltaba varios botones de golpe).

const UMBRAL := 0.55
const DELAY_INICIAL := 0.45
const DELAY_REPETIR := 0.22
const ESCENAS_MENU := ["main_menu", "derrota", "victoria", "victoria_jefe", "creditos_final", "comic_intro"]

var _eje := Vector2.ZERO
var _dir := ""
var _proximo := 0.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	# Los ui_* de este proyecto no traen botones de mando para aceptar/volver/cruceta lateral: se agregan acá.
	for par in [["ui_accept", JOY_BUTTON_A], ["ui_cancel", JOY_BUTTON_B],
			["ui_left", JOY_BUTTON_DPAD_LEFT], ["ui_right", JOY_BUTTON_DPAD_RIGHT]]:
		var e := InputEventJoypadButton.new()
		e.button_index = par[1]
		if not InputMap.action_has_event(par[0], e):
			InputMap.action_add_event(par[0], e)


func _en_menu() -> bool:
	if get_tree().paused:
		return true
	var escena := get_tree().current_scene
	return escena != null and escena.scene_file_path.get_file().get_basename() in ESCENAS_MENU


func _input(event: InputEvent) -> void:
	if event is InputEventJoypadMotion and (event.axis == JOY_AXIS_LEFT_X or event.axis == JOY_AXIS_LEFT_Y):
		if event.axis == JOY_AXIS_LEFT_X:
			_eje.x = event.axis_value
		else:
			_eje.y = event.axis_value
		if _en_menu():
			get_viewport().set_input_as_handled()


func _process(_delta: float) -> void:
	var nueva := ""
	if _en_menu() and _eje.length() >= UMBRAL:
		if absf(_eje.y) >= absf(_eje.x):
			nueva = "ui_down" if _eje.y > 0.0 else "ui_up"
		else:
			nueva = "ui_right" if _eje.x > 0.0 else "ui_left"
	var ahora := Time.get_ticks_msec() * 0.001
	if nueva != "" and (nueva != _dir or ahora >= _proximo):
		_proximo = ahora + (DELAY_INICIAL if nueva != _dir else DELAY_REPETIR)
		_pulsar(nueva)
	_dir = nueva


func _pulsar(accion: String) -> void:
	for presionado in [true, false]:
		var e := InputEventAction.new()
		e.action = accion
		e.pressed = presionado
		Input.parse_input_event(e)
