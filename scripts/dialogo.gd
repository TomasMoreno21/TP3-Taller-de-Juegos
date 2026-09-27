extends CanvasLayer

## Autoload "Dialogo": caja de diálogo reusable (narrativa + tutorial in-game).
## Uso: get_node("/root/Dialogo").mostrar(["línea 1", "línea 2"], "Amuleto")
##
## Modo TIP (no invasivo): get_node("/root/Dialogo").mostrar_tip(["texto"], "Amuleto")
## muestra un panel chico arriba-centro que se desvanece solo, SIN bloquear el
## input del jugador (explicar mecánicas sin frenar el juego).

signal dialogo_terminado

const SEG_POR_CARACTER := 0.022
const SEG_MINIMO_TIP := 2.0
const SEG_POR_CARACTER_TIP := 0.09

var _cola: Array[Dictionary] = []
var _abierto := false
var _texto_completo := ""
var _ultimo_blip := 0
## true si lo último que tocó el jugador fue un joystick: los tokens {accion} del
## texto se muestran como botones del mando; si no, como teclas.
var _usa_joypad := false
var _hint_plantilla := ""
var _re_token := RegEx.create_from_string("\\{(\\w+)\\}")

const NOMBRES_BOTON := {
	JOY_BUTTON_A: "A", JOY_BUTTON_B: "B", JOY_BUTTON_X: "X", JOY_BUTTON_Y: "Y",
	JOY_BUTTON_BACK: "Select", JOY_BUTTON_START: "Start",
	JOY_BUTTON_LEFT_SHOULDER: "LB", JOY_BUTTON_RIGHT_SHOULDER: "RB",
	JOY_BUTTON_LEFT_STICK: "L3", JOY_BUTTON_RIGHT_STICK: "R3",
	JOY_BUTTON_DPAD_UP: "cruceta ↑", JOY_BUTTON_DPAD_DOWN: "cruceta ↓",
	JOY_BUTTON_DPAD_LEFT: "cruceta ←", JOY_BUTTON_DPAD_RIGHT: "cruceta →",
}
const NOMBRES_EJE := {
	JOY_AXIS_LEFT_X: "joystick izquierdo", JOY_AXIS_LEFT_Y: "joystick izquierdo",
	JOY_AXIS_RIGHT_X: "joystick derecho", JOY_AXIS_RIGHT_Y: "joystick derecho",
	JOY_AXIS_TRIGGER_LEFT: "LT", JOY_AXIS_TRIGGER_RIGHT: "RT",
}
## Tokens que agrupan varias acciones (movimiento en ejes): en el mando se nombra
## el joystick, en teclado se listan las teclas de cada acción ("A / D").
const ALIAS := {
	"mover": ["move_left", "move_right"],
	"trepar": ["move_up", "move_down"],
	"camara": ["cam_izq", "cam_der", "cam_arr", "cam_abj"],
}
const NOMBRES_TECLA := {
	"Space": "Espacio", "Enter": "Enter", "Escape": "Esc", "Shift": "Shift",
	"Up": "↑", "Down": "↓", "Left": "←", "Right": "→", "Ctrl": "Ctrl", "Tab": "Tab",
}
var _tipeando := false
var _tips: Array[Dictionary] = []
var _tip_visible := false
var _tip_timer := 0.0

@onready var panel: PanelContainer = $Panel
@onready var nombre_label: Label = $Panel/Margin/HBox/VBox/Nombre
@onready var texto_label: RichTextLabel = $Panel/Margin/HBox/VBox/Texto
@onready var hint: Label = $Panel/Margin/HBox/VBox/Hint
@onready var retrato: Control = $Panel/Margin/HBox/RetratoWrap/Retrato
@onready var tip_panel: PanelContainer = $Tip
@onready var tip_nombre: Label = $Tip/Margin/VBox/Nombre
@onready var tip_texto: Label = $Tip/Margin/VBox/Texto


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 85
	panel.visible = false
	tip_panel.visible = false


func esta_activo() -> bool:
	return _abierto


## Diálogo narrativo CLÁSICO: caja grande, bloquea avanzar con input del jugador.
func mostrar(lineas: Array, hablante: String = "Amuleto") -> void:
	for l in lineas:
		_cola.append({"texto": String(l), "hablante": hablante})
	_tips.clear()
	_cerrar_tip()
	if not _abierto:
		_abierto = true
		panel.visible = true
		_siguiente_linea()


## Tip NO bloquecante: texto corto arriba-centro que se desvanece solo.
func mostrar_tip(lineas: Array, hablante: String = "Amuleto") -> void:
	if _abierto:
		return
	for l in lineas:
		_tips.append({"texto": String(l), "hablante": hablante})
	if not _tip_visible:
		_tip_siguiente()


func _tip_siguiente() -> void:
	if _tips.is_empty():
		_cerrar_tip()
		return
	var linea: Dictionary = _tips.pop_front()
	tip_nombre.text = str(linea.get("hablante", "Amuleto"))
	tip_texto.text = _tokens(str(linea.get("texto", "")))
	_tip_timer = maxf(SEG_MINIMO_TIP, float(String(tip_texto.text).length()) * SEG_POR_CARACTER_TIP)
	tip_panel.modulate.a = 0.0
	tip_panel.visible = true
	_tip_visible = true
	var tw := create_tween()
	tw.tween_property(tip_panel, "modulate:a", 1.0, 0.15)


func _cerrar_tip() -> void:
	_tip_visible = false
	_tip_timer = 0.0
	tip_panel.visible = false


func _siguiente_linea() -> void:
	if _cola.is_empty():
		_tips.clear()
		_cerrar_tip()
		_cerrar()
		return
	var linea: Dictionary = _cola.pop_front()
	nombre_label.text = linea["hablante"]
	_texto_completo = _tokens(linea["texto"])
	texto_label.text = _texto_completo
	texto_label.visible_ratio = 0.0
	_tipeando = true
	_ultimo_blip = 0
	hint.visible = false
	retrato.set_hablando(true)


func _process(delta: float) -> void:
	if _abierto and _tipeando:
		var duracion: float = max(_texto_completo.length(), 1) * SEG_POR_CARACTER
		texto_label.visible_ratio = min(texto_label.visible_ratio + delta / duracion, 1.0)
		var visibles := int(texto_label.visible_ratio * _texto_completo.length())
		if visibles >= _ultimo_blip + 2:
			_ultimo_blip = visibles
			var audio := get_node_or_null("/root/AudioManager")
			if audio != null:
				audio.play_ui("dialogo_tecla", -20.0)
		if texto_label.visible_ratio >= 1.0:
			_terminar_tipeo()
	elif _tip_visible:
		_tip_timer -= delta
		if _tip_timer <= 0.0:
			var tw := create_tween()
			tw.tween_property(tip_panel, "modulate:a", 0.0, 0.2)
			tw.tween_callback(_tip_siguiente)


func _terminar_tipeo() -> void:
	_tipeando = false
	# La ayuda se escribe en la escena con tokens ({dialog_next}...): se traduce al
	# dispositivo actual cada vez que aparece.
	if _hint_plantilla.is_empty():
		_hint_plantilla = hint.text
	hint.text = _tokens(_hint_plantilla)
	hint.visible = true
	retrato.set_hablando(false)


func _input(event: InputEvent) -> void:
	if event is InputEventJoypadButton or (event is InputEventJoypadMotion and absf((event as InputEventJoypadMotion).axis_value) > 0.4):
		_usa_joypad = true
	elif event is InputEventKey or event is InputEventMouseButton:
		_usa_joypad = false


## Reemplaza {accion} por la tecla o el botón asignado en el InputMap según el
## dispositivo que se está usando. Acciones desconocidas quedan como estaban.
func _tokens(texto: String) -> String:
	var salida := texto
	for m in _re_token.search_all(texto):
		var accion := m.get_string(1)
		if ALIAS.has(accion):
			salida = salida.replace(m.get_string(0), _nombre_alias(ALIAS[accion]))
		elif InputMap.has_action(accion):
			salida = salida.replace(m.get_string(0), nombre_accion(accion))
	return salida


func _nombre_alias(acciones: Array) -> String:
	var teclas: Array[String] = []
	var eje := ""
	for a in acciones:
		for ev in InputMap.action_get_events(a):
			if ev is InputEventKey:
				var k := ev as InputEventKey
				var n := OS.get_keycode_string(k.physical_keycode if k.physical_keycode != KEY_NONE else k.keycode)
				n = NOMBRES_TECLA.get(n, n)
				if not teclas.has(n):
					teclas.append(n)
				break
		if eje.is_empty():
			for ev in InputMap.action_get_events(a):
				if ev is InputEventJoypadMotion:
					eje = NOMBRES_EJE.get((ev as InputEventJoypadMotion).axis, "joystick")
					break
	var teclado := " / ".join(teclas)
	if _usa_joypad or teclado.is_empty():
		return eje if not eje.is_empty() else teclado
	return teclado


func nombre_accion(accion: String) -> String:
	var teclado := ""
	var mando := ""
	for ev in InputMap.action_get_events(accion):
		if ev is InputEventKey and teclado.is_empty():
			var k := ev as InputEventKey
			var code := k.physical_keycode if k.physical_keycode != KEY_NONE else k.keycode
			var n := OS.get_keycode_string(code)
			teclado = NOMBRES_TECLA.get(n, n)
		elif ev is InputEventMouseButton and teclado.is_empty():
			teclado = "clic izquierdo" if (ev as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT else "clic derecho"
		elif ev is InputEventJoypadButton and mando.is_empty():
			mando = NOMBRES_BOTON.get((ev as InputEventJoypadButton).button_index, "botón")
		elif ev is InputEventJoypadMotion and mando.is_empty():
			mando = NOMBRES_EJE.get((ev as InputEventJoypadMotion).axis, "joystick")
	if _usa_joypad:
		return mando if not mando.is_empty() else teclado
	return teclado if not teclado.is_empty() else mando


func _unhandled_input(event: InputEvent) -> void:
	if not _abierto:
		return
	if event.is_action_pressed("dialog_skip"):
		_saltar_todo()
		get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed("dialog_next"):
		if _tipeando:
			texto_label.visible_ratio = 1.0
			_terminar_tipeo()
		else:
			_siguiente_linea()
		get_viewport().set_input_as_handled()


func _saltar_todo() -> void:
	_cola.clear()
	_texto_completo = ""
	_tipeando = false
	_cerrar()


func _cerrar() -> void:
	_abierto = false
	panel.visible = false
	dialogo_terminado.emit()
