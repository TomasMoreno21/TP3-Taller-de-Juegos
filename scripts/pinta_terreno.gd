@tool
extends Node

## Pinta celdas decorativas en un TileMapLayer (tileset_bosque) para acompañar el
## terreno real (StaticBody2D + Polygon2D): la fila superior de cada zona se pinta
## con el tile borde (0,0) y el resto con el relleno (5,4). Funciona en el editor
## (al guardar la escena, Godot persiste el tile_data) y en runtime.

@export var nodo_terreno: NodePath
@export var pisos: Array[Dictionary] = []

const FUENTE := 0
const BORDE := Vector2i(0, 0)
const RELLENO := Vector2i(5, 4)


func _ready() -> void:
	if nodo_terreno.is_empty():
		return
	var capa: Node = get_node_or_null(nodo_terreno)
	if capa == null or not capa.has_method("set_cell"):
		push_error("pinta_terreno: nodo_terreno no apunta a un TileMapLayer")
		return
	for piso in pisos:
		var desde: Vector2i = piso.get("desde", Vector2i.ZERO)
		var hasta: Vector2i = piso.get("hasta", Vector2i.ZERO)
		for y in range(desde.y, hasta.y + 1):
			for x in range(desde.x, hasta.x + 1):
				capa.set_cell(Vector2i(x, y), FUENTE, RELLENO if y > desde.y else BORDE)