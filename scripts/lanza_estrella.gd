extends Area2D
## Lanza de la Estrella: una de sus puntas se estira hasta el piso. Primero AVISO (la punta
## brilla, línea fina y marca en el piso, sin daño), después GOLPE corto (daña una sola vez)
## y se retrae. La configura jefe_estrella.gd antes de add_child (como el proyectil).
## Modo `rayo`: rayo recto de un ojo verde (rectángulo, sin marca en el piso). Si el ojo
## `fuente` se cierra durante el aviso, el rayo se cancela. Un parry del jugador emite `devuelto`.

signal devuelto(pos: Vector2)

var rayo := false
var fuente: Node = null          # ojo que dispara (modo rayo)
var ancho_aviso := 6.0           # grosor de la línea de aviso (el rayo grueso usa una franja ancha)
var desde := Vector2.ZERO        # punta de la estrella (global)
var hasta := Vector2.ZERO        # punto del piso (global)
var dano := 15
var aviso := 0.8
var activo := 0.25               # s con daño
var retraer := 0.3
var ancho := 70.0
var empuje := 260.0
var color := Color(0.95, 0.35, 0.8)
var sonido_aviso: AudioStream    # suena al empezar el aviso (lo fija la Estrella)
var sonido_golpe: AudioStream    # suena al salir la lanza/rayo
var volumen_db := -4.0

var _t := 0.0
var _golpeo := false
var _largo := 0.0
var _punta: Polygon2D
var _linea: Line2D
var _marca: Polygon2D
var _brillo: Polygon2D


var _forma: CollisionShape2D


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
	_forma = forma
	var caja := RectangleShape2D.new()
	caja.size = Vector2(_largo, ancho)
	forma.shape = caja
	forma.position = Vector2(_largo * 0.5, 0)
	add_child(forma)
	# Aviso: línea fina por donde va a pasar, brillo en la punta y marca en el piso.
	_linea = Line2D.new()
	_linea.points = PackedVector2Array([Vector2.ZERO, Vector2(_largo, 0)])
	_linea.width = ancho_aviso
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
	_marca.visible = not rayo
	add_child(_marca)
	# La lanza: triángulo largo que crece desde la punta.
	_punta = Polygon2D.new()
	_punta.polygon = PackedVector2Array([Vector2(0, -ancho * 0.5), Vector2(_largo, -ancho * 0.5), Vector2(_largo, ancho * 0.5), Vector2(0, ancho * 0.5)]) if rayo \
		else PackedVector2Array([Vector2(0, -ancho * 0.5), Vector2(_largo, 0), Vector2(0, ancho * 0.5)])
	_punta.color = color
	_punta.scale = Vector2(0.0, 1.0)
	add_child(_punta)
	_sonar(sonido_aviso)


func _physics_process(delta: float) -> void:
	_t += delta
	if _t < aviso and rayo and fuente != null and (not is_instance_valid(fuente) or not fuente.get("abierto")):
		queue_free()   # cerraron el ojo durante el aviso: el rayo no sale
		return
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
		_sonar(sonido_golpe)
		var cam := get_viewport().get_camera_2d()
		if cam != null and cam.has_method("shake"):
			cam.shake(6.0, 0.15)
		Burst.emitir(self, hasta, color, 10, 1.0)
	var t_golpe := _t - aviso
	if t_golpe <= activo:
		if not _golpeo:
			for b in get_overlapping_bodies():
				if b.is_in_group("player") and b.has_method("take_damage"):
					if b.has_method("toca_cuerpo") and not b.toca_cuerpo(_forma.shape, _forma.global_transform):
						continue   # solo rozó las patas invisibles
					if float(b.get("_invuln_timer") if b.get("_invuln_timer") != null else 0.0) > 0.0:
						continue   # invulnerable ahora: el golpe no se gasta, sigue intentando mientras esté activo
					_golpeo = true   # un solo golpe por lanza
					_golpear(b)
					break
		return
	monitoring = false
	var r := (t_golpe - activo) / maxf(retraer, 0.01)
	_punta.scale = Vector2(maxf(1.0 - r, 0.0), 1.0)
	_marca.color.a = maxf(0.5 * (1.0 - r), 0.0)
	if r >= 1.0:
		queue_free()


func _sonar(stream: AudioStream) -> void:
	var audio := get_node_or_null("/root/AudioManager")
	if audio != null and stream != null:
		audio.play_sfx(stream, volumen_db, 0.08)


## Daña al jugador; el empuje se aleja del origen (así la guardia/parry de frente funciona).
func _golpear(b: Node2D) -> void:
	var hubo_parry := [false]
	var al_parry := func() -> void: hubo_parry[0] = true
	if b.has_signal("parry_exitoso"):
		b.parry_exitoso.connect(al_parry)
	# Rayo casi vertical (ojo justo encima/debajo): dir 0 = la guardia cubre desde cualquier lado.
	var dx := b.global_position.x - desde.x
	var dir := 0 if absf(dx) < absf(b.global_position.y - desde.y) * 0.5 else (1 if dx >= 0.0 else -1)
	b.take_damage(dano, empuje, dir)
	if b.has_signal("parry_exitoso") and b.parry_exitoso.is_connected(al_parry):
		b.parry_exitoso.disconnect(al_parry)
	if hubo_parry[0]:
		devuelto.emit(b.global_position)


func _circulo(radio: float) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in 16:
		var a := TAU * float(i) / 16.0
		pts.append(Vector2(cos(a), sin(a)) * radio)
	return pts
