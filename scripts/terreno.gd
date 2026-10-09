@tool
extends TileMapLayer
## Terreno de tiles de los niveles. Optimización: el ~95 % de las celdas está enterrado
## (rodeado de terreno) y no necesita colisión. Cada tile sólido tiene un alternativo
## (id 1) idéntico pero SIN colisión; "hornear" deja la colisión solo en una banda de
## `banda_colision` celdas junto a cualquier hueco y pasa el resto al alternativo.
## En el editor se re-hornea solo alrededor de lo que pintás o borrás; el botón
## "Hornear colisión" rehace todo el nivel (por ejemplo, tras pegar un bloque grande).

const ALT_SOLIDO := 0
const ALT_ENTERRADO := 1
## Tiles del atlas con colisión (los que tienen alternativo sin colisión).
const SOLIDOS := Rect2i(1, 1, 4, 4)
## Más celdas que esto en un solo cambio = carga de escena: no se re-hornea incremental.
const MAX_INCREMENTAL := 5000

## Espesor (en celdas) de la banda que conserva colisión junto a los huecos.
@export_range(1, 4) var banda_colision := 2
@export_tool_button("Hornear colisión", "Bake") var _boton_hornear := hornear_colision


func _update_cells(coords: Array[Vector2i], _forced_cleanup: bool) -> void:
	if not Engine.is_editor_hint() or coords.is_empty() or coords.size() > MAX_INCREMENTAL:
		return
	var revisar := {}
	var r := banda_colision
	for c in coords:
		for dy in range(-r, r + 1):
			for dx in range(-r, r + 1):
				revisar[c + Vector2i(dx, dy)] = true
	for c in revisar:
		_hornear_celda(c)


## Rehace la colisión de todas las celdas del terreno.
func hornear_colision() -> void:
	var solidas := {}
	for c in get_used_cells():
		if _es_solida(c):
			solidas[c] = true
	var enterradas := 0
	for c in solidas:
		if _hornear_celda(c, solidas) == ALT_ENTERRADO:
			enterradas += 1
	print("Terreno: %d celdas sólidas, %d enterradas sin colisión" % [solidas.size(), enterradas])


## `solidas` (opcional): caché de celdas sólidas para el horneado completo.
func _hornear_celda(c: Vector2i, solidas := {}) -> int:
	if not (solidas.has(c) if not solidas.is_empty() else _es_solida(c)):
		return -1
	var alt := ALT_ENTERRADO if _enterrada(c, solidas) else ALT_SOLIDO
	if get_cell_alternative_tile(c) != alt:
		set_cell(c, get_cell_source_id(c), get_cell_atlas_coords(c), alt)
	return alt


func _es_solida(c: Vector2i) -> bool:
	return get_cell_source_id(c) == 0 and SOLIDOS.has_point(get_cell_atlas_coords(c))


func _enterrada(c: Vector2i, solidas: Dictionary) -> bool:
	var r := banda_colision
	for dy in range(-r, r + 1):
		for dx in range(-r, r + 1):
			var v := c + Vector2i(dx, dy)
			if not (solidas.has(v) if not solidas.is_empty() else _es_solida(v)):
				return false
	return true
