@tool
extends StaticBody2D
## Gran tronco sólido para la torre con pinchos del bosque. Es un cuerpo con colisión (hijo "Colision",
## un CollisionShape2D rectangular que el script mantiene del tamaño del tronco): no se puede atravesar
## ni por los costados ni por arriba. El origen está en el centro de la base (a la altura del piso) y el
## tronco crece hacia arriba. Dibuja con polígonos planos: cuerpo, luz/sombra, vetas, grietas, nudo,
## musgo, raíces al pie y borde de pasto en el tope (donde van los pinchos).

@export var ancho := 384.0:  ## ancho del tronco (y de su colisión)
	set(v):
		ancho = maxf(v, 60.0)
		_redibujar()
@export var alto := 562.0:  ## alto del tronco (y de su colisión)
	set(v):
		alto = maxf(v, 100.0)
		_redibujar()
@export var raiz_extra := 90.0:  ## cuánto se abren las raíces al pie
	set(v):
		raiz_extra = maxf(v, 0.0)
		_redibujar()
@export var semilla := 7:
	set(v):
		semilla = v
		_redibujar()
@export_group("Colores")
@export var color_corteza := Color(0.27, 0.18, 0.12):
	set(v):
		color_corteza = v
		_redibujar()
@export var color_sombra := Color(0.17, 0.11, 0.09):
	set(v):
		color_sombra = v
		_redibujar()
@export var color_luz := Color(0.40, 0.28, 0.18):
	set(v):
		color_luz = v
		_redibujar()
@export var color_musgo := Color(0.20, 0.42, 0.20):
	set(v):
		color_musgo = v
		_redibujar()

const PASOS := 20


func _ready() -> void:
	_redibujar()


func _redibujar() -> void:
	queue_redraw()
	_actualizar_colision()


func _actualizar_colision() -> void:
	var col := get_node_or_null("Colision") as CollisionShape2D
	if col == null:
		return
	var forma := col.shape as RectangleShape2D
	if forma == null:
		forma = RectangleShape2D.new()
		col.shape = forma
	forma.size = Vector2(ancho, alto)
	col.position = Vector2(0.0, -alto * 0.5)


func _rng() -> RandomNumberGenerator:
	var g := RandomNumberGenerator.new()
	g.seed = semilla
	return g


func _draw() -> void:
	var g := _rng()
	var mitad := ancho * 0.5
	# Raíces grandes al pie (detrás del cuerpo): se abren sobre el piso a ambos lados.
	for lado: float in [-1.0, 1.0]:
		for k in 3:
			var pie := Vector2(lado * (mitad + raiz_extra * (0.55 + 0.45 * float(k) / 2.0) + g.randf_range(-8.0, 8.0)), 2.0)
			var tope := Vector2(lado * (mitad - 6.0), -g.randf_range(90.0, 170.0))
			var ctrl := Vector2(lado * (mitad + 14.0), -g.randf_range(10.0, 36.0))
			var eje := PackedVector2Array()
			for i in 11:
				var t := float(i) / 10.0
				eje.append(pie.lerp(ctrl, t).lerp(ctrl.lerp(tope, t), t))
			_cinta(eje, 10.0 + 4.0 * (2 - k), 40.0 + 12.0 * (2 - k), color_sombra if lado > 0.0 else color_corteza)
	# Cuerpo: se ensancha un poco al pie (arranque de las raíces) y es recto arriba.
	var izq := PackedVector2Array()
	var der := PackedVector2Array()
	var corte := PackedVector2Array()
	for i in PASOS + 1:
		var t := float(i) / PASOS
		var w := mitad + raiz_extra * 0.35 * pow(1.0 - t, 5.0)
		var y := -alto * t
		var li := -w
		var ld := w
		if i > 0 and i < PASOS:
			li += g.randf_range(-2.0, 1.0)
			ld += g.randf_range(-1.0, 2.0)
		izq.append(Vector2(li, y))
		der.append(Vector2(ld, y))
		corte.append(Vector2(lerpf(li, ld, 0.66 + g.randf_range(-0.03, 0.03)), y))
	var cuerpo := izq.duplicate()
	for i in range(PASOS, -1, -1):
		cuerpo.append(der[i])
	_poly(cuerpo, color_corteza)
	# Cara en sombra (derecha) y filo de luz (izquierda).
	for i in PASOS:
		_poly(PackedVector2Array([corte[i], der[i], der[i + 1], corte[i + 1]]), color_sombra)
		var la := izq[i].lerp(der[i], 0.08)
		var lb := izq[i + 1].lerp(der[i + 1], 0.08)
		_poly(PackedVector2Array([izq[i], la, lb, izq[i + 1]]), color_luz)
	# Vetas verticales de corteza: cintas onduladas, una oscura y una clara al lado.
	var n_vetas := 9
	for k in n_vetas:
		var f := (float(k) + 0.5 + g.randf_range(-0.2, 0.2)) / n_vetas
		var fase := g.randf_range(0.0, TAU)
		var t0 := g.randf_range(0.0, 0.25)
		var t1 := g.randf_range(0.7, 1.0)
		var eje := PackedVector2Array()
		var eje2 := PackedVector2Array()
		for i in 15:
			var t := lerpf(t0, t1, float(i) / 14.0)
			var idx := clampi(int(t * PASOS), 0, PASOS)
			var p := izq[idx].lerp(der[idx], f) + Vector2(sin(t * 9.0 + fase) * 5.0, 0.0)
			eje.append(p)
			eje2.append(p + Vector2(-5.0, 0.0))
		_cinta(eje, 5.0, 2.5, color_sombra)
		_cinta(eje2, 3.5, 1.8, color_luz)
	# Grietas largas y cicatrices cortas.
	for k in 9:
		var t0 := g.randf_range(0.08, 0.85)
		var i0 := clampi(int(t0 * PASOS), 0, PASOS - 1)
		var p := izq[i0].lerp(der[i0], g.randf_range(0.1, 0.9))
		var dy := g.randf_range(60.0, 150.0)
		_poly(PackedVector2Array([p + Vector2(-2.0, 0), p + Vector2(2.0, 0), p + Vector2(g.randf_range(-5.0, 5.0), -dy)]), color_sombra)
	for k in 7:
		var t0 := g.randf_range(0.1, 0.85)
		var i0 := clampi(int(t0 * PASOS), 0, PASOS - 1)
		var p := izq[i0].lerp(der[i0], g.randf_range(0.1, 0.8))
		var l := g.randf_range(24.0, 60.0)
		_poly(PackedVector2Array([p, p + Vector2(l, -2.0), p + Vector2(l * 0.9, 3.0)]), color_sombra)
	# Nudo grande, de tono de corteza (sin negro).
	var pn := Vector2(-mitad * 0.45, -alto * 0.38)
	_poly(_elipse(pn, 26.0, 40.0, 14), color_sombra)
	_poly(_elipse(pn + Vector2(2.0, 2.0), 17.0, 29.0, 14), color_corteza.darkened(0.12))
	_poly(_elipse(pn + Vector2(-4.0, -6.0), 6.0, 12.0, 10), color_luz)
	# Manchas de musgo (más abajo y en la cara de luz).
	for k in 9:
		var t0 := g.randf_range(0.04, 0.6)
		var i0 := clampi(int(t0 * PASOS), 0, PASOS)
		var pm := izq[i0].lerp(der[i0], g.randf_range(0.05, 0.95))
		_poly(_elipse(pm, g.randf_range(10.0, 22.0), g.randf_range(14.0, 34.0), 9), Color(color_musgo, 0.5))
	# Borde de pasto en el tope (donde se apoyan los pinchos): franja verde con flecos que caen por los lados.
	var y_top := -alto
	var x_prev := izq[PASOS].x - 4.0
	var x_fin := der[PASOS].x + 4.0
	var pasos_m := int(ancho / 18.0)
	_poly(PackedVector2Array([Vector2(x_prev, y_top - 6.0), Vector2(x_fin, y_top - 6.0), Vector2(x_fin, y_top + 8.0), Vector2(x_prev, y_top + 8.0)]), color_musgo.darkened(0.25))
	var xp := x_prev
	var yp := y_top + 8.0 + g.randf_range(0.0, 16.0)
	for k in range(1, pasos_m + 1):
		var x := lerpf(x_prev, x_fin, float(k) / pasos_m)
		var yy := y_top + 8.0 + g.randf_range(0.0, 26.0)
		_poly(PackedVector2Array([Vector2(xp, y_top + 6.0), Vector2(x, y_top + 6.0), Vector2(x, yy), Vector2(xp, yp)]), color_musgo)
		xp = x
		yp = yy
	for k in pasos_m * 2:
		var x := lerpf(x_prev, x_fin, (float(k) + g.randf_range(0.0, 1.0)) / (pasos_m * 2))
		var h := g.randf_range(8.0, 16.0)
		_poly(PackedVector2Array([Vector2(x - 4.0, y_top - 4.0), Vector2(x + 4.0, y_top - 4.0), Vector2(x + g.randf_range(-3.0, 3.0), y_top - 4.0 - h)]), color_musgo.lightened(0.1))
	# Sombra de contacto sobre el piso.
	_poly(_elipse(Vector2(0.0, 4.0), mitad + raiz_extra * 0.9, 8.0, 18), Color(0.04, 0.05, 0.04, 0.35))


func _elipse(c: Vector2, rx: float, ry: float, n: int) -> PackedVector2Array:
	var res := PackedVector2Array()
	for i in n:
		var a := TAU * float(i) / n
		res.append(c + Vector2(cos(a) * rx, sin(a) * ry))
	return res


func _normal(pts: PackedVector2Array, i: int) -> Vector2:
	var a := pts[maxi(i - 1, 0)]
	var b := pts[mini(i + 1, pts.size() - 1)]
	var d := (b - a).normalized()
	return Vector2(-d.y, d.x)


## Cinta de grosor decreciente (tira de cuadriláteros convexos).
func _cinta(eje: PackedVector2Array, w0: float, w1: float, color: Color) -> void:
	var n := eje.size()
	for i in n - 1:
		var wa := lerpf(w0, w1, float(i) / (n - 1)) * 0.5
		var wb := lerpf(w0, w1, float(i + 1) / (n - 1)) * 0.5
		var na := _normal(eje, i)
		var nb := _normal(eje, i + 1)
		_poly(PackedVector2Array([eje[i] + na * wa, eje[i + 1] + nb * wb, eje[i + 1] - nb * wb, eje[i] - na * wa]), color)


## Dibuja un polígono relleno; descarta los degenerados (si no, Godot imprime un error de triangulación).
func _poly(pts: PackedVector2Array, color: Color) -> void:
	if Geometry2D.triangulate_polygon(pts).is_empty():
		return
	draw_colored_polygon(pts, color)
