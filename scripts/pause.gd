extends CanvasLayer

const SCENE_CONTROLES := "res://scenes/controls.tscn"
const SCENE_MENU := "res://scenes/main_menu.tscn"

var _open := false
var _indice := 0
var _controls: CanvasLayer

@onready var botones: Array[Button] = [
	$Panel/Margin/VBox/Reanudar,
	$Panel/Margin/VBox/Controles,
	$Panel/Margin/VBox/Menu,
	$Panel/Margin/VBox/Salir,
]


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 90
	for i in botones.size():
		botones[i].pressed.connect(_on_boton_pressed.bind(i))
		botones[i].focus_entered.connect(_on_focus.bind(i))
	$Panel.visible = false


func _unhandled_input(event: InputEvent) -> void:
	if is_instance_valid(_controls):
		return
	if event.is_action_pressed("pause"):
		if _consola_abierta() or _dialogo_activo():
			return
		toggle()
		get_viewport().set_input_as_handled()
		return
	if not _open:
		return
	if event.is_action_pressed("move_up"):
		_navegar(-1)
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("move_down"):
		_navegar(1)
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("attack"):
		_on_boton_pressed(_indice)
		get_viewport().set_input_as_handled()


func _consola_abierta() -> bool:
	var consola = get_tree().get_first_node_in_group("console")
	return consola != null and consola.esta_abierta()


func _dialogo_activo() -> bool:
	var dialogo = get_node_or_null("/root/Dialogo")
	return dialogo != null and dialogo.esta_activo()


func toggle() -> void:
	if _open:
		cerrar()
	else:
		abrir()


func abrir() -> void:
	if _open:
		return
	_open = true
	_indice = 0
	$Panel.visible = true
	get_tree().paused = true
	botones[0].grab_focus.call_deferred()


func cerrar() -> void:
	if not _open:
		return
	_open = false
	$Panel.visible = false
	get_tree().paused = false


func _navegar(dir: int) -> void:
	_indice = (_indice + dir + botones.size()) % botones.size()
	botones[_indice].grab_focus()


func _on_focus(i: int) -> void:
	_indice = i


func _on_boton_pressed(i: int) -> void:
	match i:
		0:
			cerrar()
		1:
			_abrir_controles()
		2:
			_volver_menu()
		3:
			get_tree().quit()


func _abrir_controles() -> void:
	var c: CanvasLayer = (load(SCENE_CONTROLES) as PackedScene).instantiate()
	_controls = c
	add_child(c)


func _volver_menu() -> void:
	get_tree().paused = false
	get_tree().change_scene_to_file(SCENE_MENU)
