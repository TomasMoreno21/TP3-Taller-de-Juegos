@tool
extends Node2D
## Decorativo forestal vectorial (sin sprites), con el MISMO lenguaje que el fondo
## del bosque (Boske*.png): siluetas planas en grises, copas hechas de círculos
## superpuestos con manchas internas más claras, troncos que se afinan con vetas y
## ramitas, arbustos festoneados. Anclado al suelo (0,0 = pie), con sombra y viento
## opcionales. Detrás del jugador va en un contenedor z=-5; los tipos *_FRENTE /
## RAMA_COLGANTE / PASTO_ALTO son para el primer plano (ver primer_plano.gd).

## ESTALAGMITA..ESTATUA: utilería de cueva (nivel 2); antorcha, brasero, velas, círculo,
## glifo y estatua (ojos) llevan luz/fuego animado (nodo "Brillo"). Se generan en
## _generar_silueta_cueva / _generar_brillo.
enum Tipo { ARBOL, SAUCE, ARBUSTO, PASTO, PIEDRA, TRONCO_FRENTE, RAMA_COLGANTE, PASTO_ALTO,
	ESTALAGMITA, ESTALACTITA, CRISTAL, ANTORCHA, BRASERO, VELAS, ESTANDARTE, CADENAS, HUESOS,
	CIRCULO, GLIFO, JAULA, ESTATUA }

const COLORES_CUEVA := {
	Tipo.ESTALAGMITA: { "copa": Color(0.20, 0.20, 0.27) },
	Tipo.ESTALACTITA: { "copa": Color(0.17, 0.17, 0.24) },
	Tipo.CRISTAL: { "copa": Color(0.32, 0.62, 0.90) },
	Tipo.ANTORCHA: { "copa": Color(0.20, 0.17, 0.16), "tronco": Color(0.30, 0.20, 0.13) },
	Tipo.BRASERO: { "copa": Color(0.19, 0.16, 0.17), "tronco": Color(0.26, 0.22, 0.22) },
	Tipo.VELAS: { "copa": Color(0.80, 0.75, 0.62), "tronco": Color(0.55, 0.50, 0.42) },
	Tipo.ESTANDARTE: { "copa": Color(0.34, 0.08, 0.20), "tronco": Color(0.16, 0.12, 0.10) },
	Tipo.CADENAS: { "copa": Color(0.25, 0.24, 0.28) },
	Tipo.HUESOS: { "copa": Color(0.70, 0.65, 0.55) },
	Tipo.CIRCULO: { "copa": Color(0.68, 0.26, 0.80) },
	Tipo.GLIFO: { "copa": Color(0.72, 0.28, 0.84) },
	Tipo.JAULA: { "copa": Color(0.24, 0.22, 0.25) },
	Tipo.ESTATUA: { "copa": Color(0.32, 0.31, 0.42), "tronco": Color(0.2, 0.2, 0.28) },
}
const COLOR_FUEGO := [Color(1.0, 0.42, 0.10), Color(1.0, 0.72, 0.26), Color(1.0, 0.94, 0.62)]
const LUZ_RADIAL := preload("res://resources/luz_radial.tres")

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
## Solo CRISTAL: color y fuerza del halo aditivo (0 = sin halo).
@export var halo_color := Color(0.35, 0.7, 1.0)
@export_range(0.0, 1.0) var halo_alpha := 0.45
## Parpadeo de fuego / pulso de luz (antorcha, brasero, velas, círculo, glifo, ojos de estatua).
@export var parpadeo := true
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
## Arbustos y pastos se apartan al pasar el jugador y se sacuden con golpes fuertes cercanos.
@export var reactivo := true
@export var reaccion_angulo := 0.28      # rad máx. que se dobla al pasar el jugador
@export var reaccion_margen := 50.0      # px extra de alcance más allá del ancho de la silueta
@export var reaccion_rigidez := 55.0     # vuelta a la posición (más alto = más rápido)
@export var reaccion_amort := 6.5        # freno (más bajo = más bamboleo)

var _tmp := Vector4.ZERO
var _editor_sync := true
var _fase_viento := 0.0
var _hoja: Node2D
var _sombra: Polygon2D
var _brillo: Node2D
var _llamas: Array[Node2D] = []
var _halos: Array[Sprite2D] = []
var _rx := 0.0                # ángulo de reacción (resorte)
var _rv := 0.0
var _jugador: Node2D


func _ready() -> void:
	_fase_viento = randf() * TAU
	_rehacer()
	if reactivo and not Engine.is_editor_hint() and tipo in [Tipo.ARBUSTO, Tipo.PASTO, Tipo.PASTO_ALTO]:
		add_to_group("reactivo")


## Golpe fuerte en `pos` (lo llama Ambiente): la mata se inclina lejos del origen del golpe.
func empujar(pos: Vector2, fuerza: float) -> void:
	if not is_inside_tree() or _hoja == null:
		return
	var dx := global_position.x - pos.x
	var dy := absf(global_position.y - pos.y)
	if absf(dx) > 800.0 or dy > 500.0:
		return
	var cerca := 1.0 - absf(dx) / 800.0
	_rv += (1.0 if dx >= 0.0 else -1.0) * fuerza * cerca * 7.0


## Reacción al jugador: se dobla en el sentido en que corre y lejos de su cuerpo (resorte, no tween).
func _reaccionar(delta: float) -> void:
	var objetivo := 0.0
	if _jugador == null or not is_instance_valid(_jugador):
		_jugador = get_tree().get_first_node_in_group("player") as Node2D
	if _jugador != null:
		var dx := _jugador.global_position.x - global_position.x
		var dy := _jugador.global_position.y - global_position.y
		var alcance := _ancho_silueta_base() * escala * 0.5 + reaccion_margen
		# Lejos del jugador y en reposo no hay nada que calcular (hay cientos de matas en el nivel).
		if absf(dx) > alcance + 900.0 and absf(_rx) < 0.0005 and absf(_rv) < 0.0005:
			return
		if absf(dx) < alcance and dy > -320.0 and dy < 120.0:
			var cerca := 1.0 - absf(dx) / alcance
			var vx := 0.0
			if "velocity" in _jugador:
				vx = clampf(float(_jugador.velocity.x) / 320.0, -1.0, 1.0)
			objetivo = clampf(vx * 0.7 - signf(dx) * 0.3, -1.0, 1.0) * cerca * reaccion_angulo
	var d := minf(delta, 1.0 / 30.0)
	_rv += (-reaccion_rigidez * (_rx - objetivo) - reaccion_amort * _rv) * d
	_rx = clampf(_rx + _rv * d, -0.6, 0.6)


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
	if _hoja != null:
		var rot_viento := 0.0
		if viento:
			var t := Time.get_ticks_msec() * 0.001 * viento_velocidad + _fase_viento
			rot_viento = sin(t) * viento_amplitud
		if reactivo and is_in_group("reactivo"):
			_reaccionar(delta)
		_hoja.rotation = rot_viento + _rx
	if parpadeo and _brillo != null:
		var tp := Time.get_ticks_msec() * 0.001 + _fase_viento
		for i in _llamas.size():
			var f := tp * (7.0 + float(i % 3)) + float(i) * 1.7
			_llamas[i].scale = Vector2(1.0 + 0.10 * sin(f * 1.3), 1.0 + 0.16 * sin(f) + 0.06 * sin(f * 2.9))
			_llamas[i].rotation = 0.07 * sin(f * 0.8)
		for h in _halos:
			var base: float = h.get_meta("alpha")
			h.modulate.a = base * (0.82 + 0.18 * sin(tp * 5.0) + 0.06 * sin(tp * 13.0))


## Colores, flip y escala sin redibujar.
func _aplicar_config() -> void:
	if _hoja != null:
		_hoja.scale = Vector2(escala * (-1.0 if flip_h else 1.0), escala)
		_hoja.modulate = color_noche
	if _brillo != null:
		_brillo.scale = Vector2(escala * (-1.0 if flip_h else 1.0), escala)
	if _sombra != null:
		_sombra.visible = sombra and _lleva_sombra()
		_sombra.color.a = sombra_alpha


## Reconstruye la silueta completa (idempotente: limpia y vuelve a crear).
func _rehacer() -> void:
	for nodo in ["Hoja", "Sombra", "Brillo"]:
		var old := get_node_or_null(nodo)
		if old != null:
			remove_child(old)
			old.queue_free()
	_llamas.clear()
	_halos.clear()
	_brillo = null
	_hoja = Node2D.new()
	_hoja.name = "Hoja"
	add_child(_hoja)
	for pol in _generar_silueta(tipo, variante):
		_hoja.add_child(pol)
	if tipo == Tipo.CRISTAL and halo_alpha > 0.0:
		var halo := Sprite2D.new()
		halo.name = "Halo"
		halo.texture = LUZ_RADIAL
		halo.position = Vector2(0, -22)
		halo.scale = Vector2(0.35, 0.35)
		halo.modulate = Color(halo_color.r, halo_color.g, halo_color.b, halo_alpha)
		var mat := CanvasItemMaterial.new()
		mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
		mat.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
		halo.material = mat
		_hoja.add_child(halo)
	var brillo := _generar_brillo(tipo, variante)
	if not brillo.is_empty():
		_brillo = Node2D.new()
		_brillo.name = "Brillo"
		add_child(_brillo)
		for n in brillo:
			_brillo.add_child(n)
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
	if t >= Tipo.ESTALAGMITA:
		return _generar_silueta_cueva(t, v)
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


# ------------------------------------------------------------------ utilería de cueva
func _generar_silueta_cueva(t: int, v: int) -> Array[Polygon2D]:
	var colores: Dictionary = COLORES_CUEVA[t]
	var salida: Array[Polygon2D] = []
	var tinte := 1.0 + 0.12 * float((v - 1) % 4) - 0.06
	match t:
		Tipo.ESTALAGMITA:
			var h := 34.0 + float((v - 1) % 5) * 9.0
			var w := 11.0 + float((v - 1) % 3) * 3.0
			salida += [_poligono([Vector2(-w, 0), Vector2(-w * 0.6, -h * 0.55), Vector2(-w * 0.12, -h), Vector2(w * 0.3, -h * 0.62), Vector2(w, 0)], colores["copa"] * tinte)]
			salida += [_poligono([Vector2(w * 0.6, 0), Vector2(w * 1.5, -h * 0.4), Vector2(w * 2.2, 0)], colores["copa"] * (tinte * 0.85))]
			salida += [_poligono([Vector2(-w * 0.1, 0), Vector2(-w * 0.1, -h * 0.9), Vector2(w * 0.3, -h * 0.6), Vector2(w * 0.5, 0)], (colores["copa"] as Color).lightened(0.12) * tinte)]
		Tipo.ESTALACTITA:
			var h := 40.0 + float((v - 1) % 5) * 12.0
			var w := 12.0 + float((v - 1) % 3) * 3.0
			salida += [_poligono([Vector2(-w, 0), Vector2(-w * 0.55, h * 0.5), Vector2(w * 0.05, h), Vector2(w * 0.5, h * 0.55), Vector2(w, 0)], colores["copa"] * tinte)]
			salida += [_poligono([Vector2(-w * 2.0, 0), Vector2(-w * 1.4, h * 0.35), Vector2(-w * 0.9, 0)], colores["copa"] * (tinte * 0.85))]
		Tipo.CRISTAL:
			var c: Color = colores["copa"]
			var n := 3 + (v - 1) % 2
			for i in n:
				var dx := (float(i) - float(n - 1) * 0.5) * 12.0
				var hh := 26.0 + float(((v - 1) + i * 2) % 4) * 8.0
				var ww := 5.5 + float(i % 2) * 1.5
				var ang := (float(i) - float(n - 1) * 0.5) * 0.28
				var base := Vector2(dx, 0)
				var pts := PackedVector2Array([Vector2(-ww, 0), Vector2(-ww, -hh * 0.7), Vector2(0, -hh), Vector2(ww, -hh * 0.7), Vector2(ww, 0)])
				for k in pts.size():
					pts[k] = base + pts[k].rotated(ang)
				salida += [_poligono(pts, c * (0.85 + 0.1 * float(i % 2)))]
				var luz := PackedVector2Array([Vector2(-ww * 0.2, -2), Vector2(-ww * 0.2, -hh * 0.72), Vector2(0, -hh * 0.95), Vector2(ww * 0.1, -hh * 0.7), Vector2(ww * 0.1, -2)])
				for k in luz.size():
					luz[k] = base + luz[k].rotated(ang)
				salida += [_poligono(luz, c.lightened(0.45))]
		Tipo.ANTORCHA:
			var fe: Color = colores["copa"]
			salida += [_poligono([Vector2(-2.4, 0), Vector2(-2.8, -30), Vector2(2.8, -30), Vector2(2.4, 0)], colores["tronco"] * tinte)]
			salida += [_poligono([Vector2(-7, -27), Vector2(-8, -39), Vector2(8, -39), Vector2(7, -27), Vector2(2.5, -22), Vector2(-2.5, -22)], fe)]
			salida += [_poligono([Vector2(-4, -16), Vector2(4, -16), Vector2(4, -13), Vector2(-4, -13)], fe)]
			salida += [_poligono([Vector2(-8, -39), Vector2(8, -39), Vector2(7, -36.5), Vector2(-7, -36.5)], fe.lightened(0.25))]
		Tipo.BRASERO:
			var fe: Color = colores["copa"]
			salida += [_poligono([Vector2(-15, 0), Vector2(-11, 0), Vector2(-3, -26), Vector2(-6, -26)], colores["tronco"])]
			salida += [_poligono([Vector2(15, 0), Vector2(11, 0), Vector2(3, -26), Vector2(6, -26)], colores["tronco"])]
			salida += [_poligono([Vector2(-2, 0), Vector2(2, 0), Vector2(2, -26), Vector2(-2, -26)], colores["tronco"])]
			var cuenco := PackedVector2Array()
			for k in 9:
				var a := PI * float(k) / 8.0
				cuenco.append(Vector2(cos(a) * 18.0, -29.0 + sin(a) * 11.0))
			salida += [_poligono(cuenco, fe)]
			salida += [_poligono([Vector2(-20, -32), Vector2(20, -32), Vector2(19, -28.5), Vector2(-19, -28.5)], fe.lightened(0.22))]
			salida += [_poligono([Vector2(-10, -29), Vector2(10, -29), Vector2(9, -33), Vector2(-9, -33)], Color(0.55, 0.2, 0.05))]
		Tipo.VELAS:
			var cera: Color = colores["copa"]
			var nv := 3 + (v - 1) % 3
			salida += [_poligono(_elipse(Vector2(0, -1.5), Vector2(6.0 + 3.0 * float(nv), 2.6), 12), colores["tronco"])]
			for i in nv:
				var vx := (float(i) - float(nv - 1) * 0.5) * 9.0
				var vh := 10.0 + float(((v - 1) + i * 5) % 4) * 6.0
				salida += [_poligono([Vector2(vx - 2.6, -1), Vector2(vx - 2.4, -vh), Vector2(vx + 2.4, -vh), Vector2(vx + 2.6, -1)], cera * (0.9 + 0.1 * float(i % 2)))]
				salida += [_poligono([Vector2(vx - 2.4, -vh), Vector2(vx - 0.6, -vh + 5.0), Vector2(vx + 0.8, -vh + 2.0), Vector2(vx + 2.4, -vh)], cera.lightened(0.25))]
		Tipo.ESTANDARTE:
			var tela: Color = colores["copa"] * tinte
			var varilla: Color = colores["tronco"]
			salida += [_poligono([Vector2(-1.4, -22), Vector2(-1.4, 0), Vector2(1.4, 0), Vector2(1.4, -22)], varilla)]
			salida += [_poligono([Vector2(-30, -3), Vector2(30, -3), Vector2(30, 2), Vector2(-30, 2)], varilla)]
			salida += [_poligono(_elipse(Vector2(-30, -0.5), Vector2(3.5, 3.5), 8), varilla.lightened(0.2))]
			salida += [_poligono(_elipse(Vector2(30, -0.5), Vector2(3.5, 3.5), 8), varilla.lightened(0.2))]
			var largo := 84.0 + float((v - 1) % 3) * 16.0
			if v % 2 == 0:
				salida += [_poligono([Vector2(-24, 2), Vector2(24, 2), Vector2(24, largo - 6.0), Vector2(15, largo - 14.0), Vector2(8, largo), Vector2(0, largo - 12.0), Vector2(-7, largo - 4.0), Vector2(-16, largo - 16.0), Vector2(-24, largo - 8.0)], tela)]
			else:
				salida += [_poligono([Vector2(-24, 2), Vector2(24, 2), Vector2(24, largo - 6.0), Vector2(0, largo + 10.0), Vector2(-24, largo - 6.0)], tela)]
			salida += [_poligono([Vector2(-24, 2), Vector2(-19, 2), Vector2(-19, largo - 9.0), Vector2(-24, largo - 6.0)], tela.darkened(0.35))]
			salida += [_poligono([Vector2(24, 2), Vector2(19, 2), Vector2(19, largo - 9.0), Vector2(24, largo - 6.0)], tela.darkened(0.35))]
			var oro := Color(0.78, 0.55, 0.28)
			salida += [_poligono(_elipse(Vector2(0, largo * 0.36), Vector2(10, 10), 14), tela.darkened(0.45))]
			salida += [_poligono([Vector2(-9, largo * 0.36), Vector2(0, largo * 0.36 - 5.0), Vector2(9, largo * 0.36), Vector2(0, largo * 0.36 + 5.0)], oro)]
			salida += [_poligono(_elipse(Vector2(0, largo * 0.36), Vector2(2.4, 2.4), 8), tela.darkened(0.6))]
		Tipo.CADENAS:
			var hierro: Color = colores["copa"] * tinte
			var eslabones := 7 + (v - 1) % 5 * 3
			salida += [_poligono(_elipse(Vector2(0, -2), Vector2(5, 3), 8), hierro.lightened(0.15))]
			for i in eslabones:
				var frontal := i % 2 == 0
				var rx := 3.4 if frontal else 1.3
				salida += [_poligono(_elipse(Vector2(0, 4.0 + float(i) * 7.0), Vector2(rx, 5.2), 8), hierro if frontal else hierro.lightened(0.18))]
				if frontal:
					salida += [_poligono(_elipse(Vector2(0, 4.0 + float(i) * 7.0), Vector2(1.3, 3.0), 6), Color(0.03, 0.03, 0.05))]
			var fin := 4.0 + float(eslabones) * 7.0
			salida += [_poligono([Vector2(-4, fin), Vector2(4, fin), Vector2(0, fin + 12.0)], hierro.lightened(0.1))]
		Tipo.HUESOS:
			var hueso: Color = colores["copa"] * tinte
			var fila_y := [-5.5, -5.5, -5.5, -15.5, -15.5, -25.5]
			var fila_x := [-12.5, 0.0, 12.5, -6.5, 6.5, 0.0]
			var cuantos := 3 + (v - 1) % 4
			salida += [_poligono([Vector2(-22, 0), Vector2(20, 0), Vector2(15, -3), Vector2(-16, -3)], Color(0.10, 0.08, 0.09))]
			for i in cuantos:
				var c := Vector2(float(fila_x[i]) + float(((v + i) % 3) - 1) * 1.2, float(fila_y[i]))
				salida += _calavera(c, hueso * (0.92 + 0.1 * float((i + v) % 3)), 0.0 if (i + v) % 2 == 0 else 0.25)
			salida += [_poligono([Vector2(-26, -2.5), Vector2(-9, -8), Vector2(-8, -6), Vector2(-25, -0.5)], hueso.darkened(0.12))]
			salida += [_poligono([Vector2(9, -7), Vector2(27, -1), Vector2(26, 1.5), Vector2(8, -4)], hueso.darkened(0.12))]
		Tipo.JAULA:
			var fe: Color = colores["copa"]
			salida += [_poligono([Vector2(-1.2, -30), Vector2(-1.2, 16), Vector2(1.2, 16), Vector2(1.2, -30)], fe.lightened(0.1))]
			salida += [_poligono(_elipse(Vector2(0, 17), Vector2(4, 4), 8), fe.lightened(0.15))]
			salida += [_poligono([Vector2(-14, 27), Vector2(-13, 62), Vector2(13, 62), Vector2(14, 27), Vector2(0, 14)], Color(0.04, 0.03, 0.05))]
			if v % 2 == 1:
				salida += _calavera(Vector2(-2, 56), fe.lightened(0.5), 0.3)
			for i in 6:
				var bx := -12.5 + float(i) * 5.0
				salida += [_poligono([Vector2(bx - 0.9, 26), Vector2(bx - 0.9, 63), Vector2(bx + 0.9, 63), Vector2(bx + 0.9, 26)], fe)]
			salida += [_poligono([Vector2(-16, 27), Vector2(0, 12), Vector2(16, 27), Vector2(13, 29), Vector2(-13, 29)], fe.lightened(0.12))]
			salida += [_poligono([Vector2(-16, 61), Vector2(16, 61), Vector2(13, 67), Vector2(-13, 67)], fe.lightened(0.12))]
		Tipo.ESTATUA:
			var piedra: Color = colores["copa"] * tinte
			var oscuro: Color = colores["tronco"]
			salida += [_poligono([Vector2(-24, 0), Vector2(-24, -9), Vector2(-20, -9), Vector2(-20, -14), Vector2(20, -14), Vector2(20, -9), Vector2(24, -9), Vector2(24, 0)], oscuro.lightened(0.05))]
			salida += [_poligono([Vector2(-18, -14), Vector2(-13, -60), Vector2(13, -60), Vector2(18, -14)], piedra)]
			salida += [_poligono([Vector2(-13, -60), Vector2(-9, -82), Vector2(0, -108), Vector2(9, -82), Vector2(13, -60)], piedra.lightened(0.06))]
			salida += [_poligono([Vector2(-5.5, -64), Vector2(-4.5, -82), Vector2(0, -90), Vector2(4.5, -82), Vector2(5.5, -64)], Color(0.02, 0.02, 0.04))]
			salida += [_poligono([Vector2(-15, -48), Vector2(15, -48), Vector2(12, -38), Vector2(-12, -38)], piedra.darkened(0.25))]
			salida += [_poligono([Vector2(-18, -14), Vector2(-14.5, -14), Vector2(-10.5, -60), Vector2(-13, -60)], piedra.lightened(0.28))]
	return salida


## Calavera frontal simple (cráneo, mandíbula, cuencas y nariz).
func _calavera(c: Vector2, hueso: Color, inclina: float) -> Array[Polygon2D]:
	var pol: Array[Polygon2D] = []
	var oscuro := Color(0.05, 0.04, 0.05)
	pol.append(_poligono(_girar(_elipse(Vector2.ZERO, Vector2(6.2, 5.6), 12), c, inclina), hueso))
	pol.append(_poligono(_girar(PackedVector2Array([Vector2(-3.6, 3.2), Vector2(3.6, 3.2), Vector2(3.0, 7.2), Vector2(-3.0, 7.2)]), c, inclina), hueso.darkened(0.08)))
	pol.append(_poligono(_girar(_elipse(Vector2(-2.5, -0.4), Vector2(1.6, 1.9), 6), c, inclina), oscuro))
	pol.append(_poligono(_girar(_elipse(Vector2(2.5, -0.4), Vector2(1.6, 1.9), 6), c, inclina), oscuro))
	pol.append(_poligono(_girar(PackedVector2Array([Vector2(0, 1.6), Vector2(-0.9, 3.4), Vector2(0.9, 3.4)]), c, inclina), oscuro))
	return pol


func _girar(pts: PackedVector2Array, c: Vector2, ang: float) -> PackedVector2Array:
	var r := PackedVector2Array()
	for q in pts:
		r.append(c + q.rotated(ang))
	return r


## Fuego, luces y glifos brillantes (no se tiñen con color_noche; llevan parpadeo).
func _generar_brillo(t: int, v: int) -> Array[Node2D]:
	var res: Array[Node2D] = []
	match t:
		Tipo.ANTORCHA:
			res += _fuego(Vector2(0, -38), 27.0, 8.5, 62.0, 0.5)
		Tipo.BRASERO:
			res += _fuego(Vector2(0, -31), 38.0, 14.0, 105.0, 0.55)
			res += _fuego(Vector2(-9, -31), 21.0, 6.0, 0.0, 0.0)
			res += _fuego(Vector2(9, -31), 24.0, 6.5, 0.0, 0.0)
		Tipo.VELAS:
			var nv := 3 + (v - 1) % 3
			for i in nv:
				var vx := (float(i) - float(nv - 1) * 0.5) * 9.0
				var vh := 10.0 + float(((v - 1) + i * 5) % 4) * 6.0
				res += _fuego(Vector2(vx, -vh - 1.0), 8.0, 2.6, 0.0, 0.0)
			res += _halo(Vector2(0, -14), 0.34, 0.4, Color(1.0, 0.6, 0.25))
		Tipo.CIRCULO:
			var vio: Color = COLORES_CUEVA[Tipo.CIRCULO]["copa"]
			vio.a = 0.85
			res += [_linea_elipse(Vector2(0, -6), Vector2(74, 8.5), vio, 1.8)]
			res += [_linea_elipse(Vector2(0, -6), Vector2(54, 6.0), Color(vio.r, vio.g, vio.b, 0.55), 1.2)]
			for i in 8:
				var a := TAU * float(i) / 8.0 + 0.2
				var px := cos(a) * 64.0
				var py := -1.0 + sin(a) * 6.3
				var l := Line2D.new()
				l.points = PackedVector2Array([Vector2(px, py), Vector2(px, py - 7.0 - float((i + v) % 3) * 3.0)])
				l.width = 1.6
				l.default_color = Color(vio.r, vio.g, vio.b, 0.75)
				res.append(l)
			var col := Polygon2D.new()
			col.polygon = PackedVector2Array([Vector2(-60, -1), Vector2(60, -1), Vector2(42, -78), Vector2(-42, -78)])
			col.vertex_colors = PackedColorArray([Color(vio.r, vio.g, vio.b, 0.22), Color(vio.r, vio.g, vio.b, 0.22), Color(vio.r, vio.g, vio.b, 0.0), Color(vio.r, vio.g, vio.b, 0.0)])
			res.append(col)
			var hl := _halo(Vector2(0, -3), 1.0, 0.16, Color(0.62, 0.22, 0.85))
			(hl[0] as Sprite2D).scale = Vector2(1.1, 0.14)
			res += hl
		Tipo.GLIFO:
			var vio: Color = COLORES_CUEVA[Tipo.GLIFO]["copa"]
			vio.a = 0.7
			res += [_linea_elipse(Vector2.ZERO, Vector2(46, 46), vio, 2.4)]
			res += [_linea_elipse(Vector2.ZERO, Vector2(38, 38), Color(vio.r, vio.g, vio.b, 0.45), 1.3)]
			for i in 16:
				var a := TAU * float(i) / 16.0
				var l := Line2D.new()
				l.points = PackedVector2Array([Vector2(cos(a), sin(a)) * 39.0, Vector2(cos(a), sin(a)) * 46.0])
				l.width = 1.5
				l.default_color = Color(vio.r, vio.g, vio.b, 0.6)
				res.append(l)
			var triangulos := 2 if v % 2 == 0 else 1
			for k in triangulos:
				var tri := PackedVector2Array()
				for i in 3:
					tri.append(Vector2.from_angle(-PI * 0.5 + TAU * float(i) / 3.0 + PI * float(k)) * 31.0)
				var lt := Line2D.new()
				lt.points = tri
				lt.closed = true
				lt.width = 1.6
				lt.default_color = Color(vio.r, vio.g, vio.b, 0.55)
				res.append(lt)
			res += [_linea_elipse(Vector2.ZERO, Vector2(13, 6.5), Color(vio.r, vio.g, vio.b, 0.85), 1.8)]
			var iris := Polygon2D.new()
			iris.polygon = _elipse(Vector2.ZERO, Vector2(3.6, 3.6), 10)
			iris.color = Color(1.0, 0.45, 0.6, 0.9)
			res.append(iris)
			res += _halo(Vector2.ZERO, 0.85, 0.16, Color(0.62, 0.22, 0.85))
		Tipo.ESTATUA:
			if v % 2 == 1:
				for sx in [-2.6, 2.6]:
					res += _halo(Vector2(sx, -77), 0.09, 0.9, Color(1.0, 0.18, 0.28))
	return res


## Llama de 3 capas (naranja, ámbar, núcleo) + halo aditivo cálido opcional.
func _fuego(pos: Vector2, alto: float, ancho: float, radio_halo: float, alpha_halo: float) -> Array[Node2D]:
	var res: Array[Node2D] = []
	for k in 3:
		var f := 1.0 - 0.3 * float(k)
		var lla := Polygon2D.new()
		lla.polygon = _gota(alto * f, ancho * f)
		lla.color = COLOR_FUEGO[k]
		lla.position = pos - Vector2(0, float(k))
		res.append(lla)
		_llamas.append(lla)
	if radio_halo > 0.0:
		res += _halo(pos + Vector2(0, -alto * 0.35), radio_halo / 128.0, alpha_halo, Color(1.0, 0.5, 0.18))
	return res


func _gota(alto: float, ancho: float) -> PackedVector2Array:
	return PackedVector2Array([
		Vector2(-ancho, 0), Vector2(-ancho * 0.92, -alto * 0.32), Vector2(-ancho * 0.5, -alto * 0.62),
		Vector2(-ancho * 0.05, -alto), Vector2(ancho * 0.38, -alto * 0.6), Vector2(ancho * 0.92, -alto * 0.3),
		Vector2(ancho, 0), Vector2(ancho * 0.55, ancho * 0.6), Vector2(-ancho * 0.55, ancho * 0.6)])


func _halo(pos: Vector2, esc: float, alpha: float, color: Color) -> Array[Node2D]:
	var h := Sprite2D.new()
	h.texture = LUZ_RADIAL
	h.position = pos
	h.scale = Vector2(esc, esc)
	h.modulate = Color(color.r, color.g, color.b, alpha)
	h.set_meta("alpha", alpha)
	var mat := CanvasItemMaterial.new()
	mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	mat.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
	h.material = mat
	_halos.append(h)
	var res: Array[Node2D] = [h]
	return res


func _linea_elipse(centro: Vector2, radios: Vector2, color: Color, ancho: float) -> Line2D:
	var l := Line2D.new()
	l.points = _elipse(centro, radios, 28)
	l.closed = true
	l.width = ancho
	l.default_color = color
	return l


func _elipse(centro: Vector2, radios: Vector2, n: int) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in n:
		var a := TAU * float(i) / float(n)
		pts.append(Vector2(centro.x + cos(a) * radios.x, centro.y + sin(a) * radios.y))
	return pts
