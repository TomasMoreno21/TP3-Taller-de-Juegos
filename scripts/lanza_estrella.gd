extends Area2D
## Lanza de la Estrella: una de sus puntas se estira hasta el piso. Primero AVISO (la punta
## brilla, línea fina y marca en el piso, sin daño), después GOLPE corto (daña una sola vez)
## y se retrae. La configura jefe_estrella.gd antes de add_child (como el proyectil).

var desde := Vector2.ZERO        # punta de la estrella (global)
var hasta := Vector2.ZERO        # punto del piso (global)
var dano := 15
var aviso := 0.8
var activo := 0.25               # s con daño
var retraer := 0.3
var ancho := 70.0
var empuje := 260.0
var color := Color(0.95, 0.35, 0.8)

var _t := 0.0
var _golpeo := false
var _largo := 0.0
var _punta: Polygon2D
var _linea: Line2D
var _marca: Polygon2D
var _brillo: Polygon2D


func _ready() -> void:
	collision_layer = 0
	collision_mask = 4   # solo el jugador
	monitoring = false
	z_index = 4
	add_to_group("ataque_jefe")
	global_position = desde
	var v := hasta - desde
	_largo = v.length()
	rotation = v.angle()
	var forma := CollisionShape2D.new()
	var caja := RectangleShape2D.new()
	caja.size = Vector2(_largo, ancho)
	forma.shape = caja
	forma.position = Vector2(_largo * 0.5, 0)
	add_child(forma)
	# Aviso: línea fina por donde va a pasar, brillo en la punta y marca en el piso.
	_linea = Line2D.new()
	_linea.points = PackedVector2Array([Vector2.ZERO, Vector2(_largo, 0)])
	_linea.width = 6.0
	_linea.default_color = Color(color.r, color.g, color.b, 0.3)
	add_child(_linea)
	_brillo = Polygon2D.new()
	_brillo.polygon = _circulo(26.0)
	_brillo.color = Color(1, 0.9, 1, 0.8)
	add_child(_brillo)
	_marca = Polygon2D.new()
	_marca.polygon = PackedVector2Array([Vector2(-ancho, 0), Vector2(0, -12), Vector2(ancho, 0), Vector2(0, 12)])
	_marca.color = Color(color.r, color.g, color.b, 0.5)
	_marca.top_level = true
	_marca.global_position = hasta
	add_child(_marca)
	# La lanza: triángulo largo que crece desde la punta.
	_punta = Polygon2D.new()
	_punta.polygon = PackedVector2Array([Vector2(0, -ancho * 0.5), Vector2(_largo, 0), Vector2(0, ancho * 0.5)])
	_punta.color = color
	_punta.scale = Vector2(0.0, 1.0)
	add_child(_punta)


func _physics_process(delta: float) -> void:
	_t += delta
	if _t < aviso:
		var f := 14.0 + 26.0 * (_t / maxf(aviso, 0.01))
		var a := 0.5 + 0.5 * sin(_t * f)
		_linea.default_color.a = 0.15 + 0.25 * a
		_marca.color.a = 0.3 + 0.5 * a
		_brillo.scale = Vector2.ONE * (0.7 + 0.6 * (_t / maxf(aviso, 0.01)))
		return
	if not monitoring:
		monitoring = true
		_linea.visible = false
		_brillo.visible = false
		_punta.scale = Vector2.ONE
		var cam := get_viewport().get_camera_2d()
		if cam != null and cam.has_method("shake"):
			cam.shake(6.0, 0.15)
		Burst.emitir(self, hasta, color, 10, 1.0)
	var t_golpe := _t - aviso
	if t_golpe <= activo:
		if not _golpeo:
			for b in get_overlapping_bodies():
				if b.is_in_group("player") and b.has_method("take_damage"):
					_golpeo = true   # un solo golpe por lanza
					b.take_damage(dano, empuje, 1 if b.global_position.x >= hasta.x else -1)
					break
		return
	monitoring = false
	var r := (t_golpe - activo) / maxf(retraer, 0.01)
	_punta.scale = Vector2(maxf(1.0 - r, 0.0), 1.0)
	_marca.color.a = maxf(0.5 * (1.0 - r), 0.0)
	if r >= 1.0:
		queue_free()


func _circulo(radio: float) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in 16:
		var a := TAU * float(i) / 16.0
		pts.append(Vector2(cos(a), sin(a)) * radio)
	return pts
