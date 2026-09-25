@tool
extends EditorPlugin

const RUTA_ESCENA := "res://scenes/herramienta_nivel.tscn"
const RUTA_PINCHOS := "res://scenes/pinchos.tscn"
const SCRIPT_PINCHOS := "res://scripts/pinchos.gd"

var _boton: Button

# Estado del pintado de pinchos (Shift + arrastrar sobre un pincho seleccionado).
var _pintando := false
var _base: Node2D
var _inicio_x := 0.0
var _franja := 0.0
var _ultimo_k := 0
var _clones: Array[Node] = []


func _enter_tree() -> void:
	_boton = Button.new()
	_boton.text = "Herramienta de nivel"
	_boton.tooltip_text = "Inserta la herramienta de diseño (vista, saltos, grid) en la escena abierta. Da click de nuevo la mueve al origen si ya existe."
	_boton.pressed.connect(_insertar)
	# El botón ahora vive en el menú "Proyecto" del editor (siempre visible).
	# Se registra `_toggle_via_menu` (y se define) porque el editor reconstruye
	# los callbacks del menú con ese nombre; si no existe, da "Method not found".
	add_tool_menu_item("Insertar herramienta de nivel", Callable(self, "_toggle_via_menu"))
	add_tool_menu_item("Ayuda: pinchos en cadena", Callable(self, "_ayuda_pinchos"))


func _exit_tree() -> void:
	_limpiar_clones()
	remove_tool_menu_item("Insertar herramienta de nivel")
	remove_tool_menu_item("Ayuda: pinchos en cadena")
	remove_control_from_docks(_boton)
	if is_instance_valid(_boton):
		_boton.queue_free()


## Solo "manejamos" nodos pincho: así `forward_canvas_gui_input` SOLO se dispara
## cuando hay un pincho seleccionado y no estorba al resto de la edición.
func handles(object: Object) -> bool:
	var n := object as Node
	if n == null or n.get_script() == null:
		return false
	return (n.get_script() as Script).resource_path == SCRIPT_PINCHOS


func forward_canvas_gui_input(control: Control, event: InputEvent) -> bool:
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT:
			if mb.pressed:
				if mb.shift_pressed and _iniciar_pintado(mb.position, control):
					return true
			elif _pintando:
				_terminar_pintado()
				return true
		return false
	if _pintando and event is InputEventMouseMotion:
		var mm := event as InputEventMouseMotion
		_actualizar_pintado(mm.position, control)
		return true
	return false


func _toggle_via_menu() -> void:
	_insertar()


func _ayuda_pinchos() -> void:
	push_warning("Pinchos en cadena: seleccioná UN pincho, mantené Shift y arrastrá para clonarlo en fila (espaciado exacto por ancho_pincho, sin huecos).")


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


func _iniciar_pintado(mouse_pos: Vector2, control: Control) -> bool:
	var sel := get_editor_interface().get_selection().get_selected_nodes()
	if sel.size() != 1:
		return false
	_base = sel[0] as Node2D
	if _base == null or not _es_pincho(_base):
		return false
	var ancho: float = _base.get("ancho_pincho")
	var cantidad: int = _base.get("cantidad")
	_franja = ancho * maxf(1.0, cantidad)
	if _franja <= 0.0:
		return false
	_inicio_x = _base.global_position.x
	_pintando = true
	_ultimo_k = 0
	_actualizar_pintado(mouse_pos, control)
	return true


func _actualizar_pintado(mouse_pos: Vector2, control: Control) -> void:
	var k := int(round((_x_mundo(mouse_pos, control) - _inicio_x) / _franja))
	if k != _ultimo_k:
		_rebuild_clones(k)
		_ultimo_k = k


func _x_mundo(mouse_pos: Vector2, control: Control) -> float:
	var ct: Transform2D = control.get_canvas_transform()
	return (ct.affine_inverse() * mouse_pos).x


func _rebuild_clones(k: int) -> void:
	_limpiar_clones()
	if k == 0 or _base == null:
		return
	var raiz := get_editor_interface().get_edited_scene_root()
	if raiz == null:
		return
	var paq: PackedScene = load(RUTA_PINCHOS)
	var pasos: Array = []
	if k > 0:
		for i in range(1, k + 1):
			pasos.append(i)
	else:
		for i in range(-1, k - 1, -1):
			pasos.append(i)
	for i in pasos:
		var clon: Node2D = paq.instantiate()
		raiz.add_child(clon)
		clon.global_position = Vector2(_inicio_x + i * _franja, _base.global_position.y)
		for prop in ["cantidad", "ancho_pincho", "alto", "dano", "color_base", "color_estaca", "enterrado", "z_index_detras", "fraccion_zona_dano"]:
			clon.set(prop, _base.get(prop))
		clon.name = "%s_%d" % [_base.name, i]
		clon.owner = raiz
		_clones.append(clon)


func _limpiar_clones() -> void:
	for c in _clones:
		if is_instance_valid(c):
			c.free()
	_clones.clear()


func _terminar_pintado() -> void:
	_pintando = false
	_base = null
	_clones.clear()


func _es_pincho(n: Node) -> bool:
	if n.get_script() == null:
		return false
	return (n.get_script() as Script).resource_path == SCRIPT_PINCHOS