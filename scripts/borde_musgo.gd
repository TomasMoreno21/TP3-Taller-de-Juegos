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
@export var semilla := 1:
	set(v):
		semilla = v
		queue_redraw()


func _ready() -> void:
	queue_redraw()


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
	var r := _rect()
	if r.size == Vector2.ZERO:
		return
	var rng := RandomNumberGenerator.new()
	rng.seed = semilla * 7919 + int(r.size.x)
	var x0 := r.position.x
	var x1 := r.end.x
	var y := r.position.y
	if cuerpo:
		_dibujar_cuerpo(r, rng)
	if fragil:
		_dibujar_fragil(r, rng)
		return
	# Franja de pasto pegada al borde superior.
	draw_rect(Rect2(x0, y, r.size.x, 6.0), color_pasto)
	# Briznas triangulares irregulares que sobresalen.
	var x := x0
	while x < x1:
		var w := rng.randf_range(separacion * 0.7, separacion * 1.3)
		var h := alto_pasto * rng.randf_range(0.45, 1.0)
		var xe := minf(x + w, x1)
		var punta := x + (xe - x) * rng.randf_range(0.25, 0.75)
		draw_colored_polygon(PackedVector2Array([Vector2(x, y + 1.0), Vector2(punta, y - h), Vector2(xe, y + 1.0)]), color_pasto)
		x += w * 0.8
	# Veta de luz en el borde.
	draw_rect(Rect2(x0, y - 1.0, r.size.x, 3.0), color_veta)
	if not raices or r.size.y > 200.0 or absf(get_parent().rotation) > 0.01:  # bloques altos o rotados: sin raíces
		return
	# Raíces que cuelgan de la cara inferior.
	var yb := r.end.y
	var rx := x0 + rng.randf_range(8.0, 30.0)
	while rx < x1 - 6.0:
		var largo := largo_raices * rng.randf_range(0.35, 1.0)
		var ancho := rng.randf_range(3.0, 6.0)
		var desvio := rng.randf_range(-6.0, 6.0)
		draw_colored_polygon(PackedVector2Array([
			Vector2(rx - ancho, yb - 1.0), Vector2(rx + ancho, yb - 1.0),
			Vector2(rx + desvio + 1.0, yb + largo),
		]), color_raiz)
		rx += rng.randf_range(34.0, 90.0)


## Volumen del cuerpo: sombra en la mitad inferior, contorno, grietas y motas.
func _dibujar_cuerpo(r: Rect2, rng: RandomNumberGenerator) -> void:
	var pasos := 6
	for k in pasos:
		var t := float(k) / float(pasos)
		var y0 := r.position.y + r.size.y * (0.4 + 0.6 * t)
		draw_rect(Rect2(r.position.x, y0, r.size.x, r.size.y * 0.6 / float(pasos) + 0.5), Color(0, 0, 0, 0.06 + 0.05 * t))
	# Contorno oscuro.
	draw_rect(r, Color(0.03, 0.06, 0.04, 0.55), false, 2.0)
	# Grietas verticales (más en bloques anchos/altos) y motas de musgo.
	var n_grietas := clampi(int(r.size.x / 90.0 * (0.6 + r.size.y / 120.0)), 1, 14)
	for i in n_grietas:
		var gx := rng.randf_range(r.position.x + 8.0, r.end.x - 8.0)
		var gy := rng.randf_range(r.position.y + 6.0, r.position.y + r.size.y * 0.45)
		var lg := minf(rng.randf_range(10.0, 34.0), r.size.y * 0.7)
		draw_polyline(PackedVector2Array([Vector2(gx, gy), Vector2(gx + rng.randf_range(-5.0, 5.0), gy + lg * 0.5), Vector2(gx + rng.randf_range(-6.0, 6.0), gy + lg)]), color_grieta, 1.6)
	var n_motas := clampi(int(r.size.x * r.size.y / 900.0), 2, 60)
	for i in n_motas:
		var mx := rng.randf_range(r.position.x + 6.0, r.end.x - 6.0)
		var my := rng.randf_range(r.position.y + 8.0, r.end.y - 5.0)
		draw_circle(Vector2(mx, my), rng.randf_range(1.5, 3.4), color_mota)


## Estilo frágil: fisuras en zigzag de lado a lado y astillas en los bordes.
func _dibujar_fragil(r: Rect2, rng: RandomNumberGenerator) -> void:
	var cy := r.position.y + r.size.y * 0.5
	for f in 2:
		var pts := PackedVector2Array()
		var x := r.position.x + rng.randf_range(4.0, r.size.x * 0.25)
		while x < r.end.x - 6.0:
			pts.append(Vector2(x, cy + (float(f) - 0.5) * r.size.y * 0.4 + rng.randf_range(-r.size.y * 0.22, r.size.y * 0.22)))
			x += rng.randf_range(10.0, 22.0)
		if pts.size() >= 2:
			draw_polyline(pts, Color(0.16, 0.10, 0.06, 0.6), 1.8)
	for i in 5:
		var px := rng.randf_range(r.position.x, r.end.x)
		draw_rect(Rect2(px, r.position.y, rng.randf_range(4.0, 10.0), 2.5), Color(0.85, 0.72, 0.52, 0.55))
	# Grieta profunda oscura en un extremo.
	draw_colored_polygon(PackedVector2Array([
		Vector2(r.end.x - 34.0, r.position.y), Vector2(r.end.x - 28.0, r.position.y + r.size.y * 0.5),
		Vector2(r.end.x - 36.0, r.end.y), Vector2(r.end.x - 24.0, r.end.y), Vector2(r.end.x - 20.0, r.position.y)]), Color(0.10, 0.06, 0.04, 0.5))
