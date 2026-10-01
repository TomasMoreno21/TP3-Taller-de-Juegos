extends Control

## Introducción en cómic: una sola página con todas las viñetas (hijos `Vineta`, en el
## orden de `Paginas`). Cada clic revela la siguiente; clic mientras escribe completa el
## texto; después de la última, un clic pasa al juego. `dialog_skip` muestra todo y sale.

signal terminado

@export_file("*.tscn") var escena_siguiente := "res://scenes/nivel1.tscn"
@export var cambiar_escena_al_terminar := true

var _vinetas: Array[Control] = []
var _indice := -1   # última viñeta revelada
var _cerrando := false

@onready var paginas: Control = $Paginas
@onready var pista: Label = $Pista


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for hijo in paginas.get_children():
		if hijo is Control:
			_vinetas.append(hijo)
	_actualizar_pista()
	_precargar.call_deferred()   # el nivel carga mientras se lee el cómic
	if DisplayServer.get_name() != "headless":
		modulate.a = 0.0
		create_tween().tween_property(self, "modulate:a", 1.0, 0.6)
		var tw := pista.create_tween().set_loops()
		tw.tween_property(pista, "modulate:a", 0.35, 0.8)
		tw.tween_property(pista, "modulate:a", 1.0, 0.8)
	await get_tree().create_timer(0.7, false).timeout
	if _indice < 0 and not _cerrando:
		avanzar()   # la primera viñeta aparece sola, sin pedir clic


func _precargar() -> void:
	TransicionPantalla.de(get_tree()).precargar(escena_siguiente)


func _unhandled_input(event: InputEvent) -> void:
	if _cerrando:
		return
	if event.is_action_pressed("dialog_skip"):
		omitir()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("dialog_next") or event.is_action_pressed("menu_confirm") \
			or event.is_action_pressed("ui_accept") \
			or (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT):
		avanzar()
		get_viewport().set_input_as_handled()


func avanzar() -> void:
	if _cerrando:
		return
	if _indice >= 0 and _vinetas[_indice].esta_tipeando():
		_vinetas[_indice].completar_texto()
		return
	if _indice + 1 < _vinetas.size():
		_indice += 1
		_vinetas[_indice].revelar()
		_ui("ui_confirmar")
		_actualizar_pista()
	else:
		_terminar()


func omitir() -> void:
	for v in _vinetas:
		v.mostrar_completa()
	_terminar()


func _actualizar_pista() -> void:
	var ultima := _indice >= _vinetas.size() - 1
	var dlg := get_node_or_null("/root/Dialogo")
	var tecla_omitir: String = dlg.nombre_accion("dialog_skip") if dlg != null else "Esc"
	pista.text = ("Clic para empezar la aventura" if ultima else "Clic para continuar") + "   ·   %s: omitir" % tecla_omitir


func _terminar() -> void:
	if _cerrando:
		return
	_cerrando = true
	terminado.emit()
	if cambiar_escena_al_terminar:
		TransicionPantalla.de(get_tree()).cambiar_escena(escena_siguiente)


func _ui(nombre: String) -> void:
	var audio := get_node_or_null("/root/AudioManager")
	if audio != null:
		audio.play_ui(nombre)
