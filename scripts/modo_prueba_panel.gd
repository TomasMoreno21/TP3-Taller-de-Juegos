extends CanvasLayer

## Panel "MODO PRUEBA" (desde el menú principal y desde la pausa). Se arma por código, en tres pantallas simples:
## principal (dónde estás + acciones), niveles (elegir desde dónde jugar) y checkpoints (lista numerada + mapa).
## Pausa / cancelar vuelve a la pantalla anterior; en la principal cierra el panel.

const MAPA := preload("res://scripts/mapa_checkpoints.gd")
const COLOR_TITULO := Color(0.95, 0.85, 0.4)
const COLOR_SUAVE := Color(0.7, 0.75, 0.8)
const COLOR_VISTO := Color(0.6, 0.9, 0.65)

var en_juego := false
var al_ejecutar := Callable()   ## cierra la pausa (la asigna pause.gd); se llama al teletransportar

var _cerrando := false
var _pagina := &"principal"
var _panel: PanelContainer
var _titulo: Label
var _info: Label
var _contenido: VBoxContainer
var _botones_nivel: Array[Button] = []
var _botones_cp: Array[Button] = []
var _b_practica: Button
var _b_nuevo: Button
var _b_equipo: Button
var _mapa   # MapaCheckpoints (script mapa_checkpoints.gd)
var _confirmando := false


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
	sb.border_color = COLOR_TITULO
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(12)
	sb.set_content_margin_all(28)
	_panel.add_theme_stylebox_override("panel", sb)
	_panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	_panel.custom_minimum_size = Vector2(860, 0)
	_panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_panel.grow_vertical = Control.GROW_DIRECTION_BOTH
	add_child(_panel)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 12)
	_panel.add_child(vb)
	_titulo = _etiqueta("", 30, COLOR_TITULO)
	vb.add_child(_titulo)
	_info = _etiqueta("", 19, COLOR_SUAVE)
	_info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_info.custom_minimum_size.x = 800
	vb.add_child(_info)
	_contenido = VBoxContainer.new()
	_contenido.add_theme_constant_override("separation", 10)
	vb.add_child(_contenido)
	_ir_pagina(&"principal")
	_panel.modulate.a = 0.0
	create_tween().tween_property(_panel, "modulate:a", 1.0, 0.2)


func _etiqueta(txt: String, tam: int, color: Color) -> Label:
	var l := Label.new()
	l.text = txt
	l.add_theme_font_size_override("font_size", tam)
	l.add_theme_color_override("font_color", color)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	return l


func _boton(txt: String, accion: Callable, color: Color = Color(0.93, 0.9, 0.84)) -> Button:
	var b := Button.new()
	b.text = txt
	b.custom_minimum_size = Vector2(420, 54)
	b.add_theme_font_size_override("font_size", 22)
	_pintar(b, color)
	b.pressed.connect(accion)
	_contenido.add_child(b)
	return b


func _pintar(b: Button, color: Color) -> void:
	for k in ["font_color", "font_focus_color", "font_hover_color"]:
		b.add_theme_color_override(k, color)


## Cambia de pantalla: vacía el contenido, arma la nueva y deja el foco en el primer botón.
func _ir_pagina(pagina: StringName) -> void:
	_pagina = pagina
	_confirmando = false
	for h in _contenido.get_children():
		_contenido.remove_child(h)
		h.queue_free()
	_botones_nivel.clear()
	_botones_cp.clear()
	match pagina:
		&"niveles":
			_armar_niveles()
		&"checkpoints":
			_armar_checkpoints()
		_:
			_armar_principal()
	for h in _contenido.find_children("*", "Button", true, false):
		if not (h as Button).disabled:
			(h as Button).grab_focus.call_deferred()
			break


# ---------------------------------------------------------------- pantalla principal

func _armar_principal() -> void:
	_titulo.text = "MODO PRUEBA"
	var actual: int = ModoPrueba.indice_de_escena()
	var lineas: Array[String] = []
	if en_juego and actual >= 0:
		lineas.append("Estás en:  " + ModoPrueba.nombre_nivel(actual))
	var probados := 0
	for i in ModoPrueba.rutas.size():
		if ModoPrueba.visitados.has(i):
			probados += 1
	lineas.append("Probaste %d de %d niveles" % [probados, ModoPrueba.rutas.size()])
	if en_juego:
		lineas.append("Formas: " + ModoPrueba.formas_texto())
	_info.text = "\n".join(lineas)

	_boton("ELEGIR NIVEL", _ir_pagina.bind(&"niveles"))
	if en_juego:
		var cps: Array[Node2D] = ModoPrueba.checkpoints()
		var b_cp := _boton("IR A UN CHECKPOINT", _ir_pagina.bind(&"checkpoints"))
		b_cp.disabled = cps.is_empty()
		_boton("VOLVER AL ÚLTIMO CHECKPOINT", _volver_checkpoint)
		_b_equipo = _boton("DAR TODAS LAS FORMAS Y COMBOS", _dar_equipo)
	_b_practica = _boton("", _alternar_practica)
	_b_nuevo = _boton("", _nuevo_tester)
	_b_nuevo.focus_exited.connect(_cancelar_confirmacion)
	_boton("VOLVER", cerrar)
	_refrescar_textos()


func _refrescar_textos() -> void:
	if _b_practica != null:
		_b_practica.text = "PRÁCTICA (vida y energía infinitas):  %s" % ("SÍ" if ModoPrueba.practica else "NO")
		_b_practica.custom_minimum_size.x = 600
	if _b_nuevo != null:
		_b_nuevo.text = "¿SEGURO? PULSÁ DE NUEVO PARA BORRAR TODO" if _confirmando else "NUEVO TESTER (empezar de cero)"
		_pintar(_b_nuevo, Color(1.0, 0.55, 0.5) if _confirmando else Color(0.93, 0.9, 0.84))


func _alternar_practica() -> void:
	ModoPrueba.fijar_practica(not ModoPrueba.practica)
	_refrescar_textos()


func _dar_equipo() -> void:
	ModoPrueba.desbloquear_todo()
	_b_equipo.text = "FORMAS Y COMBOS DADOS"
	_b_equipo.disabled = true
	_info.text = _info.text.get_slice("\nFormas:", 0) + "\nFormas: " + ModoPrueba.formas_texto()
	var sig := _b_equipo.find_next_valid_focus()
	if sig != null:
		sig.grab_focus()


func _nuevo_tester() -> void:
	if _cerrando:
		return
	if not _confirmando:
		_confirmando = true
		_refrescar_textos()
		return
	_confirmando = false
	ModoPrueba.nuevo_tester()
	if en_juego:
		_cerrando = true
		ModoPrueba.volver_al_menu()
	else:
		_ir_pagina(&"principal")


func _cancelar_confirmacion() -> void:
	if _confirmando:
		_confirmando = false
		_refrescar_textos()


func _volver_checkpoint() -> void:
	if _cerrando:
		return
	ModoPrueba.volver_a_checkpoint(al_ejecutar)
	_cerrar_ya()


# ---------------------------------------------------------------- niveles

func _armar_niveles() -> void:
	_titulo.text = "ELEGIR NIVEL"
	_info.text = "Empezás con las formas y los combos que tendrías al llegar ahí.\nVerde: ya lo probaste."
	var actual: int = ModoPrueba.indice_de_escena()
	for i in ModoPrueba.rutas.size():
		var txt: String = ModoPrueba.nombre_nivel(i)
		var color := Color(0.93, 0.9, 0.84)
		if ModoPrueba.visitados.has(i):
			txt += "   ·   %s jugados" % ModoPrueba.tiempo_texto(float(ModoPrueba.segundos.get(i, 0.0)))
			color = COLOR_VISTO
		if en_juego and i == actual:
			txt += "   ·   ESTÁS ACÁ"
			color = COLOR_TITULO
		_botones_nivel.append(_boton(txt, _ir_nivel.bind(i), color))
	_boton("VOLVER", _ir_pagina.bind(&"principal"))


func _ir_nivel(i: int) -> void:
	if _cerrando:
		return
	_cerrando = true
	ModoPrueba.ir_a_nivel(i)


# ---------------------------------------------------------------- checkpoints

func _armar_checkpoints() -> void:
	var actual: int = ModoPrueba.indice_de_escena()
	_titulo.text = "CHECKPOINTS · " + ModoPrueba.nombre_nivel(actual).get_slice(" · ", 1)
	_info.text = "Elegí uno y te llevo ahí.   Verde: ya lo activaste   ·   Dorado: donde reaparecés"
	var cps: Array[Node2D] = ModoPrueba.checkpoints()
	var p := get_tree().get_first_node_in_group("player") as Node2D
	var punto_actual: int = ModoPrueba.checkpoint_actual_idx()

	var fila := HBoxContainer.new()
	fila.add_theme_constant_override("separation", 20)
	_contenido.add_child(fila)
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(390, 420)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	fila.add_child(scroll)
	var lista := VBoxContainer.new()
	lista.add_theme_constant_override("separation", 6)
	lista.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(lista)
	_mapa = MAPA.new()
	fila.add_child(_mapa)

	var puntos: Array[Vector2] = []
	var activados: Array[bool] = []
	for i in cps.size():
		puntos.append(cps[i].global_position)
		activados.append(cps[i].esta_activado())
		var txt := "%d · %s" % [i + 1, ModoPrueba.nombre_checkpoint(cps[i])]
		var color := Color(0.93, 0.9, 0.84)
		if activados[i]:
			color = COLOR_VISTO
		if i == punto_actual:
			txt += "   (reaparecés acá)"
			color = COLOR_TITULO
		var b := Button.new()
		b.text = txt
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.custom_minimum_size = Vector2(0, 46)
		b.add_theme_font_size_override("font_size", 20)
		_pintar(b, color)
		b.pressed.connect(_ir_checkpoint.bind(i))
		b.focus_entered.connect(_mapa.fijar_enfocado.bind(i))
		lista.add_child(b)
		_botones_cp.append(b)
	_mapa.puntos = puntos
	_mapa.activados = activados
	_mapa.actual = punto_actual
	_mapa.jugador = p.global_position if p != null else Vector2.ZERO
	_boton("VOLVER", _ir_pagina.bind(&"principal"))


func _ir_checkpoint(i: int) -> void:
	if _cerrando:
		return
	var cps: Array[Node2D] = ModoPrueba.checkpoints()
	if i < 0 or i >= cps.size():
		return
	ModoPrueba.teletransportar_a(cps[i], al_ejecutar)
	_cerrar_ya()


# ---------------------------------------------------------------- cierre

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause") or event.is_action_pressed("ui_cancel"):
		if _pagina == &"principal":
			cerrar()
		else:
			_ir_pagina(&"principal")
		get_viewport().set_input_as_handled()


func cerrar() -> void:
	if _cerrando:
		return
	_cerrando = true
	var t := create_tween()
	t.tween_property(_panel, "modulate:a", 0.0, 0.12)
	t.tween_callback(queue_free)


## Cierra sin animar (la pausa se cierra sola en el fundido del teletransporte).
func _cerrar_ya() -> void:
	_cerrando = true
	queue_free()
