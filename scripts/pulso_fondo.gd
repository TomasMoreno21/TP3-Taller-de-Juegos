extends Node
## Hace latir a su capa de fondo (el padre): la opacidad sube con cada pulso del corazón de la cueva (latido_cueva.gd).

@export var opacidad_base := 0.7
@export var fuerza := 0.3
@export var latido_ruta := "Latido"   ## nodo del latido, buscado desde la raíz de la escena

var _latido: Node


func _process(_delta: float) -> void:
	var capa := get_parent() as CanvasItem
	if capa == null:
		return
	if _latido == null or not is_instance_valid(_latido):
		var esc := get_tree().current_scene
		_latido = esc.get_node_or_null(latido_ruta) if esc != null else null
		if _latido == null:
			return
	capa.modulate.a = clampf(opacidad_base + float(_latido.pulso_actual()) * fuerza, 0.0, 1.0)
