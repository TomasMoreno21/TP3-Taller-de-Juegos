extends CanvasLayer
## Submenú de Opciones: Controles, Sonido y Créditos. Se abre desde el menú principal y la pausa.

const SCENE_CONTROLES := "res://scenes/controls.tscn"
const SCENE_SONIDO := "res://scenes/sonido.tscn"
const SCENE_CREDITOS := "res://scenes/creditos_final.tscn"   # Esc o al terminar vuelve al menú

var _cerrando := false
var _sub: CanvasLayer

@onready var panel: PanelContainer = $Panel
@onready var botones: Array[Button] = [$Panel/VBox/Controles, $Panel/VBox/Sonido, $Panel/VBox/Creditos, $Panel/VBox/Volver]


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 100
	botones[0].pressed.connect(_abrir.bind(SCENE_CONTROLES))
	botones[1].pressed.connect(_abrir.bind(SCENE_SONIDO))
	botones[2].pressed.connect(_creditos)
	botones[3].pressed.connect(cerrar)
	for b in botones:
		b.pressed.connect(_sonido.bind("ui_confirmar"))
		b.focus_entered.connect(_sonido.bind("ui_mover"))
	botones[0].grab_focus.call_deferred()
	panel.modulate.a = 0.0
	create_tween().tween_property(panel, "modulate:a", 1.0, 0.2).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)


func _sonido(nombre: String) -> void:
	get_node("/root/AudioManager").play_ui(nombre)


func _abrir(ruta: String) -> void:
	_sub = (load(ruta) as PackedScene).instantiate()
	_sub.tree_exited.connect(_refocar.bind(botones.find(get_viewport().gui_get_focus_owner())))
	_sub.layer = layer + 1   # mismo layer: se dibujaba detrás del submenú
	add_child(_sub)


func _refocar(i: int) -> void:
	if is_inside_tree():
		botones[maxi(i, 0)].grab_focus.call_deferred()


func _creditos() -> void:
	get_tree().paused = false
	TransicionPantalla.de(get_tree()).cambiar_escena(SCENE_CREDITOS)


func _unhandled_input(event: InputEvent) -> void:
	if is_instance_valid(_sub):
		return
	if event.is_action_pressed("pause") or event.is_action_pressed("ui_cancel"):
		cerrar()
		get_viewport().set_input_as_handled()


func cerrar() -> void:
	if _cerrando:
		return
	_cerrando = true
	var t := create_tween()
	t.tween_property(panel, "modulate:a", 0.0, 0.12)
	t.tween_callback(queue_free)
