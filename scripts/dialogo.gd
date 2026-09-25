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
	tip_texto.text = str(linea.get("texto", ""))
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
	_texto_completo = linea["texto"]
	texto_label.text = _texto_completo
	texto_label.visible_ratio = 0.0
	_tipeando = true
	hint.visible = false
	retrato.set_hablando(true)


func _process(delta: float) -> void:
	if _abierto and _tipeando:
		var duracion: float = max(_texto_completo.length(), 1) * SEG_POR_CARACTER
		texto_label.visible_ratio = min(texto_label.visible_ratio + delta / duracion, 1.0)
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
	hint.visible = true
	retrato.set_hablando(false)


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
