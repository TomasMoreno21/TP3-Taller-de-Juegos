class_name JuiceFx
## Efectos sueltos de "juice" que usan varios objetos del juego (romper cosas, grietas, notas).

static var _nota_idx := 0
static var _nota_ms := 0
## Semitonos de una escala pentatónica que sube con cada cristal roto seguido.
const ESCALA: Array[int] = [0, 2, 4, 7, 9, 12, 14, 16, 19, 21]


## Esquirlas pesadas que saltan y caen al romper algo (muro, caja, cristal).
static func escombros(arbol: SceneTree, pos: Vector2, color: Color, cantidad: int = 10, fuerza: float = 1.0) -> void:
	if DisplayServer.get_name() == "headless" or arbol == null:
		return
	var e := Escombros.new()
	e.color = color
	e.cantidad = cantidad
	e.fuerza = fuerza
	e.position = pos
	e.z_index = 20
	arbol.root.add_child(e)


## Grietas que se abren en el piso desde un punto (aterrizaje y pisotón del Oso).
static func grietas_suelo(arbol: SceneTree, pos: Vector2, radio: float) -> void:
	if DisplayServer.get_name() == "headless" or arbol == null:
		return
	var g := GrietasSuelo.new()
	g.radio = radio
	g.position = pos
	g.z_index = 4
	arbol.root.add_child(g)


## Dibuja un instante, casi invisible, los shaders de pantalla para que no haya un tirón la primera vez
## que se usan (el parry y el daño ocurren justo en pleno combate).
static func precalentar(arbol: SceneTree) -> void:
	if arbol == null or arbol.root.get_node_or_null("JuicePrecalentar") != null:
		return
	var capa := CanvasLayer.new()
	capa.name = "JuicePrecalentar"
	capa.layer = 6
	arbol.root.add_child(capa)
	for ruta in ["res://resources/parry_bn.gdshader", "res://resources/dano_pantalla.gdshader"]:
		var m := ShaderMaterial.new()
		m.shader = load(ruta)
		m.set_shader_parameter("cantidad", 0.0)
		var r := ColorRect.new()
		r.size = Vector2(4, 4)
		r.mouse_filter = Control.MOUSE_FILTER_IGNORE
		r.material = m
		capa.add_child(r)
	arbol.create_timer(0.3).timeout.connect(capa.queue_free)


## Campanita de cristal: cada una sube un escalón si se rompen seguidas (≤ 4 s entre ellas).
static func nota_cristal(arbol: SceneTree) -> void:
	if DisplayServer.get_name() == "headless" or arbol == null:
		return
	var ahora := Time.get_ticks_msec()
	if ahora - _nota_ms > 4000:
		_nota_idx = 0
	_nota_ms = ahora
	var semitonos: int = ESCALA[mini(_nota_idx, ESCALA.size() - 1)]
	_nota_idx += 1
	var audio := arbol.root.get_node_or_null("AudioManager")
	if audio != null and audio.has_method("tono"):
		audio.tono(660.0 * pow(2.0, semitonos / 12.0), -9.0)


class Escombros extends Node2D:
	var color := Color(0.5, 0.5, 0.5)
	var cantidad := 10
	var fuerza := 1.0
	var _trozos: Array = []
	var _t := 0.0

	func _ready() -> void:
		for i in cantidad:
			var tam := randf_range(10.0, 26.0) * (0.8 + fuerza * 0.3)
			var pts := PackedVector2Array([
				Vector2(-tam, -tam * 0.6), Vector2(tam * 0.8, -tam * 0.4), Vector2(tam * 0.5, tam * 0.7), Vector2(-tam * 0.7, tam * 0.5)])
			_trozos.append({
				"p": Vector2(randf_range(-30.0, 30.0), randf_range(-40.0, 20.0)),
				"v": Vector2(randf_range(-520.0, 520.0), randf_range(-950.0, -300.0)) * fuerza,
				"r": randf() * TAU, "w": randf_range(-9.0, 9.0), "pts": pts,
				"c": color.lerp(Color.BLACK, randf_range(0.0, 0.35)),
			})

	func _process(delta: float) -> void:
		_t += delta
		for t in _trozos:
			var v: Vector2 = t["v"]
			v.y += 2600.0 * delta
			t["v"] = v
			t["p"] = (t["p"] as Vector2) + v * delta
			t["r"] = float(t["r"]) + float(t["w"]) * delta
		modulate.a = clampf(1.0 - (_t - 0.5) / 0.5, 0.0, 1.0)
		queue_redraw()
		if _t >= 1.0:
			queue_free()

	func _draw() -> void:
		for t in _trozos:
			draw_set_transform(t["p"], t["r"], Vector2.ONE)
			draw_colored_polygon(t["pts"], t["c"])


class GrietasSuelo extends Node2D:
	var radio := 400.0
	var _lineas: Array = []
	var _t := 0.0

	func _ready() -> void:
		for lado in [-1, 1]:
			for k in 4:
				var pts := PackedVector2Array([Vector2.ZERO])
				var x := 0.0
				var y := 0.0
				var largo := radio * randf_range(0.5, 1.0) * (1.0 - k * 0.12)
				while absf(x) < largo:
					x += lado * randf_range(30.0, 70.0)
					y = randf_range(-6.0, 14.0) * (1.0 + k * 0.6)
					pts.append(Vector2(x, y))
				_lineas.append(pts)

	func _process(delta: float) -> void:
		_t += delta
		queue_redraw()
		if _t >= 1.6:
			queue_free()

	func _draw() -> void:
		var abrir := clampf(_t / 0.12, 0.0, 1.0)
		var a := clampf(1.0 - (_t - 0.9) / 0.7, 0.0, 1.0)
		for pts in _lineas:
			var n := maxi(int(pts.size() * abrir), 2)
			var tramo: PackedVector2Array = pts.slice(0, n)
			draw_polyline(tramo, Color(0.02, 0.02, 0.03, 0.9 * a), 7.0, true)
			draw_polyline(tramo, Color(0.85, 0.8, 0.7, 0.35 * a), 2.0, true)
