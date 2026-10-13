@tool
class_name PrimerPlano
extends CanvasGroup
## Grupo de primer plano: siluetas casi negras ENTRE la cámara y el jugador.
## - Paralaje: se mueve más rápido que el mundo (profundidad > 1). Su posición en
##   el editor es donde aparece cuando la cámara está centrada en él.
## - Si tapa al jugador o a un enemigo, se vuelve translúcido para no esconder
##   la acción. Es CanvasGroup: el alfa se aplica al conjunto (sin solapes).
## Hijos típicos: decorativo.tscn (TRONCO_FRENTE, RAMA_COLGANTE, PASTO_ALTO,
## ARBUSTO...) y bancos de niebla.

@export var profundidad := 1.35              ## >1 = más cerca de la cámara (se mueve más rápido)
@export var profundidad_vertical := 1.0      ## 1 = sigue la altura del mundo
@export_range(0.0, 1.0) var alfa_tapando := 0.3
@export_range(0.0, 1.0) var alfa_base := 0.88   ## opacidad normal (un poco translúcido: no "tapa" el fondo del todo)
@export var margen_jugador := Vector2(520, 340)  ## zona alrededor del jugador que se mantiene despejada (aclara antes de tapar)
@export var velocidad_fundido := 4.0         ## qué tan rápido se aclara / vuelve
@export var distancia_activa := 3200.0       ## px: más lejos de la cámara no se procesa
## Agrupa los polígonos de cada "Hoja" (árbol, rama, pasto) en una sola malla: ~675 nodos menos en el nivel 1.
## Se aplica solo a las siluetas simples (polígonos lisos); las demás no se tocan. APAGADO por defecto: en
## capturas difiere en ~70 px (puntas de 1 px, porque la malla no se ajusta a la grilla de píxeles como Polygon2D).
## Prueba: tests/diag_primer_plano_horneado.gd (HORNEAR=0|1).
@export var hornear_poligonos := false

var _ancla := Vector2.ZERO
var _alfa := 0.88
var _rect_local := Rect2()


func _ready() -> void:
	_ancla = global_position
	if not Engine.is_editor_hint():
		_preparar.call_deferred()


func _process(delta: float) -> void:
	if Engine.is_editor_hint():
		return
	var cam := get_viewport().get_camera_2d()
	if cam == null:
		return
	var c := cam.get_screen_center_position()
	if absf(_ancla.x - c.x) > distancia_activa * maxf(profundidad, 1.0):
		return
	global_position = Vector2(c.x + (_ancla.x - c.x) * profundidad, c.y + (_ancla.y - c.y) * profundidad_vertical)
	var tapa := _tapa_algo()
	_alfa = move_toward(_alfa, alfa_tapando if tapa else alfa_base, delta * velocidad_fundido)
	self_modulate.a = _alfa


func _preparar() -> void:
	_calcular_rect()   # antes de hornear: usa los Polygon2D originales
	if hornear_poligonos:
		for h in find_children("Hoja", "Node2D", true, false):
			_hornear_hoja(h as Node2D)


## Dibuja las mallas horneadas de una Hoja (un solo nodo en vez de un Polygon2D por pieza).
class _MallaHoja extends Node2D:
	var mallas: Array[ArrayMesh] = []

	func _draw() -> void:
		for m in mallas:
			draw_mesh(m, null)


## Reemplaza los Polygon2D de la Hoja por una malla con colores por vértice (mismo orden de dibujo y
## misma triangulación que usa Polygon2D). Si algún hijo no es un polígono liso, la Hoja queda como está.
func _hornear_hoja(hoja: Node2D) -> void:
	var polis: Array[Polygon2D] = []
	for c in hoja.get_children():
		var p := c as Polygon2D
		if p == null or not _poligono_liso(p):
			return
		polis.append(p)
	if polis.is_empty():
		return
	var puntos := PackedVector2Array()
	var colores := PackedColorArray()
	for p in polis:
		var pts := p.polygon
		var tri := Geometry2D.triangulate_polygon(pts)
		if tri.is_empty():
			continue   # Polygon2D tampoco lo dibuja
		var xf := p.transform
		for idx in tri:
			puntos.append(xf * (pts[idx] + p.offset))
			colores.append(p.color)
	if puntos.is_empty():
		return
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = puntos
	arrays[Mesh.ARRAY_COLOR] = colores
	var malla := ArrayMesh.new()
	malla.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	var nodo := _MallaHoja.new()
	nodo.name = "Malla"
	nodo.mallas.append(malla)
	for p in polis:
		hoja.remove_child(p)
		p.queue_free()
	hoja.add_child(nodo)


func _poligono_liso(p: Polygon2D) -> bool:
	return p.visible and p.texture == null and p.vertex_colors.is_empty() and p.polygons.is_empty() 		and p.bones.is_empty() and not p.antialiased and not p.invert_enabled and p.material == null 		and p.modulate == Color.WHITE and p.self_modulate == Color.WHITE and p.z_index == 0 		and not p.use_parent_material and p.light_mask == 1 and p.get_child_count() == 0 		and not p.show_behind_parent and not p.top_level and p.polygon.size() >= 3


## Rectángulo (local) que ocupan los polígonos hijos, para detectar si tapan.
func _calcular_rect() -> void:
	var r := Rect2()
	var primero := true
	for p in find_children("*", "Polygon2D", true, false):
		var pol := p as Polygon2D
		if pol.polygon.is_empty() or not pol.is_visible_in_tree():
			continue
		var xf := global_transform.affine_inverse() * pol.global_transform
		for v in pol.polygon:
			var q := xf * v
			if primero:
				r = Rect2(q, Vector2.ZERO)
				primero = false
			else:
				r = r.expand(q)
	_rect_local = r


func _tapa_algo() -> bool:
	if _rect_local.size == Vector2.ZERO:
		return false
	var mio := Rect2(global_position + _rect_local.position, _rect_local.size)
	for grupo in ["player", "enemy"]:
		for n in get_tree().get_nodes_in_group(grupo):
			var cuerpo := _rect_cuerpo(n)
			if cuerpo.size != Vector2.ZERO and grupo == "player":
				cuerpo = cuerpo.grow_individual(margen_jugador.x, margen_jugador.y, margen_jugador.x, margen_jugador.y * 0.4)
			if cuerpo.size != Vector2.ZERO and mio.intersects(cuerpo):
				return true
	return false


func _rect_cuerpo(n: Node) -> Rect2:
	for c in n.get_children():
		if c is CollisionShape2D and (c as CollisionShape2D).shape != null:
			return (c as CollisionShape2D).global_transform * (c as CollisionShape2D).shape.get_rect()
	return Rect2()
