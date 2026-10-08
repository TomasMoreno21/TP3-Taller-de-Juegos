extends Node

## "El corazón late" (nivel 3): la cueva pulsa como un latido que se acelera hacia el sello.
## Hijos = zonas (zona_latido.gd). Según en cuál esté el jugador, el CanvasModulate `oscuridad` se tiñe de
## su color y pulsa con su frecuencia e intensidad (transición suave). Todo editable desde cada zona.

@export var oscuridad: NodePath
@export var velocidad_cambio := 1.4   ## qué tan rápido se mezcla con la zona nueva (1/s)

var _osc: CanvasModulate
var _zonas: Array = []
var _color := Color.WHITE
var _frec := 0.4
var _int := 0.02
var _t := 0.0
var _inicial := true
var _jugador_cache: Node2D


## Intensidad del latido actual (la usan efectos que acompañan la tensión, como las motas violetas).
func intensidad_actual() -> float:
	return _int


func _ready() -> void:
	_osc = get_node_or_null(oscuridad) as CanvasModulate
	for z in get_children():
		if z.has_method("contiene"):
			_zonas.append(z)
	if _osc != null:
		_color = _osc.color


func _process(delta: float) -> void:
	if _osc == null:
		return
	if not is_instance_valid(_jugador_cache):
		_jugador_cache = get_tree().get_first_node_in_group("player") as Node2D
	var jugador := _jugador_cache
	if jugador != null:
		for z in _zonas:
			if z.contiene(jugador.global_position):
				var k := 1.0 if _inicial else clampf(velocidad_cambio * delta, 0.0, 1.0)
				_color = _color.lerp(z.color_ambiente, k)
				_frec = lerpf(_frec, z.frecuencia, k)
				_int = lerpf(_int, z.intensidad, k)
				_inicial = false
				break
	_t += delta * _frec
	var f := fposmod(_t, 1.0)
	# doble latido: "pum-pum"
	var p := exp(-pow(f * 9.0, 2.0)) + exp(-pow((f - 1.0) * 9.0, 2.0)) + 0.6 * exp(-pow((f - 0.22) * 9.0, 2.0))
	_osc.color = _color * (1.0 + _int * p)
