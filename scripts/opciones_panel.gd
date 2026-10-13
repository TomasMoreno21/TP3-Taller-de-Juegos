extends CanvasLayer
## Panel de opciones (música, efectos, pantalla completa). Se abre desde el menú y la pausa.

var _cerrando := false
var _t_click := 0.0

@onready var panel: PanelContainer = $Panel
@onready var s_musica: HSlider = $Panel/VBox/FilaMusica/Slider
@onready var s_sfx: HSlider = $Panel/VBox/FilaSfx/Slider
@onready var b_pantalla: Button = $Panel/VBox/Pantalla
@onready var volver: Button = $Panel/VBox/Volver


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 100
	var o := get_node("/root/Opciones")
	s_musica.set_value_no_signal(o.volumen_musica)
	s_sfx.set_value_no_signal(o.volumen_sfx)
	b_pantalla.set_pressed_no_signal(o.pantalla_completa)
	_texto_pantalla()
	s_musica.value_changed.connect(o.fijar_musica)
	s_sfx.value_changed.connect(_on_sfx)
	b_pantalla.toggled.connect(_on_pantalla)
	volver.pressed.connect(cerrar)
	s_musica.grab_focus.call_deferred()
	panel.modulate.a = 0.0
	create_tween().tween_property(panel, "modulate:a", 1.0, 0.2).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)


func _on_sfx(v: float) -> void:
	get_node("/root/Opciones").fijar_sfx(v)
	var ahora := Time.get_ticks_msec() * 0.001
	if ahora - _t_click > 0.12:   # sonido de prueba, sin saturar mientras se arrastra
		_t_click = ahora
		get_node("/root/AudioManager").play_ui("ui_mover")


func _on_pantalla(activa: bool) -> void:
	get_node("/root/Opciones").fijar_pantalla_completa(activa)
	_texto_pantalla()


func _texto_pantalla() -> void:
	b_pantalla.text = "PANTALLA COMPLETA: %s" % ("SÍ" if b_pantalla.button_pressed else "NO")


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
