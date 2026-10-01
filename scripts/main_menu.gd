extends Control

const SCENE_JUEGO := "res://scenes/comic_intro.tscn"   # intro en viñetas; al terminar carga nivel1
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
	_precargar_juego.call_deferred()
	_animar_entrada()


func _precargar_juego() -> void:
	TransicionPantalla.de(get_tree()).precargar(SCENE_JUEGO)


func _animar_entrada() -> void:
	$Center.modulate.a = 0.0
	var t := create_tween()
	t.tween_property($Center, "modulate:a", 1.0, 0.5).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)


func _unhandled_input(event: InputEvent) -> void:
	if is_instance_valid(_controls):
		return
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
	_resaltar(i)


## El botón con foco crece un poco y los demás vuelven a su tamaño (feedback de selección).
func _resaltar(i: int) -> void:
	for k in botones.size():
		var b := botones[k]
		b.pivot_offset = b.size * 0.5
		var objetivo := Vector2.ONE * (1.06 if k == i else 1.0)
		if DisplayServer.get_name() == "headless":
			b.scale = objetivo
			continue
		var tw := b.create_tween()
		tw.tween_property(b, "scale", objetivo, 0.12).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _on_boton_pressed(i: int) -> void:
	_ui("ui_confirmar")
	match i:
		0:
			_jugar()
		1:
			_abrir_controles()
		2:
			get_tree().quit()


func _jugar() -> void:
	get_node("/root/Progresion").reset()
	TransicionPantalla.de(get_tree()).cambiar_escena(SCENE_JUEGO)


func _abrir_controles() -> void:
	var c: CanvasLayer = (load(SCENE_CONTROLES) as PackedScene).instantiate()
	_controls = c
	add_child(c)


func _ui(nombre: String) -> void:
	var audio := get_node_or_null("/root/AudioManager")
	if audio != null:
		audio.play_ui(nombre)
