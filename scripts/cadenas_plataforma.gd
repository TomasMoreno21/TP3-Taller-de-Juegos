@tool
extends Node2D
## Cadenas que sostienen una plataforma colgante. Se cuelga como hijo del `Visual` (Polygon2D) de la plataforma:
## sube desde su borde superior hasta el techo. `largo` se ajusta a mano en el Inspector; en juego, si
## `ajustar_a_techo` está activo, se acorta/alarga solo hasta tocar el techo (máx. `largo_max_techo`).

@export var largo := 420.0:                       ## px de cadena sobre la plataforma (editor y respaldo si no hay techo)
	set(v):
		largo = maxf(v, 0.0)
		queue_redraw()
@export var ajustar_a_techo := true:              ## usar la distancia real hasta el techo (editor y juego); apagado = vale `largo`
	set(v):
		ajustar_a_techo = v
		if is_inside_tree():
			_calcular()
@export var largo_max_techo := 4000.0
@export var cantidad := 2:                        ## cadenas repartidas a lo ancho (1 = una al centro)
	set(v):
		cantidad = clampi(v, 1, 4)
		queue_redraw()
@export var margen := 38.0:                       ## distancia al borde de la plataforma de las cadenas de los extremos
	set(v):
		margen = v
		queue_redraw()
@export var ancho_cadena := 26.0:
	set(v):
		ancho_cadena = v
		queue_redraw()
@export var textura: Texture2D = preload("res://Sprites/Elementos/cadena.png"):
	set(v):
		textura = v
		queue_redraw()
@export var tinte := Color.WHITE:
	set(v):
		tinte = v
		queue_redraw()
@export var mostrar_ancla := true:                ## placa de hierro clavada en la roca arriba
	set(v):
		mostrar_ancla = v
		queue_redraw()

var largo_efectivo := 0.0      ## el mayor de los largos individuales
var _largos: Array[float] = []   ## largo de cada cadena (cada una busca su propio techo)


func _ready() -> void:
	_calcular()
	set_process(Engine.is_editor_hint())


## En el editor se recalcula si la plataforma se mueve (así las cadenas siempre llegan al techo mientras la acomodás).
var _ultima_pos := Vector2.INF

func _process(_delta: float) -> void:
	if global_position != _ultima_pos:
		_calcular()


## Busca el techo de cada cadena leyendo el TileMap (funciona igual en el editor y en juego, sin física).
func _calcular() -> void:
	_ultima_pos = global_position
	largo_efectivo = largo
	_largos.clear()
	var tm := _buscar_tilemap()
	if not ajustar_a_techo or tm == null:
		queue_redraw()
		return
	var r := _rect()
	var esc_y := absf(global_scale.y)
	for i in cantidad:
		var g := to_global(Vector2(_x_cadena(r, i), r.position.y - 4.0))
		var celda := tm.local_to_map(tm.to_local(g))
		var tope := -1
		var pasos := int(largo_max_techo / 16.0)
		var en_aire := false   # si el arranque cae dentro de roca (plataforma pegada a una pared), primero sale al aire
		for k in pasos:
			var lleno := tm.get_cell_source_id(0, Vector2i(celda.x, celda.y - k)) != -1
			if not lleno:
				en_aire = true
			elif en_aire:
				tope = celda.y - k
				break
		if tope == -1:
			_largos.append(largo)
			continue
		# Borde inferior del tile del techo; entra unos px en la roca para que el remate quede pegado.
		var y_techo := tm.to_global(Vector2(0.0, float(tope + 1) * 16.0)).y
		_largos.append(maxf((g.y - y_techo) / maxf(esc_y, 0.001) + 10.0, 0.0))
	largo_efectivo = _largos.max() if not _largos.is_empty() else largo
	queue_redraw()


func _buscar_tilemap() -> TileMap:
	var n: Node = get_parent()
	while n != null:
		var tm := n.get_node_or_null("TileMap") as TileMap
		if tm != null:
			return tm
		n = n.get_parent()
	return null


## Rectángulo local del Polygon2D padre (lo que se ve de la plataforma).
func _rect() -> Rect2:
	var p := get_parent() as Polygon2D
	if p == null or p.polygon.size() < 3:
		return Rect2(-80, -12, 160, 24)
	var mn := p.polygon[0]
	var mx := p.polygon[0]
	for v in p.polygon:
		mn = Vector2(minf(mn.x, v.x), minf(mn.y, v.y))
		mx = Vector2(maxf(mx.x, v.x), maxf(mx.y, v.y))
	return Rect2(mn, mx - mn)


func _x_cadena(r: Rect2, i: int) -> float:
	var fx := 0.5 if cantidad == 1 else float(i) / float(cantidad - 1)
	return lerpf(r.position.x + margen, r.end.x - margen, fx)


func _draw() -> void:
	if textura == null:
		return
	var r := _rect()
	var y_base := r.position.y + 3.0
	var tam := textura.get_size()
	var esc := ancho_cadena / maxf(tam.x, 1.0)
	var paso := tam.y * esc
	for i in cantidad:
		var x := _x_cadena(r, i)
		var l := _largos[i] if (ajustar_a_techo and i < _largos.size()) else largo
		if l <= 1.0:
			continue
		var y_alto := y_base - l
		var y := y_base
		while y > y_alto + 0.5:
			var seg := minf(paso, y - y_alto)
			var src_h := seg / esc
			draw_texture_rect_region(textura, Rect2(x - ancho_cadena * 0.5, y - seg, ancho_cadena, seg),
				Rect2(0.0, tam.y - src_h, tam.x, src_h), tinte)
			y -= seg
		# Argolla donde la cadena abraza la plataforma.
		draw_arc(Vector2(x, y_base + 1.0), 8.5, 0.0, TAU, 20, Color(0.07, 0.07, 0.1), 5.0)
		draw_arc(Vector2(x, y_base + 1.0), 8.5, 3.6, 5.6, 10, Color(0.55, 0.58, 0.68), 2.0)
		if mostrar_ancla:
			_ancla(Vector2(x, y_alto))


## Placa de hierro con remaches y un trozo de roca alrededor, para que la cadena "nazca" del techo.
func _ancla(p: Vector2) -> void:
	draw_colored_polygon(PackedVector2Array([p + Vector2(-34, 4), p + Vector2(-18, -14), p + Vector2(0, -20),
		p + Vector2(20, -13), p + Vector2(36, 4), p + Vector2(18, 8), p + Vector2(-18, 8)]), Color(0.16, 0.17, 0.22))
	draw_rect(Rect2(p + Vector2(-17, -6), Vector2(34, 14)), Color(0.07, 0.07, 0.1))
	draw_rect(Rect2(p + Vector2(-15, -4), Vector2(30, 10)), Color(0.27, 0.29, 0.36))
	draw_rect(Rect2(p + Vector2(-15, -4), Vector2(30, 2)), Color(0.5, 0.53, 0.63, 0.8))
	for dx in [-10.0, 10.0]:
		draw_circle(p + Vector2(dx, 1.0), 2.2, Color(0.11, 0.11, 0.15))
		draw_circle(p + Vector2(dx - 0.6, 0.4), 0.9, Color(0.65, 0.68, 0.78))
