extends CanvasLayer

const OptionScene := preload("res://scenes/levelup_option.tscn")

var _open := false
var _pendientes := 0
var _opciones: Array = []
var _indice := 0
var _slots: Array[PanelContainer] = []
var _estilo_normal: StyleBoxFlat
var _es_joypad := false

@export var pausar_al_abrir := true  # pausa el juego mientras se elige (off en los autotest)
@export var entrada_duracion := 0.28   ## animación de entrada del panel (escala + fundido)
@export var sonido_abrir: AudioStream = preload("res://assets/audio/sfx/gen/nivel_subido.wav")
@export var volumen_abrir_db := -6.0

@onready var panel: Control = $Panel
@onready var title: Label = $Panel/Margin/VBox/Title
@onready var options_row: HBoxContainer = $Panel/Margin/VBox/Options
@onready var combo_nombre: Label = $Panel/Margin/VBox/ComboInfo/ComboNombre
@onready var combo_funcion: Label = $Panel/Margin/VBox/ComboInfo/ComboFuncion
@onready var combo_como: Label = $Panel/Margin/VBox/ComboInfo/ComboComo
@onready var hint: Label = $Panel/Margin/VBox/Hint


func _ready() -> void:
	visible = true
	process_mode = Node.PROCESS_MODE_ALWAYS
	add_to_group("levelup")
	panel.visible = false
	var prog: Node = get_node("/root/Progresion")
	prog.nivel_subio.connect(func(_n: int) -> void: abrir())
	prog.forma_desbloqueada_evento.connect(func(_f: int) -> void: _canjear_diferida())


func esta_abierto() -> bool:
	return _open


func abrir() -> void:
	if _open:
		_pendientes += 1
		return
	_build_opciones()
	if _primera_elegible() < 0:
		# Ninguna forma desbloqueada tiene un combo pendiente: la mejora espera a la próxima forma.
		get_node("/root/Progresion").mejoras_diferidas += 1
		_reconstruir_slots_vacio()
		return
	_indice = _primera_elegible()
	_open = true
	panel.visible = true
	if pausar_al_abrir:
		get_tree().paused = true
	_render()
	_animar_entrada()


## El panel "salta" desde chico y transparente (el tween corre aunque el árbol esté
## en pausa: este CanvasLayer es PROCESS_MODE_ALWAYS).
func _animar_entrada() -> void:
	var audio := get_node_or_null("/root/AudioManager")
	if audio != null:
		audio.play_sfx(sonido_abrir, volumen_abrir_db)
	panel.pivot_offset = panel.size * 0.5
	panel.scale = Vector2.ONE * 0.8
	panel.modulate.a = 0.0
	var tw := create_tween().set_parallel(true)
	tw.tween_property(panel, "scale", Vector2.ONE, entrada_duracion).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(panel, "modulate:a", 1.0, entrada_duracion * 0.6)


func cerrar() -> void:
	if not _open:
		return
	_open = false
	panel.visible = false
	if _pendientes > 0:
		_pendientes -= 1
		abrir()
		return
	if pausar_al_abrir:
		get_tree().paused = false


func _input(event: InputEvent) -> void:
	if not _open:
		return
	if event is InputEventJoypadButton or event is InputEventJoypadMotion:
		_es_joypad = true
	elif event is InputEventKey:
		_es_joypad = false
	if (event.is_action_pressed("move_up") or event.is_action_pressed("ui_up")):
		_mover_indice(-1)
		get_viewport().set_input_as_handled()
	elif (event.is_action_pressed("move_down") or event.is_action_pressed("ui_down")):
		_mover_indice(1)
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("menu_confirm"):
		_confirmar()
		get_viewport().set_input_as_handled()


func _mover_indice(dir: int) -> void:
	if _opciones.is_empty():
		return
	_ui("ui_mover")
	var candidata := _indice + dir
	for _i in range(_opciones.size()):
		candidata = posmod(candidata, _opciones.size())
		if not _opciones[candidata]["bloqueada"]:
			_indice = candidata
			_render()
			return
		candidata += dir


## Si hay una mejora esperando y ya hay una forma con combo pendiente, abre el menú.
func _canjear_diferida() -> void:
	var prog: Node = get_node("/root/Progresion")
	if int(prog.mejoras_diferidas) <= 0:
		return
	prog.mejoras_diferidas -= 1
	abrir()


func _primera_elegible() -> int:
	for i in range(_opciones.size()):
		if not _opciones[i]["bloqueada"]:
			return i
	return -1


func _reconstruir_slots_vacio() -> void:
	_opciones = []
	_reconstruir_slots()


## ¿La forma ya tiene todos sus combos? Entonces no aparece más entre las opciones.
func _forma_completa(player: Node, prog: Node, i: int) -> bool:
	if player == null or player.forms.size() <= i or player.forms[i] == null:
		return false
	return prog.combos_desbloqueados_forma(i) >= player.forms[i].combos.size()


func _build_opciones() -> void:
	_opciones = []
	var prog: Node = get_node("/root/Progresion")
	var player := get_tree().get_first_node_in_group("player")
	var max_formas := 4
	if player != null:
		max_formas = player.forms.size()
	for i in range(max_formas):
		if _forma_completa(player, prog, i):
			continue
		var nombre := "Humano"
		var color := Color(0.9, 0.9, 0.9)
		if player != null and player.forms[i] != null:
			nombre = player.forms[i].form_name
			color = player.forms[i].color
		_opciones.append({"form_index": i, "nombre": nombre, "color": color, "bloqueada": not prog.forma_desbloqueada(i)})
	_reconstruir_slots()


func _reconstruir_slots() -> void:
	for slot in _slots:
		slot.queue_free()
	_slots = []
	for op in _opciones:
		var slot := OptionScene.instantiate() as PanelContainer
		options_row.add_child(slot)
		if _estilo_normal == null:
			_estilo_normal = slot.get_theme_stylebox("panel") as StyleBoxFlat
		var icon: Control = slot.get_node("VBox/Icon") as Control
		icon.set("forma", op["form_index"])
		icon.set("color_icono", op["color"])
		icon.set("bloqueado", op["bloqueada"])
		(slot.get_node("VBox/Nombre") as Label).text = op["nombre"]
		slot.resized.connect(func() -> void: slot.pivot_offset = slot.size / 2.0)
		_slots.append(slot)


func _render() -> void:
	title.text = "¡NIVEL %d!" % get_node("/root/Progresion").nivel
	for i in range(_slots.size()):
		var slot: PanelContainer = _slots[i]
		if i == _indice and _estilo_normal != null:
			var sel := _estilo_normal.duplicate() as StyleBoxFlat
			sel.border_color = Color(0.95, 0.85, 0.4, 1)
			sel.border_width_left = 3
			sel.border_width_top = 3
			sel.border_width_right = 3
			sel.border_width_bottom = 3
			sel.bg_color = Color(0.2, 0.17, 0.06, 0.9)
			slot.add_theme_stylebox_override("panel", sel)
			slot.scale = Vector2(1.08, 1.08)
		else:
			slot.remove_theme_stylebox_override("panel")
			slot.scale = Vector2.ONE
	_render_detalle_combo()


func _render_detalle_combo() -> void:
	var op: Dictionary = _opciones[_indice]
	var prog: Node = get_node("/root/Progresion")
	var player := get_tree().get_first_node_in_group("player")
	if op["bloqueada"]:
		combo_nombre.text = "Forma bloqueada"
		combo_funcion.text = "Subí de nivel para desbloquearla."
		combo_como.text = ""
		return
	if player == null or player.forms.size() <= op["form_index"]:
		combo_nombre.text = "Forma desbloqueada"
		combo_funcion.text = ""
		combo_como.text = ""
		return
	var forma: Forma = player.forms[op["form_index"]]
	var desbloqueados: int = prog.combos_desbloqueados_forma(op["form_index"])
	if desbloqueados >= forma.combos.size():
		combo_nombre.text = "Forma desbloqueada"
		combo_funcion.text = "Ya tiene todos sus combos."
		combo_como.text = ""
		return
	var c: Dictionary = forma.combos[desbloqueados]
	combo_nombre.text = "Combo: %s" % str(c.get("nombre", "Combo"))
	combo_funcion.text = "Es un ataque más fuerte."
	combo_como.text = "%s" % _secuencia_texto(c.get("secuencia", []))


func _secuencia_texto(secuencia: Array) -> String:
	var partes: PackedStringArray = []
	for paso in secuencia:
		var label := "?"
		match str(paso):
			"light":
				label = "X" if _es_joypad else "J"
			"heavy":
				label = "Y" if _es_joypad else "K"
			"special":
				label = "B" if _es_joypad else "L"
		partes.append(label)
	return " + ".join(partes)


func _confirmar() -> void:
	if _opciones.is_empty():
		cerrar()
		return
	var op: Dictionary = _opciones[_indice]
	if op["bloqueada"]:
		return
	_ui("ui_confirmar")
	get_node("/root/Progresion").elegir_mejora(op["form_index"])
	cerrar()


func _ui(nombre: String) -> void:
	var audio := get_node_or_null("/root/AudioManager")
	if audio != null:
		audio.play_ui(nombre)
