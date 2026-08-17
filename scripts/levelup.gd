extends CanvasLayer

var _open := false
var _opciones: Array = []
var _indice := 0

@export var pausar_al_abrir := true  # pausa el juego mientras se elige (off en los autotest)

@onready var panel: Control = $Panel
@onready var title: Label = $Panel/Margin/VBox/Title
@onready var options_label: RichTextLabel = $Panel/Margin/VBox/Options
@onready var hint: Label = $Panel/Margin/VBox/Hint


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	panel.visible = false
	var prog: Node = get_node("/root/Progresion")
	prog.nivel_subio.connect(func(_n: int) -> void: abrir())


func abrir() -> void:
	if _open:
		return
	_build_opciones()
	_indice = 0
	_open = true
	panel.visible = true
	if pausar_al_abrir:
		get_tree().paused = true
	_render()


func cerrar() -> void:
	if not _open:
		return
	_open = false
	panel.visible = false
	if pausar_al_abrir:
		get_tree().paused = false


func _input(event: InputEvent) -> void:
	if not _open:
		return
	if event.is_action_pressed("move_up"):
		_indice = (_indice - 1 + _opciones.size()) % _opciones.size()
		_render()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("move_down"):
		_indice = (_indice + 1) % _opciones.size()
		_render()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("attack") or event.is_action_pressed("ui_accept"):
		_confirmar()
		get_viewport().set_input_as_handled()


func _build_opciones() -> void:
	_opciones = []
	var prog: Node = get_node("/root/Progresion")
	var player := get_tree().get_first_node_in_group("player")
	var max_formas := 4
	if player != null:
		max_formas = player.forms.size()
	for i in range(max_formas):
		if prog.forma_desbloqueada(i):
			var nombre := "Humano"
			if player != null and player.forms[i] != null:
				nombre = player.forms[i].form_name
			_opciones.append({"form_index": i, "nombre": nombre})


func _render() -> void:
	title.text = "¡NIVEL %d!" % get_node("/root/Progresion").nivel
	var txt := ""
	for i in range(_opciones.size()):
		var op: Dictionary = _opciones[i]
		var marca := "▶" if i == _indice else "  "
		txt += "%s [color=%s]%s[/color]\n" % [marca, "gold" if i == _indice else "white", op["nombre"]]
	options_label.text = txt


func _confirmar() -> void:
	if _opciones.is_empty():
		cerrar()
		return
	var op: Dictionary = _opciones[_indice]
	get_node("/root/Progresion").elegir_mejora(op["form_index"])
	cerrar()