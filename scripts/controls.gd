extends CanvasLayer

var _cerrando := false

@onready var panel: PanelContainer = $Panel
@onready var volver: Button = $Panel/Margin/VBox/Volver


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 100
	volver.pressed.connect(cerrar)
	volver.grab_focus.call_deferred()
	panel.modulate.a = 0.0
	var t := create_tween()
	t.tween_property(panel, "modulate:a", 1.0, 0.2).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)


func _unhandled_input(event: InputEvent) -> void:
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
