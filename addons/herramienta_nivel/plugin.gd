@tool
extends EditorPlugin

const RUTA_ESCENA := "res://scenes/herramienta_nivel.tscn"

var _boton: Button


func _enter_tree() -> void:
	_boton = Button.new()
	_boton.text = "Herramienta de nivel"
	_boton.tooltip_text = "Inserta la herramienta de diseño (vista, saltos, grid) en la escena abierta. Da click de nuevo la mueve al origen si ya existe."
	_boton.pressed.connect(_insertar)
	# El botón ahora vive en el menú "Proyecto" del editor (siempre visible).
	# Se registra `_toggle_via_menu` (y se define) porque el editor reconstruye
	# los callbacks del menú con ese nombre; si no existe, da "Method not found".
	add_tool_menu_item("Insertar herramienta de nivel", Callable(self, "_toggle_via_menu"))


func _exit_tree() -> void:
	remove_tool_menu_item("Insertar herramienta de nivel")
	remove_control_from_docks(_boton)
	if is_instance_valid(_boton):
		_boton.queue_free()


## Acción del menú (nombre que el editor usa para invocar la entrada).
func _toggle_via_menu() -> void:
	_insertar()


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