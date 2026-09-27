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
	if (event.is_action_pressed("move_up") or event.is_action_pressed("ui_up")):
		_navegar(-1)
		get_viewport().set_input_as_handled()
	elif (event.is_action_pressed("move_down") or event.is_action_pressed("ui_down")):
		_navegar(1)
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("menu_confirm"):
		get_viewport().set_input_as_handled()
		_on_boton_pressed(_indice)


func _navegar(dir: int) -> void:
	_ui("ui_mover")
	_indice = (_indice + dir + botones.size()) % botones.size()
	botones[_indice].grab_focus()


func _on_focus(i: int) -> void:
	_indice = i


func _on_boton_pressed(i: int) -> void:
	_ui("ui_confirmar")
	match i:
		0:
			_reintentar()
		1:
			TransicionPantalla.de(get_tree()).cambiar_escena(SCENE_MENU)


func _reintentar() -> void:
	var player := get_tree().get_first_node_in_group("player")
	if player != null and player.has_method("tiene_checkpoint") and player.has_method("reaparecer_en_checkpoint") and player.tiene_checkpoint():
		# Con la pantalla en negro: reaparece, se limpian las arenas y se quita el panel.
		TransicionPantalla.de(get_tree()).fundido(func() -> void:
			get_tree().paused = false
			player.reaparecer_en_checkpoint()
			_restaurar_post_muerte()
			queue_free())
	else:
		TransicionPantalla.de(get_tree()).recargar()


## Al morir DENTRO de una arena, el encounter queda RUNNING y la cámara fija al
## centro del combate: al reaparecer el jugador quedaba fuera de encuadre con
## la pelea a medias (y bloqueada). Se resetean las arenas a INACTIVE y se
## restaura la cámara normal para volver al checkpoint limpio.
func _restaurar_post_muerte() -> void:
	var player := get_tree().get_first_node_in_group("player")
	if player != null:
		var cam := player.get_viewport().get_camera_2d()
		if cam != null and cam.has_method("modo_normal"):
			cam.modo_normal(true)
	for e in get_tree().get_nodes_in_group("encounter"):
		if e.has_method("reiniciar"):
			e.reiniciar()


func _ui(nombre: String) -> void:
	var audio := get_node_or_null("/root/AudioManager")
	if audio != null:
		audio.play_ui(nombre)
