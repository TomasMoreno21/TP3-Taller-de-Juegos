extends Node

## Aclara el ambiente al bajar a la cueva: mezcla el tinte de noche del nivel (CanvasModulate del mundo y del fondo)
## hacia un tono más claro según la profundidad del jugador, para que se vea mejor sin dejar de ser oscura.
## Arriba (bosque) no cambia nada. Editable desde el Inspector.

@export var noche: NodePath = ^"../../Noche"        ## nodo Noche del nivel (noche.gd)
@export var y_cueva := 2000.0                       ## desde esta altura del jugador empieza la cueva
@export var desvanecer := 500.0                     ## px bajo y_cueva hasta llegar al tono pleno
@export var color_mundo_cueva := Color(0.82, 0.9, 1.0)
@export var color_fondo_cueva := Color(0.9, 0.97, 1.0)
@export var suavizado := 2.5

var _noche: Node
var _mundo: CanvasModulate
var _fondo: Array[CanvasModulate] = []
var _base_mundo := Color.WHITE
var _base_fondo := Color.WHITE
var _k := 0.0
var _busca := 0.0


func _ready() -> void:
	_noche = get_node_or_null(noche)
	if _noche == null:
		set_process(false)
		return
	_mundo = _noche.get_node_or_null("Oscuridad") as CanvasModulate
	_base_mundo = _noche.color_noche
	_base_fondo = _noche.color_fondo


func _process(delta: float) -> void:
	var jugador := get_tree().get_first_node_in_group("player") as Node2D
	if jugador == null or _mundo == null:
		return
	if _fondo.is_empty():
		_busca -= delta
		if _busca <= 0.0:
			_busca = 0.5
			for f in _noche.get_parent().find_children("NocheFondo", "CanvasModulate", true, false):
				_fondo.append(f as CanvasModulate)
	var objetivo := clampf((jugador.global_position.y - y_cueva) / maxf(desvanecer, 1.0), 0.0, 1.0)
	_k = lerpf(_k, objetivo, 1.0 - exp(-suavizado * delta))
	_mundo.color = _base_mundo.lerp(color_mundo_cueva, _k)
	for f in _fondo:
		f.color = _base_fondo.lerp(color_fondo_cueva, _k)
