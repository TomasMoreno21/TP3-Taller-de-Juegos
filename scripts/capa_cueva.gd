@tool
extends ParallaxLayer
## Capa de fondo de CUEVA vectorial con estética de cueva profunda:
## oscuridad que crece hacia abajo, luz cenital desde la entrada y niebla
## atmosférica entre planos. Estilo "menos pero más grande": pocos elementos
## bien leíbles (estalactitas del techo, columnas masivas, estalagmitas del
## piso) anclados a superficies reales, sin ruido de guijarros aleatorios.
## Cada capa dibuja de forma CONTINUA en ancho_total/centro_x y alto
## (y_techo..y_fondo). Configurable desde el Inspector.

@export_enum("sombra", "pared", "secta", "estalactitas", "pilares", "estalagmitas", "agua") var tipo := "sombra":
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
## Fracción superior (0-1) del alto que entra en fundido desde transparente: sirve
## para que el techo de la cueva no corte en seco sobre un fondo exterior.
@export_range(0.0, 0.5) var fundido_superior := 0.0:
	set(value):
		fundido_superior = value
		queue_redraw()
@export var y_techo := -1500.0:
	set(value):
		y_techo = value
		queue_redraw()
## Fondo (abajo) de la caverna, límite inferior de la cámara en nivel vertical.
@export var y_fondo := 7600.0:
	set(value):
		y_fondo = value
		queue_redraw()
## Color de la niebla atmosférica que se dibuja entre los planos.
@export var color_niebla := Color(0.36, 0.44, 0.58):
	set(value):
		color_niebla = value
		queue_redraw()
## Color de acento de la secta (sigilos, resplandor de nichos) y de sus fuegos.
@export var color_acento := Color(0.6, 0.22, 0.75):
	set(value):
		color_acento = value
		queue_redraw()
@export var color_fuego := Color(1.0, 0.55, 0.2):
	set(value):
		color_fuego = value
		queue_redraw()
## Cuánta niebla atmosférica se dibuja en esta capa (0 = ninguna).
@export_range(0.0, 1.0, 0.05) var niebla := 0.18:
	set(value):
		niebla = clampf(value, 0.0, 1.0)
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
		"secta":
			_dibujar_secta(x_min, x_max, ancho)
		"estalactitas":
			_dibujar_estalactitas(x_min, x_max, ancho)
		"pilares":
			_dibujar_pilares(x_min, x_max, ancho)
		"estalagmitas":
			_dibujar_estalagmitas(x_min, x_max, ancho)
		"agua":
			_dibujar_agua(x_min, x_max, ancho)
	# El dibujo fija el RNG global con semillas fijas (para que la cueva sea siempre igual):
	# se re-aleatoriza al terminar, si no todo el azar del juego (IA, luciérnagas, partículas) sería idéntico en cada partida.
	randomize()


## Posición x del centro de una familia, repartida uniformemente con jitter.
func _centro_familia(x_min: float, ancho: float, n: int, i: int) -> float:
	return x_min + (i + randf_range(0.2, 0.8)) * (ancho / float(n))


## Punto de una celda en rejilla horizontal × vertical (columnas × filas).
func _punto_rejilla(x_min: float, ancho: float, cols: int, ic: int, y_top: float, alto: float, filas: int, ifi: int) -> Vector2:
	return Vector2(
		x_min + (ic + randf_range(0.2, 0.8)) * ancho / float(cols),
		y_top + (ifi + randf_range(0.2, 0.8)) * alto / float(filas))


func _dibujar_sombra(x_min: float, x_max: float, ancho: float) -> void:
	var alto := y_fondo - y_techo
	# Fondo del abismo: el degradado se oscurece hacia abajo (la luz entra
	# por arriba). Abajo, ya en plena oscuridad de la cueva profunda.
	_dibujar_franja(x_min, x_max, y_techo, y_fondo + 900.0, color_a, color_b)
	# Luz cenital: halo amplio en la parte superior del abismo que se desvanece
	# hacia abajo, como la luz de la entrada que apenas llega hasta el fondo.
	var cx_luz := centro_x
	for k in 4:
		var w := 320.0 * (1.0 + k * 0.9)
		var top := y_techo - 60.0
		var h_luz := alto * (0.62 - k * 0.1)
		draw_rect(Rect2(cx_luz - w * 0.5, top, w, h_luz),
			Color(0.55, 0.68, 0.85, 0.03 + k * 0.011))
	# Bóvedas del fondo: siluetas amplias y muy tenues (plano más lejano).
	# Pocas (ancho desplazado) para no ensuciar: cada 3600 px.
	var bc := maxi(2, roundi(ancho / 3600.0))
	var bf := 2
	for i in bc:
		for j in bf:
			seed(semilla * 41 + i * 5 + j * 7)
			var p := _punto_rejilla(x_min, ancho, bc, i, y_techo + 400.0, alto - 800.0, bf, j)
			var rw := randf_range(520.0, 900.0)
			var rh := randf_range(300.0, 520.0)
			draw_colored_polygon(_arco_elipse(p, Vector2(rw, rh), 12),
				Color(color_a.r, color_a.g, color_a.b, randf_range(0.16, 0.26)))
	# Niebla lejana: bandas amplias que funden el fondo del abismo.
	_dibujar_capa_niebla(x_min, x_max, alto, 4, 0.55)


func _dibujar_pared(x_min: float, x_max: float, ancho: float) -> void:
	var alto := y_fondo - y_techo
	_dibujar_franja(x_min, x_max, y_techo, y_fondo, color_a, color_a.darkened(0.45))
	# Estratos de roca: bandas horizontales onduladas, espejo de la geología
	# de la caverna. Espaciados y constantes, sin ruido.
	var sc := 4
	var sf := maxi(2, roundi(alto / 1000.0))
	for i in sc:
		for j in sf:
			seed(semilla * 17 + i * 11 + j * 13)
			var p := _punto_rejilla(x_min, ancho, sc, i + 1, y_techo + 300.0, alto - 500.0, sf, j)
			_estrato(x_min, x_max, p.y, randf_range(0.1, 0.18))
	# Relieve de la roca: manchas grandes y suaves, más claras y más oscuras, que
	# rompen la pared lisa (sin bordes marcados: alfa muy bajo).
	var rc := maxi(3, roundi(ancho / 1100.0))
	var rf := maxi(3, roundi(alto / 900.0))
	for i in rc:
		for j in rf:
			seed(semilla * 97 + i * 19 + j * 23)
			var c := _punto_rejilla(x_min, ancho, rc, i, y_techo + 200.0, alto - 400.0, rf, j)
			var rx := randf_range(320.0, 640.0)
			var ry := randf_range(200.0, 400.0)
			var clara_m := randf() < 0.45
			var base_m := color_a.lightened(0.35) if clara_m else color_a.darkened(0.5)
			var pts_m := PackedVector2Array()
			for k in 10:
				var ang := TAU * float(k) / 10.0
				var rr := randf_range(0.7, 1.0)
				pts_m.append(c + Vector2(cos(ang) * rx * rr, sin(ang) * ry * rr))
			draw_colored_polygon(pts_m, Color(base_m.r, base_m.g, base_m.b, randf_range(0.05, 0.1)))
	# Bandas de estrato claras (capas de roca distinta) sobre las líneas de estrato.
	var nb := maxi(3, roundi(alto / 850.0))
	for j in nb:
		seed(semilla * 131 + j * 29)
		var yb := y_techo + 500.0 + (float(j) + randf_range(0.1, 0.9)) * (alto - 900.0) / float(nb)
		var grosor := randf_range(50.0, 120.0)
		var arriba := PackedVector2Array()
		var abajo := PackedVector2Array()
		var xb := int(floor(x_min))
		while xb <= int(ceil(x_max)):
			var off := sin(float(xb) * 0.0021 + float(j) * 1.7) * 26.0
			arriba.append(Vector2(xb, yb + off))
			abajo.append(Vector2(xb, yb + off + grosor + sin(float(xb) * 0.0035 + float(j)) * 14.0))
			xb += 200
		abajo.reverse()
		arriba.append_array(abajo)
		var cb := color_a.lightened(0.28)
		draw_colored_polygon(arriba, Color(cb.r, cb.g, cb.b, randf_range(0.05, 0.085)))
	# Vetas de humedad: chorreados oscuros que bajan desde un estrato, con un brillo fino.
	var nh := maxi(6, roundi(ancho / 800.0))
	for i in nh:
		seed(semilla * 151 + i * 43)
		var hx := x_min + randf() * ancho
		var hy := y_techo + randf_range(500.0, alto - 1200.0)
		var hl := randf_range(320.0, 900.0)
		var hw := randf_range(8.0, 20.0)
		var cs := color_a.darkened(0.6)
		draw_polygon(PackedVector2Array([Vector2(hx - hw, hy), Vector2(hx + hw, hy), Vector2(hx + hw * 0.3, hy + hl), Vector2(hx - hw * 0.3, hy + hl)]),
			PackedColorArray([Color(cs.r, cs.g, cs.b, 0.16), Color(cs.r, cs.g, cs.b, 0.16), Color(cs.r, cs.g, cs.b, 0.0), Color(cs.r, cs.g, cs.b, 0.0)]))
		draw_line(Vector2(hx + hw * 0.55, hy + 8.0), Vector2(hx + hw * 0.2, hy + hl * 0.7), Color(0.7, 0.8, 0.95, 0.05), 2.0)
	# Pocas grietas grandes y verticales, colocadas con sentido geológico
	# (arrancan de un estrato y bajan). No forman rejilla tupida.
	var n_gri := maxi(2, roundi(ancho / 2200.0))
	for i in n_gri:
		seed(semilla * 3 + i * 101)
		var x := _centro_familia(x_min, ancho, n_gri, i)
		var y0 := y_techo + randf_range(400.0, 2400.0)
		_dibujar_falla_at(x, y0, randf_range(1000.0, 1800.0), randf_range(0.14, 0.22))
	# Haces de luz tenues que entran por grietas del techo (oblicuos, se apagan hacia abajo).
	var n_luz := maxi(2, roundi(ancho / 3800.0))
	for i in n_luz:
		seed(semilla * 61 + i * 37)
		var lx := _centro_familia(x_min, ancho, n_luz, i)
		var ly := y_techo + randf_range(500.0, alto * 0.55)
		var lw := randf_range(150.0, 280.0)
		var largo := randf_range(1300.0, 2100.0)
		var sesgo := randf_range(200.0, 380.0)
		# Tres capas anidadas (ancha tenue → estrecha más clara): borde suave, sin filo duro.
		for capa in 3:
			var f := 1.0 - 0.33 * float(capa)
			var c_luz := Color(0.72, 0.82, 0.95, 0.03 + 0.012 * float(capa))
			var c_luz0 := Color(c_luz.r, c_luz.g, c_luz.b, 0.0)
			draw_polygon(PackedVector2Array([Vector2(lx - lw * 0.5 * f, ly), Vector2(lx + lw * 0.5 * f, ly),
				Vector2(lx + lw * 0.9 * f + sesgo, ly + largo), Vector2(lx - lw * 0.9 * f + sesgo, ly + largo)]),
				PackedColorArray([c_luz, c_luz, c_luz0, c_luz0]))
		# Motas de polvo que flotan dentro del haz.
		for m in 14:
			var t := randf()
			var mp := Vector2(lx + lerpf(-lw * 0.4, lw * 0.4, randf()) + sesgo * t, ly + largo * t * 0.85)
			draw_circle(mp, randf_range(1.6, 3.6), Color(0.85, 0.92, 1.0, randf_range(0.10, 0.22) * (1.0 - t)))
	# Niebla media: corta la roca a la altura del descenso, dando profundidad.
	_dibujar_capa_niebla(x_min, x_max, alto, 3, 0.7)


func _dibujar_estalactitas(x_min: float, x_max: float, ancho: float) -> void:
	var techo_h := 520.0
	var base_techo := y_techo + techo_h
	# Masa del techo con borde inferior iluminado por la luz de la entrada.
	if fundido_superior > 0.0:
		# Sin corte seco arriba: la masa entra en fundido desde transparente.
		var tiras := 24
		for k in tiras:
			var ck := color_a
			ck.a *= smoothstep(0.0, 1.0, float(k) / float(tiras - 1))
			draw_rect(Rect2(x_min, y_techo + techo_h * k / float(tiras), ancho, techo_h / float(tiras) + 1.0), ck)
	else:
		draw_rect(Rect2(x_min, y_techo, ancho, techo_h), color_a)
	draw_polyline(PackedVector2Array([
		Vector2(x_min, base_techo), Vector2(x_max, base_techo)]),
		Color(color_a.lightened(0.5).r, color_a.lightened(0.5).g, color_a.lightened(0.5).b, 0.5), 3.0)
	# Plano trasero del techo (lejano): estalactitas cortas y muy tenues,
	# separadas. Apenas sugieren un segundo plano.
	var n_tr := maxi(2, roundi(ancho / 2400.0))
	for i in n_tr:
		seed(semilla * 37 + i * 23)
		var x := _centro_familia(x_min, ancho, n_tr, i)
		_dibujar_estalactita(x, randf_range(36.0, 60.0), randf_range(180.0, 400.0) * densidad, base_techo, 0.32)
	# Plano principal: familias de estalactitas GRANDES y leíbles, bien
	# separadas entre sí (una familia cada ~1500 px), la central más larga.
	var n := maxi(2, roundi(ancho / 1500.0))
	for i in n:
		seed(semilla * 7 + i * 13)
		var cx := _centro_familia(x_min, ancho, n, i)
		var n_est := randi_range(3, 5)
		for e in n_est:
			var off := (e - (n_est - 1) * 0.5) * randf_range(70.0, 110.0)
			var centro: bool = e == floor(n_est * 0.5)
			var h := randf_range(260.0, 480.0) * densidad
			if centro:
				h = randf_range(620.0, 950.0) * densidad
			_dibujar_estalactita(cx + off, randf_range(60.0, 110.0), h, base_techo)
	# Hebras muy largas (columnatas colgantes): pocas, atraviesan la niebla y
	# guían la mirada hacia el fondo. Cada ~2600 px de ancho.
	var nc := maxi(2, roundi(ancho / 2600.0))
	for i in nc:
		seed(semilla * 29 + i * 19)
		var x := _centro_familia(x_min, ancho, nc, i)
		var h := randf_range(1400.0, 2200.0) * densidad
		_dibujar_estalactita(x, randf_range(34.0, 52.0), h, base_techo)


func _dibujar_pilares(x_min: float, x_max: float, ancho: float) -> void:
	# Columnas masivas: pocas (cada ~1800 px) pero imponentes. Trazan la
	# escala de la cueva profunda y unen piso con la niebla superior.
	var n := maxi(2, roundi(ancho / 1800.0))
	for i in n:
		seed(semilla * 11 + i * 17)
		var x := _centro_familia(x_min, ancho, n, i)
		var base_w := randf_range(380.0, 520.0)
		var h := randf_range(3200.0, 4800.0) * densidad
		_dibujar_pilar(x, base_w, h)
	# Guijarros grandes junto a la base (unión piso-columna), pocos.
	var rc := maxi(2, roundi(ancho / 2600.0))
	for i in rc:
		seed(semilla * 73 + i * 41)
		var x := _centro_familia(x_min, ancho, rc, i)
		_dibujar_roca(x, y_base + randf_range(4.0, 14.0), randf_range(120.0, 190.0), randf_range(90.0, 140.0), randf_range(0.6, 0.9))
	# Niebla frente a las columnas: corta los fustes y refuerza la profundidad.
	_dibujar_capa_niebla(x_min, x_max, y_fondo - y_techo, 3, 1.0)


func _dibujar_estalagmitas(x_min: float, x_max: float, ancho: float) -> void:
	# Familias grandes del piso del lago, bien separadas (cada ~1600 px).
	# La punta central es la más alta; contrastan con la niebla y el agua.
	var n := maxi(2, roundi(ancho / 1600.0))
	for i in n:
		seed(semilla * 23 + i * 29)
		var cx := _centro_familia(x_min, ancho, n, i)
		var n_pic := randi_range(3, 5)
		for p in n_pic:
			var off := (p - (n_pic - 1) * 0.5) * randf_range(70.0, 110.0)
			var centro: bool = p == floor(n_pic * 0.5)
			var h := randf_range(220.0, 380.0) * densidad
			var bw := randf_range(60.0, 95.0)
			if centro:
				h = randf_range(500.0, 760.0) * densidad
				bw = randf_range(85.0, 125.0)
			_dibujar_estalagmita_at(cx + off, bw, h, y_base)
	# Rocas bajas de la orilla muy espaciadas (contrapeso horizontal).
	var rc := maxi(2, roundi(ancho / 3000.0))
	for i in rc:
		seed(semilla * 83 + i * 53)
		var x := _centro_familia(x_min, ancho, rc, i)
		_dibujar_roca(x, y_base + randf_range(6.0, 16.0), randf_range(140.0, 220.0), randf_range(80.0, 120.0), randf_range(0.5, 0.75))


func _dibujar_agua(x_min: float, x_max: float, ancho: float) -> void:
	# Lago inferior: cubre desde su y_base hasta el fondo (+900).
	draw_rect(Rect2(x_min, y_base, ancho, y_fondo + 900.0 - y_base), color_a)
	# Línea de la orilla iluminada por la luz cenital.
	draw_rect(Rect2(x_min, y_base, ancho, 6.0), Color(color_b.r, color_b.g, color_b.b, 0.5))
	# Ondas: 3 líneas simples, con reflejo brillante en la primera.
	for k in 3:
		seed(semilla * 31 + k)
		var yy := y_base + 40.0 + float(k) * randf_range(80.0, 150.0)
		var alfa: float = 0.5 if k == 0 else 0.24
		draw_polyline(_onda(x_min, x_max, yy, semilla + k * 2.1), Color(color_b.r, color_b.g, color_b.b, alfa), 3.0)
	# Reflejos tenues del fondo sobre el agua.
	for i in 8:
		seed(semilla * 53 + i)
		var x := x_min + randf_range(160.0, ancho - 160.0)
		var xy := randf_range(80.0, 400.0)
		draw_rect(Rect2(x, y_base + 14.0 + randf_range(-4.0, 4.0), 2.0, xy), Color(color_b.r, color_b.g, color_b.b, 0.12))


## Capa de la SECTA: nichos tallados con estatuas encapuchadas, sigilos pintados en la
## pared y candelabros lejanos. Pocos elementos grandes en rejilla, con huecos.
func _dibujar_secta(x_min: float, x_max: float, ancho: float) -> void:
	var alto := y_fondo - y_techo
	var cols := maxi(3, roundi(ancho / (2500.0 / densidad)))
	var filas := maxi(3, roundi(alto / 1250.0))
	for i in cols:
		for j in filas:
			seed(semilla * 131 + i * 17 + j * 29)
			if randf() < 0.22:
				continue
			var p := _punto_rejilla(x_min, ancho, cols, i, y_techo + 900.0, alto - 1800.0, filas, j)
			var k := randf()
			if k < 0.46:
				_dibujar_nicho(p.x, p.y + 380.0, randf_range(340.0, 500.0), randf_range(760.0, 960.0), randf() < 0.75)
			elif k < 0.76:
				_dibujar_sigilo(p, randf_range(260.0, 400.0))
			else:
				_dibujar_candelabros(p)
	_dibujar_capa_niebla(x_min, x_max, alto, 2, 0.5)


## Punto de luz cálida con halo suave (candelabro / vela lejana).
func _luz_calida(p: Vector2, r: float, fuerza: float = 1.0) -> void:
	for k in 4:
		var rr := r * (1.0 + float(k) * 1.5)
		draw_circle(p, rr, Color(color_fuego.r, color_fuego.g, color_fuego.b, (0.075 - 0.014 * float(k)) * fuerza))
	draw_circle(p, r * 0.55, Color(1.0, 0.9, 0.55, 0.9 * fuerza))


func _dibujar_candelabros(p: Vector2) -> void:
	for s in [-1.0, 1.0]:
		var q := Vector2(p.x + s * randf_range(150.0, 260.0), p.y + randf_range(-40.0, 40.0))
		draw_rect(Rect2(q.x - 3.0, q.y, 6.0, 46.0), color_a.darkened(0.5))
		draw_rect(Rect2(q.x - 9.0, q.y - 2.0, 18.0, 5.0), color_a.darkened(0.3))
		_luz_calida(q + Vector2(0, -12.0), 9.0)


## Sigilo pintado en la pared: anillos, triángulo y ojo, en el color de acento.
func _dibujar_sigilo(c: Vector2, r: float) -> void:
	var a := Color(color_acento.r, color_acento.g, color_acento.b, 0.3)
	for k in 3:
		draw_circle(c, r * (1.25 - 0.18 * float(k)), Color(color_acento.r, color_acento.g, color_acento.b, 0.035))
	draw_polyline(_circulo(c, r, 40), a, 5.0)
	draw_polyline(_circulo(c, r * 0.82, 40), Color(a.r, a.g, a.b, 0.18), 3.0)
	for i in 20:
		var ang := TAU * float(i) / 20.0
		draw_line(c + Vector2.from_angle(ang) * r * 0.82, c + Vector2.from_angle(ang) * r, Color(a.r, a.g, a.b, 0.24), 3.0)
	var tri := PackedVector2Array()
	for i in 4:
		tri.append(c + Vector2.from_angle(-PI * 0.5 + TAU * float(i % 3) / 3.0) * r * 0.62)
	draw_polyline(tri, Color(a.r, a.g, a.b, 0.26), 4.0)
	draw_polyline(_elipse(c + Vector2(0, r * 0.06), Vector2(r * 0.2, r * 0.1), 20) + PackedVector2Array([c + Vector2(r * 0.2, r * 0.06)]), Color(a.r, a.g, a.b, 0.32), 4.0)
	draw_circle(c + Vector2(0, r * 0.06), r * 0.055, Color(1.0, 0.4, 0.55, 0.32))


func _circulo(c: Vector2, r: float, n: int) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in n + 1:
		pts.append(c + Vector2.from_angle(TAU * float(i) / float(n)) * r)
	return pts


## Arco de medio punto: base plana en y=base, lados rectos hasta `alto - w/2`.
func _arco_nicho(cx: float, base: float, w: float, alto: float) -> PackedVector2Array:
	var pts := PackedVector2Array()
	var y_res := base - alto + w * 0.5
	pts.append(Vector2(cx - w * 0.5, base))
	for i in 15:
		var ang := PI + PI * float(i) / 14.0
		pts.append(Vector2(cx + cos(ang) * w * 0.5, y_res + sin(ang) * w * 0.62))
	pts.append(Vector2(cx + w * 0.5, base))
	return pts


func _dibujar_nicho(cx: float, base: float, w: float, alto: float, estatua: bool) -> void:
	var marco := color_b.lightened(0.12)
	draw_colored_polygon(_arco_nicho(cx, base + 18.0, w + 64.0, alto + 50.0), Color(marco.r, marco.g, marco.b, 0.7))
	draw_colored_polygon(_arco_nicho(cx, base, w, alto), color_a.darkened(0.7))
	for k in 3:
		draw_colored_polygon(_arco_nicho(cx, base, w * (0.9 - 0.22 * float(k)), alto * (0.86 - 0.2 * float(k))),
			Color(color_acento.r, color_acento.g, color_acento.b, 0.05 + 0.02 * float(k)))
	draw_rect(Rect2(cx - w * 0.5 - 60.0, base, w + 120.0, 26.0), Color(marco.r, marco.g, marco.b, 0.75))
	if estatua:
		_dibujar_estatua_fondo(cx, base - 4.0, alto * 0.62)
	for s in [-1.0, 1.0]:
		var q := Vector2(cx + s * (w * 0.5 + 52.0), base - 200.0)
		draw_rect(Rect2(q.x - 3.0, q.y, 6.0, 60.0), color_a.darkened(0.4))
		_luz_calida(q + Vector2(0, -10.0), 8.0, 0.9)


## Figura encapuchada de espaldas a la luz: capucha en punta, túnica y ojos rojos.
func _dibujar_estatua_fondo(cx: float, base: float, h: float) -> void:
	var piedra := color_b.lightened(0.05)
	var w := h * 0.36
	draw_rect(Rect2(cx - w * 0.62, base - h * 0.1, w * 1.24, h * 0.1), piedra.darkened(0.25))
	draw_colored_polygon(PackedVector2Array([
		Vector2(cx - w * 0.5, base - h * 0.1), Vector2(cx - w * 0.36, base - h * 0.56),
		Vector2(cx + w * 0.36, base - h * 0.56), Vector2(cx + w * 0.5, base - h * 0.1)]), piedra)
	draw_colored_polygon(PackedVector2Array([
		Vector2(cx - w * 0.36, base - h * 0.56), Vector2(cx - w * 0.24, base - h * 0.78),
		Vector2(cx, base - h), Vector2(cx + w * 0.24, base - h * 0.78), Vector2(cx + w * 0.36, base - h * 0.56)]), piedra.lightened(0.05))
	draw_colored_polygon(PackedVector2Array([
		Vector2(cx - w * 0.15, base - h * 0.6), Vector2(cx - w * 0.12, base - h * 0.78),
		Vector2(cx, base - h * 0.84), Vector2(cx + w * 0.12, base - h * 0.78), Vector2(cx + w * 0.15, base - h * 0.6)]), Color(0.01, 0.01, 0.02))
	for s in [-1.0, 1.0]:
		var e := Vector2(cx + s * w * 0.06, base - h * 0.7)
		draw_circle(e, 16.0, Color(1.0, 0.15, 0.25, 0.10))
		draw_circle(e, 5.0, Color(1.0, 0.25, 0.35, 0.9))
	draw_colored_polygon(PackedVector2Array([
		Vector2(cx - w * 0.5, base - h * 0.1), Vector2(cx - w * 0.44, base - h * 0.1),
		Vector2(cx - w * 0.3, base - h * 0.56), Vector2(cx - w * 0.36, base - h * 0.56)]), Color(piedra.lightened(0.3).r, piedra.lightened(0.3).g, piedra.lightened(0.3).b, 0.6))


## Relleno vertical degradado (noche de cueva) para el fondo.
func _dibujar_franja(x_min: float, x_max: float, top: float, bot: float, claro: Color, oscuro: Color) -> void:
	var ancho := x_max - x_min
	var n := 28 if fundido_superior <= 0.0 else 90
	for i in n:
		var t := float(i) / float(n - 1)
		var c := claro.lerp(oscuro, t * t)
		if fundido_superior > 0.0:
			c.a *= smoothstep(0.0, fundido_superior, t)
		var y0 := top + (bot - top) * t
		var y1 := top + (bot - top) * (i + 1) / float(n - 1)
		draw_rect(Rect2(x_min, y0, ancho, y1 - y0), c)


## Bandas de niebla atmosférica: `n_bandas` franjas onduladas horizontales
## repartidas en el alto, más densas hacia abajo (la cueva se empaña abajo).
## `opacidad` escala la fuerza de cada banda según la lejanía de la capa.
func _dibujar_capa_niebla(x_min: float, x_max: float, alto: float, n_bandas: int, opacidad: float) -> void:
	if niebla <= 0.0:
		return
	for b in n_bandas:
		seed(semilla + b * 97)
		var t := float(b + 1) / float(n_bandas + 1)
		var y := y_techo + alto * (0.25 + 0.55 * t)
		var h := randf_range(240.0, 520.0)
		var alfa := niebla * opacidad * randf_range(0.5, 1.0) * (0.5 + 0.6 * t)
		_dibujar_banda_niebla(x_min, x_max, y, h, alfa)


## Franja simple de niebla (polígono ondulado suave, debilita los planos).
func _dibujar_banda_niebla(x_min: float, x_max: float, y: float, h: float, alfa: float) -> void:
	# Degradado vertical: transparente arriba, más densa en el medio y transparente abajo
	# (sin bordes duros de rectángulo).
	var col := Color(color_niebla.r, color_niebla.g, color_niebla.b, alfa)
	var col0 := Color(col.r, col.g, col.b, 0.0)
	var paso := 260
	var x := int(floor(x_min))
	var fin := int(ceil(x_max))
	var prev := Vector2.ZERO
	var primero := true
	while x <= fin:
		var yy := y + sin(x * 0.0016 + y * 0.004) * 14.0 + randf_range(-6.0, 6.0)
		if not primero:
			draw_polygon(PackedVector2Array([prev, Vector2(x, yy), Vector2(x, yy + h * 0.5), prev + Vector2(0, h * 0.5)]),
				PackedColorArray([col0, col0, col, col]))
			draw_polygon(PackedVector2Array([prev + Vector2(0, h * 0.5), Vector2(x, yy + h * 0.5), Vector2(x, yy + h), prev + Vector2(0, h)]),
				PackedColorArray([col, col, col0, col0]))
		prev = Vector2(x, yy)
		primero = false
		x += paso


## Línea horizontal ondulada tenue: estrato de roca de la pared.
func _estrato(x_min: float, x_max: float, y: float, alfa: float) -> void:
	seed(int(y))
	var pts := PackedVector2Array()
	var paso := 160
	for x in range(int(floor(x_min)), int(ceil(x_max)), paso):
		pts.append(Vector2(x, y + sin(x * 0.004 + y * 0.01) * 4.0 + randf_range(-3.0, 3.0)))
	draw_polyline(pts, Color(color_a.lightened(0.22).r, color_a.lightened(0.22).g, color_a.lightened(0.22).b, alfa), 1.5)


## Grieta vertical fina y alargada que arranca en la posición dada. `largo` es
## cuánto baja desde `org_y`.
func _dibujar_falla_at(x: float, org_y: float, largo: float, alfa: float) -> void:
	var izq := PackedVector2Array()
	var der := PackedVector2Array()
	var y := org_y
	var y_max := org_y + largo
	while y < y_max:
		var w := randf_range(5.0, 16.0)
		izq.append(Vector2(x - w, y))
		der.append(Vector2(x + w, y))
		y += largo / randf_range(10.0, 16.0)
	var pts := PackedVector2Array()
	pts.append_array(izq)
	for i in range(der.size() - 1, -1, -1):
		pts.append(der[i])
	draw_colored_polygon(pts, Color(color_a.r, color_a.g, color_a.b, alfa))


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
	var base_h := randf_range(110.0, 170.0)
	var cap_h := randf_range(80.0, 120.0)
	var y_ba := y_base
	var y_bt := y_base - base_h
	var y_cap := y_base - h                       # cara superior del capitel
	var y_cap_inf := y_cap + cap_h * 0.5          # entra de los dos escalones
	var y_fust_t := y_cap_inf + cap_h * 0.5       # tope del fuste
	var fust_t_w := fuste_w * 0.96
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
	var losa_h := randf_range(18.0, 30.0)
	draw_rect(Rect2(x - fuste_w * 0.62, y_cap - losa_h, fuste_w * 1.24, losa_h), pil_color.lightened(0.12))
	# Luz de borde en el lateral izquierdo (luz desde arriba/izquierda).
	var edge := maxf(6.0, fuste_w * 0.04)
	draw_colored_polygon(PackedVector2Array([
		Vector2(x - fuste_w * 0.5, y_bt), Vector2(x - fuste_w * 0.5 + edge, y_bt),
		Vector2(x - fust_t_w * 0.5 + edge * 0.8, y_fust_t), Vector2(x - fust_t_w * 0.5, y_fust_t)]),
		Color(pil_color.lightened(0.5).r, pil_color.lightened(0.5).g, pil_color.lightened(0.5).b, 0.28))
	# Sombra del fondo en el lateral derecho.
	draw_rect(Rect2(x + cap_w1 * 0.5 - 10.0, y_cap_inf, 10.0, cap_h * 0.5), pil_color.darkened(0.4))
	# Grietas finas en el fuste.
	seed(int(x) * 7 + int(y_ba) * 3)
	for g in randi_range(1, 2):
		var gy := y_bt - h * randf_range(0.15, 0.7)
		_dibujar_falla_at(x + randf_range(-fuste_w * 0.2, fuste_w * 0.2), gy, h * 0.16, 0.16)


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
