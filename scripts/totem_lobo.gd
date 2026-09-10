extends Area2D

## Tótem de desbloqueo del Lobo (nivel 1): al tocarlo fuerza la lista de formas
## desbloqueadas (`formas_desbloqueadas`) y sube al nivel correspondiente.
## El texto explicativo se carga desde data/dialogos.json con `dialogo_id`
## (mismo patrón que dialog_trigger.gd).

const DIALOGOS_PATH := "res://data/dialogos.json"

static var _cache: Dictionary = {}
static var _cache_cargado := false

@export var dialogo_id: String = "p1_lobo"
@export var formas_desbloqueadas: Array[int] = [0, 1]
@export var nivel_desbloqueo := 2

var _activado := false


func _ready() -> void:
	monitoring = true
	collision_layer = 0
	collision_mask = 4
	body_entered.connect(_on_body_entered)


func _on_body_entered(body: Node2D) -> void:
	if _activado or not body.is_in_group("player"):
		return
	_activado = true
	var prog: Node = get_node("/root/Progresion")
	prog.formas_forzadas = formas_desbloqueadas
	if int(prog.nivel) < nivel_desbloqueo:
		prog.set_nivel(nivel_desbloqueo)
	_mostrar_dialogo()


func _mostrar_dialogo() -> void:
	if dialogo_id.is_empty():
		return
	if not _cache_cargado:
		var datos: Variant = JSON.parse_string(FileAccess.get_file_as_string(DIALOGOS_PATH))
		if datos is Dictionary:
			_cache = datos
		_cache_cargado = true
	var entrada: Variant = _cache.get(dialogo_id)
	if entrada is not Dictionary:
		push_error("TotemLobo: no existe el diálogo '%s' en %s" % [dialogo_id, DIALOGOS_PATH])
		return
	var lineas: Array = entrada.get("lineas", [])
	if lineas.is_empty():
		return
	get_node("/root/Dialogo").mostrar(lineas, str(entrada.get("hablante", "Amuleto")))