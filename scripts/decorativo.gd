@tool
extends Node2D
## Decorativo forestal vectorial (sin sprites), con el MISMO lenguaje que el fondo
## del bosque (Boske*.png): siluetas planas en grises, copas hechas de círculos
## superpuestos con manchas internas más claras, troncos que se afinan con vetas y
## ramitas, arbustos festoneados. Anclado al suelo (0,0 = pie), con sombra y viento
## opcionales. Detrás del jugador va en un contenedor z=-5; los tipos *_FRENTE /
## RAMA_COLGANTE / PASTO_ALTO son para el primer plano (ver primer_plano.gd).

enum Tipo { ARBOL, SAUCE, ARBUSTO, PASTO, PIEDRA, TRONCO_FRENTE, RAMA_COLGANTE, PASTO_ALTO }

@export var tipo := Tipo.ARBOL:
	set(value):
		tipo = value
		queue_redraw()
@export_range(1, 10) var variante := 1:
	set(value):
		variante = value
		queue_redraw()
@export var escala := 5.0:
	set(value):
		escala = maxf(value, 0.1)
		queue_redraw()
@export var flip_h := false:
	set(value):
		flip_h = value
		queue_redraw()
## Gris base de la silueta (escala de tonos: ver PaletaMundo). Las manchas de luz
## y las vetas se derivan de este tono.
@export var tono := Color(0.215, 0.22, 0.225):   # = PaletaMundo.DECO (literal: el editor lo lee aunque no haya cargado la clase)
	set(value):
		tono = value
		_tmp = Vector4.ZERO
@export var color_noche := Color(0.8, 0.85, 0.97):
	set(value):
		color_noche = value
		queue_redraw()
@export var sombra := true
@export var sombra_alpha := 0.25:
	set(value):
		sombra_alpha = clampf(value, 0.0, 1.0)
		queue_redraw()
@export var viento := true
@export var viento_amplitud := 0.03:
	set(value):
		viento_amplitud = absf(value)
@export var viento_velocidad := 1.5:
	set(value):
		viento_velocidad = absf(value)

var _tmp := Vector4.ZERO
var _editor_sync := true
var _fase_viento := 0.0
var _hoja: Node2D
var _sombra: Polygon2D


func _ready() -> void:
	_fase_viento = randf() * TAU
	_rehacer()


func _process(delta: float) -> void:
	if Engine.is_editor_hint():
		if _editor_sync:
			var s := scale
			if s != Vector2.ONE:
				_editor_sync = false
				escala = maxf(escala * s.x, 0.1)
				scale = Vector2.ONE
				_editor_sync = true
				_rehacer()
		var clave := Vector4(float(tipo), float(variante), escala, tono.r + tono.g * 10.0 + tono.b * 100.0)
		if clave != _tmp:
			_tmp = clave
			_rehacer()
		_aplicar_config()
		return
	if viento and _hoja != null:
		var t := Time.get_ticks_msec() * 0.001 * viento_velocidad + _fase_viento
		_hoja.rotation = sin(t) * viento_amplitud


## Colores, flip y escala sin redibujar.
func _aplicar_config() -> void:
	if _hoja != null:
		_hoja.scale = Vector2(escala * (-1.0 if flip_h else 1.0), escala)
		_hoja.modulate = color_noche
	if _sombra != null:
		_sombra.visible = sombra and _lleva_sombra()
		_sombra.color.a = sombra_alpha


## Reconstruye la silueta completa (idempotente: limpia y vuelve a crear).
func _rehacer() -> void:
	for nodo in ["Hoja", "Sombra"]:
		var old := get_node_or_null(nodo)
		if old != null:
			old.queue_free()
	_hoja = Node2D.new()
	_hoja.name = "Hoja"
	add_child(_hoja)
	for pol in _generar_silueta(tipo, variante):
		_hoja.add_child(pol)
	_sombra = null
	if sombra and _lleva_sombra():
		_sombra = Polygon2D.new()
		_sombra.name = "Sombra"
		_sombra.z_index = -1
		_sombra.position.y = 3.0
		_sombra.color = Color(0, 0, 0, sombra_alpha)
		_sombra.polygon = _elipse_sombra()
		add_child(_sombra)
	_aplicar_config()


func _lleva_sombra() -> bool:
	return tipo in [Tipo.ARBOL, Tipo.SAUCE, Tipo.ARBUSTO, Tipo.PIEDRA]


# ------------------------------------------------------------------ siluetas
## Coordenadas locales en tamaño "base" (y<=0 hacia arriba, 0 = suelo; en
## RAMA_COLGANTE 0 = punto de cuelgue y crece hacia abajo). La escala la pone Hoja.
func _generar_silueta(t: int, v: int) -> Array[Polygon2D]:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(t * 1000 + v)
	# Dos tonos como en el fondo: cara clara / cara en sombra y manchas de luz grandes.
	var base := tono
	var luz := _aclarar(tono, 0.12)
	var sombra_cara := _aclarar(tono, -0.065)
	var veta := _aclarar(tono, -0.1)
	var out: Array[Polygon2D] = []
	match t:
		Tipo.ARBOL:
			var alto_tronco := rng.randf_range(64.0, 84.0)
			out += _tronco(rng, 9.0, 5.5, alto_tronco, base, sombra_cara, veta, 2 + v % 2)
			var centro := Vector2(rng.randf_range(-6.0, 6.0), -alto_tronco - 20.0)
			out += _copa(rng, centro, Vector2(46.0, 28.0) * rng.randf_range(0.9, 1.15), 6 + v % 3, sombra_cara, luz)
		Tipo.SAUCE:
			# Tronco alto sin copa que sale del cuadro, como los troncos del fondo.
			out += _tronco(rng, 10.0, 7.0, 300.0, base, sombra_cara, veta, 3)
		Tipo.ARBUSTO:
			out += _arbusto(rng, Vector2(40.0, 24.0) * rng.randf_range(0.85, 1.15), sombra_cara, luz)
		Tipo.PASTO:
			out += _mata(rng, 5 + v % 4, 14.0, 30.0, sombra_cara)
		Tipo.PIEDRA:
			out += _piedra(rng, base, luz)
		Tipo.TRONCO_FRENTE:
			out += _tronco(rng, 13.0, 9.5, 420.0, base, _aclarar(base, -0.015), _aclarar(base, 0.02), 2)
		Tipo.RAMA_COLGANTE:
			out += _rama_colgante(rng, base, _aclarar(base, 0.03))
		Tipo.PASTO_ALTO:
			out += _mata(rng, 9 + v % 5, 40.0, 78.0, base)
			out += _arbusto(rng, Vector2(30.0, 16.0), base, _aclarar(base, 0.03))
	return out


## Tronco orgánico como los del fondo: bordes curvos (leve comba), base que se
## abre, punta redondeada, dos caras (clara a la izquierda, sombra a la derecha
## con un corte curvo), vetas cortas y ramas en "cuerno" que se doblan hacia arriba.
func _tronco(rng: RandomNumberGenerator, ancho_base: float, ancho_arriba: float, alto: float,
		color: Color, color_sombra: Color, color_veta: Color, ramitas: int) -> Array[Polygon2D]:
	var out: Array[Polygon2D] = []
	var comba := rng.randf_range(-0.07, 0.07) * alto
	var inclin := rng.randf_range(-0.05, 0.05) * alto
	var apertura := ancho_base * rng.randf_range(0.45, 0.8)
	var fase := rng.randf() * TAU
	const N := 18
	var izq := PackedVector2Array()
	var der := PackedVector2Array()
	var corte := PackedVector2Array()
	var centros: Array[float] = []
	var anchos: Array[float] = []
	for k in N + 1:
		var f := float(k) / N
		var y := -alto * f
		var cx := sin(f * PI) * comba + inclin * f
		var w := lerpf(ancho_base, ancho_arriba, pow(f, 0.8)) + apertura * pow(1.0 - f, 5.0)
		w *= 1.0 + 0.06 * sin(f * 6.0 + fase)
		centros.append(cx)
		anchos.append(w)
		izq.append(Vector2(cx - w, y))
		der.append(Vector2(cx + w, y))
		corte.append(Vector2(cx + w * (0.15 + 0.12 * sin(f * 4.0 + fase)), y))
	# Punta redondeada.
	var tapa := PackedVector2Array()
	var wt: float = anchos[N]
	for i in range(1, 8):
		var a := PI - PI * float(i) / 8.0
		tapa.append(Vector2(centros[N] + cos(a) * wt, -alto - sin(a) * wt * 0.55))
	var contorno := izq + tapa
	for k in range(N, -1, -1):
		contorno.append(der[k])
	out.append(_poligono(contorno, color))
	# Cara en sombra: del corte curvo al borde derecho.
	var cara := PackedVector2Array()
	for k in N + 1:
		cara.append(corte[k])
	for k in range(N, -1, -1):
		cara.append(der[k])
	out.append(_poligono(cara, color_sombra))
	# Ramas en cuerno (curvas, afinadas, punta redonda; a veces en "Y").
	for i in ramitas:
		var f := rng.randf_range(0.3, 0.78)
		var k := int(f * N)
		var lado := -1.0 if i % 2 == 0 else 1.0
		var origen := Vector2(centros[k] + anchos[k] * lado * 0.85, -alto * f)
		var largo := rng.randf_range(11.0, 18.0)
		out += _cuerno(origen, lado, largo, rng.randf_range(1.8, 2.4), color if lado < 0 else color_sombra)
		if rng.randf() < 0.5:
			var medio := origen + Vector2(lado * largo * 0.35, -largo * 0.3)
			out += _cuerno(medio, lado, largo * 0.5, 1.2, color if lado < 0 else color_sombra)
	# Brote en la base, como en varios troncos del fondo.
	if rng.randf() < 0.6:
		var lado_b := -1.0 if rng.randf() < 0.5 else 1.0
		out += _cuerno(Vector2(centros[1] + anchos[1] * lado_b * 0.9, -alto * 0.05), lado_b, rng.randf_range(9.0, 14.0), 1.7,
				color if lado_b < 0 else color_sombra)
	# Vetas: trazos cortos, finos y curvos a lo largo del tronco.
	for i in 3 + rng.randi() % 3:
		var f0 := rng.randf_range(0.12, 0.7)
		var f1 := minf(f0 + rng.randf_range(0.1, 0.22), 0.92)
		var u := rng.randf_range(-0.55, 0.45)
		var v_izq := PackedVector2Array()
		var v_der := PackedVector2Array()
		for j in 6:
			var f := lerpf(f0, f1, float(j) / 5.0)
			var k2 := clampi(int(f * N), 0, N)
			var x := centros[k2] + anchos[k2] * u + sin(f * 9.0) * 0.6
			var g := 0.55 * sin(PI * float(j) / 5.0) + 0.05
			v_izq.append(Vector2(x - g, -alto * f))
			v_der.insert(0, Vector2(x + g, -alto * f))
		out.append(_poligono(v_izq + v_der, color_veta))
	return out


## Rama en "cuerno": sale del tronco, se curva hacia arriba y se afina hasta una
## punta redondeada (curva cuadrática).
func _cuerno(origen: Vector2, lado: float, largo: float, grosor: float, color: Color) -> Array[Polygon2D]:
	var ctrl := origen + Vector2(lado * largo * 0.75, -largo * 0.1)
	var punta := origen + Vector2(lado * largo * 0.85, -largo * 0.95)
	var izq := PackedVector2Array()
	var der := PackedVector2Array()
	const M := 9
	var prev := origen
	for j in M + 1:
		var f := float(j) / M
		var p := origen.lerp(ctrl, f).lerp(ctrl.lerp(punta, f), f)
		var dir := (p - prev).normalized() if j > 0 else (ctrl - origen).normalized()
		var n := dir.orthogonal()
		var w := lerpf(grosor, grosor * 0.35, f)
		izq.append(p + n * w)
		der.insert(0, p - n * w)
		prev = p
	var out: Array[Polygon2D] = [_poligono(izq + der, color)]
	out.append(_poligono(_circulo(punta, grosor * 0.4, 8), color))
	return out


## Copa como las del fondo: círculos oscuros grandes superpuestos, bolitas que
## cuelgan del borde inferior y manchas claras GRANDES con forma de nube.
func _copa(rng: RandomNumberGenerator, centro: Vector2, radios: Vector2, n: int,
		color: Color, color_luz: Color) -> Array[Polygon2D]:
	var out: Array[Polygon2D] = []
	var grandes: Array[Vector3] = []   # x, y, r
	grandes.append(Vector3(centro.x, centro.y, radios.y * 1.05))
	for i in n:
		var a := TAU * float(i) / float(n) + rng.randf_range(-0.25, 0.25)
		var p := centro + Vector2(cos(a) * radios.x, sin(a) * radios.y * 0.7)
		grandes.append(Vector3(p.x, p.y, rng.randf_range(0.5, 0.78) * radios.y))
	for g in grandes:
		out.append(_poligono(_circulo(Vector2(g.x, g.y), g.z, 18), color))
	# Bolitas colgando del borde de abajo.
	for i in 3 + rng.randi() % 3:
		var x := centro.x + rng.randf_range(-0.85, 0.85) * radios.x
		var y := centro.y + radios.y * rng.randf_range(0.55, 0.95)
		out.append(_poligono(_circulo(Vector2(x, y), radios.y * rng.randf_range(0.1, 0.2), 12), color))
	# Manchas de luz: nubes de 4-6 círculos, arriba a la izquierda de varios círculos grandes.
	var elegidos := grandes.duplicate()
	elegidos.shuffle()
	for e in elegidos.slice(0, mini(3 + rng.randi() % 2, elegidos.size())):
		var g: Vector3 = e
		var c: Vector2 = Vector2(g.x, g.y) + Vector2(-0.18, -0.2) * g.z
		for k in 4 + rng.randi() % 3:
			var q: Vector2 = c + Vector2(rng.randf_range(-0.34, 0.34), rng.randf_range(-0.26, 0.26)) * g.z
			out.append(_poligono(_circulo(q, g.z * rng.randf_range(0.2, 0.34), 14), color_luz))
	return out


## Arbusto festoneado como los de Boske12: cúpula con muchos bultitos en el borde
## superior y alguna mancha de luz.
func _arbusto(rng: RandomNumberGenerator, radios: Vector2, color: Color, color_luz: Color) -> Array[Polygon2D]:
	var out: Array[Polygon2D] = []
	out.append(_poligono(_medio_circulo(Vector2.ZERO, radios.x, radios.y * 0.85), color))
	var n := 10 + rng.randi() % 5
	for i in n:
		var f := float(i) / float(n - 1)
		var a := lerpf(PI * 1.06, TAU * 0.97, f)
		var p := Vector2(cos(a) * radios.x * 0.92, sin(a) * radios.y * 0.8)
		var r := radios.y * rng.randf_range(0.2, 0.34)
		out.append(_poligono(_circulo(Vector2(p.x, minf(p.y, -r * 0.3)), r, 14), color))
	for i in 1 + rng.randi() % 2:
		var c := Vector2(rng.randf_range(-0.35, 0.2) * radios.x, -radios.y * rng.randf_range(0.4, 0.6))
		for k in 3:
			var q := c + Vector2(rng.randf_range(-0.12, 0.12) * radios.x, rng.randf_range(-0.1, 0.1) * radios.y)
			out.append(_poligono(_circulo(q, radios.y * rng.randf_range(0.14, 0.22), 12), color_luz))
	return out


## Mata de hojas curvas (y alguna ramita en "Y").
func _mata(rng: RandomNumberGenerator, n: int, alto_min: float, alto_max: float, color: Color) -> Array[Polygon2D]:
	var out: Array[Polygon2D] = []
	var ancho := float(n) * 4.5
	for i in n:
		var x := -ancho * 0.5 + ancho * (float(i) + 0.5) / float(n)
		var h := rng.randf_range(alto_min, alto_max)
		var curva := rng.randf_range(-0.45, 0.45) * h
		var g := rng.randf_range(1.8, 3.0)
		var izq := PackedVector2Array()
		var der := PackedVector2Array()
		for k in 5:
			var f := float(k) / 4.0
			var p := Vector2(x + curva * f * f, -h * f)
			var w := g * (1.0 - f)
			izq.append(p + Vector2(-w, 0))
			der.insert(0, p + Vector2(w, 0))
		out.append(_poligono(izq + der, color))
	return out


## Piedra redondeada de base plana con una mancha de luz arriba.
func _piedra(rng: RandomNumberGenerator, color: Color, color_luz: Color) -> Array[Polygon2D]:
	var rx := rng.randf_range(22.0, 34.0)
	var ry := rng.randf_range(13.0, 19.0)
	var out: Array[Polygon2D] = []
	out.append(_poligono(_medio_circulo(Vector2.ZERO, rx, ry), color))
	out.append(_poligono(_circulo(Vector2(-rx * 0.2, -ry * 0.62), ry * 0.32, 12), color_luz))
	return out


## Rama que cuelga desde arriba (0,0 = cuelgue) con racimos de hojas en círculos.
func _rama_colgante(rng: RandomNumberGenerator, color: Color, color_luz: Color) -> Array[Polygon2D]:
	var out: Array[Polygon2D] = []
	var largo := rng.randf_range(90.0, 140.0)
	var dx := rng.randf_range(-30.0, 30.0)
	var izq := PackedVector2Array()
	var der := PackedVector2Array()
	for k in 7:
		var f := float(k) / 6.0
		var p := Vector2(dx * f * f, largo * f)
		var w := lerpf(6.0, 1.5, f)
		izq.append(p + Vector2(-w, 0))
		der.insert(0, p + Vector2(w, 0))
	out.append(_poligono(izq + der, color))
	for i in 3 + rng.randi() % 3:
		var f := rng.randf_range(0.35, 1.0)
		var p := Vector2(dx * f * f + rng.randf_range(-14.0, 14.0), largo * f)
		out += _copa(rng, p, Vector2(20.0, 13.0) * rng.randf_range(0.8, 1.2), 5, color, color_luz)
	return out


## Rama como cinta que se afina de `grosor_a` a `grosor_b`.
func _rama(a: Vector2, b: Vector2, grosor_a: float, grosor_b: float, color: Color) -> Polygon2D:
	var n := (b - a).orthogonal().normalized()
	return _poligono(PackedVector2Array([a + n * grosor_a, b + n * grosor_b, b - n * grosor_b, a - n * grosor_a]), color)


func _aclarar(c: Color, cuanto: float) -> Color:
	return Color(clampf(c.r + cuanto, 0.0, 1.0), clampf(c.g + cuanto, 0.0, 1.0), clampf(c.b + cuanto, 0.0, 1.0), c.a)


func _poligono(puntos: PackedVector2Array, color: Color) -> Polygon2D:
	var p := Polygon2D.new()
	p.polygon = puntos
	p.color = color
	return p


func _circulo(centro: Vector2, r: float, n: int) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in n:
		var a := TAU * float(i) / float(n)
		pts.append(centro + Vector2(cos(a), sin(a)) * r)
	return pts


## Media elipse hacia arriba con la base plana en y = centro.y.
func _medio_circulo(centro: Vector2, rx: float, ry: float) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in 17:
		var a := PI + PI * float(i) / 16.0
		pts.append(centro + Vector2(cos(a) * rx, sin(a) * ry))
	return pts


func _elipse_sombra() -> PackedVector2Array:
	var ancho := maxf(_ancho_silueta_base() * escala * 0.85, 24.0)
	var alto := maxf(ancho * 0.22, 6.0)
	var pts := PackedVector2Array()
	for i in 14:
		var a := TAU * float(i) / 14.0
		pts.append(Vector2(cos(a) * ancho * 0.5, sin(a) * alto * 0.5))
	return pts


func _ancho_silueta_base() -> float:
	match tipo:
		Tipo.SAUCE:
			return 30.0
		Tipo.ARBUSTO:
			return 80.0
		Tipo.PIEDRA:
			return 60.0
	return 90.0
