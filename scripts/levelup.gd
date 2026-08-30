extends CanvasLayer

const OptionScene := preload("res://scenes/levelup_option.tscn")

var _open := false
var _opciones: Array = []
var _indice := 0
var _slots: Array[PanelContainer] = []
var _estilo_normal: StyleBoxFlat

@export var pausar_al_abrir := true  # pausa el juego mientras se elige (off en los autotest)

@onready var panel: Control = $Panel
@onready var title: Label = $Panel/Margin/VBox/Title
@onready var options_row: HBoxContainer = $Panel/Margin/VBox/Options
@onready var hint: Label = $Panel/Margin/VBox/Hint


func _ready() -> void:
	visible = true
	process_mode = Node.PROCESS_MODE_ALWAYS
	add_to_group("levelup")
	panel.visible = false
	var prog: Node = get_node("/root/Progresion")
	prog.nivel_subio.connect(func(_n: int) -> void: abrir())


func esta_abierto() -> bool:
	return _open


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
		_mover_indice(-1)
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("move_down"):
		_mover_indice(1)
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("menu_confirm"):
		_confirmar()
		get_viewport().set_input_as_handled()


func _mover_indice(dir: int) -> void:
	if _opciones.is_empty():
		return
	var candidata := _indice + dir
	for _i in range(_opciones.size()):
		candidata = posmod(candidata, _opciones.size())
		if not _opciones[candidata]["bloqueada"]:
			_indice = candidata
			_render()
			return
		candidata += dir


func _build_opciones() -> void:
	_opciones = []
	var prog: Node = get_node("/root/Progresion")
	var player := get_tree().get_first_node_in_group("player")
	var max_formas := 4
	if player != null:
		max_formas = player.forms.size()
	for i in range(max_formas):
		var nombre := "Humano"
		var color := Color(0.9, 0.9, 0.9)
		if player != null and player.forms[i] != null:
			nombre = player.forms[i].form_name
			color = player.forms[i].color
		_opciones.append({"form_index": i, "nombre": nombre, "color": color, "bloqueada": not prog.forma_desbloqueada(i)})
	_reconstruir_slots()


func _reconstruir_slots() -> void:
	for slot in _slots:
		slot.queue_free()
	_slots = []
	for op in _opciones:
		var slot := OptionScene.instantiate() as PanelContainer
		options_row.add_child(slot)
		if _estilo_normal == null:
			_estilo_normal = slot.get_theme_stylebox("panel") as StyleBoxFlat
		var icon: Control = slot.get_node("VBox/Icon") as Control
		icon.set("forma", op["form_index"])
		icon.set("color_icono", op["color"])
		icon.set("bloqueado", op["bloqueada"])
		(slot.get_node("VBox/Nombre") as Label).text = op["nombre"]
		slot.resized.connect(func() -> void: slot.pivot_offset = slot.size / 2.0)
		_slots.append(slot)


func _render() -> void:
	title.text = "¡NIVEL %d!" % get_node("/root/Progresion").nivel
	for i in range(_slots.size()):
		var slot: PanelContainer = _slots[i]
		if i == _indice and _estilo_normal != null:
			var sel := _estilo_normal.duplicate() as StyleBoxFlat
			sel.border_color = Color(0.95, 0.85, 0.4, 1)
			sel.border_width_left = 3
			sel.border_width_top = 3
			sel.border_width_right = 3
			sel.border_width_bottom = 3
			sel.bg_color = Color(0.2, 0.17, 0.06, 0.9)
			slot.add_theme_stylebox_override("panel", sel)
			slot.scale = Vector2(1.08, 1.08)
		else:
			slot.remove_theme_stylebox_override("panel")
			slot.scale = Vector2.ONE


func _confirmar() -> void:
	if _opciones.is_empty():
		cerrar()
		return
	var op: Dictionary = _opciones[_indice]
	if op["bloqueada"]:
		return
	get_node("/root/Progresion").elegir_mejora(op["form_index"])
	cerrar()