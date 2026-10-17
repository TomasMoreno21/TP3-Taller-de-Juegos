extends Node

signal fragmentos_cambiado(total: int)
signal nivel_cambiado(nuevo_nivel: int)
signal combo_desbloqueado(form_index: int, combo_nombre: String)
signal nivel_subio(nuevo_nivel: int)
signal forma_desbloqueada_evento(form_index: int)

## Fragmentos acumulados para alcanzar los niveles 2, 3, 4 y 5 (4 subidas = 1 combo por forma).
## Ajustados a ~1 y 1/3 de subida por nivel de juego (orbes azules en los niveles, 14/10: nivel 1 = 11, nivel 2 = 17, nivel 3 = 21; 49 en total):
## 1.ª al ~75 % del nivel 1; 2.ª la da el orbe `PremioA1_3` del nivel 2 (`da_subida_de_nivel`: 28 = 11 del nivel 1 + los otros 16 del nivel 2 + ese; sin él no se llega);
## 3.ª a ~1/4 del nivel 3 (34 = 28 + 6 de sus 21) y 4.ª al ~85 % del nivel 3 (46 = 28 + 18; deja margen de 3 almas, 49 en total).
## Si se agregan o quitan orbes, reajustar.
const FRAGMENTOS_NIVEL: Array[int] = [8, 28, 34, 46]
const FRAGMENTOS_IMPOSIBLE := 999999

var fragmentos := 0
var nivel := 1
## Pasos mínimos del combo ligero disponibles (los niveles avanzados los fijan con SetupProgresion).
var pasos_luz_base := 1
## Subidas de nivel que no tuvieron forma con combo pendiente: se canjean al desbloquear otra forma.
var mejoras_diferidas := 0
var combos_desbloqueados: Dictionary = {}
var barreras_abiertas: Dictionary = {}
## Almas ya recogidas (clave escena + ruta del nodo): al recargar el nivel (morir sin checkpoint, reiniciar) no reaparecen,
## porque los fragmentos que dieron se conservan (si no, se duplican y rompen los umbrales de nivel).
var almas_recogidas: Dictionary = {}
## Dialogos ya mostrados (persisten entre muertes; se limpian al resetear partida).
var dialogos_vistos: Dictionary = {}
## Acciones que el jugador ya hizo en esta partida (mover, saltar, golpe_ligero...): el tutorial no se las pide de nuevo.
var acciones_hechas: Dictionary = {}
## Consejos y controles que el Amuleto ya mostró (se releen en Ayuda del Amuleto).
var ayuda_vista: Array = []
## Veces que el jugador cayó en esta partida (el Amuleto reacciona si se repite).
var muertes := 0
## Plataformas fragiles ya rotas (por escena/posicion; persisten entre muertes y reinicios de nivel).
var plataformas_rotas: Dictionary = {}
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


## Subida garantizada (orbes especiales): completa los fragmentos que faltan para el siguiente nivel.
func forzar_subida() -> void:
	if es_nivel_maximo():
		return
	add_fragmentos(maxi(fragmentos_para_nivel(nivel + 1) - fragmentos, 0))


func subir_nivel() -> void:
	nivel += 1
	nivel_cambiado.emit(nivel)
	nivel_subio.emit(nivel)


## Fragmentos acumulados necesarios para alcanzar el nivel n (ver FRAGMENTOS_NIVEL).
func fragmentos_para_nivel(n: int) -> int:
	if n <= 1:
		return 0
	if n - 2 < FRAGMENTOS_NIVEL.size():
		return FRAGMENTOS_NIVEL[n - 2]
	return FRAGMENTOS_IMPOSIBLE


func es_nivel_maximo() -> bool:
	return nivel >= FRAGMENTOS_NIVEL.size() + 1


func set_nivel(n: int) -> void:
	nivel = maxi(n, 1)
	fragmentos = maxi(fragmentos, fragmentos_para_nivel(nivel))
	nivel_cambiado.emit(nivel)


func reset() -> void:
	fragmentos = 0
	nivel = 1
	pasos_luz_base = 1
	mejoras_diferidas = 0
	combos_desbloqueados = {}
	barreras_abiertas = {}
	almas_recogidas = {}
	dialogos_vistos = {}
	acciones_hechas = {}
	ayuda_vista = []
	muertes = 0
	var dialogo := get_node_or_null("/root/Dialogo")
	if dialogo != null:
		dialogo.limpiar()
	plataformas_rotas = {}
	formas_forzadas = []
	_extra_formas = {}
	fragmentos_cambiado.emit(0)
	nivel_cambiado.emit(1)


## Arranca "como si ya hubieras llegado hasta acá" (selector de nivel del modo prueba): partida limpia con
## `frag` fragmentos acumulados, el nivel que les corresponde, 1 combo por cada subida (formas en orden)
## y las formas que desbloquearon los tótems anteriores. No emite subidas: no abre el LevelUp.
func saltar_a_punto(frag: int, formas_extra: Array) -> void:
	reset()
	fragmentos = maxi(frag, 0)
	while nivel < FRAGMENTOS_NIVEL.size() + 1 and fragmentos >= fragmentos_para_nivel(nivel + 1):
		nivel += 1
	for f in mini(nivel - 1, 4):
		combos_desbloqueados[f] = 1
	for f in formas_extra:
		_extra_formas[int(f)] = true
	fragmentos_cambiado.emit(fragmentos)
	nivel_cambiado.emit(nivel)


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
	return maxi(maxi(nivel, 1), pasos_luz_base)


## True si el diálogo con ese id ya se mostró en esta partida (persiste entre muertes).
func dialogo_visto(id: String) -> bool:
	return dialogos_vistos.has(id)


## Marca un diálogo como ya mostrado.
func marcar_dialogo_visto(id: String) -> void:
	dialogos_vistos[id] = true


## True si la plataforma fragil con esa clave ya se rompio en esta partida.
func plataforma_rota(clave: String) -> bool:
	return plataformas_rotas.has(clave)


## Registra una plataforma fragil como rota (persiste hasta reset()).
func marcar_plataforma_rota(clave: String) -> void:
	plataformas_rotas[clave] = true
