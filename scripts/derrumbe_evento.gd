extends Node2D
## Derrumbes del nivel. Fuera de la zona la cueva solo se queja de vez en cuando (vibración leve + alguna piedra);
## entre `inicio` y `fin` (en x) el techo se viene abajo de verdad: shake constante y fuerte, lluvia de escombros y
## rocas con aviso (una sombra en el piso) que caen sobre la posición del jugador y hacen daño: quedarse quieto
## no es opción, hay que avanzar. Se coloca en el editor: arrastrar nodos a `inicio` y `fin`.

@export var inicio: Node2D                          ## el derrumbe fuerte arranca al pasar por la x de este nodo
@export var fin: Node2D                             ## y se corta al llegar a la x de este nodo

@export_group("Zona de derrumbe")
@export var pausa_min := 1.0                        ## s entre oleadas de escombros
@export var pausa_max := 2.0
@export var primera_espera := 0.6                   ## s hasta la primera oleada tras entrar
@export var fuerza_shake := 18.0                    ## shake constante mientras dura la zona (>= 6 desprende polvo del techo)
@export var intervalo_shake := 0.22                 ## s entre sacudidas (cada una dura un poco más, así no hay huecos)
@export var duracion_oleada := 1.2                  ## s en que se reparten los escombros de cada oleada
@export var escombros_por_oleada := Vector2i(14, 22)
@export var dispersion := Vector2(-500.0, 800.0)    ## x relativa al jugador donde caen (más hacia adelante)
@export var color_escombro := Color(0.28, 0.29, 0.36)

@export_group("Rocas que persiguen")
@export var rocas_dirigidas := true                 ## cae una roca con aviso sobre donde estás: hay que seguir avanzando
@export var pausa_roca_min := 1.1                   ## s entre rocas dirigidas
@export var pausa_roca_max := 1.8
@export var aviso_s := 0.9                          ## s que dura la sombra de aviso antes del impacto
@export var anticipo := 0.35                        ## s de velocidad del jugador que se adelanta al apuntar
@export var dano_roca := 12
@export var radio_dano := 80.0                      ## px de ancho (a cada lado) del impacto que hacen daño

@export_group("Ambiente (fuera de la zona)")
@export var ambiente_activo := true
@export var ambiente_pausa_min := 9.0               ## s entre vibraciones leves
@export var ambiente_pausa_max := 20.0
@export var ambiente_fuerza := 3.5
@export var ambiente_duracion := 0.6
@export var ambiente_piedras := Vector2i(1, 3)      ## piedritas que caen con cada vibración

var _activo := false
var _espera := 0.0
var _t_shake := 0.0
var _t_roca := 0.0
var _t_amb := 8.0
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
		_t_shake = 0.0
		_t_roca = pausa_roca_max
	elif not dentro and _activo:
		_activo = false
		_t_amb = randf_range(ambiente_pausa_min, ambiente_pausa_max)
	if not _activo:
		_ambiente(delta)
		return
	_t_shake -= delta
	if _t_shake <= 0.0:
		_t_shake = intervalo_shake
		_sacudir(fuerza_shake, intervalo_shake * 1.8)
	_espera -= delta
	if _espera <= 0.0:
		_espera = randf_range(pausa_min, pausa_max)
		_oleada()
	if rocas_dirigidas:
		_t_roca -= delta
		if _t_roca <= 0.0:
			_t_roca = randf_range(pausa_roca_min, pausa_roca_max)
			_roca_dirigida()


func _sacudir(fuerza: float, duracion: float) -> void:
	var cam := get_viewport().get_camera_2d()
	if cam != null and cam.has_method("shake"):
		cam.shake(fuerza, duracion)


## Fuera de la zona: de vez en cuando una vibración leve y alguna piedra.
func _ambiente(delta: float) -> void:
	if not ambiente_activo:
		return
	_t_amb -= delta
	if _t_amb > 0.0:
		return
	_t_amb = randf_range(ambiente_pausa_min, ambiente_pausa_max)
	_sacudir(ambiente_fuerza, ambiente_duracion)
	var n := randi_range(ambiente_piedras.x, ambiente_piedras.y)
	for i in n:
		get_tree().create_timer(randf_range(0.1, ambiente_duracion + 0.4), false).timeout.connect(_soltar_escombro.bind(4.0, 10.0, true))


func _oleada() -> void:
	var n := randi_range(escombros_por_oleada.x, escombros_por_oleada.y)
	for i in n:
		get_tree().create_timer(randf_range(0.0, duracion_oleada), false).timeout.connect(_soltar_escombro.bind(9.0, 26.0, false))


func _soltar_escombro(r_min: float, r_max: float, ambiente: bool) -> void:
	if not is_instance_valid(_jugador) or (not ambiente and not _activo):
		return
	var x := _jugador.global_position.x + (randf_range(-450.0, 450.0) if ambiente else randf_range(dispersion.x, dispersion.y))
	var techo := _techo_sobre(Vector2(x, _jugador.global_position.y))
	if techo == INF:
		return   # sin techo sobre esa x: no cae nada
	var e := _Escombro.new()
	e.radio = randf_range(r_min, r_max)
	e.color = color_escombro.lightened(randf_range(-0.05, 0.12))
	e.global_position = Vector2(x, techo + 26.0)
	e.vel = Vector2(randf_range(-40.0, 40.0), 0.0)
	e.giro = randf_range(-6.0, 6.0)
	get_parent().add_child(e)


func _techo_sobre(desde: Vector2) -> float:
	var q := PhysicsRayQueryParameters2D.create(desde, desde + Vector2(0, -1600), 1)
	var h := get_world_2d().direct_space_state.intersect_ray(q)
	return INF if h.is_empty() else float((h.position as Vector2).y)


## Roca grande con sombra de aviso sobre la posición (adelantada) del jugador.
func _roca_dirigida() -> void:
	if not is_instance_valid(_jugador):
		return
	var vx := 0.0
	if "velocity" in _jugador:
		vx = float(_jugador.velocity.x)
	var x := _jugador.global_position.x + vx * anticipo
	var espacio := get_world_2d().direct_space_state
	var arriba := Vector2(x, _jugador.global_position.y - 60.0)
	var piso := espacio.intersect_ray(PhysicsRayQueryParameters2D.create(arriba, arriba + Vector2(0, 900), 1))
	if piso.is_empty():
		return
	var techo := _techo_sobre(arriba)
	if techo == INF:
		return
	var a := _Aviso.new()
	a.global_position = piso.position as Vector2
	a.duracion = aviso_s
	a.ancho = radio_dano
	get_parent().add_child(a)
	var cuerpo := {"x": x, "techo": techo}
	get_tree().create_timer(aviso_s, false).timeout.connect(_caer_roca_dirigida.bind(cuerpo))


func _caer_roca_dirigida(d: Dictionary) -> void:
	var e := _Escombro.new()
	e.radio = 30.0
	e.color = color_escombro.lightened(0.06)
	e.global_position = Vector2(float(d["x"]), float(d["techo"]) + 30.0)
	e.vel = Vector2(0.0, 900.0)
	e.giro = randf_range(-4.0, 4.0)
	e.dano = dano_roca
	e.radio_dano = radio_dano
	e.sacudir = fuerza_shake * 0.5
	get_parent().add_child(e)


## Sombra de aviso en el piso: crece y pulsa hasta el impacto.
class _Aviso extends Node2D:
	var duracion := 0.9
	var ancho := 80.0
	var _t := 0.0

	func _ready() -> void:
		z_index = 3

	func _process(delta: float) -> void:
		_t += delta
		queue_redraw()
		if _t >= duracion + 0.1:
			queue_free()

	func _draw() -> void:
		var k := clampf(_t / maxf(duracion, 0.01), 0.0, 1.0)
		var pulso := 0.5 + 0.5 * sin(_t * 22.0)
		var rx := ancho * (0.4 + 0.6 * k)
		var pts := PackedVector2Array()
		for i in 20:
			var a := TAU * float(i) / 20.0
			pts.append(Vector2(cos(a) * rx, sin(a) * rx * 0.18 - 3.0))
		draw_colored_polygon(pts, Color(0.05, 0.03, 0.04, 0.55 * k))
		draw_polyline(pts + PackedVector2Array([pts[0]]), Color(0.95, 0.35, 0.2, (0.35 + 0.5 * pulso) * k), 2.5)


## Roca que cae del techo y se deshace en polvo contra el piso. Las dirigidas (`dano` > 0) lastiman si caen sobre el jugador.
class _Escombro extends Node2D:
	var radio := 12.0
	var color := Color(0.3, 0.3, 0.38)
	var vel := Vector2.ZERO
	var giro := 0.0
	var dano := 0
	var radio_dano := 80.0
	var sacudir := 0.0
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
			_impacto(h.position as Vector2)
			queue_free()
			return
		global_position += paso
		if vel.y > 2600.0 and dano <= 0:
			queue_free()

	func _impacto(p: Vector2) -> void:
		Burst.emitir(self, p, color.lightened(0.2), 10 if dano <= 0 else 26, 0.8 if dano <= 0 else 1.6)
		if dano <= 0:
			return
		var cam := get_viewport().get_camera_2d()
		if cam != null and cam.has_method("shake") and sacudir > 0.0:
			cam.shake(sacudir, 0.25)
		var j := get_tree().get_first_node_in_group("player") as Node2D
		if j != null and absf(j.global_position.x - p.x) <= radio_dano and j.global_position.y - p.y > -260.0 and j.global_position.y - p.y < 80.0 and j.has_method("take_damage"):
			j.take_damage(dano, 0.0, 0, true)
