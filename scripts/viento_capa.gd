extends Sprite2D
## Viento lateral para las capas de arboles del fondo. Mismo criterio que
## decorativo.gd: la copa se mece de un lado a otro mientras la base queda
## clavada. Solo rota; no toca position ni scale, asi la capa queda
## exactamente donde el usuario la acomodo.
## Para que la base quede clavada, el pivote (origen del nodo) tiene que
## coincidir con la base del dibujo: eso se logra con el par
## Sprite.offset.y = -alto/2  +  ParallaxLayer.motion_offset.y = +alto/2
## (el par se cancela, no mueve nada, solo mueve el pivote).

@export var viento := true
@export var viento_amplitud := 0.015:
	set(value):
		viento_amplitud = absf(value)
@export var viento_velocidad := 0.8:
	set(value):
		viento_velocidad = absf(value)
@export var fase := 0.0

var _t := 0.0
var _base_rot := 0.0


func _ready() -> void:
	_t = fase
	_base_rot = rotation


func _process(delta: float) -> void:
	if not viento:
		return
	_t += viento_velocidad * delta
	rotation = _base_rot + sin(_t) * viento_amplitud
