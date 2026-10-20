extends CanvasLayer

const SCENE_OPCIONES := "res://scenes/opciones.tscn"
const SCENE_MODO_PRUEBA := "res://scripts/modo_prueba_panel.gd"   # panel armado por código

@export var duracion_fundido := 0.14   ## s del fundido al abrir/cerrar la pausa
var _tween_fundido: Tween
const AMULETO_X := 285.0      ## px a la derecha del centro de la pantalla (el panel mide 480 de ancho)
const AMULETO_Y := 90.0       ## px bajo el centro: la gema; el globo crece hacia arriba
const AMULETO_ANCHO := 400.0
const TAM_GEMA := 96.0
const COLA_GLOBO := 62.0     ## largo de la cola del globo (56) + aire

@export var segundos_por_consejo := 6.0   ## cada cuánto cambia el consejo del Amuleto
var _amuleto: Control
var _retrato: Control
var _gema: Control
var _globo: Control
var _tw_texto: Tween
var _timer_consejo: Timer
var _i_consejo := 0
var _t_flota := 0.0
var _open := false
var _indice := 0
var _sonar := false   ## el foco inicial no suena
var _controls: CanvasLayer

@onready var botones: Array[Button] = [
	$Panel/Margin/VBox/Reanudar,
	$Panel/Margin/VBox/Opciones,
	$Panel/Margin/VBox/ModoPrueba,
	$Panel/Margin/VBox/Menu,
	$Panel/Margin/VBox/Salir,
]
@onready var dim: ColorRect = $Dim


func _ready() -> void:
	visible = true
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 90
	var modo_prueba := get_node_or_null("/root/ModoPrueba")
	if modo_prueba == null or not modo_prueba.habilitado:   # versión final: sin modo prueba ni línea de ubicación
		botones.erase($Panel/Margin/VBox/ModoPrueba)
		$Panel/Margin/VBox/ModoPrueba.hide()
		$Panel/Margin/VBox/Ubicacion.hide()
	for i in botones.size():
		botones[i].pressed.connect(_on_boton_pressed.bind(i))
		botones[i].focus_entered.connect(_on_focus.bind(i))
	$Panel.visible = false
	dim.visible = false
	_armar_amuleto()


## El Amuleto, igual que en el juego (gema + globo de cómic con cola), flota al lado de la ventana
## y va diciendo de a uno los consejos que ya mostró.
func _armar_amuleto() -> void:
	_amuleto = Control.new()
	_amuleto.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_amuleto.visible = false
	add_child(_amuleto)
	_globo = (load("res://scripts/globo_dialogo.gd") as GDScript).new()
	_globo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_amuleto.add_child(_globo)
	_gema = Control.new()
	_gema.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_gema.size = Vector2(TAM_GEMA, TAM_GEMA)
	_amuleto.add_child(_gema)
	_retrato = Control.new()
	_retrato.set_script(load("res://scripts/amuleto_retrato.gd"))
	_retrato.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_retrato.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_gema.add_child(_retrato)
	_timer_consejo = Timer.new()
	_timer_consejo.wait_time = segundos_por_consejo
	_timer_consejo.timeout.connect(_siguiente_consejo)
	add_child(_timer_consejo)


## Ubica el grupo a la derecha de la ventana, centrado en vertical: la gema un poco bajo el medio y el globo encima.
func _ubicar_amuleto() -> void:
	var vp := get_viewport().get_visible_rect().size
	_amuleto.position = Vector2(vp.x * 0.5 + AMULETO_X, vp.y * 0.5 + AMULETO_Y)
	_gema.position = Vector2(AMULETO_ANCHO * 0.5 - TAM_GEMA * 0.5, 0.0)


func _siguiente_consejo(primero := false) -> void:
	var prog := get_node_or_null("/root/Progresion")
	var lista: Array = [] if prog == null else Array(prog.ayuda_vista)
	var texto := "Todavía no tengo consejos. Te iré avisando mientras avanzás."
	if not lista.is_empty():
		_i_consejo = 0 if primero else (_i_consejo + 1) % lista.size()
		texto = str(lista[_i_consejo])
	_globo.configurar(texto, "Amuleto", 0, 26, AMULETO_ANCHO)
	_globo.cola_a = Vector2(_globo.size.x * 0.5, 0.0)   # la cola sale del centro del globo, sobre la gema
	_globo.position = Vector2((AMULETO_ANCHO - _globo.size.x) * 0.5, -_globo.size.y - COLA_GLOBO)
	if _tw_texto != null and _tw_texto.is_valid():
		_tw_texto.kill()
	if DisplayServer.get_name() == "headless":
		_globo.set_ratio(1.0)
		return
	_retrato.set_hablando(true)
	_globo.set_ratio(0.0)
	var dur := clampf(texto.length() * 0.025, 0.4, 3.0)
	_tw_texto = create_tween().set_ignore_time_scale(true).set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	_tw_texto.tween_method(_globo.set_ratio, 0.0, 1.0, dur)
	_tw_texto.tween_callback(_retrato.set_hablando.bind(false))


func _process(delta: float) -> void:
	if _open and _amuleto != null:
		_t_flota += delta
		_gema.position.y = sin(_t_flota * 2.0) * 7.0


func _unhandled_input(event: InputEvent) -> void:
	if is_instance_valid(_controls):
		return
	if event.is_action_pressed("pause"):
		if _dialogo_activo() or _levelup_abierto() or _jugador_muerto() or get_tree().get_first_node_in_group("victoria") != null:
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
	_actualizar_ubicacion()
	$Panel.visible = true
	dim.visible = true
	_amuleto.visible = true
	_ubicar_amuleto()
	_siguiente_consejo(true)
	_timer_consejo.start()
	get_tree().paused = true
	_ui("ui_pausa")
	_sonar = false
	botones[0].grab_focus.call_deferred()
	set.call_deferred("_sonar", true)
	_fundido(true)


func cerrar() -> void:
	if not _open:
		return
	_open = false
	_timer_consejo.stop()
	get_tree().paused = false
	Input.action_release("jump")   # el botón que confirmó (A / Espacio) no debe hacer saltar al volver
	_fundido(false)


## Aparece/desaparece con un fundido corto (reloj real: corre en pausa y con hitstop). En headless es instantáneo.
func _fundido(entra: bool) -> void:
	if _tween_fundido != null and _tween_fundido.is_valid():
		_tween_fundido.kill()
	var panel := $Panel as Control
	if DisplayServer.get_name() == "headless":
		panel.visible = entra
		dim.visible = entra
		_amuleto.visible = entra
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
		_amuleto.modulate.a = 0.0
		_tween_fundido.tween_property(_amuleto, "modulate:a", 1.0, duracion_fundido)
		_tween_fundido.tween_property(panel, "scale", Vector2.ONE, duracion_fundido).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	else:
		_tween_fundido.tween_property(panel, "modulate:a", 0.0, duracion_fundido * 0.7)
		_tween_fundido.tween_property(dim, "modulate:a", 0.0, duracion_fundido * 0.7)
		_tween_fundido.tween_property(_amuleto, "modulate:a", 0.0, duracion_fundido * 0.7)
		_tween_fundido.chain().tween_callback(func() -> void:
			if not _open:
				panel.visible = false
				dim.visible = false
				_amuleto.visible = false)


## Al cerrar un panel el foco quedó huérfano: se lo devuelve al botón elegido (feedback con mando).
func _refocar() -> void:
	if is_inside_tree():
		botones[_indice].grab_focus.call_deferred()


func _navegar(dir: int) -> void:
	_indice = (_indice + dir + botones.size()) % botones.size()
	botones[_indice].grab_focus()


func _on_focus(i: int) -> void:
	if _sonar:
		_ui("ui_mover")
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


## Dónde está el jugador (nivel y checkpoints activados), para que el tester sepa en qué parte del juego está.
func _actualizar_ubicacion() -> void:
	var etiqueta: Label = $Panel/Margin/VBox/Ubicacion
	var modo_prueba := get_node_or_null("/root/ModoPrueba")
	if modo_prueba == null or not modo_prueba.habilitado:
		return
	var texto: String = modo_prueba.nombre_nivel(modo_prueba.indice_de_escena())
	var cp: Vector2i = modo_prueba.checkpoints_progreso()
	if cp.y > 0:
		texto += "\nCheckpoints %d/%d" % [cp.x, cp.y]
	etiqueta.text = texto
	etiqueta.visible = not texto.is_empty()


func _on_boton_pressed(i: int) -> void:
	_ui("ui_confirmar")
	match botones[i].name:
		&"Reanudar":
			cerrar()
		&"Opciones":
			_abrir_opciones()
		&"ModoPrueba":
			_abrir_modo_prueba()
		&"Menu":
			_reiniciar_nivel()
		&"Salir":
			get_tree().quit()


func _reiniciar_nivel() -> void:
	TransicionPantalla.de(get_tree()).recargar()


func _abrir_opciones() -> void:
	var c: CanvasLayer = (load(SCENE_OPCIONES) as PackedScene).instantiate()
	_controls = c
	c.tree_exited.connect(_refocar)
	add_child(c)


func _abrir_modo_prueba() -> void:
	var c: CanvasLayer = (load(SCENE_MODO_PRUEBA) as GDScript).new()
	c.en_juego = true
	c.al_ejecutar = cerrar   # teletransportarse cierra la pausa
	_controls = c
	c.tree_exited.connect(_refocar)
	add_child(c)


func _ui(nombre: String) -> void:
	var audio := get_node_or_null("/root/AudioManager")
	if audio != null:
		audio.play_ui(nombre)
