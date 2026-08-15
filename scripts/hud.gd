extends CanvasLayer

const SALIDA_DUR := 2.2

var _player: Node2D
var _idle_timer: Timer
var _top_timer: Timer
var _cola_avisos: Array[String] = []

@onready var info: RichTextLabel = $Margin/Info
@onready var combo_label: RichTextLabel = $ComboLabel
@onready var hp_bar: ProgressBar = $Bars/Rows/HpRow/HpBar
@onready var esp_bar: ProgressBar = $Bars/Rows/EspRow/EspBar
@onready var esp_cap: PanelContainer = $Bars/Rows/EspRow/EspCap
@onready var prog_label: Label = $ProgLabel
@onready var aviso: Label = $Aviso
@onready var racha_box: VBoxContainer = $Racha
@onready var racha_valor: Label = $Racha/Valor

var _esp_cap_style: StyleBoxFlat


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS

	_esp_cap_style = esp_cap.get_theme_stylebox("panel").duplicate()
	esp_cap.add_theme_stylebox_override("panel", _esp_cap_style)

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
	_player.attack_performed.connect(_on_attack_performed)
	_player.health_changed.connect(_on_health_changed)
	_player.energia_changed.connect(_on_energia_changed)
	_player.transformacion_agotada.connect(_on_agotada)
	_player.racha_changed.connect(_on_racha_changed)
	_actualizar_cap_forma()


func _on_fragmentos(_total: int) -> void:
	_prog_refresh()


func _on_nivel(_nuevo: int) -> void:
	_prog_refresh()


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
	_actualizar_cap_forma()


func _actualizar_cap_forma() -> void:
	if _player == null or _esp_cap_style == null:
		return
	var data = _player.forms[_player.current_form]
	_esp_cap_style.bg_color = data.color


func _on_racha_changed(cantidad: int) -> void:
	if cantidad >= 2:
		racha_valor.text = str(cantidad)
		racha_box.visible = true
	else:
		racha_box.visible = false


func _on_attack_performed(_attack_type: String, _step: Variant) -> void:
	_idle_timer.start()


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
	combo_label.text = ""


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
