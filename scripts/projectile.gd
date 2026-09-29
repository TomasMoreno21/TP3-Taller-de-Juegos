extends Area2D

@export var sonido_impacto: AudioStream = preload("res://assets/audio/sfx/gen/proyectil_impacto.wav")
@export var volumen_impacto_db := -12.0

var direction := Vector2.RIGHT
var speed := 700.0
var damage := 15
var enemy_shot := false
var homing := false
var homing_strength := 24.0
var homing_range := 3000.0
var _life := 2.5
var _consumido := false
var _cam: Camera2D
var _homing_timer := 0.0
const HOMING_TICK := 0.04  # cada cuánto re-busca el homing (evita lookup de grupo por frame)

@onready var visual: Polygon2D = $Visual
@onready var hitbox: CollisionShape2D = $Hitbox


const TERRAIN_LAYER := 1  # capa de colisión del TileMap

@export var estela_puntos := 7           ## largo de la estela en puntos (0 = sin estela)
@export var giro_grados_s := 540.0        ## giro del proyectil sobre sí mismo (0 = fijo)

var _estela: Line2D


func _ready() -> void:
	# Detecta al Player (4) o Enemigos (2) según el dueño, y además el terreno (1).
	collision_mask = (4 if enemy_shot else 2) | TERRAIN_LAYER
	body_entered.connect(_on_body_entered)
	monitoring = true
	_cam = get_viewport().get_camera_2d()
	if estela_puntos > 0 and DisplayServer.get_name() != "headless":
		_estela = Line2D.new()
		_estela.top_level = true          # los puntos viven en el mundo, no siguen al proyectil
		_estela.width = 9.0
		_estela.z_index = -1
		var curva := Curve.new()
		curva.add_point(Vector2(0.0, 0.0))
		curva.add_point(Vector2(1.0, 1.0))
		_estela.width_curve = curva
		var g := Gradient.new()
		var c := visual.color if visual != null else Color.WHITE
		g.set_color(0, Color(c.r, c.g, c.b, 0.0))
		g.set_color(1, Color(c.r, c.g, c.b, 0.7))
		_estela.gradient = g
		add_child(_estela)


func _actualizar_estela() -> void:
	if _estela == null:
		return
	_estela.add_point(global_position)
	while _estela.get_point_count() > estela_puntos:
		_estela.remove_point(0)


func _physics_process(delta: float) -> void:
	if visual != null and giro_grados_s > 0.0:
		visual.rotation += deg_to_rad(giro_grados_s) * delta
	_actualizar_estela()
	_homing_timer -= delta
	if homing and not enemy_shot and _homing_timer <= 0.0:
		_homing_timer = HOMING_TICK
		var target: Node2D = _buscar_enemigo_cercano()
		if target != null:
			var to_target: Vector2 = target.global_position - global_position
			if to_target.length_squared() > 0.01:
				var dir_deseada: Vector2 = to_target.normalized()
				var blended: Vector2 = direction.lerp(dir_deseada, homing_strength * delta)
				if blended.length_squared() > 0.01:
					direction = blended.normalized()
	# Rechaza el terreno (evita atravesar el tilemap a alta velocidad), pero
	# NO los objetos de energía (barreras y cristales): el sónico los atraviesa.
	if _choca_terreno(delta):
		_impacto(0.7)
		queue_free()
		return
	global_position += direction * speed * delta
	if _fuera_de_camara():
		queue_free()
		return
	_life -= delta
	if _life <= 0.0:
		queue_free()


## Parry del Humano: el proyectil vuelve contra los enemigos, más rápido y más fuerte.
func _reflejar() -> void:
	enemy_shot = false
	direction = -direction
	speed *= 1.25
	damage = int(damage * 1.5)
	collision_mask = 2 | TERRAIN_LAYER
	if visual != null:
		visual.color = Color(0.85, 0.95, 1.0)
	_life = maxf(_life, 1.5)
	_impacto(0.8)
	Burst.chispas(self, global_position, int(signf(direction.x)) if direction.x != 0.0 else 1, Color(0.85, 0.95, 1.0), 9, 1.4)


## Chispazo del color del proyectil donde pega (terreno más chico que en un cuerpo).
func _impacto(escala: float) -> void:
	var audio := get_node_or_null("/root/AudioManager")
	if audio != null:
		audio.play_sfx(sonido_impacto, volumen_impacto_db + (0.0 if escala >= 1.0 else -4.0), 0.1)
	var color := visual.color if visual != null else Color.WHITE
	Burst.emitir(self, global_position, color, int(10 * escala), escala)


## Raycast del extremo del proyectil hacia dónde va a avanzar este frame.
## Devuelve true si choca con el terreno antes de llegar. Los objetos de
## energía (cristales y barreras, group barrera_energia/cristal) se saltean
## para que el proyectil sónico del jugador los atraviese.
func _choca_terreno(delta: float) -> bool:
	var espacio := get_world_2d().direct_space_state
	if espacio == null:
		return false
	var origen := global_position
	var destino := global_position + direction * speed * delta + direction * 4.0
	for _i in 20:
		var q := PhysicsRayQueryParameters2D.create(origen, destino)
		q.collide_with_areas = false
		q.collide_with_bodies = true
		q.collision_mask = TERRAIN_LAYER
		var hit := espacio.intersect_ray(q)
		if hit.is_empty():
			return false
		var col: Object = hit["collider"]
		if not enemy_shot and _es_energia(col):
			# Salta el objeto de energía y sigue mirando más allá.
			origen = (hit["position"] as Vector2) + direction * 4.0
			continue
		return true
	return false


func _es_energia(col: Object) -> bool:
	if not col is Node:
		return false
	var n := col as Node
	return n.is_in_group("cristal") or n.is_in_group("barrera_energia")


func _fuera_de_camara() -> bool:
	if not is_instance_valid(_cam):
		_cam = get_viewport().get_camera_2d()
	if _cam == null:
		return false
	var view_size: Vector2 = get_viewport_rect().size / _cam.zoom
	var cam_pos: Vector2 = _cam.global_position
	var half: Vector2 = view_size * 0.5 + Vector2(80, 80)
	return global_position.x < cam_pos.x - half.x or global_position.x > cam_pos.x + half.x or global_position.y < cam_pos.y - half.y or global_position.y > cam_pos.y + half.y


func _buscar_enemigo_cercano() -> Node2D:
	var mejor: Node2D = null
	var mejor_dist := homing_range
	for n in get_tree().get_nodes_in_group("enemy"):
		if not _activo_y_vivo(n):
			continue
		var d := global_position.distance_to(n.global_position)
		if d < mejor_dist:
			mejor_dist = d
			mejor = n
	if mejor != null:
		return mejor
	for n in get_tree().get_nodes_in_group("cristal"):
		if not is_instance_valid(n) or not n.has_method("take_damage"):
			continue
		var d := global_position.distance_to(n.global_position)
		if d < mejor_dist:
			mejor_dist = d
			mejor = n
	return mejor


func _activo_y_vivo(n: Node) -> bool:
	if not is_instance_valid(n) or not n.has_method("take_damage"):
		return false
	if n.get("_activo") == false:
		return false
	if "health" in n and int(n.health) <= 0:
		return false
	return true


func _on_body_entered(body: Node2D) -> void:
	if _consumido:
		return   # queue_free es diferido: dos cuerpos en el mismo paso de física no deben pegar dos veces
	# El sónico atraviesa las barreras de energía sin explotar contra ellas.
	if body.is_in_group("barrera_energia"):
		return
	if enemy_shot and body.has_method("parry_activo") and body.parry_activo():
		_reflejar()
		return
	if body.has_method("take_damage"):
		var dano_final := damage
		if not enemy_shot and body.is_in_group("enemy"):
			var ed: Resource = body.get("enemy_data")
			if ed != null and ed.get("sonico_dano_mult") != null:
				dano_final = int(round(damage * float(ed.sonico_dano_mult)))
		_consumido = true
		# Signo de la dirección (int() de un vector normalizado daba 0 en disparos inclinados: sin retroceso).
		body.take_damage(dano_final, 120.0, 1 if direction.x >= 0.0 else -1)
		if homing and not enemy_shot and body.is_in_group("enemy"):
			var v := body.get_node_or_null("Visual")
			if v != null:
				v.modulate = Color(0.78, 0.55, 1.0)
				var tw := v.create_tween()
				tw.tween_property(v, "modulate", Color(1, 1, 1), 0.12)
		_impacto(1.0)
		queue_free()
