@tool
extends ParallaxLayer
## Capa de fondo de la CANTERA (atardecer): cielo con sol, mesas de roca, tótems gigantes y bruma.
## Siluetas planas como el resto del mundo; el tinte cálido lo aporta la escena noche_cantera.
## Cada capa dibuja continua en ancho_total/centro_x y en alto (y_techo..y_fondo). Todo editable.

@export_enum("cielo", "mesas", "totems", "bruma") var tipo := "cielo":
	set(v):
		tipo = v
		queue_redraw()
@export var color_a := Color(0.95, 0.62, 0.32):
	set(v):
		color_a = v
		queue_redraw()
@export var color_b := Color(0.32, 0.16, 0.14):
	set(v):
		color_b = v
		queue_redraw()
@export var color_sol := Color(1.0, 0.86, 0.55):
	set(v):
		color_sol = v
		queue_redraw()
@export var densidad := 1.0:
	set(v):
		densidad = maxf(v, 0.05)
		queue_redraw()
@export var semilla := 1:
	set(v):
		semilla = v
		queue_redraw()
@export_range(2000, 40000, 500) var ancho_total := 11000.0:
	set(v):
		ancho_total = v
		queue_redraw()
@export_range(-20000, 20000, 100) var centro_x := 3600.0:
	set(v):
		centro_x = v
		queue_redraw()
@export var y_techo := 0.0:
	set(v):
		y_techo = v
		queue_redraw()
@export var y_fondo := 4500.0:
	set(v):
		y_fondo = v
		queue_redraw()
## Altura media de las cimas (mesas y tótems) medida desde y_techo hacia abajo (0..1 del alto).
@export_range(0.0, 1.0) var altura_relativa := 0.35:
	set(v):
		altura_relativa = v
		queue_redraw()
@export var color_niebla := Color(0.95, 0.66, 0.45):
	set(v):
		color_niebla = v
		queue_redraw()
@export_range(0.0, 1.0) var niebla := 0.25:
	set(v):
		niebla = v
		queue_redraw()


func _draw() -> void:
	var x_min := centro_x - ancho_total * 0.5
	seed(semilla)
	match tipo:
		"cielo":
			_dibujar_cielo(x_min)
		"mesas":
			_dibujar_mesas(x_min)
		"totems":
			_dibujar_totems(x_min)
		"bruma":
			_dibujar_bruma(x_min)
	randomize()


func _dibujar_cielo(x_min: float) -> void:
	var n := 40
	var alto := y_fondo - y_techo
	for i in n:
		var t := float(i) / float(n - 1)
		var y0 := y_techo + alto * t
		var y1 := y_techo + alto * float(i + 1) / float(n - 1)
		draw_rect(Rect2(x_min, y0, ancho_total, y1 - y0 + 1.0), color_a.lerp(color_b, t * t))
	# Sol grande y bajo, con halo de capas anchas.
	var sol := Vector2(centro_x + ancho_total * 0.12, y_techo + alto * 0.16)
	for k in 6:
		draw_circle(sol, 260.0 + float(k) * 190.0, Color(color_sol.r, color_sol.g, color_sol.b, 0.04))
	draw_circle(sol, 250.0, Color(color_sol.r, color_sol.g, color_sol.b, 0.95))
	# Bandas de nubes largas y finas.
	var nubes := int(ancho_total / 900.0 * densidad)
	for i in nubes:
		var p := Vector2(x_min + randf() * ancho_total, y_techo + alto * randf_range(0.02, 0.42))
		var w := randf_range(500.0, 1400.0)
		var h := randf_range(16.0, 42.0)
		draw_colored_polygon(_elipse(p, Vector2(w * 0.5, h), 14), Color(color_niebla.r, color_niebla.g, color_niebla.b, randf_range(0.10, 0.22)))


func _dibujar_mesas(x_min: float) -> void:
	var alto := y_fondo - y_techo
	var x := x_min
	var cima_media := y_techo + alto * altura_relativa
	while x < x_min + ancho_total:
		var w := randf_range(500.0, 1300.0) / densidad
		var cima := cima_media + randf_range(-alto * 0.14, alto * 0.14)
		var esc := randf_range(60.0, 180.0)
		# Mesa: cima plana, laderas escalonadas.
		var pts := PackedVector2Array([Vector2(x, y_fondo + 200.0), Vector2(x + esc * 0.4, cima + esc * 1.4), Vector2(x + esc, cima + esc * 0.5),
			Vector2(x + esc * 1.2, cima), Vector2(x + w - esc * 1.2, cima), Vector2(x + w - esc, cima + esc * 0.5),
			Vector2(x + w - esc * 0.4, cima + esc * 1.4), Vector2(x + w, y_fondo + 200.0)])
		draw_colored_polygon(pts, color_b)
		# Cara iluminada del borde superior (luz del sol bajo).
		draw_polyline(PackedVector2Array([Vector2(x + esc * 1.2, cima), Vector2(x + w - esc * 1.2, cima)]), color_a.lightened(0.25), 4.0)
		# Estratos horizontales.
		for j in 3:
			var ye := cima + esc * (0.9 + j * 0.8)
			draw_line(Vector2(x + esc * 0.7, ye), Vector2(x + w - esc * 0.7, ye), Color(color_a.r, color_a.g, color_a.b, 0.12), 3.0)
		x += w * randf_range(0.55, 0.9)


func _dibujar_totems(x_min: float) -> void:
	var alto := y_fondo - y_techo
	var n := maxi(2, roundi(ancho_total / (2300.0 / densidad)))
	for i in n:
		seed(semilla * 13 + i * 31)
		var cx := x_min + (i + randf_range(0.25, 0.75)) * ancho_total / float(n)
		var base_w := randf_range(260.0, 380.0)
		var cima := y_techo + alto * altura_relativa + randf_range(-alto * 0.12, alto * 0.12)
		var roto := randf() < 0.35
		_dibujar_totem(cx, base_w, cima, roto)


## Tótem: pilar de bloques con cabeza de oso en lo alto (o cima rota). Cae hasta y_fondo.
func _dibujar_totem(cx: float, w: float, cima: float, roto: bool) -> void:
	var col := color_b
	var luz := color_a.lightened(0.1)
	# Fuste hasta el fondo, con bloques marcados.
	draw_rect(Rect2(cx - w * 0.5, cima, w, y_fondo + 200.0 - cima), col)
	var bloque := w * 1.15
	var y := cima + bloque
	while y < y_fondo:
		draw_line(Vector2(cx - w * 0.5, y), Vector2(cx + w * 0.5, y), Color(0, 0, 0, 0.22), 4.0)
		y += bloque
	draw_line(Vector2(cx - w * 0.5, cima), Vector2(cx - w * 0.5, cima + bloque * 6.0), Color(luz.r, luz.g, luz.b, 0.35), 5.0)
	if roto:
		# Cima quebrada: dientes irregulares.
		var pts := PackedVector2Array([Vector2(cx - w * 0.5, cima), Vector2(cx - w * 0.2, cima - w * 0.25), Vector2(cx, cima - w * 0.05),
			Vector2(cx + w * 0.25, cima - w * 0.4), Vector2(cx + w * 0.5, cima)])
		draw_colored_polygon(pts, col)
		return
	# Cabeza de oso: bloque ancho, orejas redondas y ojos.
	var hw := w * 1.35
	var hh := w * 1.1
	draw_rect(Rect2(cx - hw * 0.5, cima - hh, hw, hh), col)
	for s in [-1.0, 1.0]:
		draw_circle(Vector2(cx + s * hw * 0.42, cima - hh), w * 0.28, col)
		draw_circle(Vector2(cx + s * hw * 0.42, cima - hh), w * 0.13, Color(0, 0, 0, 0.25))
		draw_rect(Rect2(cx + s * w * 0.28 - w * 0.09, cima - hh * 0.62, w * 0.18, w * 0.1), Color(color_sol.r, color_sol.g, color_sol.b, 0.55))
	draw_rect(Rect2(cx - w * 0.2, cima - hh * 0.4, w * 0.4, w * 0.2), Color(0, 0, 0, 0.3))
	draw_line(Vector2(cx - hw * 0.5, cima - hh), Vector2(cx + hw * 0.5, cima - hh), Color(luz.r, luz.g, luz.b, 0.4), 4.0)


func _dibujar_bruma(x_min: float) -> void:
	var alto := y_fondo - y_techo
	var bandas := maxi(3, roundi(alto / 700.0 * densidad))
	for b in bandas:
		seed(semilla * 7 + b * 97)
		var y := y_techo + alto * (float(b) + randf_range(0.2, 0.8)) / float(bandas)
		var h := randf_range(260.0, 520.0)
		var col := Color(color_niebla.r, color_niebla.g, color_niebla.b, niebla * randf_range(0.5, 1.0))
		var col0 := Color(col.r, col.g, col.b, 0.0)
		var x := int(floor(x_min))
		var prev := Vector2.ZERO
		var primero := true
		while x <= int(ceil(x_min + ancho_total)):
			var yy := y + sin(x * 0.0017 + y * 0.004) * 16.0
			if not primero:
				draw_polygon(PackedVector2Array([prev, Vector2(x, yy), Vector2(x, yy + h * 0.5), prev + Vector2(0, h * 0.5)]), PackedColorArray([col0, col0, col, col]))
				draw_polygon(PackedVector2Array([prev + Vector2(0, h * 0.5), Vector2(x, yy + h * 0.5), Vector2(x, yy + h), prev + Vector2(0, h)]), PackedColorArray([col, col, col0, col0]))
			prev = Vector2(x, yy)
			primero = false
			x += 260


func _elipse(centro: Vector2, radios: Vector2, n: int) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in n:
		var a := TAU * float(i) / float(n)
		pts.append(Vector2(centro.x + cos(a) * radios.x, centro.y + sin(a) * radios.y))
	return pts
