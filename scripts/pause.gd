extends CanvasLayer

const SCENE_CONTROLES := "res://scenes/controls.tscn"
const SCENE_MENU := "res://scenes/main_menu.tscn"
const SCENE_OPCIONES := "res://scenes/opciones.tscn"
const SCENE_AYUDA := "res://scripts/ayuda_panel.gd"   # panel armado por código

@export var duracion_fundido := 0.14   ## s del fundido al abrir/cerrar la pausa
var _tween_fundido: Tween
var _open := false
var _indice := 0
var _controls: CanvasLayer

@onready var botones: Array[Button] = [
	$Panel/Margin/VBox/Reanudar,
	$Panel/Margin/VBox/Controles,
	$Panel/Margin/VBox/Opciones,
	$Panel/Margin/VBox/Ayuda,
	$Panel/Margin/VBox/Menu,
	$Panel/Margin/VBox/VolverMenu,
	$Panel/Margin/VBox/Salir,
]
@onready var dim: ColorRect = $Dim


func _ready() -> void:
	visible = true
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 90
	for i in botones.size():
		botones[i].pressed.connect(_on_boton_pressed.bind(i))
		botones[i].focus_entered.connect(_on_focus.bind(i))
	$Panel.visible = false
	dim.visible = false


func _unhandled_input(event: InputEvent) -> void:
	if is_instance_valid(_controls):
		return
	if event.is_action_pressed("pause"):
		if _consola_abierta() or _dialogo_activo() or _levelup_abierto() or _jugador_muerto():
			return
		toggle()
		get_viewport().set_input_as_handled()
		return
	if not _open:
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


func _consola_abierta() -> bool:
	var consola = get_tree().get_first_node_in_group("console")
	return consola != null and consola.esta_abierta()


func _dialogo_activo() -> bool:
	var dialogo = get_node_or_null("/root/Dialogo")
	return dialogo != null and dialogo.esta_activo()


## Con la secuencia de muerte o el panel "HAS CAÍDO" en pantalla, Esc no debe abrir/cerrar la pausa
## (cerrarla desbloqueaba el juego con el panel puesto).
func _jugador_muerto() -> bool:
	var p := get_tree().get_first_node_in_group("player")
	return p != null and bool(p.get("_derrota_activa"))


func _levelup_abierto() -> bool:
	var levelup = get_tree().get_first_node_in_group("levelup")
	return levelup != null and levelup.esta_abierto()


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
	dim.visible = true
	get_tree().paused = true
	_ui("ui_pausa")
	botones[0].grab_focus.call_deferred()
	_fundido(true)


func cerrar() -> void:
	if not _open:
		return
	_open = false
	get_tree().paused = false
	_fundido(false)


## Aparece/desaparece con un fundido corto (reloj real: corre en pausa y con hitstop). En headless es instantáneo.
func _fundido(entra: bool) -> void:
	if _tween_fundido != null and _tween_fundido.is_valid():
		_tween_fundido.kill()
	var panel := $Panel as Control
	if DisplayServer.get_name() == "headless":
		panel.visible = entra
		dim.visible = entra
		panel.modulate.a = 1.0
		dim.modulate.a = 1.0
		return
	panel.pivot_offset = panel.size * 0.5
	_tween_fundido = create_tween().set_ignore_time_scale(true).set_pause_mode(Tween.TWEEN_PAUSE_PROCESS).set_parallel(true)
	if entra:
		panel.modulate.a = 0.0
		dim.modulate.a = 0.0
		panel.scale = Vector2.ONE * 0.94
		_tween_fundido.tween_property(panel, "modulate:a", 1.0, duracion_fundido)
		_tween_fundido.tween_property(dim, "modulate:a", 1.0, duracion_fundido)
		_tween_fundido.tween_property(panel, "scale", Vector2.ONE, duracion_fundido).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	else:
		_tween_fundido.tween_property(panel, "modulate:a", 0.0, duracion_fundido * 0.7)
		_tween_fundido.tween_property(dim, "modulate:a", 0.0, duracion_fundido * 0.7)
		_tween_fundido.chain().tween_callback(func() -> void:
			if not _open:
				panel.visible = false
				dim.visible = false)


func _navegar(dir: int) -> void:
	_ui("ui_mover")
	_indice = (_indice + dir + botones.size()) % botones.size()
	botones[_indice].grab_focus()


func _on_focus(i: int) -> void:
	_indice = i
	for k in botones.size():
		var b := botones[k]
		b.pivot_offset = b.size * 0.5
		var objetivo := Vector2.ONE * (1.05 if k == i else 1.0)
		if DisplayServer.get_name() == "headless":
			b.scale = objetivo
			continue
		b.create_tween().set_ignore_time_scale(true).set_pause_mode(Tween.TWEEN_PAUSE_PROCESS) \
			.tween_property(b, "scale", objetivo, 0.1).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _on_boton_pressed(i: int) -> void:
	_ui("ui_confirmar")
	match i:
		0:
			cerrar()
		1:
			_abrir_controles()
		2:
			_abrir_opciones()
		3:
			_abrir_ayuda()
		4:
			_reiniciar_nivel()
		5:
			_volver_menu()
		6:
			get_tree().quit()


func _reiniciar_nivel() -> void:
	TransicionPantalla.de(get_tree()).recargar()


func _abrir_controles() -> void:
	var c: CanvasLayer = (load(SCENE_CONTROLES) as PackedScene).instantiate()
	_controls = c
	add_child(c)


func _abrir_opciones() -> void:
	var c: CanvasLayer = (load(SCENE_OPCIONES) as PackedScene).instantiate()
	_controls = c
	add_child(c)


func _abrir_ayuda() -> void:
	var c: CanvasLayer = (load(SCENE_AYUDA) as GDScript).new()
	_controls = c
	add_child(c)


func _volver_menu() -> void:
	TransicionPantalla.de(get_tree()).cambiar_escena(SCENE_MENU)


func _ui(nombre: String) -> void:
	var audio := get_node_or_null("/root/AudioManager")
	if audio != null:
		audio.play_ui(nombre)
