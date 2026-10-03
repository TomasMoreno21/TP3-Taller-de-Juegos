extends Node2D
## Evento de derrumbe ambiental: mientras el jugador está entre `inicio` y `fin` (en x), la cueva retumba
## por oleadas (shake fuerte + polvo del techo) y caen escombros cerca de él. Es solo ambientación (sin daño).
## Se coloca en el editor: arrastrar nodos a `inicio` (p. ej. un checkpoint) y `fin` (p. ej. el diálogo final).

@export var inicio: Node2D                          ## el evento arranca al pasar por la x de este nodo
@export var fin: Node2D                             ## y se corta al llegar a la x de este nodo
@export var pausa_min := 3.0                        ## s entre oleadas
@export var pausa_max := 6.0
@export var primera_espera := 1.2                   ## s hasta la primera oleada tras entrar
@export var fuerza_shake := 9.0                     ## shake de cada oleada (>= 6 desprende polvo del techo)
@export var duracion_shake := 1.1
@export var escombros_por_oleada := Vector2i(4, 7)
@export var dispersion := Vector2(-500.0, 800.0)    ## x relativa al jugador donde caen (más hacia adelante)
@export var color_escombro := Color(0.28, 0.29, 0.36)

var _activo := false
var _espera := 0.0
var _jugador: Node2D


func _ready() -> void:
	set_physics_process(true)


func _physics_process(delta: float) -> void:
	if inicio == null or fin == null:
		return
	if not is_instance_valid(_jugador):
		_jugador = get_tree().get_first_node_in_group("player") as Node2D
		if _jugador == null:
			return
	var x := _jugador.global_position.x
	var dentro := x >= inicio.global_position.x and x < fin.global_position.x
	if dentro and not _activo:
		_activo = true
		_espera = primera_espera
	elif not dentro and _activo:
		_activo = false
	if not _activo:
		return
	_espera -= delta
	if _espera <= 0.0:
		_espera = randf_range(pausa_min, pausa_max)
		_oleada()


func _oleada() -> void:
	var cam := get_viewport().get_camera_2d()
	if cam != null and cam.has_method("shake"):
		cam.shake(fuerza_shake, duracion_shake)
	var n := randi_range(escombros_por_oleada.x, escombros_por_oleada.y)
	for i in n:
		get_tree().create_timer(randf_range(0.0, duracion_shake)).timeout.connect(_soltar_escombro)


func _soltar_escombro() -> void:
	if not _activo or not is_instance_valid(_jugador):
		return
	var espacio := get_world_2d().direct_space_state
	var x := _jugador.global_position.x + randf_range(dispersion.x, dispersion.y)
	var desde := Vector2(x, _jugador.global_position.y)
	var q := PhysicsRayQueryParameters2D.create(desde, desde + Vector2(0, -1600), 1)
	var h := espacio.intersect_ray(q)
	if h.is_empty():
		return   # sin techo sobre esa x: no cae nada
	var e := _Escombro.new()
	e.radio = randf_range(9.0, 26.0)
	e.color = color_escombro.lightened(randf_range(-0.05, 0.12))
	e.global_position = (h.position as Vector2) + Vector2(0, 26)
	e.vel = Vector2(randf_range(-40.0, 40.0), 0.0)
	e.giro = randf_range(-6.0, 6.0)
	get_parent().add_child(e)


## Roca que cae del techo, rebota en polvo contra el piso y desaparece. Sin colisión con el jugador.
class _Escombro extends Node2D:
	var radio := 12.0
	var color := Color(0.3, 0.3, 0.38)
	var vel := Vector2.ZERO
	var giro := 0.0
	var _puntos := PackedVector2Array()

	func _ready() -> void:
		z_index = 4
		var n := 7
		for i in n:
			var a := TAU * i / n
			_puntos.append(Vector2(cos(a), sin(a)) * radio * randf_range(0.65, 1.1))
		queue_redraw()

	func _draw() -> void:
		draw_colored_polygon(_puntos, color)
		draw_polyline(_puntos + PackedVector2Array([_puntos[0]]), color.darkened(0.45), 2.0)

	func _physics_process(delta: float) -> void:
		vel.y += 1900.0 * delta
		rotation += giro * delta
		var paso := vel * delta
		var q := PhysicsRayQueryParameters2D.create(global_position, global_position + paso + Vector2(0, radio), 1)
		var h := get_world_2d().direct_space_state.intersect_ray(q)
		if not h.is_empty():
			Burst.emitir(self, h.position, color.lightened(0.2), 10, 0.8)
			queue_free()
			return
		global_position += paso
		if vel.y > 2600.0:
			queue_free()
