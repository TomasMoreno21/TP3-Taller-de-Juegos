extends CanvasLayer

## "Ayuda del Amuleto" (desde la pausa): elegir cuánta ayuda se quiere y releer los consejos
## y controles que el Amuleto ya mostró. Se arma por código y se cierra con Volver / pausa / cancelar.

var _cerrando := false
var _panel: PanelContainer
var _boton_nivel: Button
var _volver: Button


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 100
	var fondo := ColorRect.new()
	fondo.color = Color(0.02, 0.025, 0.03, 0.95)
	fondo.set_anchors_preset(Control.PRESET_FULL_RECT)
	fondo.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(fondo)
	_panel = PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.06, 0.07, 0.09, 0.97)
	sb.border_color = Color(0.95, 0.85, 0.4)
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(12)
	sb.set_content_margin_all(28)
	_panel.add_theme_stylebox_override("panel", sb)
	_panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	_panel.custom_minimum_size = Vector2(760, 0)
	_panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_panel.grow_vertical = Control.GROW_DIRECTION_BOTH
	add_child(_panel)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 14)
	_panel.add_child(vb)
	var titulo := Label.new()
	titulo.text = "AYUDA DEL AMULETO"
	titulo.add_theme_font_size_override("font_size", 28)
	titulo.add_theme_color_override("font_color", Color(0.95, 0.85, 0.4))
	titulo.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vb.add_child(titulo)
	_boton_nivel = _boton("")
	_boton_nivel.pressed.connect(_ciclar_nivel)
	vb.add_child(_boton_nivel)
	var sub := Label.new()
	sub.text = "Lo que el Amuleto ya te enseñó:"
	sub.add_theme_font_size_override("font_size", 18)
	sub.add_theme_color_override("font_color", Color(0.65, 0.7, 0.75))
	vb.add_child(sub)
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(0, 280)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	vb.add_child(scroll)
	var lista := Label.new()
	lista.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	lista.custom_minimum_size.x = 700
	lista.add_theme_font_size_override("font_size", 19)
	lista.add_theme_color_override("font_color", Color(0.9, 0.92, 0.85))
	lista.text = _texto_consejos()
	scroll.add_child(lista)
	_volver = _boton("VOLVER")
	_volver.pressed.connect(cerrar)
	vb.add_child(_volver)
	_actualizar_boton()
	_boton_nivel.grab_focus.call_deferred()
	_panel.modulate.a = 0.0
	create_tween().tween_property(_panel, "modulate:a", 1.0, 0.2)


func _boton(txt: String) -> Button:
	var b := Button.new()
	b.text = txt
	b.custom_minimum_size = Vector2(360, 50)
	b.add_theme_font_size_override("font_size", 20)
	return b


func _texto_consejos() -> String:
	var prog := get_node_or_null("/root/Progresion")
	if prog == null or prog.ayuda_vista.is_empty():
		return "Todavía no hay consejos. El Amuleto te irá avisando mientras avanzás."
	var lineas: Array[String] = []
	for t in prog.ayuda_vista:
		lineas.append("•  " + str(t))
	return "\n".join(lineas)


func _ciclar_nivel() -> void:
	var dlg := get_node_or_null("/root/Dialogo")
	if dlg == null:
		return
	dlg.set_nivel_ayuda((dlg.nivel_ayuda + 2) % 3)   # Completa → Ligera → Ninguna → Completa
	_actualizar_boton()


func _actualizar_boton() -> void:
	var dlg := get_node_or_null("/root/Dialogo")
	var n: int = dlg.nivel_ayuda if dlg != null else 2
	_boton_nivel.text = "AYUDA: %s" % str(["NINGUNA", "LIGERA", "COMPLETA"][n])


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause") or event.is_action_pressed("ui_cancel"):
		cerrar()
		get_viewport().set_input_as_handled()


func cerrar() -> void:
	if _cerrando:
		return
	_cerrando = true
	var t := create_tween()
	t.tween_property(_panel, "modulate:a", 0.0, 0.12)
	t.tween_callback(queue_free)
