@tool
class_name PrimerPlano
extends CanvasGroup
## Grupo de primer plano: siluetas casi negras ENTRE la cámara y el jugador.
## - Paralaje: se mueve más rápido que el mundo (profundidad > 1). Su posición en
##   el editor es donde aparece cuando la cámara está centrada en él.
## - Si tapa al jugador o a un enemigo, se vuelve translúcido para no esconder
##   la acción. El aclarado es POR ELEMENTO (cada "Hoja" de los decorativos):
##   si un grupo tiene varios matojos/ramas, solo se aclaran los que tapan.
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

@export_group("Difuminado inferior")
@export var difuminado_base := false          ## degradé negro bajo cada elemento: tapa el hueco con fondo debajo (pasto, troncos, matojos)
@export var difuminado_alto := 160.0          ## px de degradé (transparente → negro) sobre el borde inferior del elemento
@export var difuminado_largo := 260.0         ## px de negro sólido bajo el borde inferior
@export var difuminado_fin := 140.0            ## px finales en que el negro se desvanece (evita una columna negra si la cámara baja mucho)
@export_range(0.0, 0.45) var difuminado_margen := 0.2   ## recorte lateral (fracción del ancho) para no sobresalir de la silueta
@export var tono_difuminado := Color(0.04, 0.042, 0.045, 1)
@export_group("")

var _ancla := Vector2.ZERO
var _hojas: Array[Node2D] = []    ## cada "Hoja" = un elemento (árbol, rama, matojo...) que se aclara por separado
var _rects: Array[Rect2] = []     ## AABB local de cada Hoja, para saber si tapa
var _alfa: Array[float] = []      ## alfa actual de cada Hoja
var _alfa_base_hoja: Array[float] = []   ## alfa propia de la Hoja (color de noche) para no pisarla


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
	_actualizar_tapado(delta)


func _preparar() -> void:
	_calcular_rect()   # antes de hornear: usa los Polygon2D originales
	if hornear_poligonos:
		for h in find_children("Hoja", "Node2D", true, false):
			_hornear_hoja(h as Node2D)
	if difuminado_base:
		_crear_difuminados()


## Bajo cada elemento (matojo, tronco) agrega un degradé a negro hacia abajo, para que no se vea
## flotando con fondo claro debajo. Hijo de la Hoja: se aclara junto con ella cuando tapa al jugador.
func _crear_difuminados() -> void:
	var inv := global_transform.affine_inverse()
	for i in _hojas.size():
		var hoja := _hojas[i]
		var r := _rects[i]
		var margen := r.size.x * difuminado_margen
		var x0 := r.position.x + margen
		var x1 := r.end.x - margen
		var y0 := r.end.y - difuminado_alto
		var y1 := r.end.y
		var y2 := r.end.y + difuminado_largo
		var y3 := y2 + difuminado_fin
		var a_hoja := (inv * hoja.global_transform).affine_inverse()
		var clr := tono_difuminado
		var clr0 := Color(clr.r, clr.g, clr.b, 0.0)
		var poli := Polygon2D.new()
		poli.name = "DifuminadoBase"
		# Arriba transparente → negro en el borde del elemento → sólido → se vuelve a desvanecer (no asoma como columna si la cámara está muy abajo).
		poli.polygon = PackedVector2Array([a_hoja * Vector2(x0, y0), a_hoja * Vector2(x1, y0), a_hoja * Vector2(x1, y1),
			a_hoja * Vector2(x1, y2), a_hoja * Vector2(x1, y3), a_hoja * Vector2(x0, y3), a_hoja * Vector2(x0, y2),
			a_hoja * Vector2(x0, y1)])
		poli.vertex_colors = PackedColorArray([clr0, clr0, clr, clr, clr0, clr0, clr, clr])
		hoja.add_child(poli)


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


## AABB local de cada "Hoja" (el bloque que dibuja cada decorativo), para saber por separado si
## tapa. Se calcula por Hoja y no como una sola unión del grupo entero: así cada matojo/rama se
## aclara solo, aunque en el mismo grupo haya varios elementos separados.
func _calcular_rect() -> void:
	_hojas.clear()
	_rects.clear()
	_alfa.clear()
	_alfa_base_hoja.clear()
	var inv := global_transform.affine_inverse()
	for h in find_children("Hoja", "Node2D", true, false):
		var hoja := h as Node2D
		var r := Rect2()
		var primero := true
		for c in hoja.get_children():
			var pol := c as Polygon2D
			if pol == null or pol.polygon.is_empty() or not pol.is_visible_in_tree():
				continue
			var xf := inv * pol.global_transform
			for v in pol.polygon:
				var q := xf * v
				if primero:
					r = Rect2(q, Vector2.ZERO)
					primero = false
				else:
					r = r.expand(q)
		if primero:
			continue
		_hojas.append(hoja)
		_rects.append(r)
		_alfa.append(alfa_base)
		_alfa_base_hoja.append(hoja.modulate.a)


## Funde el alfa de cada elemento del grupo: solo se aclaran los que tapan al jugador o a un enemigo.
func _actualizar_tapado(delta: float) -> void:
	if _hojas.is_empty():
		return
	var cuerpos := _cuerpos()
	for i in _hojas.size():
		var hoja := _hojas[i]
		if not is_instance_valid(hoja):
			continue
		var tapa := false
		if not cuerpos.is_empty():
			var mio := Rect2(global_position + _rects[i].position, _rects[i].size)
			for cuerpo in cuerpos:
				if mio.intersects(cuerpo):
					tapa = true
					break
		_alfa[i] = move_toward(_alfa[i], alfa_tapando if tapa else alfa_base, delta * velocidad_fundido)
		hoja.modulate.a = _alfa_base_hoja[i] * _alfa[i]


## Cuerpos (AABB en mundo) que el primer plano puede tapar: jugador (con margen) y enemigos.
func _cuerpos() -> Array[Rect2]:
	var out: Array[Rect2] = []
	for grupo in ["player", "enemy"]:
		for n in get_tree().get_nodes_in_group(grupo):
			var cuerpo := _rect_cuerpo(n)
			if cuerpo.size == Vector2.ZERO:
				continue
			if grupo == "player":
				cuerpo = cuerpo.grow_individual(margen_jugador.x, margen_jugador.y, margen_jugador.x, margen_jugador.y * 0.4)
			out.append(cuerpo)
	return out


func _rect_cuerpo(n: Node) -> Rect2:
	for c in n.get_children():
		if c is CollisionShape2D and (c as CollisionShape2D).shape != null:
			return (c as CollisionShape2D).global_transform * (c as CollisionShape2D).shape.get_rect()
	return Rect2()
