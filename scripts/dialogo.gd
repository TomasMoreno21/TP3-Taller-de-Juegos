extends CanvasLayer

## Autoload "Dialogo": caja de diálogo reusable (narrativa + tutorial in-game).
## Uso: get_node("/root/Dialogo").mostrar(["línea 1", "línea 2"], "Amuleto")

signal dialogo_terminado

const SEG_POR_CARACTER := 0.022

var _cola: Array[Dictionary] = []
var _abierto := false
var _texto_completo := ""
var _tipeando := false

@onready var panel: PanelContainer = $Panel
@onready var nombre_label: Label = $Panel/Margin/HBox/VBox/Nombre
@onready var texto_label: RichTextLabel = $Panel/Margin/HBox/VBox/Texto
@onready var hint: Label = $Panel/Margin/HBox/VBox/Hint
@onready var retrato: Control = $Panel/Margin/HBox/RetratoWrap/Retrato


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 85
	panel.visible = false


func esta_activo() -> bool:
	return _abierto


func mostrar(lineas: Array, hablante: String = "Amuleto") -> void:
	for l in lineas:
		_cola.append({"texto": String(l), "hablante": hablante})
	if not _abierto:
		_abierto = true
		get_tree().paused = true
		panel.visible = true
		_siguiente_linea()


func _siguiente_linea() -> void:
	if _cola.is_empty():
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
	if not _abierto or not _tipeando:
		return
	var duracion: float = max(_texto_completo.length(), 1) * SEG_POR_CARACTER
	texto_label.visible_ratio = min(texto_label.visible_ratio + delta / duracion, 1.0)
	if texto_label.visible_ratio >= 1.0:
		_terminar_tipeo()


func _terminar_tipeo() -> void:
	_tipeando = false
	hint.visible = true
	retrato.set_hablando(false)


func _unhandled_input(event: InputEvent) -> void:
	if not _abierto:
		return
	if event.is_action_pressed("attack") or event.is_action_pressed("ui_accept"):
		if _tipeando:
			texto_label.visible_ratio = 1.0
			_terminar_tipeo()
		else:
			_siguiente_linea()
		get_viewport().set_input_as_handled()


func _cerrar() -> void:
	_abierto = false
	panel.visible = false
	get_tree().paused = false
	dialogo_terminado.emit()
