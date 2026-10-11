@tool
extends Node2D
## Soporte vectorial para plataformas del bosque, para que no parezcan flotantes. Se cuelga como hijo
## de la plataforma (StaticBody2D con un Polygon2D o un CollisionShape2D rectangular) y dibuja con
## polígonos planos y luz/sombra de un solo lado, igual que el resto del arte. Sin colisión.
##   PILAR  -> la plataforma es la copa ancha de un tronco que baja hasta el piso. El tronco se abre
##             en el tope hasta el ancho de la plataforma (parece una extensión suya) y se angosta
##             hacia abajo; con desplazamiento_x la base se corre y el tronco se curva como una raíz.
##   LIANAS -> dos lianas largas en los extremos, con hojas, que suben hasta el cielo y se pierden.
## Pensado para plataformas horizontales (no rotadas). Poner z_index = -1 para que quede detrás.

enum Modo { PILAR, LIANAS }

@export var modo: Modo = Modo.PILAR:
	set(v):
		modo = v
		queue_redraw()
@export var desplazamiento_x := 0.0:  ## px que se corre la base del tronco respecto del centro (curva el tronco)
	set(v):
		desplazamiento_x = v
		queue_redraw()
@export var ancho := 64.0:  ## ancho del tronco en su parte más angosta
	set(v):
		ancho = maxf(v, 10.0)
		queue_redraw()
@export var largo := 140.0:  ## alto del tronco si no se usa suelo_y (en LIANAS: hasta dónde suben)
	set(v):
		largo = maxf(v, 20.0)
		queue_redraw()
@export var suelo_y := 0.0:  ## Y global del piso: si es > 0, el tronco llega solo hasta ahí
	set(v):
		suelo_y = v
		queue_redraw()
@export var alto_copa := 80.0:  ## px que tarda el tronco en abrirse hasta el ancho de la plataforma
	set(v):
		alto_copa = maxf(v, 10.0)
		queue_redraw()
@export var margen_lianas := 16.0:  ## distancia de las lianas al borde de la plataforma
	set(v):
		margen_lianas = v
		queue_redraw()
@export var sombra := true:  ## penumbra suave bajo la plataforma
	set(v):
		sombra = v
		queue_redraw()
@export var semilla := 1:
	set(v):
		semilla = v
		queue_redraw()
@export_group("Colores")
@export var color_corteza := Color(0.27, 0.18, 0.12):
	set(v):
		color_corteza = v
		queue_redraw()
@export var color_sombra := Color(0.17, 0.11, 0.09):
	set(v):
		color_sombra = v
		queue_redraw()
@export var color_luz := Color(0.40, 0.28, 0.18):
	set(v):
		color_luz = v
		queue_redraw()
@export var color_musgo := Color(0.20, 0.42, 0.20):
	set(v):
		color_musgo = v
		queue_redraw()
@export var color_liana := Color(0.13, 0.30, 0.16):
	set(v):
		color_liana = v
		queue_redraw()

const PASOS := 24


func _ready() -> void:
	set_notify_transform(true)
	queue_redraw()


func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSFORM_CHANGED and Engine.is_editor_hint():
		queue_redraw()


## Rectángulo de la plataforma (en coordenadas de este nodo).
func _rect() -> Rect2:
	var cuerpo := get_parent()
	if cuerpo == null:
		return Rect2(-140, -15, 280, 30)
	for c in cuerpo.get_children():
		if c is Polygon2D and (c as Polygon2D).polygon.size() >= 3:
			var mn := Vector2(INF, INF)
			var mx := Vector2(-INF, -INF)
			for v in (c as Polygon2D).polygon:
				var w: Vector2 = (c as Polygon2D).transform * v
				mn = mn.min(w)
				mx = mx.max(w)
			return Rect2(mn - position, mx - mn)
	for c in cuerpo.get_children():
		if c is CollisionShape2D and c.shape is RectangleShape2D:
			var s: Vector2 = (c.shape as RectangleShape2D).size * c.scale
			return Rect2(c.position - s * 0.5 - position, s)
	return Rect2(-140, -15, 280, 30)


func _alto_soporte(r: Rect2) -> float:
	if suelo_y > 0.0:
		return maxf(suelo_y - global_position.y - r.end.y + 10.0, 20.0)
	return largo


func _draw() -> void:
	var r := _rect()
	if sombra:
		_dibujar_sombra(r)
	match modo:
		Modo.PILAR:
			_dibujar_pilar(r)
		Modo.LIANAS:
			_dibujar_lianas(r)


func _rng() -> RandomNumberGenerator:
	var g := RandomNumberGenerator.new()
	g.seed = semilla
	return g


## Penumbra bajo la plataforma: se desvanece hacia abajo y se estrecha.
func _dibujar_sombra(r: Rect2) -> void:
	var cx := r.get_center().x
	var mitad := r.size.x * 0.5
	var y := r.end.y - 2.0
	var oscuro := Color(0.03, 0.06, 0.05, 0.26)
	var nulo := Color(0.03, 0.06, 0.05, 0.0)
	draw_polygon(
		PackedVector2Array([Vector2(cx - mitad, y), Vector2(cx + mitad, y), Vector2(cx + mitad * 0.62, y + 54.0), Vector2(cx - mitad * 0.62, y + 54.0)]),
		PackedColorArray([oscuro, oscuro, nulo, nulo]))


# ---------------------------------------------------------------- PILAR

func _dibujar_pilar(r: Rect2) -> void:
	var g := _rng()
	var y0 := r.end.y - 4.0
	var h := _alto_soporte(r)
	var cx_tope := r.get_center().x
	var cx_base := cx_tope + desplazamiento_x
	var mitad_plat := r.size.x * 0.5
	var mitad_tronco := ancho * 0.5
	var izq := PackedVector2Array()
	var der := PackedVector2Array()
	var corte := PackedVector2Array()   # borde entre la cara iluminada y la sombreada
	for i in PASOS + 1:
		var t := float(i) / PASOS
		var d := h * t
		# La copa: arriba el tronco mide lo mismo que la plataforma y se cierra en una curva cóncava.
		var u := clampf(d / minf(alto_copa, h * 0.7), 0.0, 1.0)
		var copa := (mitad_plat - mitad_tronco) * pow(1.0 - u, 2.4)
		var w := mitad_tronco * (1.0 - 0.10 * sin(t * PI) + 1.25 * pow(t, 6.0)) + copa
		# El eje va del centro de la plataforma a la base con una curva suave (el tronco se inclina).
		var c := lerpf(cx_tope, cx_base, pow(t, 1.5)) + sin(t * 2.4 + semilla) * 4.0
		var y := y0 + d
		var tem := 1.0 if u >= 1.0 else 0.4
		var li := c - w + g.randf_range(-2.0, 2.0) * tem
		var ld := c + w + g.randf_range(-2.0, 2.0) * tem
		izq.append(Vector2(li, y))
		der.append(Vector2(ld, y))
		corte.append(Vector2(lerpf(li, ld, 0.62 + g.randf_range(-0.05, 0.05)), y))
	# Cuerpo, cara en sombra y filo de luz.
	var cuerpo := izq.duplicate()
	for i in range(PASOS, -1, -1):
		cuerpo.append(der[i])
	draw_colored_polygon(cuerpo, color_corteza)
	for i in PASOS:
		draw_colored_polygon(PackedVector2Array([corte[i], der[i], der[i + 1], corte[i + 1]]), color_sombra)
		var luz_a := izq[i].lerp(der[i], 0.15)
		var luz_b := izq[i + 1].lerp(der[i + 1], 0.15)
		draw_colored_polygon(PackedVector2Array([izq[i], luz_a, luz_b, izq[i + 1]]), color_luz)
	# Grietas: astillas largas y finas, en la parte angosta del tronco.
	for k in 6:
		var t0 := g.randf_range(0.25, 0.75)
		var i0 := clampi(int(t0 * PASOS), 0, PASOS - 1)
		var f := g.randf_range(0.2, 0.8)
		var p := izq[i0].lerp(der[i0], f)
		var dy := g.randf_range(0.12, 0.26) * h
		var dx := g.randf_range(-4.0, 4.0)
		draw_colored_polygon(PackedVector2Array([p + Vector2(-1.8, 0), p + Vector2(1.8, 0), p + Vector2(dx, dy)]), color_sombra)
	# Nudo.
	var inudo := clampi(int(PASOS * 0.5), 0, PASOS)
	var pn := izq[inudo].lerp(der[inudo], g.randf_range(0.35, 0.6))
	draw_colored_polygon(_elipse(pn, 9.0, 13.0, 10), color_sombra)
	draw_colored_polygon(_elipse(pn + Vector2(1.5, 1.0), 4.5, 7.0, 10), color_corteza)
	# Raíces del pie (garras que se abren sobre el piso).
	var yb := y0 + h
	var dedos := [[izq, -1.0, color_corteza], [der, 1.0, color_sombra]]
	for dd in dedos:
		var lado: PackedVector2Array = dd[0]
		var s: float = dd[1]
		var a := lado[PASOS - 5]
		var b := lado[PASOS - 2] + Vector2(s * 12.0, 4.0)
		var c2 := lado[PASOS] + Vector2(s * (32.0 + g.randf_range(0.0, 10.0)), 3.0)
		var base := lado[PASOS] + Vector2(-s * 10.0, 3.0)
		draw_colored_polygon(PackedVector2Array([a, b, c2, base]) if s > 0.0 else PackedVector2Array([a, base, c2, b]), dd[2])
	# Musgo que cae por el borde de la copa, con borde irregular (cubre el encuentro con la plataforma).
	var pasos_m := int(r.size.x / 28.0)
	var xs0 := izq[0].x
	var xs1 := der[0].x
	var prev_x := xs0
	var prev_y := y0 + 6.0 + g.randf_range(0.0, 12.0)
	for k in range(1, pasos_m + 1):
		var x := lerpf(xs0, xs1, float(k) / pasos_m)
		var yy := y0 + 6.0 + g.randf_range(0.0, 18.0)
		draw_colored_polygon(PackedVector2Array([Vector2(prev_x, y0), Vector2(x, y0), Vector2(x, yy), Vector2(prev_x, prev_y)]), color_musgo)
		prev_x = x
		prev_y = yy
	# Sombra de contacto sobre el piso.
	draw_colored_polygon(_elipse(Vector2(cx_base, yb + 4.0), ancho * 0.95, 7.0, 14), Color(0.04, 0.05, 0.04, 0.35))


# ---------------------------------------------------------------- LIANAS

## Dos lianas en los extremos de la plataforma, largas (se pierden fuera de pantalla).
func _dibujar_lianas(r: Rect2) -> void:
	var g := _rng()
	var y_ini := r.position.y + 8.0
	var y_fin := r.position.y - largo
	var extremos := [r.position.x + margen_lianas, r.end.x - margen_lianas]
	for n in 2:
		var x: float = extremos[n]
		var fase := g.randf_range(0.0, TAU)
		var amp := g.randf_range(5.0, 9.0)
		var eje := PackedVector2Array()
		var tramos := int(largo / 28.0)
		for i in tramos + 1:
			var t := float(i) / tramos
			eje.append(Vector2(x + sin(t * 11.0 + fase) * amp * minf(t * 4.0, 1.0), lerpf(y_ini, y_fin, t)))
		_cinta_degradada(eje, 11.0, 7.0, color_liana)
		_cinta_degradada(_desplazar(eje, Vector2(-2.6, 0.0)), 3.6, 2.4, color_liana.lightened(0.28))
		# Hojas alternadas, una cada ~120 px.
		var hojas := int(largo / 120.0)
		for k in hojas:
			var t2 := (float(k) + 0.6) / hojas * 0.96 + g.randf_range(-0.01, 0.01)
			var i2 := clampi(int(t2 * tramos), 0, eje.size() - 2)
			var p := eje[i2]
			var s := 1.0 if (k + n) % 2 == 0 else -1.0
			var largo_h := g.randf_range(18.0, 26.0)
			var col := Color(color_musgo, clampf((1.0 - t2) / 0.3, 0.0, 1.0))
			draw_colored_polygon(PackedVector2Array([p, p + Vector2(s * largo_h * 0.5, -largo_h * 0.55), p + Vector2(s * largo_h, -largo_h * 0.15), p + Vector2(s * largo_h * 0.45, 3.0)]), col)
		# Amarre: lazo oscuro donde la liana se ata a la plataforma.
		draw_colored_polygon(PackedVector2Array([Vector2(x - 7.0, y_ini - 6.0), Vector2(x + 7.0, y_ini - 6.0), Vector2(x + 6.0, y_ini + 8.0), Vector2(x - 6.0, y_ini + 8.0)]), color_sombra)


# ---------------------------------------------------------------- utilidades

func _desplazar(pts: PackedVector2Array, d: Vector2) -> PackedVector2Array:
	var res := PackedVector2Array()
	for p in pts:
		res.append(p + d)
	return res


func _elipse(c: Vector2, rx: float, ry: float, n: int) -> PackedVector2Array:
	var res := PackedVector2Array()
	for i in n:
		var a := TAU * float(i) / n
		res.append(c + Vector2(cos(a) * rx, sin(a) * ry))
	return res


## Normales de una poligonal (promedio de los tramos vecinos).
func _normal(pts: PackedVector2Array, i: int) -> Vector2:
	var a := pts[maxi(i - 1, 0)]
	var b := pts[mini(i + 1, pts.size() - 1)]
	var d := (b - a).normalized()
	return Vector2(-d.y, d.x)


## Cinta de grosor decreciente que se desvanece hacia el final (la liana se pierde en el cielo).
## Tira de cuadriláteros convexos (sin problemas de triangulación).
func _cinta_degradada(eje: PackedVector2Array, w0: float, w1: float, color: Color) -> void:
	var n := eje.size()
	for i in n - 1:
		var ta := float(i) / (n - 1)
		var tb := float(i + 1) / (n - 1)
		var wa := lerpf(w0, w1, ta) * 0.5
		var wb := lerpf(w0, w1, tb) * 0.5
		var na := _normal(eje, i)
		var nb := _normal(eje, i + 1)
		var ca := Color(color, clampf((1.0 - ta) / 0.3, 0.0, 1.0))
		var cb := Color(color, clampf((1.0 - tb) / 0.3, 0.0, 1.0))
		draw_polygon(PackedVector2Array([eje[i] + na * wa, eje[i + 1] + nb * wb, eje[i + 1] - nb * wb, eje[i] - na * wa]), PackedColorArray([ca, cb, cb, ca]))
