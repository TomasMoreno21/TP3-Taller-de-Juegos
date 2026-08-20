extends Node

signal fragmentos_cambiado(total: int)
signal nivel_cambiado(nuevo_nivel: int)
signal combo_desbloqueado(form_index: int, combo_nombre: String)
signal nivel_subio(nuevo_nivel: int)

const FRAGMENTOS_POR_NIVEL := 3

var fragmentos := 0
var nivel := 1
var combos_desbloqueados: Dictionary = {}


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS


func add_fragmentos(cantidad: int) -> void:
	fragmentos += maxi(cantidad, 0)
	fragmentos_cambiado.emit(fragmentos)
	while fragmentos >= nivel * FRAGMENTOS_POR_NIVEL:
		subir_nivel()


func subir_nivel() -> void:
	nivel += 1
	nivel_cambiado.emit(nivel)
	nivel_subio.emit(nivel)


func set_nivel(n: int) -> void:
	nivel = maxi(n, 1)
	fragmentos = maxi(fragmentos, nivel * FRAGMENTOS_POR_NIVEL)
	nivel_cambiado.emit(nivel)


func reset() -> void:
	fragmentos = 0
	nivel = 1
	combos_desbloqueados = {}
	fragmentos_cambiado.emit(0)
	nivel_cambiado.emit(1)


func elegir_mejora(form_index: int) -> void:
	if not combos_desbloqueados.has(form_index):
		combos_desbloqueados[form_index] = 0
	var player := get_tree().get_first_node_in_group("player")
	var total := 1
	if player != null and player.forms.size() > form_index:
		total = player.forms[form_index].combos.size()
	combos_desbloqueados[form_index] = mini(int(combos_desbloqueados[form_index]) + 1, total)
	var combo_nombre: String = _nombre_combo(form_index, combos_desbloqueados[form_index] - 1)
	combo_desbloqueado.emit(form_index, combo_nombre)


func combos_desbloqueados_forma(form_index: int) -> int:
	return int(combos_desbloqueados.get(form_index, 0))


func _nombre_combo(form_index: int, indice: int) -> String:
	var player := get_tree().get_first_node_in_group("player")
	if player != null and not player.forms.is_empty() and indice >= 0:
		var forma: Forma = player.forms[form_index]
		if forma.combos.size() > indice:
			return str(forma.combos[indice].get("nombre", "Combo"))
	return "Combo"


func forma_desbloqueada(_form_index: int) -> bool:
	# TEMPORAL (pruebas): todas las formas desbloqueadas. Volver a:
	# 17/08: desbloqueo progresivo por nivel (nivel 2 -> Lobo, 3 -> Oso, 4 -> Murciélago)
	# return form_index < nivel
	return true


func pasos_luz() -> int:
	return maxi(nivel, 1)
