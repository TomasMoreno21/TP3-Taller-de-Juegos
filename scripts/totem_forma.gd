extends Node2D
## Aspecto del tótem de espíritu (lo usa `unlock_forma.tscn`), en el lenguaje del mundo: siluetas de
## piedra gris apagada (como la decoración del bosque, ver PaletaMundo) con facetas planas de luz y
## sombra, y el color reservado a lo jugable: ojos, anillos y sello brillan del color de la forma.
## La cabeza del animal va de PERFIL, mirando al frente (como el Lobo y el Oso del jugador).
## Se dibuja por código (sin texturas); el origen del nodo es el SUELO, el tótem crece hacia arriba.
## Antes de desbloquear late invitando; ya desbloqueado queda en calma, con brillo tenue.

const PIEDRA := Color(0.30, 0.31, 0.33)
const ACENTOS := {
	0: Color(0.62, 0.92, 0.62),
	1: Color(0.4, 0.68, 1.0),    # = PaletaMundo.ACENTO_ALMA
	2: Color(1.0, 0.68, 0.28),
	3: Color(0.78, 0.52, 1.0),
}
const TOPE_CABEZA := { 1: -296.0, 2: -290.0, 3: -292.0 }

var forma := 1
var acento := Color(0.4, 0.68, 1.0)
var orbe: Node2D = null          ## sello flotante del padre (para el haz y las motas)
var gastado := false             ## ya desbloqueado: brillo en calma
var _t := 0.0
var _flare := 0.0
var _brillo: Node2D


func _ready() -> void:
	_brillo = Node2D.new()
	var mat := CanvasItemMaterial.new()
	mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	mat.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
	_brillo.material = mat
	add_child(_brillo)
	_brillo.draw.connect(_dibujar_brillo)
	_t = randf() * 10.0


func configurar(f: int, color_acento: Color, orbe_ref: Node2D, ya_dado: bool) -> void:
	forma = f
	acento = color_acento
	orbe = orbe_ref
	gastado = ya_dado
	queue_redraw()


## Al desbloquear: ojos y anillos estallan y luego quedan en calma.
func despertar() -> void:
	gastado = true
	_flare = 1.0
	var tw := create_tween()
	tw.tween_property(self, "_flare", 0.0, 1.2).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)


func _process(delta: float) -> void:
	_t += delta
	if DisplayServer.get_name() == "headless":
		return
	queue_redraw()
	if _brillo != null:
		_brillo.queue_redraw()


# ------------------------------------------------------------------ utilidades

func _tono(f: float, a := 1.0) -> Color:
	return Color(clampf(PIEDRA.r * f, 0.0, 1.0), clampf(PIEDRA.g * f, 0.0, 1.0), clampf(PIEDRA.b * f, 0.0, 1.0), a)


func _pl(pts: Array, col: Color) -> void:
	draw_colored_polygon(PackedVector2Array(pts), col)


func _contorno(pts: Array, grosor := 2.0) -> void:
	var p := PackedVector2Array(pts)
	p.append(p[0])
	draw_polyline(p, Color(0.04, 0.045, 0.05, 0.85), grosor, true)


func _espejo(pts: Array) -> Array:
	var r := []
	for i in range(pts.size() - 1, -1, -1):
		r.append(Vector2(-pts[i].x, pts[i].y))
	return r


func _elipse(c: Vector2, rx: float, ry: float, col: Color, n := 18) -> void:
	var p := PackedVector2Array()
	for i in n:
		var a := TAU * float(i) / float(n)
		p.append(c + Vector2(cos(a) * rx, sin(a) * ry))
	draw_colored_polygon(p, col)


func _intensidad() -> float:
	return (0.38 if gastado else 0.78 + 0.22 * sin(_t * 2.3)) + _flare * 1.4


func _ojos() -> Array[Vector2]:
	match forma:
		2: return [Vector2(30, -238)]
		3: return [Vector2(-9, -210), Vector2(9, -210)]
		_: return [Vector2(17, -227)]


func _ancho() -> float:
	return 40.0 if forma == 2 else 28.0


# ------------------------------------------------------------------ piedra

func _draw() -> void:
	_elipse(Vector2(6, 1), 76.0, 8.0, Color(0, 0, 0, 0.3))
	_zocalo()
	_fuste()
	match forma:
		2: _cabeza_oso()
		3: _cabeza_murcielago()
		_: _cabeza_lobo()
	_hierba()


func _zocalo() -> void:
	var w := _ancho()
	var losa := [Vector2(-w - 36, 0), Vector2(w + 30, 0), Vector2(w + 24, -15), Vector2(-w - 30, -17)]
	_pl(losa, _tono(0.72))
	_pl([Vector2(-w - 30, -17), Vector2(w + 24, -15), Vector2(w + 16, -22), Vector2(-w - 22, -24)], _tono(1.15))
	_contorno(losa, 1.6)
	var losa2 := [Vector2(-w - 18, -24), Vector2(w + 14, -22), Vector2(w + 8, -38), Vector2(-w - 12, -40)]
	_pl(losa2, _tono(0.9))
	_pl([Vector2(-w - 18, -24), Vector2(-w - 6, -24), Vector2(-w - 4, -39), Vector2(-w - 12, -40)], _tono(1.2))
	_contorno(losa2, 1.6)


func _fuste() -> void:
	var wb := _ancho() + 4.0
	var wt := _ancho() - 3.0
	var alto := 170.0
	var cuerpo := [Vector2(-wb, -38), Vector2(wb, -38), Vector2(wt, -alto), Vector2(-wt, -alto)]
	_pl(cuerpo, _tono(0.95))
	# Facetas: luz a la izquierda, sombra a la derecha.
	_pl([Vector2(-wb, -38), Vector2(-wb * 0.4, -38), Vector2(-wt * 0.4, -alto), Vector2(-wt, -alto)], _tono(1.22))
	_pl([Vector2(wb * 0.45, -38), Vector2(wb, -38), Vector2(wt, -alto), Vector2(wt * 0.45, -alto)], _tono(0.66))
	# Oclusión al pie.
	draw_polygon(PackedVector2Array([Vector2(-wb, -38), Vector2(wb, -38), Vector2(wb - 2, -80), Vector2(-wb + 2, -80)]),
		PackedColorArray([Color(0, 0, 0, 0.3), Color(0, 0, 0, 0.3), Color(0, 0, 0, 0), Color(0, 0, 0, 0)]))
	_contorno(cuerpo, 1.8)
	# Vetas y astillas.
	var v := _tono(0.4)
	draw_polyline(PackedVector2Array([Vector2(-wb * 0.3, -50), Vector2(-wb * 0.15, -66), Vector2(-wb * 0.4, -80)]), v, 1.8, true)
	draw_polyline(PackedVector2Array([Vector2(wb * 0.2, -150), Vector2(wb * 0.05, -160)]), v, 1.6, true)
	# Anillos tallados.
	for y in [-64.0, -132.0]:
		var w: float = wb + (wt - wb) * ((-y - 38.0) / (alto - 38.0))
		draw_line(Vector2(-w, y), Vector2(w, y), _tono(0.4), 4.0)
		draw_line(Vector2(-w, y - 3.0), Vector2(w, y - 3.0), _tono(1.3), 1.5)


func _hierba() -> void:
	var h := Color(0.09, 0.1, 0.1)
	var w := _ancho()
	for x in [-w - 40.0, -w - 34.0, -w - 28.0, w + 26.0, w + 32.0, w + 38.0]:
		draw_line(Vector2(x, 0), Vector2(x + signf(x) * 4.0, -15.0 - absf(fmod(x, 7.0))), h, 2.2)


# ------------------------------------------------------------------ cabezas

func _ojo_tallado(pts: Array) -> void:
	_pl(pts, Color(acento.r * 0.35 + 0.65, acento.g * 0.35 + 0.65, acento.b * 0.35 + 0.65))


func _cabeza_lobo() -> void:
	var cab := [Vector2(-26, -170), Vector2(-32, -206), Vector2(-27, -238), Vector2(-16, -296), Vector2(0, -254), Vector2(8, -284),
		Vector2(16, -250), Vector2(40, -236), Vector2(68, -222), Vector2(70, -211), Vector2(44, -206), Vector2(30, -194), Vector2(24, -178), Vector2(26, -170)]
	_pl(cab, _tono(0.95))
	_pl([Vector2(-27, -238), Vector2(-16, -296), Vector2(0, -254), Vector2(8, -284), Vector2(16, -250), Vector2(40, -236), Vector2(12, -228), Vector2(-24, -214)], _tono(1.25))
	_pl([Vector2(-30, -190), Vector2(-10, -196), Vector2(20, -200), Vector2(44, -206), Vector2(30, -194), Vector2(24, -178), Vector2(26, -170), Vector2(-26, -170)], _tono(0.66))
	_pl([Vector2(-17, -282), Vector2(-14, -260), Vector2(-6, -262)], Color(acento, 0.3))   # interior de la oreja
	_contorno(cab)
	draw_polyline(PackedVector2Array([Vector2(70, -211), Vector2(46, -210), Vector2(34, -200)]), _tono(0.3), 2.0, true)
	_elipse(Vector2(67, -220), 3.5, 3.0, Color(0.05, 0.05, 0.06))
	_ojo_tallado([Vector2(8, -232), Vector2(26, -226), Vector2(22, -222), Vector2(8, -227)])


func _cabeza_oso() -> void:
	_elipse(Vector2(-6, -276), 14.0, 14.0, _tono(1.05))
	draw_arc(Vector2(-6, -276), 14.0, 0.0, TAU, 20, Color(0.04, 0.045, 0.05, 0.85), 1.8, true)   # oreja redonda
	_elipse(Vector2(-6, -276), 7.5, 7.5, Color(acento, 0.28))
	var cab := [Vector2(-40, -170), Vector2(-50, -206), Vector2(-42, -244), Vector2(-16, -264), Vector2(14, -266), Vector2(38, -252), Vector2(48, -238),
		Vector2(74, -226), Vector2(76, -208), Vector2(50, -200), Vector2(44, -184), Vector2(34, -170)]
	_pl(cab, _tono(0.95))
	_pl([Vector2(-42, -244), Vector2(-16, -264), Vector2(14, -266), Vector2(38, -252), Vector2(48, -238), Vector2(10, -234), Vector2(-34, -220)], _tono(1.25))
	_pl([Vector2(-40, -170), Vector2(-50, -206), Vector2(-32, -212), Vector2(10, -208), Vector2(44, -200), Vector2(44, -184), Vector2(34, -170)], _tono(0.66))
	_contorno(cab)
	_elipse(Vector2(74, -219), 5.0, 4.0, Color(0.05, 0.05, 0.06))
	draw_polyline(PackedVector2Array([Vector2(76, -208), Vector2(54, -207)]), _tono(0.3), 2.0, true)
	draw_line(Vector2(22, -246), Vector2(42, -240), _tono(0.3), 4.0)   # ceja pesada
	_elipse(Vector2(30, -236), 4.8, 4.8, Color(acento.r * 0.35 + 0.65, acento.g * 0.35 + 0.65, acento.b * 0.35 + 0.65))


func _cabeza_murcielago() -> void:
	# Alas plegadas como una capa sobre los lados del fuste.
	var ala := [Vector2(-22, -194), Vector2(-48, -198), Vector2(-68, -150), Vector2(-64, -98), Vector2(-54, -112), Vector2(-50, -70),
		Vector2(-40, -94), Vector2(-32, -56), Vector2(-22, -100)]
	_pl(ala, _tono(0.62))
	_pl(_espejo(ala), _tono(0.46))
	_contorno(ala, 1.8)
	_contorno(_espejo(ala), 1.8)
	for k in [2, 4, 6, 7]:
		draw_line(ala[0], ala[k], _tono(0.9), 1.8)
		draw_line(Vector2(-ala[0].x, ala[0].y), Vector2(-ala[k].x, ala[k].y), _tono(0.5), 1.8)
	# Orejas enormes y cabeza.
	for s in [-1.0, 1.0]:
		var oreja := [Vector2(-5 * s, -222), Vector2(-30 * s, -292), Vector2(-28 * s, -204)]
		_pl(oreja, _tono(1.1 if s < 0.0 else 0.7))
		_contorno(oreja, 1.8)
		_pl([Vector2(-10 * s, -222), Vector2(-27 * s, -274), Vector2(-25 * s, -210)], Color(acento, 0.3))
	var cab := [Vector2(0, -234), Vector2(-16, -230), Vector2(-24, -208), Vector2(-16, -184), Vector2(0, -178)]
	_pl(cab, _tono(1.1))
	_pl(_espejo(cab), _tono(0.72))
	_contorno(cab + _espejo(cab), 1.8)
	for s in [-1.0, 1.0]:
		_ojo_tallado([Vector2(-15 * s, -213), Vector2(-3 * s, -208), Vector2(-4 * s, -205), Vector2(-15 * s, -209)])
		_pl([Vector2(3 * s, -190), Vector2(7 * s, -190), Vector2(5 * s, -183)], Color(0.88, 0.88, 0.86))   # colmillo


# ------------------------------------------------------------------ brillo (suma de luz)

func _dibujar_brillo() -> void:
	var inten := _intensidad()
	var charco := PackedVector2Array()
	for i in 20:
		var a := TAU * float(i) / 20.0
		charco.append(Vector2(cos(a) * 82.0, sin(a) * 11.0))
	_brillo.draw_colored_polygon(charco, Color(acento, 0.09 * inten))
	# Anillos tallados: la luz del espíritu corre por la piedra.
	var wb := _ancho() + 4.0
	var wt := _ancho() - 3.0
	for y in [-64.0, -132.0]:
		var w: float = wb + (wt - wb) * ((-y - 38.0) / 132.0)
		_brillo.draw_line(Vector2(-w + 2.0, y), Vector2(w - 2.0, y), Color(acento, 0.5 * inten), 2.2)
		_brillo.draw_line(Vector2(-w + 2.0, y), Vector2(w - 2.0, y), Color(acento, 0.12 * inten), 8.0)
	for p in _ojos():
		_brillo.draw_circle(p, 16.0, Color(acento, 0.15 * inten))
		_brillo.draw_circle(p, 8.0, Color(acento, 0.3 * inten))
		_brillo.draw_circle(p, 3.0, Color(1, 1, 1, 0.5 * minf(inten, 1.4)))
	var tope: float = TOPE_CABEZA.get(forma, -280.0)
	_brillo.draw_circle(Vector2(0, tope + 40.0), 46.0, Color(acento, 0.05 * inten))
	_orbe_y_brasas(inten, tope)


func _orbe_y_brasas(inten: float, tope: float) -> void:
	var pos_orbe := Vector2.ZERO
	var a_orbe := 0.0
	var esc := 1.0
	if orbe != null and is_instance_valid(orbe) and orbe.visible:
		pos_orbe = orbe.position - position
		a_orbe = orbe.modulate.a
		esc = orbe.scale.x / 1.5
	if a_orbe > 0.01:
		var pts := PackedVector2Array([Vector2(-8, tope), Vector2(8, tope), Vector2(2.0, pos_orbe.y + 12.0), Vector2(-2.0, pos_orbe.y + 12.0)])
		_brillo.draw_polygon(pts, PackedColorArray([Color(acento, 0.18 * a_orbe * inten), Color(acento, 0.18 * a_orbe * inten), Color(acento, 0.0), Color(acento, 0.0)]))
		_brillo.draw_circle(pos_orbe, 30.0 * esc, Color(acento, 0.13 * a_orbe))
		_brillo.draw_circle(pos_orbe, 16.0 * esc, Color(acento, 0.28 * a_orbe))
		_brillo.draw_circle(pos_orbe, 7.0 * esc, Color(1, 1, 1, 0.75 * a_orbe))
		for i in 6:
			var ang := _t * (0.9 + 0.22 * float(i)) + float(i) * 1.05
			var rad := (26.0 + 7.0 * sin(_t * 1.3 + float(i))) * esc
			_brillo.draw_circle(pos_orbe + Vector2(cos(ang) * rad, sin(ang) * rad * 0.5), 2.0 + float(i % 2), Color(acento, 0.7 * a_orbe))
	# Motas que suben, como las luciérnagas del bosque.
	for i in 8:
		var u := fposmod(_t * 0.2 + float(i) * 0.125, 1.0)
		var x := sin(float(i) * 7.3 + _t * 0.8) * (22.0 + float(i) * 3.0)
		_brillo.draw_circle(Vector2(x, tope + 30.0 - u * 120.0), 1.6 + float(i % 3) * 0.5, Color(acento, sin(u * PI) * 0.65 * clampf(inten, 0.0, 1.2)))
