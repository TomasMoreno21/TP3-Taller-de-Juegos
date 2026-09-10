extends Node

signal fragmentos_cambiado(total: int)
signal nivel_cambiado(nuevo_nivel: int)
signal combo_desbloqueado(form_index: int, combo_nombre: String)
signal nivel_subio(nuevo_nivel: int)
signal forma_desbloqueada_evento(form_index: int)

var fragmentos := 0
var nivel := 1
var combos_desbloqueados: Dictionary = {}
var barreras_abiertas: Dictionary = {}
## Dialogos ya mostrados (persisten entre muertes; se limpian al resetear partida).
var dialogos_vistos: Dictionary = {}
## Si no está vacía, las formas se desbloquean SOLO por esta lista (ignora el nivel).
## La setea cada nivel desde el editor (scripts/setup_progresion_nivel.gd).
var formas_forzadas: Array = []
## Formas desbloqueadas por eventos de nivel (trigger unlock_forma), persisten entre muertes.
var _extra_formas: Dictionary = {}


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS


func add_fragmentos(cantidad: int) -> void:
	fragmentos += maxi(cantidad, 0)
	fragmentos_cambiado.emit(fragmentos)
	while fragmentos >= fragmentos_para_nivel(nivel + 1):
		subir_nivel()


func subir_nivel() -> void:
	nivel += 1
	nivel_cambiado.emit(nivel)
	nivel_subio.emit(nivel)


## Fragmentos acumulados necesarios para alcanzar el nivel n (5, 12, 21, 32...).
func fragmentos_para_nivel(n: int) -> int:
	return maxi(n - 1, 0) * (n + 3)


func set_nivel(n: int) -> void:
	nivel = maxi(n, 1)
	fragmentos = maxi(fragmentos, fragmentos_para_nivel(nivel))
	nivel_cambiado.emit(nivel)


func reset() -> void:
	fragmentos = 0
	nivel = 1
	combos_desbloqueados = {}
	barreras_abiertas = {}
	dialogos_vistos = {}
	formas_forzadas = []
	_extra_formas = {}
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


func forma_desbloqueada(form_index: int) -> bool:
	# Desbloqueos de eventos (triggers de nivel) tienen prioridad sobre todo.
	if _extra_formas.has(form_index):
		return true
	# 04/09: cada nivel puede forzar su lista de formas desde el editor.
	if not formas_forzadas.is_empty():
		return form_index in formas_forzadas
	# 17/08: desbloqueo progresivo por nivel (nivel 2 -> Lobo, 3 -> Oso, 4 -> Murciélago)
	return form_index < nivel


## Desbloquea una forma por evento de nivel (persiste hasta reset()).
func desbloquear_forma(form_index: int) -> void:
	if _extra_formas.has(form_index):
		return
	_extra_formas[form_index] = true
	forma_desbloqueada_evento.emit(form_index)


func pasos_luz() -> int:
	return maxi(nivel, 1)


## True si el diálogo con ese id ya se mostró en esta partida (persiste entre muertes).
func dialogo_visto(id: String) -> bool:
	return dialogos_vistos.has(id)


## Marca un diálogo como ya mostrado.
func marcar_dialogo_visto(id: String) -> void:
	dialogos_vistos[id] = true
