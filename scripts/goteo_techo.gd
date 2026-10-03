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
@export var volumen_db := -22.0
@export_flags_2d_physics var mascara := 1

var _espera := 1.0


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
	g.sonido = sonido
	g.volumen_db = volumen_db
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
		if not _cayendo:
			var k := clampf(_t / formacion, 0.0, 1.0)
			draw_circle(Vector2(0, 2.0 + 2.0 * k), 1.0 + 2.2 * k, color)
		else:
			draw_circle(Vector2(0, 0), 2.6, color)
			draw_colored_polygon(PackedVector2Array([Vector2(-2.4, -1.0), Vector2(2.4, -1.0), Vector2(0, -12.0 - minf(_vy * 0.015, 14.0))]), color)

	func _salpicar() -> void:
		set_process(false)
		visible = false
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
				audio.play_sfx(sonido, volumen_db, 0.15)
		get_tree().create_timer(1.0).timeout.connect(queue_free)
