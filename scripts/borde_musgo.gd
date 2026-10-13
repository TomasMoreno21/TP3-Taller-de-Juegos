@tool
extends Node2D
## Remate vectorial para pisos y plataformas rectangulares: labio de pasto arriba,
## veta clara y (opcional) raíces colgando abajo. Se cuelga como hijo de un
## StaticBody2D con CollisionShape2D rectangular y toma su rectángulo.
## Colores planos, sin colisión; todo editable en el Inspector.

@export var color_pasto := Color(0.20, 0.42, 0.20):
	set(v):
		color_pasto = v
		queue_redraw()
@export var color_veta := Color(0.42, 0.62, 0.30):
	set(v):
		color_veta = v
		queue_redraw()
@export var color_raiz := Color(0.20, 0.13, 0.10):
	set(v):
		color_raiz = v
		queue_redraw()
@export var alto_pasto := 16.0:
	set(v):
		alto_pasto = v
		queue_redraw()
@export var separacion := 22.0:  ## px entre briznas
	set(v):
		separacion = maxf(v, 6.0)
		queue_redraw()
@export var raices := true:
	set(v):
		raices = v
		queue_redraw()
@export var largo_raices := 46.0:
	set(v):
		largo_raices = v
		queue_redraw()
## Detalle del cuerpo: sombra inferior, grietas, motas y contorno oscuro.
@export var cuerpo := true:
	set(v):
		cuerpo = v
		queue_redraw()
@export var color_grieta := Color(0.06, 0.10, 0.07, 0.38):
	set(v):
		color_grieta = v
		queue_redraw()
@export var color_mota := Color(0.45, 0.62, 0.32, 0.30):
	set(v):
		color_mota = v
		queue_redraw()
## Estilo "frágil": sin pasto ni raíces; grietas en zigzag y astillas (plataformas que se rompen).
@export var fragil := false:
	set(v):
		fragil = v
		queue_redraw()
## Estilo "piedra" (plataformas de cueva): lascas bajas y chatas en vez de briznas, dientes de roca en vez de raíces.
## Pensado con colores fríos (color_pasto = roca, color_veta = filo claro, color_raiz = roca oscura).
@export var piedra := false:
	set(v):
		piedra = v
		queue_redraw()
@export var semilla := 1:
	set(v):
		semilla = v
		queue_redraw()


## En runtime, los bordes muy anchos (el piso del nivel, ~32000 px) se parten en trozos: cada trozo es un
## CanvasItem propio y Godot lo descarta cuando está fuera de pantalla (antes eran ~2000 llamadas de dibujo por frame).
const ANCHO_TROZO := 1024.0
const ANCHO_MIN_TROZEAR := 2048.0

var _trozos: Array[Node2D] = []
var _mallas: Dictionary = {}   # id del CanvasItem -> mallas vivas (si se libera la malla, el dibujo desaparece)


## Trozo de un borde ancho: dibuja solo su tramo [x0, x1) con el mismo azar que el borde entero.
class _Trozo extends Node2D:
	var musgo: Node2D
	var x0 := 0.0
	var x1 := 0.0

	func _draw() -> void:
		musgo._dibujar_en(self, x0, x1)


func _ready() -> void:
	queue_redraw()
	if not Engine.is_editor_hint():
		_trocear()


func _trocear() -> void:
	if fragil:
		return
	var r := _rect()
	if r.size.x <= ANCHO_MIN_TROZEAR:
		return
	var x := r.position.x
	while x < r.end.x:
		var t := _Trozo.new()
		t.musgo = self
		t.x0 = x
		t.x1 = x + ANCHO_TROZO if x + ANCHO_TROZO < r.end.x else INF   # el último trozo llega hasta el final
		t.use_parent_material = true
		add_child(t)
		_trozos.append(t)
		x += ANCHO_TROZO


func _rect() -> Rect2:
	var body := get_parent()
	if body == null:
		return Rect2()
	if body is Polygon2D and (body as Polygon2D).polygon.size() >= 3:
		var mn0 := Vector2(INF, INF)
		var mx0 := Vector2(-INF, -INF)
		for v0 in (body as Polygon2D).polygon:
			mn0 = mn0.min(v0)
			mx0 = mx0.max(v0)
		return Rect2(mn0 - position, mx0 - mn0)
	# Se prefiere el rectángulo del Polygon2D visual (es lo que se ve); si no hay,
	# el del CollisionShape2D rectangular.
	for c in body.get_children():
		if c is Polygon2D and (c as Polygon2D).polygon.size() >= 3:
			var mn := Vector2(INF, INF)
			var mx := Vector2(-INF, -INF)
			for v in (c as Polygon2D).polygon:
				var w: Vector2 = (c as Polygon2D).transform * v
				mn = mn.min(w)
				mx = mx.max(w)
			return Rect2(mn - position, mx - mn)
	for c in body.get_children():
		if c is CollisionShape2D and c.shape is RectangleShape2D:
			var s: Vector2 = (c.shape as RectangleShape2D).size * c.scale
			return Rect2(c.position - s * 0.5 - position, s)
	return Rect2()


func _draw() -> void:
	if not _trozos.is_empty():
		return
	_dibujar_en(self, -INF, INF)


## Dibuja una lista de triángulos sueltos de un solo color como una malla (1 llamada de dibujo).
func _malla(ci: CanvasItem, triangulos: PackedVector2Array, col: Color) -> void:
	if triangulos.is_empty():
		return
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = triangulos
	var malla := ArrayMesh.new()
	malla.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	var id := ci.get_instance_id()
	if not _mallas.has(id):
		_mallas[id] = []
	_mallas[id].append(malla)
	ci.draw_mesh(malla, null, Transform2D.IDENTITY, col)


## Rect relleno recortado al tramo [cx0, cx1) del trozo.
func _rx(ci: CanvasItem, cx0: float, cx1: float, x: float, y: float, w: float, h: float, col: Color) -> void:
	var a := maxf(x, cx0)
	var b := minf(x + w, cx1)
	if b > a:
		ci.draw_rect(Rect2(a, y, b - a, h), col)


## Dibuja el borde en `ci` (el propio nodo o un trozo). Todo el azar se consume igual en cada trozo
## (mismo resultado que dibujarlo entero); solo se emite lo que cae en [cx0, cx1).
func _dibujar_en(ci: CanvasItem, cx0: float, cx1: float) -> void:
	_mallas.erase(ci.get_instance_id())
	var r := _rect()
	if r.size == Vector2.ZERO:
		return
	var rng := RandomNumberGenerator.new()
	rng.seed = semilla * 7919 + int(r.size.x)
	var x0 := r.position.x
	var x1 := r.end.x
	var y := r.position.y
	if cuerpo:
		_dibujar_cuerpo(ci, r, rng, cx0, cx1)
	if fragil:
		_dibujar_fragil(r, rng)
		return
	# Franja de pasto pegada al borde superior.
	_rx(ci, cx0, cx1, x0, y, r.size.x, 6.0, color_pasto)
	# Briznas triangulares irregulares que sobresalen (todas en UNA malla: una sola llamada de dibujo).
	var briznas := PackedVector2Array()
	var x := x0
	while x < x1:
		var w := rng.randf_range(separacion * 0.7, separacion * 1.3) * (1.8 if piedra else 1.0)
		var h := alto_pasto * rng.randf_range(0.45, 1.0)
		var xe := minf(x + w, x1)
		var punta := x + (xe - x) * rng.randf_range(0.25, 0.75)
		if x >= cx0 and x < cx1:
			briznas.append_array(PackedVector2Array([Vector2(x, y + 1.0), Vector2(punta, y - h), Vector2(xe, y + 1.0)]))
		x += w * 0.8
	_malla(ci, briznas, color_pasto)
	# Veta de luz en el borde.
	_rx(ci, cx0, cx1, x0, y - 1.0, r.size.x, 3.0, color_veta)
	if not raices or r.size.y > 200.0 or absf(get_parent().rotation) > 0.01:  # bloques altos o rotados: sin raíces
		return
	var colgajos := PackedVector2Array()
	# Raíces que cuelgan de la cara inferior.
	var yb := r.end.y
	var rx := x0 + rng.randf_range(8.0, 30.0)
	while rx < x1 - 6.0:
		var largo := largo_raices * rng.randf_range(0.35, 1.0)
		var ancho := rng.randf_range(3.0, 6.0) * (1.9 if piedra else 1.0)
		var desvio := rng.randf_range(-6.0, 6.0) * (0.4 if piedra else 1.0)
		if rx >= cx0 and rx < cx1:
			colgajos.append_array(PackedVector2Array([
				Vector2(rx - ancho, yb - 1.0), Vector2(rx + ancho, yb - 1.0),
				Vector2(rx + desvio + 1.0, yb + largo),
			]))
		rx += rng.randf_range(34.0, 90.0) * (1.4 if piedra else 1.0)
	_malla(ci, colgajos, color_raiz)


## Volumen del cuerpo: sombra en la mitad inferior, contorno, grietas y motas.
func _dibujar_cuerpo(ci: CanvasItem, r: Rect2, rng: RandomNumberGenerator, cx0: float, cx1: float) -> void:
	var pasos := 6
	for k in pasos:
		var t := float(k) / float(pasos)
		var y0 := r.position.y + r.size.y * (0.4 + 0.6 * t)
		_rx(ci, cx0, cx1, r.position.x, y0, r.size.x, r.size.y * 0.6 / float(pasos) + 0.5, Color(0, 0, 0, 0.06 + 0.05 * t))
	# Contorno oscuro (en un trozo: arriba y abajo recortados; los costados solo en los extremos del borde).
	var col_c := Color(0.03, 0.06, 0.04, 0.55)
	if cx0 <= r.position.x and cx1 >= r.end.x:
		ci.draw_rect(r, col_c, false, 2.0)
	else:
		var a := maxf(r.position.x, cx0)
		var b := minf(r.end.x, cx1)
		if b > a:
			ci.draw_line(Vector2(a, r.position.y), Vector2(b, r.position.y), col_c, 2.0)
			ci.draw_line(Vector2(a, r.end.y), Vector2(b, r.end.y), col_c, 2.0)
		if r.position.x >= cx0 and r.position.x < cx1:
			ci.draw_line(r.position, Vector2(r.position.x, r.end.y), col_c, 2.0)
		if r.end.x >= cx0 and r.end.x <= cx1:
			ci.draw_line(Vector2(r.end.x, r.position.y), r.end, col_c, 2.0)
	# Grietas verticales (más en bloques anchos/altos) y motas de musgo.
	var n_grietas := clampi(int(r.size.x / 90.0 * (0.6 + r.size.y / 120.0)), 1, 14)
	for i in n_grietas:
		var gx := rng.randf_range(r.position.x + 8.0, r.end.x - 8.0)
		var gy := rng.randf_range(r.position.y + 6.0, r.position.y + r.size.y * 0.45)
		var lg := minf(rng.randf_range(10.0, 34.0), r.size.y * 0.7)
		var p1 := Vector2(gx + rng.randf_range(-5.0, 5.0), gy + lg * 0.5)
		var p2 := Vector2(gx + rng.randf_range(-6.0, 6.0), gy + lg)
		if gx >= cx0 and gx < cx1:
			ci.draw_polyline(PackedVector2Array([Vector2(gx, gy), p1, p2]), color_grieta, 1.6)
	var n_motas := clampi(int(r.size.x * r.size.y / 900.0), 2, 60)
	for i in n_motas:
		var mx := rng.randf_range(r.position.x + 6.0, r.end.x - 6.0)
		var my := rng.randf_range(r.position.y + 8.0, r.end.y - 5.0)
		var rad := rng.randf_range(1.5, 3.4)
		if mx >= cx0 and mx < cx1:
			ci.draw_circle(Vector2(mx, my), rad, color_mota)


## Estilo frágil: tablones de madera vieja con herrajes, clavos, vetas, grietas y astillas colgando.
func _dibujar_fragil(r: Rect2, rng: RandomNumberGenerator) -> void:
	var x0 := r.position.x
	var x1 := r.end.x
	var y0 := r.position.y
	var y1 := r.end.y
	var h := r.size.y
	# Sombra del canto inferior y brillo del borde superior.
	draw_rect(Rect2(x0, y1 - h * 0.28, r.size.x, h * 0.28), Color(0.07, 0.04, 0.03, 0.42))
	draw_rect(Rect2(x0, y0, r.size.x, 3.0), Color(0.93, 0.80, 0.60, 0.55))
	# Tablones: junta vertical oscura + vetas largas dentro de cada uno.
	var junta := x0
	while true:
		var ancho := rng.randf_range(54.0, 86.0)
		var fin := minf(junta + ancho, x1)
		for g in 2:
			var gy := y0 + h * (0.32 + 0.3 * g) + rng.randf_range(-2.0, 2.0)
			var gx := junta + rng.randf_range(6.0, 16.0)
			draw_line(Vector2(gx, gy), Vector2(minf(gx + rng.randf_range(22.0, 44.0), fin - 6.0), gy + rng.randf_range(-1.5, 1.5)), Color(0.16, 0.10, 0.06, 0.32), 1.5)
		if fin >= x1 - 1.0:
			break
		draw_line(Vector2(fin, y0 + 3.0), Vector2(fin, y1), Color(0.10, 0.06, 0.04, 0.7), 2.2)
		draw_line(Vector2(fin + 2.0, y0 + 3.0), Vector2(fin + 2.0, y1 - h * 0.28), Color(0.9, 0.76, 0.56, 0.18), 1.2)
		for lado in [-9.0, 9.0]:
			var c := Vector2(fin + lado, y0 + h * 0.36)
			draw_circle(c, 2.4, Color(0.11, 0.09, 0.08))
			draw_circle(c + Vector2(-0.7, -0.7), 1.0, Color(0.55, 0.52, 0.5, 0.8))
		junta = fin
	# Herrajes de hierro en los extremos con remaches.
	for bx in [x0, x1 - 12.0]:
		draw_rect(Rect2(bx, y0, 12.0, h), Color(0.20, 0.22, 0.28))
		draw_rect(Rect2(bx, y0, 12.0, 2.5), Color(0.42, 0.45, 0.55, 0.8))
		draw_circle(Vector2(bx + 6.0, y0 + h * 0.3), 2.0, Color(0.5, 0.52, 0.6))
		draw_circle(Vector2(bx + 6.0, y0 + h * 0.72), 2.0, Color(0.5, 0.52, 0.6))
	# Grietas en zigzag que recorren la tabla.
	for f in 2:
		var pts := PackedVector2Array()
		var x := x0 + rng.randf_range(20.0, r.size.x * 0.3)
		while x < x1 - 20.0:
			pts.append(Vector2(x, y0 + h * (0.35 + 0.3 * f) + rng.randf_range(-h * 0.2, h * 0.2)))
			x += rng.randf_range(12.0, 26.0)
		if pts.size() >= 2:
			draw_polyline(pts, Color(0.08, 0.05, 0.03, 0.75), 2.2)
	# Astillas y pedazos que cuelgan del canto inferior.
	var ax := x0 + 18.0
	while ax < x1 - 22.0:
		var aw := rng.randf_range(6.0, 14.0)
		var al := rng.randf_range(5.0, h * 0.7)
		draw_colored_polygon(PackedVector2Array([Vector2(ax, y1 - 1.0), Vector2(ax + aw, y1 - 1.0), Vector2(ax + aw * rng.randf_range(0.2, 0.8), y1 + al)]), Color(0.30, 0.21, 0.13))
		ax += rng.randf_range(26.0, 60.0)
	# Grieta profunda hacia un extremo.
	draw_colored_polygon(PackedVector2Array([
		Vector2(x1 - 46.0, y0), Vector2(x1 - 38.0, y0 + h * 0.5),
		Vector2(x1 - 48.0, y1), Vector2(x1 - 32.0, y1), Vector2(x1 - 28.0, y0)]), Color(0.07, 0.04, 0.03, 0.6))
