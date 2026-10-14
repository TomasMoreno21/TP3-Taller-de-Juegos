extends PointLight2D
## Luz que late con el corazón de la cueva (latido_cueva.gd): su energía sube con cada pulso,
## más fuerte cuanto más cerca del sello está el jugador.

@export var latido: NodePath
@export var energia_base := 0.5
@export var fuerza_latido := 0.7      ## energía extra en el pico del pulso
@export var intensidad_ref := 0.16    ## intensidad del latido con la que el pulso llega a su máximo

var _latido: Node


func _ready() -> void:
	_latido = get_node_or_null(latido)


func _process(_delta: float) -> void:
	if _latido == null or not _latido.has_method("pulso_actual"):
		return
	var k := clampf(float(_latido.intensidad_actual()) / intensidad_ref, 0.15, 1.0)
	energy = energia_base + float(_latido.pulso_actual()) * k * fuerza_latido
