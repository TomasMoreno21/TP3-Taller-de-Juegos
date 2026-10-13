extends Node2D

## Goteo del techo de la cueva: de tanto en tanto, cerca de la cámara, se forma una gota en el techo de roca,
## cae y salpica al tocar el piso. Usa el terreno real (rayos): siempre nace de un techo y llega a un piso.

@export var activo := true
@export var intervalo_min := 1.6          ## s entre gota y gota (se sortea entre min y max)
@export var intervalo_max := 4.2
@export var alcance_x := 1100.0           ## px a cada lado del centro de la cámara donde pueden nacer
@export var busqueda_techo := 900.0       ## px hacia arriba (desde la altura del jugador) para hallar un techo
@export var caida_max := 1500.0           ## una gota que no encuentra piso en esta distancia no se genera
@export var gravedad := 1900.0
@export var formacion := 0.8              ## s que la gota se hincha colgando antes de soltarse
@export var color := Color(0.74, 0.86, 1.0, 0.9)
@export var sonido: AudioStream           ## opcional: "plic" al salpicar (solo si cae a la vista)
@export var sonidos: Array[AudioStream] = []   ## variantes del "plic": si hay, se sortea una en cada gota (reemplaza a `sonido`)
@export var variacion_tono := 0.15
@export_group("Ondas y charcos")
@export var ondas := true                 ## al caer, el agua dibuja anillos que se expanden sobre el piso
@export var charcos := true               ## donde cae el agua sobre piso plano se forma un charco que sigue goteando
@export_range(0.0, 1.0) var prob_charco := 0.3        ## probabilidad de que una gota nueva deje un charco
@export_range(0.0, 1.0) var prob_repetir_charco := 0.45   ## probabilidad de que una gota nueva caiga en un charco ya formado
@export var max_charcos := 6
@export var color_charco := Color(0.5, 0.68, 0.88, 0.32)
@export var volumen_db := -22.0
@export_flags_2d_physics var mascara := 1

var _espera := 1.0
var _charcos: Array = []


func _process(delta: float) -> void:
	if not activo:
		return
	_espera -= delta
	if _espera > 0.0:
		return
	_espera = randf_range(intervalo_min, intervalo_max)
	_nueva_gota()


func _nueva_gota() -> void:
	var cam := get_viewport().get_camera_2d()
	if cam == null:
		return
	var c := cam.get_screen_center_position()
	var jugador := get_tree().get_first_node_in_group("player") as Node2D
	var y0 := jugador.global_position.y if jugador != null else c.y
	var x := c.x + randf_range(-alcance_x, alcance_x)
	_charcos = _charcos.filter(func(ch): return is_instance_valid(ch))
	if charcos and not _charcos.is_empty() and randf() < prob_repetir_charco:
		var ch: Node2D = _charcos[randi() % _charcos.size()]
		if absf(ch.global_position.x - c.x) < alcance_x and absf(ch.global_position.y - y0) < 1400.0:
			x = ch.global_position.x + randf_range(-18.0, 18.0)
			y0 = ch.global_position.y - 6.0
	var espacio := get_world_2d().direct_space_state
	var q := PhysicsRayQueryParameters2D.create(Vector2(x, y0), Vector2(x, y0 - busqueda_techo))
	q.collision_mask = mascara
	var techo := espacio.intersect_ray(q)
	if techo.is_empty():
		return
	var punto: Vector2 = techo.position + Vector2(0, 3)
	var q2 := PhysicsRayQueryParameters2D.create(punto, punto + Vector2(0, caida_max))
	q2.collision_mask = mascara
	var piso := espacio.intersect_ray(q2)
	if piso.is_empty():
		return
	var g := _Gota.new()
	g.top_level = true
	g.piso_y = piso.position.y
	g.gravedad = gravedad
	g.formacion = formacion
	g.color = color
	g.sonido = sonidos[randi() % sonidos.size()] if not sonidos.is_empty() else sonido
	g.volumen_db = volumen_db
	g.variacion_tono = variacion_tono
	g.ondas = ondas
	g.nuevo_charco = charcos and randf() < prob_charco and (piso.normal as Vector2).y < -0.95
	g.color_charco = color_charco
	g.dueno = self
	g.z_index = 1
	add_child(g)
	g.global_position = punto


class _Gota extends Node2D:
	var piso_y := 0.0
	var gravedad := 1900.0
	var formacion := 0.8
	var color := Color.WHITE
	var sonido: AudioStream
	var volumen_db := -22.0
	var variacion_tono := 0.15
	var ondas := true
	var nuevo_charco := false
	var color_charco := Color(0.5, 0.68, 0.88, 0.32)
	var dueno: Node
	var _salpico := false
	var _t := 0.0
	var _vy := 0.0
	var _cayendo := false

	func _process(delta: float) -> void:
		_t += delta
		if not _cayendo:
			if _t >= formacion:
				_cayendo = true
		else:
			_vy += gravedad * delta
			global_position.y += _vy * delta
			if global_position.y >= piso_y:
				_salpicar()
				return
		queue_redraw()

	func _draw() -> void:
		if _salpico:
			return
		if not _cayendo:
			var k := clampf(_t / formacion, 0.0, 1.0)
			draw_circle(Vector2(0, 2.0 + 2.0 * k), 1.0 + 2.2 * k, color)
		else:
			draw_circle(Vector2(0, 0), 2.6, color)
			draw_colored_polygon(PackedVector2Array([Vector2(-2.4, -1.0), Vector2(2.4, -1.0), Vector2(0, -12.0 - minf(_vy * 0.015, 14.0))]), color)

	func _salpicar() -> void:
		set_process(false)
		_salpico = true
		queue_redraw()
		var punto := Vector2(global_position.x, piso_y - 1.0)
		if ondas:
			var o = _Onda.new()
			o.top_level = true
			o.color = color_charco
			o.z_index = 1
			add_child(o)
			o.global_position = punto
		if nuevo_charco and dueno != null and dueno.has_method("_registrar_charco"):
			dueno._registrar_charco(punto, color_charco)
		var p := CPUParticles2D.new()
		p.top_level = true
		p.one_shot = true
		p.amount = 6
		p.explosiveness = 1.0
		p.lifetime = 0.45
		p.direction = Vector2.UP
		p.spread = 65.0
		p.initial_velocity_min = 70.0
		p.initial_velocity_max = 150.0
		p.gravity = Vector2(0, 900)
		p.scale_amount_min = 1.4
		p.scale_amount_max = 2.4
		p.color = Color(color, 0.75)
		p.z_index = 1
		add_child(p)
		p.global_position = Vector2(global_position.x, piso_y - 1.0)
		p.emitting = true
		var cam := get_viewport().get_camera_2d()
		if sonido != null and cam != null and cam.get_screen_center_position().distance_to(global_position) < 1300.0:
			var audio := get_node_or_null("/root/AudioManager")
			if audio != null:
				audio.play_sfx(sonido, volumen_db, variacion_tono)
		get_tree().create_timer(1.6).timeout.connect(queue_free)


## Crea un charco en `punto` (si no hay otro cerca); los más viejos se descartan. Lo llama la gota al salpicar.
func _registrar_charco(punto: Vector2, col: Color) -> void:
	for ch in _charcos:
		if is_instance_valid(ch) and ch.global_position.distance_to(punto) < 110.0:
			return
	var c := _Charco.new()
	c.top_level = true
	c.color = col
	c.ancho = randf_range(70.0, 130.0)
	c.z_index = 1
	add_child(c)
	c.global_position = punto
	_charcos.append(c)
	while _charcos.size() > max_charcos:
		var viejo = _charcos.pop_front()
		if is_instance_valid(viejo):
			viejo.queue_free()


## Anillos que se expanden y se desvanecen sobre el piso.
class _Onda extends Node2D:
	var color := Color(0.5, 0.68, 0.88, 0.32)
	var _t := 0.0

	func _process(delta: float) -> void:
		_t += delta
		queue_redraw()
		if _t > 1.3:
			queue_free()

	func _draw() -> void:
		for i in 2:
			var t := _t - 0.18 * float(i)
			if t <= 0.0:
				continue
			var k := clampf(t / 1.0, 0.0, 1.0)
			var r := 6.0 + 30.0 * k
			var a := (1.0 - k) * 0.9
			var pts := PackedVector2Array()
			for j in 25:
				var an := TAU * float(j) / 24.0
				pts.append(Vector2(cos(an) * r, sin(an) * r * 0.22))
			draw_polyline(pts, Color(color.r + 0.15, color.g + 0.12, color.b + 0.08, a * 0.8), 1.6)


## Charco: óvalo plano que aparece despacio, con un brillo; se retira solo si la cámara se aleja mucho.
class _Charco extends Node2D:
	var color := Color(0.5, 0.68, 0.88, 0.32)
	var ancho := 100.0
	var _t := 0.0

	func _process(delta: float) -> void:
		_t += delta
		queue_redraw()
		var cam := get_viewport().get_camera_2d()
		if cam != null and cam.get_screen_center_position().distance_to(global_position) > 3200.0:
			queue_free()

	func _draw() -> void:
		var f := clampf(_t / 3.0, 0.0, 1.0)
		var pts := PackedVector2Array()
		for j in 25:
			var an := TAU * float(j) / 24.0
			pts.append(Vector2(cos(an) * ancho * 0.5 * f, sin(an) * 5.0 * f + 1.0))
		draw_colored_polygon(pts, Color(color.r * 0.5, color.g * 0.6, color.b * 0.8, color.a * f))
		draw_polyline(PackedVector2Array([Vector2(-ancho * 0.25 * f, -0.5), Vector2(ancho * 0.05 * f, -1.5)]), Color(0.85, 0.93, 1.0, 0.45 * f), 1.4)
