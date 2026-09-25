@tool
extends ParallaxLayer
## Capa de fondo de CUEVA vectorial (siluetas planas). Cada capa dibuja su
## formación (pared rocosa, estalactitas, pilares, estalagmitas, agua) de
## forma CONTINUA a lo largo de todo el ancho y alto del nivel (ancho_total,
## centro_x, y_techo, y_fondo), sin cortes en los bordes. El descenso vertical
## está pensado como un abismo: techo con estalactitas arriba, columnas de
## piedra que suben desde el fondo, grietas/estratos en las paredes y un lago
## en la base. Todo anclado a una superficie real (techo, piso o pared), nada
## flotando. Configurable desde el Inspector.

@export_enum("sombra", "pared", "estalactitas", "pilares", "estalagmitas", "agua") var tipo := "sombra":
	set(value):
		tipo = value
		queue_redraw()
@export var color_a := Color(0.1, 0.12, 0.18):
	set(value):
		color_a = value
		queue_redraw()
@export var color_b := Color(0.05, 0.06, 0.1):
	set(value):
		color_b = value
		queue_redraw()
@export var y_base := 1000.0:
	set(value):
		y_base = value
		queue_redraw()
@export var densidad := 1.0:
	set(value):
		densidad = maxf(value, 0.05)
		queue_redraw()
@export var semilla := 1:
	set(value):
		semilla = value
		queue_redraw()
## Ancho total del nivel que cubre la capa.
@export_range(2000, 40000, 500) var ancho_total := 21000.0:
	set(value):
		ancho_total = value
		queue_redraw()
@export_range(-20000, 20000, 100) var centro_x := 0.0:
	set(value):
		centro_x = value
		queue_redraw()
## Techo (arriba) de la caverna, límite de la cámara en nivel vertical.
@export var y_techo := -1500.0:
	set(value):
		y_techo = value
		queue_redraw()
## Fondo (abajo) de la caverna, límite inferior de la cámara en nivel vertical.
@export var y_fondo := 7600.0:
	set(value):
		y_fondo = value
		queue_redraw()


func _draw() -> void:
	var x_min := centro_x - ancho_total * 0.5
	var x_max := centro_x + ancho_total * 0.5
	var ancho := maxf(x_max - x_min, 1.0)
	seed(semilla)
	match tipo:
		"sombra":
			_dibujar_sombra(x_min, x_max, ancho)
		"pared":
			_dibujar_pared(x_min, x_max, ancho)
		"estalactitas":
			_dibujar_estalactitas(x_min, x_max, ancho)
		"pilares":
			_dibujar_pilares(x_min, x_max, ancho)
		"estalagmitas":
			_dibujar_estalagmitas(x_min, x_max, ancho)
		"agua":
			_dibujar_agua(x_min, x_max, ancho)


## Posición x del centro de una familia, repartida uniformemente con jitter.
func _centro_familia(x_min: float, ancho: float, n: int, i: int) -> float:
	return x_min + (i + randf_range(0.15, 0.85)) * (ancho / float(n))


## Punto de una celda en rejilla horizontal × vertical (columnas × filas).
func _punto_rejilla(x_min: float, ancho: float, cols: int, ic: int, y_top: float, alto: float, filas: int, ifi: int) -> Vector2:
	return Vector2(
		x_min + (ic + randf_range(0.2, 0.8)) * ancho / float(cols),
		y_top + (ifi + randf_range(0.2, 0.8)) * alto / float(filas))


func _dibujar_sombra(x_min: float, x_max: float, ancho: float) -> void:
	var alto := y_fondo - y_techo
	_dibujar_franja(x_min, x_max, y_techo, y_fondo + 900.0, color_a, color_b)
	# Haz de luz desde la entrada: franja vertical tenue en el centro (apertura arriba).
	var cx_luz := centro_x
	draw_rect(Rect2(cx_luz - 15.0, y_techo, 30.0, alto * 0.55), Color(0.85, 0.95, 1.0, 0.05))
	draw_rect(Rect2(cx_luz - 48.0, y_techo, 96.0, alto * 0.34), Color(0.85, 0.95, 1.0, 0.03))
	# Grietas grandes y verticales, muy tenues, en rejilla por todo el descenso.
	var gc := maxi(2, roundi(ancho / 1600.0))
	var gf := maxi(2, roundi(alto / 1500.0))
	for i in gc:
		for j in gf:
			seed(semilla * 3 + i * 101 + j)
			var p := _punto_rejilla(x_min, ancho, gc, i, y_techo, alto, gf, j)
			_dibujar_falla_at(p.x, p.y, randf_range(1400.0, 2200.0), randf_range(0.08, 0.16))
	# Bóvedas de caverna lejanas: siluetas suaves en rejilla algo más espaciada.
	var bc := maxi(2, roundi(ancho / 2000.0))
	var bf := maxi(2, roundi(alto / 2100.0))
	for i in bc:
		for j in bf:
			seed(semilla * 41 + i * 5 + j * 7)
			var p := _punto_rejilla(x_min, ancho, bc, i, y_techo + 300.0, alto - 600.0, bf, j)
			var rw := randf_range(400.0, 720.0)
			var rh := randf_range(220.0, 460.0)
			draw_colored_polygon(_arco_elipse(p, Vector2(rw, rh), 12), Color(color_a.r, color_a.g, color_a.b, randf_range(0.22, 0.34)))
	# Siluetas de roca lejanas adicionales (profundidad en la capa más lejana):
	# guijarros tenues distribuidos en rejilla dispersa, más oscuros que la pared.
	var rcs := maxi(3, roundi(ancho / 700.0))
	var rfs := maxi(3, roundi(alto / 500.0))
	for i in rcs:
		for j in rfs:
			seed(semilla * 91 + i * 61 + j * 71)
			var p := _punto_rejilla(x_min, ancho, rcs, i, y_techo + 200.0, alto - 400.0, rfs, j)
			if randf() < 0.6:
				_dibujar_roca(p.x, p.y, randf_range(80.0, 200.0), randf_range(50.0, 130.0), randf_range(0.1, 0.24))


func _dibujar_pared(x_min: float, x_max: float, ancho: float) -> void:
	var alto := y_fondo - y_techo
	_dibujar_franja(x_min, x_max, y_techo, y_fondo, color_a, color_a.darkened(0.4))
	# Estratos horizontales de roca: líneas onduladas tenues en rejilla vertical.
	var sc := 4
	var sf := maxi(3, roundi(alto / 900.0))
	for i in sc:
		for j in sf:
			seed(semilla * 17 + i * 11 + j * 13)
			var p := _punto_rejilla(x_min, ancho, sc, i + 1, y_techo + 200.0, alto - 300.0, sf, j)
			_estrato(x_min, x_max, p.y, randf_range(0.12, 0.24))
	# Grietas definidas, repartidas en rejilla por todo el descenso.
	var gc := maxi(3, roundi(ancho / 1200.0))
	var gf := maxi(3, roundi(alto / 1300.0))
	for i in gc:
		for j in gf:
			seed(semilla * 3 + i * 101 + j)
			var p := _punto_rejilla(x_min, ancho, gc, i, y_techo, alto, gf, j)
			_dibujar_falla_at(p.x, p.y, randf_range(900.0, 1500.0), randf_range(0.16, 0.28))
	# Racimos de cristales anclados a la roca de las paredes: rejilla densa.
	var cc := maxi(3, roundi(ancho / 700.0))
	var cf := maxi(3, roundi(alto / 800.0))
	for i in cc:
		for j in cf:
			seed(semilla * 5 + i * 7 + j * 13)
			var p := _punto_rejilla(x_min, ancho, cc, i, y_techo + 200.0, alto - 400.0, cf, j)
			var n_cr := randi_range(2, 3)
			for c in n_cr:
				_dibujar_cristal(p.x + (c - (n_cr - 1) * 0.5) * randf_range(24.0, 40.0), p.y, randf_range(9.0, 15.0), randf_range(0.22, 0.42))
	# Guijarros y piedras sueltas del fondo: rejilla MUY densa con tamaños y
	# alphas variados. Las tenues y pequeñas dan lejanía; las grandes y claras
	# anclan el primer plano (profundidad por contraste de escala).
	var rc := maxi(4, roundi(ancho / 380.0))
	var rf := maxi(4, roundi(alto / 340.0))
	for i in rc:
		for j in rf:
			seed(semilla * 67 + i * 13 + j * 29)
			var p := _punto_rejilla(x_min, ancho, rc, i, y_techo + 420.0, alto - 500.0, rf, j)
			var s := randf_range(14.0, 60.0) * densidad
			var h := s * randf_range(0.6, 1.0)
			var lejos: bool = randf() < 0.45
			_dibujar_roca(p.x, p.y, s, h, randf_range(0.22, 0.5), lejos)
			if randf() < 0.3:
				_dibujar_falla_at(p.x, p.y - s * 0.4, randf_range(240.0, 460.0), randf_range(0.08, 0.14))


func _dibujar_estalactitas(x_min: float, x_max: float, ancho: float) -> void:
	# Techo de la caverna (parte superior del descenso), masa oscura completa.
	var techo_h := 520.0
	var base_techo := y_techo + techo_h
	draw_rect(Rect2(x_min, y_techo, ancho, techo_h), color_a)
	# Hilera TRASERA (profundidad): estalactitas pequeñas, tenues y más juntas,
	# intercaladas entre las principales. Definen un segundo plano del techo.
	var n_tr := maxi(3, roundi(ancho / 420.0))
	for i in n_tr:
		seed(semilla * 37 + i * 23)
		var x := _centro_familia(x_min, ancho, n_tr, i)
		var h_tr := randf_range(120.0, 320.0) * densidad
		_dibujar_estalactita(x, randf_range(30.0, 55.0), h_tr, base_techo, randf_range(0.28, 0.42))
	# Hilera PRINCIPAL del techo: familias densas, la central más larga.
	var n := maxi(3, roundi(ancho / 520.0))
	for i in n:
		seed(semilla * 7 + i * 13)
		var cx := _centro_familia(x_min, ancho, n, i)
		var n_est := randi_range(3, 5)
		for e in n_est:
			var off := (e - (n_est - 1) * 0.5) * randf_range(50.0, 90.0)
			var centro: bool = e == floor(n_est * 0.5)
			var h := randf_range(180.0, 420.0) * densidad
			if centro:
				h = randf_range(480.0, 820.0) * densidad
			_dibujar_estalactita(cx + off, randf_range(45.0, 90.0), h, base_techo)
	# Estalactitas finas y MUY largas (hebras) que descienden del techo casi
	# hasta la mitad del abismo: el detalle baja y llena todo el alto.
	var nc := maxi(3, roundi(ancho / 600.0))
	for i in nc:
		seed(semilla * 29 + i * 19)
		var x := _centro_familia(x_min, ancho, nc, i)
		var h := randf_range(1200.0, 1900.0) * densidad
		_dibujar_estalactita(x, randf_range(28.0, 46.0), h, base_techo)
	# Roca frontal sobresaliendo del techo hacia abajo (recorte del fondo).
	# Guijarros sueltos en la masa del techo, todo anclado a la roca.
	var rc := maxi(3, roundi(ancho / 620.0))
	for i in rc:
		seed(semilla * 43 + i * 31)
		var x := _centro_familia(x_min, ancho, rc, i)
		_dibujar_roca(x, base_techo + randf_range(10.0, 40.0), randf_range(70.0, 130.0), randf_range(70.0, 120.0), randf_range(0.5, 0.8))
		_dibujar_roca(x + randf_range(40.0, 90.0), base_techo + randf_range(8.0, 30.0), randf_range(40.0, 80.0), randf_range(40.0, 70.0), randf_range(0.35, 0.55))


func _dibujar_pilares(x_min: float, x_max: float, ancho: float) -> void:
	# Columnas de piedra macizas que suben desde el fondo (y_base): base
	# ensanchada, fuste cónico, capitel escalonado y losa superior. Cada una
	# se dibuja como polígonos convexos separados (triangulación segura) con
	# luz de borde a la izquierda y sombra a la derecha.
	var n := maxi(3, roundi(ancho / 700.0))
	for i in n:
		seed(semilla * 11 + i * 17)
		var x := _centro_familia(x_min, ancho, n, i)
		var base_w := randf_range(320.0, 460.0)
		var h := randf_range(2200.0, 4400.0) * densidad
		_dibujar_pilar(x, base_w, h)
		# Guijarros en la base de cada columna: unión con el piso.
		if randf() < 0.7:
			_dibujar_roca(x + randf_range(-base_w * 0.7, base_w * 0.7), y_base + randf_range(-6.0, 10.0), randf_range(70.0, 140.0), randf_range(50.0, 100.0), randf_range(0.45, 0.75))


func _dibujar_estalagmitas(x_min: float, x_max: float, ancho: float) -> void:
	# Hilera TRASERA (profundidad): estalagmitas bajas, tenues y más juntas,
	# definen un segundo plano del piso del lago.
	var n_tr := maxi(3, roundi(ancho / 480.0))
	for i in n_tr:
		seed(semilla * 61 + i * 17)
		var x := _centro_familia(x_min, ancho, n_tr, i)
		var h_tr := randf_range(90.0, 200.0) * densidad
		_dibujar_estalagmita_at(x, randf_range(30.0, 55.0), h_tr, y_base, randf_range(0.28, 0.42))
	# Hilera PRINCIPAL del piso (la orilla del lago): familias densas, pico
	# central más alto. Todas ancladas al piso, ninguna flotando.
	var n := maxi(3, roundi(ancho / 480.0))
	for i in n:
		seed(semilla * 23 + i * 29)
		var cx := _centro_familia(x_min, ancho, n, i)
		var n_pic := randi_range(3, 5)
		for p in n_pic:
			var off := (p - (n_pic - 1) * 0.5) * randf_range(45.0, 80.0)
			var centro: bool = p == floor(n_pic * 0.5)
			var h := randf_range(170.0, 330.0) * densidad
			var bw := randf_range(50.0, 85.0)
			if centro:
				h = randf_range(360.0, 560.0) * densidad
				bw = randf_range(65.0, 105.0)
			_dibujar_estalagmita_at(cx + off, bw, h, y_base)
	# Rocas y guijarros sueltos en la orilla + piedras grandes del fondo.
	var rc := maxi(3, roundi(ancho / 520.0))
	for i in rc:
		seed(semilla * 73 + i * 41)
		var x := _centro_familia(x_min, ancho, rc, i)
		_dibujar_roca(x, y_base + randf_range(4.0, 16.0), randf_range(60.0, 120.0), randf_range(55.0, 100.0), randf_range(0.5, 0.85))
	# Rocas altas tipo "pilares rotos" del fondo, con luz de borde.
	var pr := maxi(2, roundi(ancho / 900.0))
	for i in pr:
		seed(semilla * 83 + i * 53)
		var x := _centro_familia(x_min, ancho, pr, i)
		var pr_h := randf_range(400.0, 800.0) * densidad
		_dibujar_falla_at(x, y_base - pr_h, pr_h * 0.35, 0.3)
		_dibujar_roca(x, y_base, randf_range(90.0, 150.0), pr_h, randf_range(0.7, 0.95))


func _dibujar_agua(x_min: float, x_max: float, ancho: float) -> void:
	# Lago inferior de la caverna: cubre desde su y_base hasta el fondo (+900).
	draw_rect(Rect2(x_min, y_base, ancho, y_fondo + 900.0 - y_base), color_a)
	# Orilla: banda clara bajo la línea del agua, luego ondas.
	draw_rect(Rect2(x_min, y_base, ancho, 8.0), Color(color_b.r, color_b.g, color_b.b, 0.6))
	# Ondas de la superficie: 3 líneas bien separadas, con reflejo brillante.
	for k in 3:
		seed(semilla * 31 + k)
		var yy := y_base + 40.0 + float(k) * randf_range(70.0, 140.0)
		var alfa: float = 0.5 if k == 0 else 0.28
		draw_polyline(_onda(x_min, x_max, yy, semilla + k * 2.1), Color(color_b.r, color_b.g, color_b.b, alfa), 3.0)
	# Reflejos verticales muy tenues hacia abajo, más altos en el lago grande.
	for i in 12:
		seed(semilla * 53 + i)
		var x := x_min + randf_range(160.0, ancho - 160.0)
		var xy := randf_range(80.0, 400.0)
		draw_rect(Rect2(x, y_base + 14.0 + randf_range(-4.0, 4.0), 2.0, xy), Color(color_b.r, color_b.g, color_b.b, 0.12))


## Relleno vertical degradado (noche de cueva) para el fondo.
func _dibujar_franja(x_min: float, x_max: float, top: float, bot: float, claro: Color, oscuro: Color) -> void:
	var ancho := x_max - x_min
	var n := 24
	for i in n:
		var t := float(i) / float(n - 1)
		var c := claro.lerp(oscuro, t)
		var y0 := top + (bot - top) * t
		var y1 := top + (bot - top) * (i + 1) / float(n - 1)
		draw_rect(Rect2(x_min, y0, ancho, y1 - y0), c)


## Línea horizontal ondulada tenue: estrato de roca de la pared.
func _estrato(x_min: float, x_max: float, y: float, alfa: float) -> void:
	seed(int(y))
	var pts := PackedVector2Array()
	var paso := 140
	for x in range(int(floor(x_min)), int(ceil(x_max)), paso):
		pts.append(Vector2(x, y + sin(x * 0.004 + y * 0.01) * 4.0 + randf_range(-3.0, 3.0)))
	draw_polyline(pts, Color(color_a.lightened(0.22).r, color_a.lightened(0.22).g, color_a.lightened(0.22).b, alfa), 1.5)


## Grieta vertical fina y alargada que arranca en la posición dada. `largo` es
## cuánto baja desde `org_y`. Independiente del techo: se coloca en la rejilla.
func _dibujar_falla_at(x: float, org_y: float, largo: float, alfa: float) -> void:
	var izq := PackedVector2Array()
	var der := PackedVector2Array()
	var y := org_y
	var y_max := org_y + largo
	while y < y_max:
		var w := randf_range(5.0, 18.0)
		izq.append(Vector2(x - w, y))
		der.append(Vector2(x + w, y))
		y += largo / randf_range(10.0, 16.0)
	var pts := PackedVector2Array()
	pts.append_array(izq)
	for i in range(der.size() - 1, -1, -1):
		pts.append(der[i])
	draw_colored_polygon(pts, Color(color_a.r, color_a.g, color_a.b, alfa))


func _dibujar_cristal(x: float, y: float, s: float, alfa: float) -> void:
	var pts := PackedVector2Array([
		Vector2(x, y - s * 1.4), Vector2(x + s * 0.55, y),
		Vector2(x, y + s * 1.4), Vector2(x - s * 0.55, y),
	])
	draw_colored_polygon(pts, Color(color_b.r, color_b.g, color_b.b, alfa))
	draw_polyline(PackedVector2Array([Vector2(x, y - s * 1.4), Vector2(x, y + s * 1.4)]), Color(color_b.r, color_b.g, color_b.b, alfa + 0.1), 1.0)


## Estalactita clásica: ancha en la unión con la masa del techo, perfil que se
## estrecha y termina en punta. `base_y` es la cara inferior de la masa.
func _dibujar_estalactita(x: float, base_w: float, h: float, base_y: float, alfa: float = 1.0) -> void:
	var j := randf_range(-base_w * 0.1, base_w * 0.1)
	var col := Color(color_b.r, color_b.g, color_b.b, alfa)
	draw_colored_polygon(PackedVector2Array([
		Vector2(x - base_w * 0.5, base_y), Vector2(x - base_w * 0.4 + j * 0.4, base_y + h * 0.28),
		Vector2(x - base_w * 0.28, base_y + h * 0.55), Vector2(x - base_w * 0.14, base_y + h * 0.8),
		Vector2(x, base_y + h),
		Vector2(x + base_w * 0.14, base_y + h * 0.8), Vector2(x + base_w * 0.28, base_y + h * 0.55),
		Vector2(x + base_w * 0.4 + j, base_y + h * 0.28), Vector2(x + base_w * 0.5, base_y)]), col)
	# Vena central + luz de borde en la punta (rim light inferior).
	draw_polyline(PackedVector2Array([
		Vector2(x, base_y + h * 0.15), Vector2(x - base_w * 0.05, base_y + h * 0.6), Vector2(x, base_y + h * 0.92)]),
		Color(color_b.lightened(0.22).r, color_b.lightened(0.22).g, color_b.lightened(0.22).b, alfa * 0.3), 1.0)
	draw_polyline(PackedVector2Array([
		Vector2(x - base_w * 0.4, base_y + h * 0.35), Vector2(x, base_y + h),
		Vector2(x + base_w * 0.4, base_y + h * 0.35)]),
		Color(color_b.lightened(0.18).r, color_b.lightened(0.18).g, color_b.lightened(0.18).b, alfa * 0.35), 1.5)


## Estalagmita clásica: crece desde el piso, ancha en la base y apuntada arriba.
func _dibujar_estalagmita_at(x: float, base: float, h: float, piso_y: float, alfa: float = 1.0) -> void:
	var col := Color(color_b.r, color_b.g, color_b.b, alfa)
	draw_colored_polygon(PackedVector2Array([
		Vector2(x - base * 0.5, piso_y), Vector2(x - base * 0.34, piso_y - h * 0.35),
		Vector2(x - base * 0.14, piso_y - h * 0.7), Vector2(x, piso_y - h),
		Vector2(x + base * 0.14, piso_y - h * 0.7), Vector2(x + base * 0.34, piso_y - h * 0.35),
		Vector2(x + base * 0.5, piso_y)]), col)
	# Luz de borde en la punta (rim light superior).
	draw_polyline(PackedVector2Array([
		Vector2(x - base * 0.3, piso_y - h * 0.4), Vector2(x, piso_y - h),
		Vector2(x + base * 0.3, piso_y - h * 0.4)]), Color(color_b.lightened(0.18).r, color_b.lightened(0.18).g, color_b.lightened(0.18).b, alfa * 0.35), 1.5)


## Roca/guijarro suelto: media-elipse convexa (segura), base plana. s = ancho,
## h = alto. Con alfa bajo equivale a una piedra lejana (profundidad).
func _dibujar_roca(x: float, y: float, s: float, h: float, alfa: float, claro: bool = false) -> void:
	var col := Color(color_a.lightened(0.15).r, color_a.lightened(0.15).g, color_a.lightened(0.15).b, alfa) if claro else Color(color_a.r, color_a.g, color_a.b, alfa)
	var pts := PackedVector2Array()
	for k in 7:
		var a := PI + PI * float(k) / 6.0
		pts.append(Vector2(x + cos(a) * s, y - sin(a) * h))
	draw_colored_polygon(pts, col)
	# Luz de borde en la cara superior de la piedra.
	draw_polyline(PackedVector2Array([
		Vector2(x - s * 0.6, y - h * 0.6), Vector2(x - s * 0.2, y - h * 0.95),
		Vector2(x + s * 0.3, y - h * 0.75), Vector2(x + s * 0.6, y - h * 0.2)]),
		Color(color_a.lightened(0.4).r, color_a.lightened(0.4).g, color_a.lightened(0.4).b, alfa * 0.5), 1.5)


## Columna de piedra completa: base, fuste con luz/sombra, capitel y losa.
func _dibujar_pilar(x: float, base_w: float, h: float) -> void:
	var fuste_w := base_w * randf_range(0.5, 0.62)
	var base_h := randf_range(90.0, 150.0)
	var cap_h := randf_range(70.0, 110.0)
	var y_ba := y_base
	var y_bt := y_base - base_h
	var y_cap := y_base - h                       # cara superior del capitel
	var y_cap_inf := y_cap + cap_h * 0.5          # entra de los dos escalones
	var y_fust_t := y_cap_inf + cap_h * 0.5       # tope del fuste
	var fust_t_w := fuste_w * 0.94
	var pil_color := color_a
	# Base ensanchada.
	draw_colored_polygon(PackedVector2Array([
		Vector2(x - base_w * 0.5, y_ba), Vector2(x - fuste_w * 0.5, y_bt),
		Vector2(x + fuste_w * 0.5, y_bt), Vector2(x + base_w * 0.5, y_ba)]), pil_color)
	# Fuste cónico.
	draw_colored_polygon(PackedVector2Array([
		Vector2(x - fuste_w * 0.5, y_bt), Vector2(x - fust_t_w * 0.5, y_fust_t),
		Vector2(x + fust_t_w * 0.5, y_fust_t), Vector2(x + fuste_w * 0.5, y_bt)]), pil_color)
	# Capitel: dos escalones horizontales.
	var cap_w1 := fuste_w * 1.5
	var cap_w2 := fuste_w * 1.05
	draw_rect(Rect2(x - cap_w1 * 0.5, y_cap_inf, cap_w1, cap_h * 0.5), pil_color)
	draw_rect(Rect2(x - cap_w2 * 0.5, y_cap, cap_w2, cap_h * 0.5), pil_color)
	# Losa superior (protección/cornisa).
	var losa_h := randf_range(16.0, 28.0)
	draw_rect(Rect2(x - fuste_w * 0.62, y_cap - losa_h, fuste_w * 1.24, losa_h), pil_color.lightened(0.12))
	# Luz de borde en el lateral izquierdo (luz desde arriba/izquierda).
	var edge := maxf(5.0, fuste_w * 0.035)
	draw_colored_polygon(PackedVector2Array([
		Vector2(x - fuste_w * 0.5, y_bt), Vector2(x - fuste_w * 0.5 + edge, y_bt),
		Vector2(x - fust_t_w * 0.5 + edge * 0.8, y_fust_t), Vector2(x - fust_t_w * 0.5, y_fust_t)]),
		Color(pil_color.lightened(0.5).r, pil_color.lightened(0.5).g, pil_color.lightened(0.5).b, 0.9))
	# Sombra de la bóveda en el lateral derecho del capitel.
	draw_rect(Rect2(x + cap_w1 * 0.5 - 10.0, y_cap_inf, 10.0, cap_h * 0.5), pil_color.darkened(0.35))
	# Grietas finas en el fuste.
	seed(int(x) * 7 + int(y_ba) * 3)
	for g in randi_range(1, 2):
		var gy := y_bt - h * randf_range(0.15, 0.7)
		_dibujar_falla_at(x + randf_range(-fuste_w * 0.2, fuste_w * 0.2), gy, h * 0.18, 0.18)


func _onda(x_min: float, x_max: float, yy: float, fase: float) -> PackedVector2Array:
	var pts := PackedVector2Array()
	var paso := 90
	var ini := int(floor(x_min))
	for x in range(ini, int(ceil(x_max)), paso):
		pts.append(Vector2(x, yy + sin(x * 0.006 + fase) * 6.0))
	return pts


## Arco de elipse superior (bóveda de caverna lejana).
func _arco_elipse(centro: Vector2, radios: Vector2, n: int) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in n:
		var a := PI + PI * float(i) / float(n - 1)
		pts.append(Vector2(centro.x + cos(a) * radios.x, centro.y + sin(a) * radios.y))
	return pts


func _elipse(centro: Vector2, radios: Vector2, n: int) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in n:
		var a := TAU * float(i) / float(n)
		pts.append(Vector2(centro.x + cos(a) * radios.x, centro.y + sin(a) * radios.y))
	return pts