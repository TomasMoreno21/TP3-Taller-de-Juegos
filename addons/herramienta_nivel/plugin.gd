@tool
extends EditorPlugin

const RUTA_ESCENA := "res://scenes/herramienta_nivel.tscn"

var _boton: Button


func _enter_tree() -> void:
	_boton = Button.new()
	_boton.text = "Herramienta de nivel"
	_boton.tooltip_text = "Inserta la herramienta de diseño (vista, saltos, grid) en la escena abierta. Da click de nuevo la mueve al origen si ya existe."
	_boton.pressed.connect(_insertar)
	add_control_to_dock(DOCK_SLOT_LEFT_BR, _boton)


func _exit_tree() -> void:
	remove_control_from_docks(_boton)
	if is_instance_valid(_boton):
		_boton.queue_free()


func _insertar() -> void:
	var editor := get_editor_interface()
	var raiz := editor.get_edited_scene_root()
	if raiz == null:
		return
	var existente := raiz.get_node_or_null("HerramientaNivel")
	if existente != null:
		push_warning("La herramienta de nivel ya está en esta escena.")
		return
	var paq: PackedScene = load(RUTA_ESCENA)
	var nodo: Node = paq.instantiate()
	nodo.name = "HerramientaNivel"
	raiz.add_child(nodo)
	nodo.owner = raiz
	editor.get_selection().clear()
	editor.get_selection().add_node(nodo)