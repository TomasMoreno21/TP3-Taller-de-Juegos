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
var homing_offset := Vector2.ZERO   # punto de mira respecto del objetivo (p. ej. más abajo que el pecho)
var _life := 2.5
var margen_camara := 80.0   # px fuera de pantalla hasta los que el disparo del jugador sigue vivo (más margen = más alcance visible)
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

@export_group("Aspecto")
@export var color_jugador := Color(0.72, 0.52, 1.0)   ## onda sónica del Murciélago
@export var color_enemigo := Color(1.0, 0.2, 0.18)   ## onda roja de los enemigos
@export var tamano := 1.5                              ## escala del dibujo (el hitbox no cambia)
@export var giro_estrella_s := 6.0                     ## rad/s a los que gira la estrella del orbe enemigo
@export_group("")

var _t := 0.0
var _arte: Node2D

## Capa de dibujo del proyectil: se orienta con la dirección y se redibuja cada frame.
class _Arte extends Node2D:
	var proj: Area2D

	func _draw() -> void:
		if proj != null:
			proj._dibujar_arte(self)


func _ready() -> void:
	_aplicar_color()
	_arte = _Arte.new()
	(_arte as _Arte).proj = self
	_arte.z_index = 2
	add_child(_arte)
	if visual != null:
		visual.visible = false   # el dibujo lo hace _Arte; el Polygon2D queda solo como fuente del color
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
	_t += delta
	if _arte != null:
		_arte.rotation = direction.angle()
		_arte.queue_redraw()
	if visual != null and giro_grados_s > 0.0:
		visual.rotation += deg_to_rad(giro_grados_s) * delta
	_actualizar_estela()
	_homing_timer -= delta
	if homing and not enemy_shot and _homing_timer <= 0.0:
		_homing_timer = HOMING_TICK
		var target: Node2D = _buscar_enemigo_cercano()
		if target != null:
			# El punto de mira bajo es para el torso de los enemigos; al cristal se le apunta al centro
			# (si no, el proyectil pasaba por debajo y nunca lo tocaba).
			var mira := homing_offset if target.is_in_group("enemy") else Vector2.ZERO
			var to_target: Vector2 = centro_objetivo(target) + mira - global_position
			if to_target.length_squared() > 0.01:
				var dir_deseada: Vector2 = to_target.normalized()
				var blended: Vector2 = direction.lerp(dir_deseada, clampf(homing_strength * HOMING_TICK, 0.0, 1.0))
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
	_aplicar_color()
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
	# Los disparos enemigos nacen a veces fuera de pantalla (arquero lejano): margen amplio para que no se borren al aparecer.
	var half: Vector2 = view_size * 0.5 + (Vector2(400, 400) if enemy_shot else Vector2(margen_camara, margen_camara))
	return global_position.x < cam_pos.x - half.x or global_position.x > cam_pos.x + half.x or global_position.y < cam_pos.y - half.y or global_position.y > cam_pos.y + half.y


func _buscar_enemigo_cercano() -> Node2D:
	var mejor: Node2D = null
	var mejor_dist := homing_range
	for n in get_tree().get_nodes_in_group("enemy"):
		if not _activo_y_vivo(n):
			continue
		var d := global_position.distance_to(n.global_position)
		if n.get("flotante") == true:
			d *= 0.35   # prioridad a los voladores
		if d >= mejor_dist:
			continue   # (antes del raycast: es lo caro)
		if not linea_libre(self, global_position, centro_objetivo(n)):
			continue   # detrás de la roca / otro piso: no se le persigue
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
	if mejor != null:
		return mejor
	for n in get_tree().get_nodes_in_group("ojo_verde"):
		if not is_instance_valid(n):
			continue
		var d := global_position.distance_to(n.global_position)
		if n.abierto and d < mejor_dist and linea_libre(self, global_position, n.global_position):
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
	if enemy_shot and body.has_method("parry_proyectil") and body.parry_proyectil(direction.x):
		_reflejar()
		return
	if body.has_method("take_damage"):
		var dano_final := damage
		if not enemy_shot and body.is_in_group("enemy"):
			var ed: Resource = body.get("enemy_data")
			if ed != null and ed.get("sonico_dano_mult") != null:
				dano_final = int(round(damage * float(ed.sonico_dano_mult)))
		_consumido = true
		if not enemy_shot and "golpe_proyectil" in body:
			body.golpe_proyectil = true   # el flotante solo recibe daño de proyectiles
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


## True si entre `desde` y `hasta` no hay terreno (las barreras y cristales de energía no cuentan).
## El teledirigido solo persigue a lo que ve: antes viraba hacia enemigos de otro piso, a través de la roca.
static func linea_libre(ref: Node2D, desde: Vector2, hasta: Vector2) -> bool:
	var espacio := ref.get_world_2d().direct_space_state
	if espacio == null:
		return true
	var origen := desde
	for _i in 12:
		var q := PhysicsRayQueryParameters2D.create(origen, hasta)
		q.collide_with_areas = false
		q.collision_mask = TERRAIN_LAYER
		var hit := espacio.intersect_ray(q)
		if hit.is_empty():
			return true
		var col: Object = hit["collider"]
		if col is Node and ((col as Node).is_in_group("cristal") or (col as Node).is_in_group("barrera_energia")):
			origen = (hit["position"] as Vector2) + (hasta - desde).normalized() * 4.0
			continue
		return false
	return false


## Centro del collider del objetivo (el medio del sprite). `global_position` de un enemigo son sus pies.
static func centro_objetivo(n: Node2D) -> Vector2:
	for c in n.get_children():
		if c is CollisionShape2D and (c as CollisionShape2D).shape != null and not (c as CollisionShape2D).disabled:
			return ((c as CollisionShape2D).global_transform * (c as CollisionShape2D).shape.get_rect()).get_center()
	return n.global_position


## Color según el dueño (onda violeta del jugador / brasa naranja del enemigo) en el dibujo, el halo, la luz y la estela.
func _aplicar_color() -> void:
	if visual == null:
		return
	if visual.color == Color(0.72, 0.52, 1.0, 1.0):   # color de la escena sin tocar: lo decide quién dispara
		visual.color = color_enemigo if enemy_shot else color_jugador
	var c := visual.color
	var halo := get_node_or_null("Halo") as Sprite2D
	if halo != null:
		halo.modulate = Color(c.r, c.g, c.b, 0.55)
	var luz := get_node_or_null("Luz") as PointLight2D
	if luz != null:
		luz.color = c
	var trail := get_node_or_null("Trail") as CPUParticles2D
	if trail != null:
		trail.color = Color(c.r, c.g, c.b, 0.65)


func _dibujar_arte(ci: CanvasItem) -> void:
	var c := visual.color if visual != null else color_jugador
	_dibujar_onda(ci, c, tamano)


func _escalar(pts: Array, k: float) -> PackedVector2Array:
	var res := PackedVector2Array()
	for v in pts:
		res.append((v as Vector2) * k)
	return res


## Onda sónica: núcleo brillante, cola afilada y medialunas que se abren hacia adelante.
func _dibujar_onda(ci: CanvasItem, c: Color, k: float) -> void:
	var luz := c.lerp(Color.WHITE, 0.6)
	ci.draw_colored_polygon(_escalar([Vector2(-8, -8), Vector2(-52, 0), Vector2(-8, 8)], k), Color(c.r, c.g, c.b, 0.4))
	ci.draw_circle(Vector2.ZERO, 11.0 * k, c)
	ci.draw_circle(Vector2.ZERO, 5.5 * k, luz)
	for i in 2:
		var avance := fposmod(_t * 3.0 + float(i) / 2.0, 1.0)   # dos ondas salen del núcleo y se desvanecen
		var r := (16.0 + avance * 22.0) * k
		var x := (6.0 + avance * 26.0) * k
		var ancho := (7.0 - avance * 3.0) * k
		_media_luna(ci, Vector2(x - r * 0.4, 0.0), r, ancho, deg_to_rad(50.0), Color(luz.r, luz.g, luz.b, (1.0 - avance) * 0.85))


## Medialuna (arco afinado en las puntas) con la punta mirando a +X.
func _media_luna(ci: CanvasItem, centro: Vector2, r: float, grosor: float, ang: float, color: Color) -> void:
	var puntos := PackedVector2Array()
	const N := 10
	for i in N + 1:
		var a := lerpf(-ang, ang, float(i) / N)
		puntos.append(centro + Vector2.from_angle(a) * r)
	for i in range(N, -1, -1):
		var a := lerpf(-ang, ang, float(i) / N)
		var g := grosor * cos(a / ang * PI * 0.5)
		puntos.append(centro + Vector2.from_angle(a) * (r - g))
	ci.draw_colored_polygon(puntos, color)
