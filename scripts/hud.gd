extends CanvasLayer

const SALIDA_DUR := 2.2
const GOLPES_MAX := 2
const FILA_PASO := 44.0

var _player: Node2D
var _idle_timer: Timer
var _top_timer: Timer
var _cola_avisos: Array[String] = []
var _filas: Array[RichTextLabel] = []
var _fila_tweens: Array[Tween] = []
var _historial: Array[String] = []
var _combo_base_pos: Vector2

@onready var info: RichTextLabel = $Margin/Info
@onready var combo_label: RichTextLabel = $ComboLabel
@onready var hp_bar: ProgressBar = $Bars/Rows/HpRow/HpBar
@onready var esp_bar: ProgressBar = $Bars/Rows/EspRow/EspBar
@onready var prog_label: Label = $ProgLabel
@onready var sel_label: Label = $SelLabel
@onready var aviso: Label = $Aviso


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS

	_idle_timer = Timer.new()
	_idle_timer.wait_time = 1.5
	_idle_timer.one_shot = true
	_idle_timer.timeout.connect(_limpiar_idle)
	add_child(_idle_timer)

	_top_timer = Timer.new()
	_top_timer.wait_time = SALIDA_DUR
	_top_timer.one_shot = true
	_top_timer.timeout.connect(_fade_top)
	add_child(_top_timer)

	_crear_filas()
	_combo_base_pos = combo_label.position

	var prog: Node = get_node("/root/Progresion")
	prog.fragmentos_cambiado.connect(_on_fragmentos)
	prog.nivel_cambiado.connect(_on_nivel)
	prog.nivel_subio.connect(_on_nivel_subio)
	prog.combo_desbloqueado.connect(_on_combo)

	_prog_refresh()
	_connectar_player.call_deferred()


func _connectar_player() -> void:
	_player = get_tree().get_first_node_in_group("player")
	if _player == null:
		return
	_player.form_changed.connect(_on_form_changed)
	_player.forma_selectada_cambiada.connect(_on_forma_selectada)
	_player.attack_performed.connect(_on_attack_performed)
	_player.health_changed.connect(_on_health_changed)
	_player.energia_changed.connect(_on_energia_changed)
	_player.transformacion_agotada.connect(_on_agotada)
	_actualizar_selector()


func _on_fragmentos(_total: int) -> void:
	_prog_refresh()


func _on_nivel(_nuevo: int) -> void:
	_prog_refresh()
	_actualizar_selector()


func _on_combo(_form_index: int, combo_nombre: String) -> void:
	_aviso("¡%s desbloqueado!" % combo_nombre)


func _on_nivel_subio(nuevo_nivel: int) -> void:
	_aviso("¡NIVEL %d ALCANZADO!" % nuevo_nivel)
	var form_nombre := _forma_nueva(nuevo_nivel)
	if form_nombre != "":
		_aviso("¡%s DESBLOQUEADO!" % form_nombre)


func _forma_nueva(nuevo_nivel: int) -> String:
	var form_idx := nuevo_nivel - 1
	if form_idx <= 0:
		return ""
	var player := get_tree().get_first_node_in_group("player")
	if player != null and player.forms.size() > form_idx:
		return str(player.forms[form_idx].form_name)
	return ""


func _on_form_changed(form_name: String) -> void:
	_aviso("Forma: %s" % form_name)


func _on_forma_selectada(_index: int) -> void:
	_actualizar_selector()


func _actualizar_selector() -> void:
	if _player == null:
		return
	var prog: Node = get_node("/root/Progresion")
	var partes: Array[String] = []
	for i in range(_player.forms.size()):
		if not prog.forma_desbloqueada(i):
			continue
		var nombre := str(_player.forms[i].form_name).to_upper()
		if i == _player.current_form and i == _player.forma_seleccionada:
			partes.append("◈ " + nombre)
		elif i == _player.forma_seleccionada:
			partes.append("[" + nombre + "]")
		else:
			partes.append(nombre)
	sel_label.text = "FORMAS   " + "   ".join(partes)


func _crear_filas() -> void:
	_filas = [combo_label]
	_fila_tweens = [null]
	combo_label.visible = false
	for i in range(1, GOLPES_MAX):
		var f := RichTextLabel.new()
		f.bbcode_enabled = true
		f.scroll_active = false
		f.add_theme_font_size_override("normal_font_size", 34)
		f.vertical_alignment = 1
		f.horizontal_alignment = 2
		f.anchor_left = 1.0
		f.anchor_right = 1.0
		f.anchor_top = 1.0
		f.anchor_bottom = 1.0
		f.offset_left = -560.0
		f.offset_right = -160.0
		f.offset_top = -80.0 - i * FILA_PASO
		f.offset_bottom = -32.0 - i * FILA_PASO
		f.modulate.a = 0.0
		f.visible = false
		add_child(f)
		_filas.append(f)
		_fila_tweens.append(null)


func _on_attack_performed(_attack_type: String, _step: Variant) -> void:
	_idle_timer.start()
	var txt := _texto_ataque(_attack_type, _step)
	_historial.push_front(txt)
	if _historial.size() > GOLPES_MAX:
		_historial.pop_back()
	_pintar_golpes()


func _pintar_golpes() -> void:
	for i in range(GOLPES_MAX):
		var fila: RichTextLabel = _filas[i]
		if i >= _historial.size():
			fila.text = ""
			fila.visible = false
			continue
		fila.text = _historial[i]
		fila.visible = true
		if _fila_tweens[i] != null:
			_fila_tweens[i].kill()
			_fila_tweens[i] = null
		if i == 0:
			_fila_tweens[i] = create_tween()
			_fila_tweens[i].tween_property(fila, "modulate:a", 1.0, 0.25)
		else:
			fila.modulate.a = 1.0
			_fila_tweens[i] = create_tween()
			_fila_tweens[i].tween_interval(0.25)
			_fila_tweens[i].tween_property(fila, "modulate:a", 0.0, 0.25)


func _texto_ataque(_attack_type: String, _step: Variant) -> String:
	if _attack_type == "combo":
		return "[color=#ffd76a]%s[/color]" % str(_step)
	var nombre := "LIGERO" if _attack_type == "light" else ("FUERTE" if _attack_type == "heavy" else "ESPECIAL")
	return "[color=#ffd76a]%s[/color]" % nombre


func _on_health_changed(hp: int, max_hp: int) -> void:
	hp_bar.max_value = max_hp
	hp_bar.value = hp


func _on_energia_changed(energia: float) -> void:
	esp_bar.max_value = 100.0
	esp_bar.value = energia


func _on_agotada() -> void:
	_aviso("Transformación agotada")


func _prog_refresh() -> void:
	var prog: Node = get_node("/root/Progresion")
	prog_label.text = "FRAGMENTOS %d/3 · NIVEL %d" % [prog.fragmentos % 3, prog.nivel]


func _limpiar_idle() -> void:
	var activa: RichTextLabel = _filas[0]
	if activa.text == "":
		_limpiar_todo()
		return
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(activa, "position:x", activa.position.x - 220.0, 0.6).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	tw.tween_property(activa, "modulate:a", 0.0, 0.6)
	tw.finished.connect(_limpiar_todo)


func _limpiar_todo() -> void:
	_historial.clear()
	for i in range(_filas.size()):
		if _fila_tweens[i] != null:
			_fila_tweens[i].kill()
			_fila_tweens[i] = null
		_filas[i].text = ""
		_filas[i].visible = false
		_filas[i].modulate.a = 0.0
	_filas[0].position = _combo_base_pos


func _aviso(texto: String) -> void:
	if aviso.visible:
		_cola_avisos.append(texto)
		return
	_mostrar_aviso(texto)


func _mostrar_aviso(texto: String) -> void:
	aviso.text = texto
	aviso.visible = true
	aviso.modulate.a = 1.0
	_top_timer.start()


func _fade_top() -> void:
	if aviso.visible:
		var t := create_tween()
		t.tween_property(aviso, "modulate:a", 0.0, 0.6)
		t.tween_callback(func() -> void:
			aviso.visible = false
			_siguiente_aviso()
		)
	else:
		_siguiente_aviso()


func _siguiente_aviso() -> void:
	if _cola_avisos.is_empty():
		return
	_mostrar_aviso(_cola_avisos.pop_front())
