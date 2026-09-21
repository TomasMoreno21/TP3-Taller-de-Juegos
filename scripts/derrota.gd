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
	elif event.is_action_pressed("menu_confirm"):
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
	var player := get_tree().get_first_node_in_group("player")
	if player != null and player.has_method("tiene_checkpoint") and player.has_method("reaparecer_en_checkpoint") and player.tiene_checkpoint():
		player.reaparecer_en_checkpoint()
		_restaurar_post_muerte()
		queue_free()
	else:
		get_tree().reload_current_scene()


## Al morir DENTRO de una arena, el encounter queda RUNNING y la cámara fija al
## centro del combate: al reaparecer el jugador quedaba fuera de encuadre con
## la pelea a medias (y bloqueada). Se resetean las arenas a INACTIVE y se
## restaura la cámara normal para volver al checkpoint limpio.
func _restaurar_post_muerte() -> void:
	var player := get_tree().get_first_node_in_group("player")
	if player != null:
		var cam := player.get_viewport().get_camera_2d()
		if cam != null and cam.has_method("modo_normal"):
			cam.modo_normal()
	for e in get_tree().get_nodes_in_group("encounter"):
		if e.has_method("reiniciar"):
			e.reiniciar()
