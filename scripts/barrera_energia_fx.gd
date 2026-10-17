@tool
extends Node2D
## Efecto visual del muro de energía de la barrera. Al empezar el nivel mide el hueco real del terreno
## (rayos contra el TileMap) y el muro toma esa forma: sigue el contorno de la roca arriba, abajo y a los
## costados en vez de ser un rectángulo que se mete en los tiles. Dibuja velo con degradado, contorno
## brillante, corrientes que suben, bandas de luz, motas y chisporroteos. Solo dibuja (sin colisión).
## Se cuelga bajo `Barrera/Visual`, centrado en el muro; todo es editable en el Inspector.

@export var ancho := 220.0:   ## ancho máximo del muro (si el hueco es más angosto, se ajusta al hueco)
	set(v):
		ancho = maxf(v, 20.0)
		_perfil_rectangular()
@export var alto := 677.0:    ## alto máximo del muro
	set(v):
		alto = maxf(v, 40.0)
		_perfil_rectangular()
@export var ajustar_al_terreno := true   ## medir el hueco y tomar su forma (en el editor se ve el rectángulo)
@export var capa_terreno := 1            ## capa de colisión del TileMap
@export var color_base := Color(0.62, 0.38, 0.88)    ## velo y corrientes
@export var color_luz := Color(0.90, 0.78, 1.0)      ## contorno, núcleos y chispas
@export var corrientes := 8                            ## cintas de energía que suben
@export var velocidad := 70.0                          ## px/s de las corrientes
@export var bandas := 3                                ## bandas horizontales de luz que barren hacia arriba
@export var motas := 18
@export var chispas_cada := 0.9                        ## s entre chisporroteos (0 = sin chispas)
@export var semilla := 5
@export var intensidad := 1.7                         ## qué tan notoria es la barrera: opacidad del velo, bandas, corrientes y contorno (1 = como antes)

const PASO := 8.0

var _px := PackedFloat32Array()    # x de cada columna del perfil (coordenadas locales)
var _ptop := PackedFloat32Array()  # y del borde superior en esa columna
var _pbot := PackedFloat32Array()  # y del borde inferior
var _ttile := PackedByteArray()    # 1 si el borde superior de esa columna toca un tile (0 = abierto)
var _btile := PackedByteArray()    # ídem abajo
var _pared_izq := true             # el costado toca una pared (si es abierto, el muro se desvanece en vez de cortarse)
var _pared_der := true
var _ajustado := false
var _t := 0.0
var _t_busca := 0.0
var _chispa_t := 0.0
var _chispa_vida := 0.0
var _chispa_pts := PackedVector2Array()
# Dibujo por lotes: el velo (estático) y las cintas/bandas (animadas) van como un solo "triangle array" cada uno,
# no como cientos de draw_polygon (cada uno era una llamada de dibujo y costaba varios ms por frame).
var _velo_idx := PackedInt32Array()
var _velo_pts := PackedVector2Array()
var _velo_col := PackedColorArray()
var _velo_listo := false
var _tri_idx := PackedInt32Array()
var _tri_pts := PackedVector2Array()
var _tri_col := PackedColorArray()
var _caja := Rect2()       # caja local del muro (para no redibujar fuera de pantalla)
var _en_pantalla := true
const MARGEN_PANTALLA := 160.0


func _ready() -> void:
	_perfil_rectangular()
	if not Engine.is_editor_hint():
		_ocultar_relleno_plano.call_deferred()


## El velo ya se dibuja aquí con degradado y desvanecido; el Polygon2D plano "Poly" dejaría un borde recto visible.
## (Se oculta en diferido porque barrera_bosque.gd lo vuelve visible en su _ready.)
func _ocultar_relleno_plano() -> void:
	var poly := get_parent().get_node_or_null("Poly") as Polygon2D
	if poly != null:
		poly.visible = false


## Perfil por defecto: el rectángulo ancho × alto.
func _perfil_rectangular() -> void:
	_px = PackedFloat32Array()
	_ptop = PackedFloat32Array()
	_pbot = PackedFloat32Array()
	_ttile = PackedByteArray()
	_btile = PackedByteArray()
	_pared_izq = true
	_pared_der = true
	var n := maxi(int(ancho / PASO), 2)
	for i in n + 1:
		_px.append(lerpf(-ancho * 0.5, ancho * 0.5, float(i) / n))
		_ptop.append(-alto * 0.5)
		_pbot.append(alto * 0.5)
		_ttile.append(1)
		_btile.append(1)
	_perfil_cambiado()
	queue_redraw()


func _process(delta: float) -> void:
	_t += delta
	if not Engine.is_editor_hint() and ajustar_al_terreno and not _ajustado:
		_t_busca -= delta
		if _t_busca <= 0.0:
			_t_busca = 0.5
			_intentar_ajuste()
	if _chispa_vida > 0.0:
		_chispa_vida -= delta
		if _chispa_vida <= 0.0:
			_chispa_pts = PackedVector2Array()
	if chispas_cada > 0.0:
		_chispa_t -= delta
		if _chispa_t <= 0.0:
			_chispa_t = chispas_cada * randf_range(0.6, 1.5)
			_nueva_chispa()
	# Fuera de pantalla no se redibuja (el canvas conserva el último dibujo y tampoco lo renderiza).
	_en_pantalla = Engine.is_editor_hint() or _caja_en_camara()
	if _en_pantalla:
		queue_redraw()


# ---------------------------------------------------------------- ajuste al hueco

## Mide el hueco cuando el jugador se acerca (el terreno ya está cargado). Si el resultado no es fiable, reintenta.
func _intentar_ajuste() -> void:
	var jugador := get_tree().get_first_node_in_group("player") as Node2D
	if jugador != null and global_position.distance_to(jugador.global_position) > 1600.0:
		return
	if _medir_hueco():
		_ajustado = true


func _medir_hueco() -> bool:
	var espacio := get_world_2d().direct_space_state
	if espacio == null:
		return false
	var excluir: Array[RID] = []
	var cuerpo := get_parent().get_parent() if get_parent() != null else null
	if cuerpo is CollisionObject2D:
		excluir.append((cuerpo as CollisionObject2D).get_rid())
	var mitad_alto := alto * 0.5
	var alcance_v := mitad_alto + 90.0   # se mira un poco más allá del alto nominal: el muro llega hasta la roca
	var maximo_x := ancho * 0.5
	var cols_x: Array[float] = []
	var cols_t: Array[float] = []
	var cols_b: Array[float] = []
	var libres: Array[bool] = []
	var n := int(ceil(maximo_x / PASO))
	for i in range(-n, n + 1):
		var x := clampf(float(i) * PASO, -maximo_x, maximo_x)
		var p := to_global(Vector2(x, 0.0))
		var q := PhysicsPointQueryParameters2D.new()
		q.position = p
		q.collision_mask = 1 << (capa_terreno - 1)
		q.exclude = excluir
		var libre := espacio.intersect_point(q, 1).is_empty()
		var t := -alcance_v
		var b := alcance_v
		if libre:
			t = _distancia_rayo(espacio, p, Vector2.UP, alcance_v, excluir)
			b = _distancia_rayo(espacio, p, Vector2.DOWN, alcance_v, excluir)
			t = -t
			if b - t < 24.0:
				libre = false   # una rendija: no cuenta como hueco
		cols_x.append(x)
		cols_t.append(t)
		cols_b.append(b)
		libres.append(libre)
	# Solo cuenta el tramo continuo de columnas libres que contiene el centro.
	var c := n
	if not libres[c]:
		return false   # el centro cae dentro de un tile: medición dudosa, se reintenta
	var i0 := c
	var i1 := c
	while i0 > 0 and libres[i0 - 1]:
		i0 -= 1
	while i1 < libres.size() - 1 and libres[i1 + 1]:
		i1 += 1
	if i1 - i0 < 3:
		return false
	# Los bordes laterales se afinan con un rayo horizontal a la altura del centro.
	var izq := cols_x[i0]
	var der := cols_x[i1]
	if i0 > 0:
		izq = _x_pared(espacio, to_global(Vector2(cols_x[i0], 0.0)), -1.0, PASO * 1.5, excluir, cols_x[i0])
	if i1 < libres.size() - 1:
		der = _x_pared(espacio, to_global(Vector2(cols_x[i1], 0.0)), 1.0, PASO * 1.5, excluir, cols_x[i1])
	_px = PackedFloat32Array()
	_ptop = PackedFloat32Array()
	_pbot = PackedFloat32Array()
	_ttile = PackedByteArray()
	_btile = PackedByteArray()
	_pared_izq = i0 > 0
	_pared_der = i1 < libres.size() - 1
	for i in range(i0, i1 + 1):
		var x := clampf(cols_x[i], izq, der)
		_px.append(x)
		_ptop.append(cols_t[i])
		_pbot.append(cols_b[i])
		_ttile.append(1 if cols_t[i] > -alcance_v + 1.0 else 0)
		_btile.append(1 if cols_b[i] < alcance_v - 1.0 else 0)
	_px[0] = izq
	_px[_px.size() - 1] = der
	_actualizar_relleno()
	_perfil_cambiado()
	queue_redraw()
	return true


## Distancia hasta el primer tile en esa dirección (o `maximo` si no hay).
func _distancia_rayo(espacio: PhysicsDirectSpaceState2D, desde: Vector2, dir: Vector2, maximo: float, excluir: Array[RID]) -> float:
	var q := PhysicsRayQueryParameters2D.create(desde, desde + dir * maximo)
	q.collision_mask = 1 << (capa_terreno - 1)
	q.exclude = excluir
	var hit := espacio.intersect_ray(q)
	if hit.is_empty():
		return maximo
	return desde.distance_to(hit["position"])


## x local de la pared más cercana hacia `lado` (-1 izquierda, 1 derecha) desde un punto libre.
func _x_pared(espacio: PhysicsDirectSpaceState2D, desde: Vector2, lado: float, alcance: float, excluir: Array[RID], x_local: float) -> float:
	var q := PhysicsRayQueryParameters2D.create(desde, desde + Vector2(lado * alcance, 0.0))
	q.collision_mask = 1 << (capa_terreno - 1)
	q.exclude = excluir
	var hit := espacio.intersect_ray(q)
	if hit.is_empty():
		return x_local
	return to_local(hit["position"]).x


## El relleno plano (Polygon2D "Poly" hermano) toma la forma medida para que no sobresalga del hueco.
func _actualizar_relleno() -> void:
	var poly := get_parent().get_node_or_null("Poly") as Polygon2D
	if poly == null or _px.size() < 2:
		return
	var pts := PackedVector2Array()
	for i in _px.size():
		pts.append(position + Vector2(_px[i], _ptop[i]))
	for i in range(_px.size() - 1, -1, -1):
		pts.append(position + Vector2(_px[i], _pbot[i]))
	poly.scale = Vector2.ONE
	poly.position = Vector2.ZERO
	poly.polygon = pts


# ---------------------------------------------------------------- dibujo

## Límites verticales (arriba, abajo) del perfil en `x`; Vector2(INF, -INF) fuera del muro.
func _limites(x: float) -> Vector2:
	var n := _px.size()
	if n < 2 or x < _px[0] or x > _px[n - 1]:
		return Vector2(INF, -INF)
	var i := 0
	while i < n - 2 and _px[i + 1] < x:
		i += 1
	var span := maxf(_px[i + 1] - _px[i], 0.001)
	var u := clampf((x - _px[i]) / span, 0.0, 1.0)
	return Vector2(lerpf(_ptop[i], _ptop[i + 1], u), lerpf(_pbot[i], _pbot[i + 1], u))


func _nueva_chispa() -> void:
	var n := _px.size()
	if n < 2:
		return
	_chispa_vida = 0.12
	var y_rel := randf_range(0.2, 0.8)
	_chispa_pts = PackedVector2Array()
	var pasos := 9
	for i in pasos + 1:
		var x := lerpf(_px[0], _px[n - 1], float(i) / pasos)
		var lim := _limites(x)
		var y := lerpf(lim.x, lim.y, y_rel) + randf_range(-14.0, 14.0) * (0.0 if i == 0 or i == pasos else 1.0)
		_chispa_pts.append(Vector2(x, clampf(y, lim.x, lim.y)))


## Color del velo en un vértice. Los extremos abiertos (sin tile ni pared) se desvanecen a transparente para que el
## muro no termine en un corte recto: `abierto_arriba/abajo` por columna, y los costados según `_pared_izq/der`.
func _color_velo(xn: float, yn: float, abierto_arriba: bool, abierto_abajo: bool) -> Color:
	var c := color_base
	var borde := pow(absf(xn * 2.0 - 1.0), 3.0)
	var a := minf((0.17 + 0.26 * borde + 0.20 * yn) * intensidad, 0.95)
	if not _pared_izq:
		a *= smoothstep(0.0, 0.22, xn)
	if not _pared_der:
		a *= smoothstep(0.0, 0.22, 1.0 - xn)
	if abierto_arriba and yn < 0.5:
		a *= 0.0
	if abierto_abajo and yn > 0.5:
		a *= 0.0
	return Color(c.r, c.g, c.b, a)


## El perfil cambió: el velo se recalcula y se actualiza la caja usada para el recorte por cámara.
func _perfil_cambiado() -> void:
	_velo_listo = false
	var n := _px.size()
	if n < 2:
		_caja = Rect2()
		return
	var y_min := 0.0
	var y_max := 0.0
	for i in n:
		y_min = minf(y_min, _ptop[i])
		y_max = maxf(y_max, _pbot[i])
	_caja = Rect2(_px[0], y_min, _px[n - 1] - _px[0], y_max - y_min).grow(40.0)   # holgura: chispas, contorno y motas


## True si el muro (más un margen) cae dentro de lo que ve la cámara.
func _caja_en_camara() -> bool:
	var vp := get_viewport()
	if vp == null or _caja.size == Vector2.ZERO:
		return true
	var vista: Rect2 = vp.get_canvas_transform().affine_inverse() * vp.get_visible_rect()
	var caja_mundo: Rect2 = global_transform * _caja
	return vista.grow(MARGEN_PANTALLA).intersects(caja_mundo)


## Agrega un cuadrilátero con color por vértice a los arrays (mismo resultado que draw_polygon de 4 puntos).
func _quad(pts: PackedVector2Array, cols: PackedColorArray, idx: PackedInt32Array, a: Vector2, b: Vector2, c: Vector2, d: Vector2,
		ca: Color, cb: Color, cc: Color, cd: Color) -> void:
	var o := pts.size()
	pts.append(a)
	pts.append(b)
	pts.append(c)
	pts.append(d)
	cols.append(ca)
	cols.append(cb)
	cols.append(cc)
	cols.append(cd)
	idx.append(o)
	idx.append(o + 1)
	idx.append(o + 2)
	idx.append(o)
	idx.append(o + 2)
	idx.append(o + 3)


func _construir_velo() -> void:
	_velo_idx = PackedInt32Array()
	_velo_pts = PackedVector2Array()
	_velo_col = PackedColorArray()
	var n := _px.size()
	var x0 := _px[0]
	var ancho_real := maxf(_px[n - 1] - x0, 1.0)
	# Velo: columnas con degradado (más cargado en los bordes y hacia abajo).
	for i in n - 1:
		var xa := _px[i]
		var xb := _px[i + 1]
		if xb - xa < 0.01:
			continue
		var na := (xa - x0) / ancho_real
		var nb := (xb - x0) / ancho_real
		_quad(_velo_pts, _velo_col, _velo_idx, Vector2(xa, _ptop[i]), Vector2(xb, _ptop[i + 1]), Vector2(xb, _pbot[i + 1]), Vector2(xa, _pbot[i]),
			_color_velo(na, 0.0, _ttile[i] == 0, false), _color_velo(nb, 0.0, _ttile[i + 1] == 0, false),
			_color_velo(nb, 1.0, false, _btile[i + 1] == 0), _color_velo(na, 1.0, false, _btile[i] == 0))
	_velo_listo = true


## Contorno brillante de un tramo continuo (halo ancho + núcleo fino).
func _tramo_contorno(pts: PackedVector2Array, halo: Color, nucleo: Color) -> void:
	if pts.size() < 2:
		return
	draw_polyline(pts, halo, 9.0 * intensidad, true)
	draw_polyline(pts, nucleo, 3.0 + intensidad, true)


func _draw() -> void:
	var n := _px.size()
	if n < 2:
		return
	var item := get_canvas_item()
	var c := color_base
	var l := color_luz
	var x0 := _px[0]
	var x1 := _px[n - 1]
	var ancho_real := maxf(x1 - x0, 1.0)
	if not _velo_listo:
		_construir_velo()
	if not _velo_idx.is_empty():
		RenderingServer.canvas_item_add_triangle_array(item, _velo_idx, _velo_pts, _velo_col)
	_tri_idx.resize(0)
	_tri_pts.resize(0)
	_tri_col.resize(0)
	var g := RandomNumberGenerator.new()
	g.seed = semilla
	# Corrientes: cintas onduladas que suben y se desvanecen; solo dentro del hueco.
	for i in corrientes:
		var x_c := lerpf(x0 + ancho_real * 0.08, x1 - ancho_real * 0.08, (float(i) + 0.5) / corrientes)
		var vel := velocidad * g.randf_range(0.6, 1.4)
		var largo := g.randf_range(120.0, 240.0)
		var fase := g.randf_range(0.0, TAU)
		var ancho_c := g.randf_range(2.5, 6.0)
		var lim := _limites(x_c)
		if lim.x == INF:
			continue
		var h_c := lim.y - lim.x
		var ciclo := h_c + largo
		var y_cab := lim.y - fposmod(_t * vel + g.randf_range(0.0, ciclo), ciclo)
		var pasos := 10
		for k in pasos:
			var u0 := float(k) / pasos
			var u1 := float(k + 1) / pasos
			var ya := y_cab + u0 * largo
			var yb := y_cab + u1 * largo
			if yb < lim.x or ya > lim.y:
				continue
			ya = clampf(ya, lim.x, lim.y)
			yb = clampf(yb, lim.x, lim.y)
			var xa := x_c + sin(ya * 0.018 + _t * 1.6 + fase) * 7.0
			var xb := x_c + sin(yb * 0.018 + _t * 1.6 + fase) * 7.0
			var ca := Color(l.r, l.g, l.b, minf(sin(u0 * PI) * 0.55 * intensidad, 1.0))
			var cb := Color(l.r, l.g, l.b, minf(sin(u1 * PI) * 0.55 * intensidad, 1.0))
			_quad(_tri_pts, _tri_col, _tri_idx, Vector2(xa - ancho_c, ya), Vector2(xa + ancho_c, ya), Vector2(xb + ancho_c, yb), Vector2(xb - ancho_c, yb), ca, ca, cb, cb)
	# Bandas de luz que barren de abajo hacia arriba: franjas por columna recortadas al hueco.
	var y_min := 0.0
	var y_max := 0.0
	for i in n:
		y_min = minf(y_min, _ptop[i])
		y_max = maxf(y_max, _pbot[i])
	for b in bandas:
		var y := y_max - fposmod(_t * velocidad * 0.9 + float(b) * (y_max - y_min) / maxf(bandas, 1), y_max - y_min)
		var alto_b := 46.0
		var tr := Color(l.r, l.g, l.b, 0.0)
		var cen := Color(l.r, l.g, l.b, minf(0.20 * intensidad, 0.7))
		for i in n - 1:
			var xa := _px[i]
			var xb := _px[i + 1]
			if xb - xa < 0.01:
				continue
			for mitad in 2:
				var ya := y - alto_b if mitad == 0 else y
				var yb := y if mitad == 0 else y + alto_b * 0.5
				var qa := Vector2(clampf(ya, _ptop[i], _pbot[i]), clampf(yb, _ptop[i], _pbot[i]))
				var qb := Vector2(clampf(ya, _ptop[i + 1], _pbot[i + 1]), clampf(yb, _ptop[i + 1], _pbot[i + 1]))
				if qa.y - qa.x < 0.5 and qb.y - qb.x < 0.5:
					continue
				var c0 := tr if mitad == 0 else cen
				var c1 := cen if mitad == 0 else tr
				_quad(_tri_pts, _tri_col, _tri_idx, Vector2(xa, qa.x), Vector2(xb, qb.x), Vector2(xb, qb.y), Vector2(xa, qa.y), c0, c0, c1, c1)
	if not _tri_idx.is_empty():
		RenderingServer.canvas_item_add_triangle_array(item, _tri_idx, _tri_pts, _tri_col)
	# Contorno brillante solo donde el muro toca roca: sigue el contorno del terreno arriba, abajo y en las paredes.
	var pulso := 0.75 + 0.25 * sin(_t * 2.2)
	var halo := Color(c.r, c.g, c.b, minf(0.35 * intensidad, 0.9) * pulso)
	var nucleo := Color(l.r, l.g, l.b, 0.85 * pulso)
	var tramo_t := PackedVector2Array()
	var tramo_b := PackedVector2Array()
	for i in n - 1:
		if _ttile[i] == 1 and _ttile[i + 1] == 1:
			if tramo_t.is_empty():
				tramo_t.append(Vector2(_px[i], _ptop[i]))
			tramo_t.append(Vector2(_px[i + 1], _ptop[i + 1]))
		else:
			_tramo_contorno(tramo_t, halo, nucleo)
			tramo_t = PackedVector2Array()
		if _btile[i] == 1 and _btile[i + 1] == 1:
			if tramo_b.is_empty():
				tramo_b.append(Vector2(_px[i], _pbot[i]))
			tramo_b.append(Vector2(_px[i + 1], _pbot[i + 1]))
		else:
			_tramo_contorno(tramo_b, halo, nucleo)
			tramo_b = PackedVector2Array()
	_tramo_contorno(tramo_t, halo, nucleo)
	_tramo_contorno(tramo_b, halo, nucleo)
	if _pared_izq:
		draw_line(Vector2(_px[0], _ptop[0]), Vector2(_px[0], _pbot[0]), halo, 9.0, true)
		draw_line(Vector2(_px[0], _ptop[0]), Vector2(_px[0], _pbot[0]), nucleo, 3.0, true)
	if _pared_der:
		draw_line(Vector2(_px[n - 1], _ptop[n - 1]), Vector2(_px[n - 1], _pbot[n - 1]), halo, 9.0, true)
		draw_line(Vector2(_px[n - 1], _ptop[n - 1]), Vector2(_px[n - 1], _pbot[n - 1]), nucleo, 3.0, true)
	# Motas de energía a la deriva (solo dentro del hueco).
	for m in motas:
		var s := g.randf_range(0.0, 1000.0)
		var x := lerpf(x0 + ancho_real * 0.05, x1 - ancho_real * 0.05, fposmod(sin(s * 12.9898) * 43758.5453, 1.0))
		var lim_m := _limites(x)
		if lim_m.x == INF:
			continue
		var vy := g.randf_range(18.0, 46.0)
		var y := lim_m.y - fposmod(_t * vy + fposmod(s * 37.0, lim_m.y - lim_m.x), maxf(lim_m.y - lim_m.x, 1.0))
		var tt := 0.5 + 0.5 * sin(_t * 3.0 + s)
		draw_circle(Vector2(x + sin(_t + s) * 6.0, y), 1.6 + tt * 1.6, Color(l.r, l.g, l.b, 0.25 + 0.5 * tt))
	# Chisporroteo eléctrico.
	if _chispa_pts.size() > 1:
		draw_polyline(_chispa_pts, Color(c.r, c.g, c.b, 0.55), 7.0, true)
		draw_polyline(_chispa_pts, Color(1.0, 1.0, 1.0, 0.9), 2.2, true)
