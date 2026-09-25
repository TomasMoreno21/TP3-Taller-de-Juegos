extends Area2D

## Disparador de diálogo colocable en el editor: narrativa o tutorial de mecánicas.
## Modo "Zona": habla cuando el jugador entra al área. Modo "Automatico": habla solo al cargar la escena.
## Si `dialogo_id` está seteado, las líneas/hablante/modo/retraso/una_vez se cargan desde
## res://data/dialogos.json (la entrada del dict debe existir). Los exports de abajo quedan
## como fallback/definición para triggers sin id.

const DIALOGOS_PATH := "res://data/dialogos.json"

static var _cache: Dictionary = {}
static var _cache_cargado := false

@export var dialogo_id: String = ""
@export var lineas: PackedStringArray = []
@export var hablante: String = "Amuleto"
@export_enum("Zona", "Automatico") var modo: String = "Zona"
@export_enum("Narrativa", "Tip") var tipo: String = "Narrativa"
@export var una_vez := true
@export var retraso := 0.6

var _disparado := false


func _cargar_dialogo_por_id() -> void:
	if dialogo_id.is_empty():
		return
	if not _cache_cargado:
		var texto: String = FileAccess.get_file_as_string(DIALOGOS_PATH)
		var datos: Variant = JSON.parse_string(texto)
		if datos is Dictionary:
			_cache = datos
		_cache_cargado = true
	var entrada: Variant = _cache.get(dialogo_id)
	if entrada is not Dictionary:
		push_error("DialogTrigger: no existe el diálogo '%s' en %s" % [dialogo_id, DIALOGOS_PATH])
		return
	lineas = PackedStringArray(entrada.get("lineas", []))
	hablante = str(entrada.get("hablante", hablante))
	modo = str(entrada.get("modo", modo))
	tipo = str(entrada.get("tipo", tipo)).capitalize()
	una_vez = bool(entrada.get("una_vez", una_vez))
	retraso = float(entrada.get("retraso", retraso))


func _ready() -> void:
	_cargar_dialogo_por_id()
	if modo == "Automatico":
		monitoring = false
		await get_tree().create_timer(retraso).timeout
		_disparar()
	else:
		monitoring = true
		collision_layer = 0
		collision_mask = 4
		body_entered.connect(_on_body_entered)


func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("player"):
		_disparar()


func _disparar() -> void:
	if una_vez and _disparado:
		return
	if lineas.is_empty():
		_disparado = true
		return
	var prog := get_node_or_null("/root/Progresion") as Node
	if prog != null and not dialogo_id.is_empty():
		# una_vez=true (default): se muestra una sola vez por partida y persiste
		# aunque el jugador muera (Progresion es autoload). una_vez=false en el
		# JSON: se vuelve a mostrar cada vez que se re-entra a la zona; el flag
		# del JSON manda sobre esta regla.
		var visto: bool = prog.dialogo_visto(dialogo_id)
		if una_vez and visto:
			_disparado = true
			return
		if una_vez:
			prog.marcar_dialogo_visto(dialogo_id)
	_disparado = true
	if tipo == "Tip":
		get_node("/root/Dialogo").mostrar_tip(Array(lineas), hablante)
	else:
		get_node("/root/Dialogo").mostrar(Array(lineas), hablante)
