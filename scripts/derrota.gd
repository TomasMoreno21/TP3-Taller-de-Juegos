extends CanvasLayer

const SCENE_MENU := "res://scenes/main_menu.tscn"

var _indice := 0

@onready var botones: Array[Button] = [
	$UIRoot/Center/VBox/Panel/Opciones/BotonReintentar,
	$UIRoot/Center/VBox/Panel/Opciones/BotonMenu,
]


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 95
	for i in botones.size():
		botones[i].pressed.connect(_on_boton_pressed.bind(i))
		botones[i].focus_entered.connect(_on_focus.bind(i))
	botones[_indice].grab_focus.call_deferred()
	$UIRoot/Dim.visible = true


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("move_up"):
		_navegar(-1)
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("move_down"):
		_navegar(1)
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("attack"):
		get_viewport().set_input_as_handled()
		_on_boton_pressed(_indice)


func _navegar(dir: int) -> void:
	_indice = (_indice + dir + botones.size()) % botones.size()
	botones[_indice].grab_focus()


func _on_focus(i: int) -> void:
	_indice = i


func _on_boton_pressed(i: int) -> void:
	match i:
		0:
			_reintentar()
		1:
			get_tree().paused = false
			get_tree().change_scene_to_file(SCENE_MENU)


func _reintentar() -> void:
	get_tree().paused = false
	get_tree().reload_current_scene()
