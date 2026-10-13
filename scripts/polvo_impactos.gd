extends Node

## Polvo que se desprende del techo con el movimiento del jugador: cae una nubecita al aterrizar de una caída fuerte,
## y al correr bajo un techo bajo se suelta un poco de tanto en tanto. Usa el techo real (rayo hacia arriba).

@export var activo := true
@export var impacto_min := 350.0               ## velocidad de caída mínima (la señal del jugador) para que caiga polvo
@export var alcance_techo := 1300.0            ## px sobre el jugador donde buscamos techo (más lejos = no cae nada)
@export var color := Color(0.66, 0.74, 0.9, 0.55)
@export var motas_min := 8
@export var motas_max := 40
@export_group("Al correr")
@export var correr_activo := true
@export var correr_velocidad := 430.0          ## px/s mínimos para soltar polvo
@export var correr_techo_max := 520.0          ## solo si el techo está más cerca que esto
@export var correr_pausa := Vector2(1.4, 3.2)  ## s entre polvaredas
@export var correr_motas := 5

var _jugador: Node2D
var _espera := 2.0
static var _tex: Texture2D


func _ready() -> void:
	_jugador = get_tree().get_first_node_in_group("player") as Node2D
	if _jugador != null and _jugador.has_signal("aterrizaje_fuerte"):
		_jugador.aterrizaje_fuerte.connect(_al_aterrizar)


func _physics_process(delta: float) -> void:
	if not activo or not correr_activo or not is_instance_valid(_jugador):
		return
	if not _jugador.is_on_floor() or absf(_jugador.velocity.x) < correr_velocidad:
		return
	_espera -= delta
	if _espera > 0.0:
		return
	_espera = randf_range(correr_pausa.x, correr_pausa.y)
	var techo := _techo(_jugador.global_position, correr_techo_max)
	if techo != INF:
		_nube(Vector2(_jugador.global_position.x, techo + 4.0), correr_motas, 90.0)


func _al_aterrizar(pos: Vector2, impacto: float) -> void:
	if not activo or impacto < impacto_min:
		return
	var techo := _techo(pos, alcance_techo)
	if techo == INF:
		return
	var k := clampf((impacto - impacto_min) / 700.0, 0.0, 1.0)
	_nube(Vector2(pos.x, techo + 4.0), int(lerpf(float(motas_min), float(motas_max), k)), lerpf(140.0, 320.0, k))


func _techo(desde: Vector2, alcance: float) -> float:
	var q := PhysicsRayQueryParameters2D.create(desde, desde + Vector2(0, -alcance), 1)
	var h := get_viewport().world_2d.direct_space_state.intersect_ray(q)
	return INF if h.is_empty() else float((h.position as Vector2).y)


func _nube(pos: Vector2, cantidad: int, ancho: float) -> void:
	if DisplayServer.get_name() == "headless":
		return
	var p := CPUParticles2D.new()
	p.top_level = true
	p.one_shot = true
	p.emitting = false
	p.amount = maxi(cantidad, 1)
	p.explosiveness = 0.55
	p.randomness = 0.6
	p.lifetime = 2.2
	p.texture = _textura()
	p.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	p.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	p.emission_rect_extents = Vector2(ancho * 0.5, 6.0)
	p.direction = Vector2(0, 1)
	p.spread = 25.0
	p.gravity = Vector2(0, 90)
	p.initial_velocity_min = 8.0
	p.initial_velocity_max = 40.0
	p.damping_min = 20.0
	p.damping_max = 60.0
	p.scale_amount_min = 0.1
	p.scale_amount_max = 0.3
	p.color = color
	var g := Gradient.new()
	g.offsets = PackedFloat32Array([0.0, 0.15, 1.0])
	g.colors = PackedColorArray([Color(1, 1, 1, 0), Color(1, 1, 1, 1), Color(1, 1, 1, 0)])
	p.color_ramp = g
	p.z_index = 3
	add_child(p)
	p.global_position = pos
	p.emitting = true
	get_tree().create_timer(p.lifetime + 0.5).timeout.connect(p.queue_free)


func _textura() -> Texture2D:
	if _tex == null:
		var g := Gradient.new()
		g.offsets = PackedFloat32Array([0.0, 0.5, 1.0])
		g.colors = PackedColorArray([Color(1, 1, 1, 1), Color(1, 1, 1, 0.35), Color(1, 1, 1, 0)])
		var t := GradientTexture2D.new()
		t.gradient = g
		t.width = 32
		t.height = 32
		t.fill = GradientTexture2D.FILL_RADIAL
		t.fill_from = Vector2(0.5, 0.5)
		t.fill_to = Vector2(1.0, 0.5)
		_tex = t
	return _tex
