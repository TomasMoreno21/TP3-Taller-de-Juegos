extends Control

const SCENE_JUEGO := "res://scenes/main.tscn"
const SCENE_CONTROLES := "res://scenes/controls.tscn"

var _indice := 0
var _controls: CanvasLayer

@onready var botones: Array[Button] = [
	$Center/VBox/Options/Jugar,
	$Center/VBox/Options/Controles,
	$Center/VBox/Options/Salir,
]


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for i in botones.size():
		botones[i].pressed.connect(_on_boton_pressed.bind(i))
		botones[i].focus_entered.connect(_on_focus.bind(i))
	botones[0].grab_focus.call_deferred()
	_animar_entrada()


func _animar_entrada() -> void:
	$Center.modulate.a = 0.0
	var t := create_tween()
	t.tween_property($Center, "modulate:a", 1.0, 0.5).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)


func _unhandled_input(event: InputEvent) -> void:
	if is_instance_valid(_controls):
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


func _navegar(dir: int) -> void:
	_indice = (_indice + dir + botones.size()) % botones.size()
	botones[_indice].grab_focus()


func _on_focus(i: int) -> void:
	_indice = i


func _on_boton_pressed(i: int) -> void:
	match i:
		0:
			_jugar()
		1:
			_abrir_controles()
		2:
			get_tree().quit()


func _jugar() -> void:
	get_node("/root/Progresion").reset()
	get_tree().change_scene_to_file(SCENE_JUEGO)


func _abrir_controles() -> void:
	var c: CanvasLayer = (load(SCENE_CONTROLES) as PackedScene).instantiate()
	_controls = c
	add_child(c)
