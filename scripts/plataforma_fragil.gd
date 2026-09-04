extends StaticBody2D
## Plataforma/piso frágil: al pisarla tiembla durante `tiempo_temblor` y luego
## se destruye o se cae (configurable). La colisión ("Collision") y el visual
## ("Visual") son nodos editables dentro de la escena.

enum Ruptura { DESTRUIR, CAER }

@export var tiempo_temblor := 1.0
@export var modo_ruptura := Ruptura.DESTRUIR
@export var temblor_max := 3.0       # px de vaivén al temblar (crece hacia la ruptura)
@export var gravedad_caida := 2400.0 # aceleración al caer (modo CAER)

enum Fase { ESPERA, TEMBLOR, CAYENDO, ROTA }

var _fase: int = Fase.ESPERA
var _t := 0.0
var _vel_caida := 0.0
var _visual: Polygon2D
var _shape: CollisionShape2D


func _ready() -> void:
	add_to_group("plataforma_fragil")
	collision_layer = 1
	_visual = get_node_or_null("Visual") as Polygon2D
	_shape = get_node_or_null("Collision") as CollisionShape2D
	if _visual == null:
		_visual = _crear_visual_fallback()
	if _shape == null:
		_shape = _crear_collision_fallback()


func _physics_process(delta: float) -> void:
	match _fase:
		Fase.ESPERA:
			var player: Node2D = get_tree().get_first_node_in_group("player")
			if player is CharacterBody2D and player.is_on_floor():
				if _rect_toca(_rect_propio(), player):
					_fase = Fase.TEMBLOR
		Fase.TEMBLOR:
			_t += delta
			var prog := clampf(_t / maxf(tiempo_temblor, 0.01), 0.0, 1.0)
			_visual.position.x = randf_range(-temblor_max, temblor_max) * prog
			if _t >= tiempo_temblor:
				_romper()
		Fase.CAYENDO:
			_vel_caida = minf(_vel_caida + gravedad_caida * delta, 2600.0)
			position.y += _vel_caida * delta
			if global_position.y > 4500.0:
				queue_free()


func _romper() -> void:
	if _fase == Fase.ROTA:
		return
	_shape.set_deferred("disabled", true)
	_visual.position.x = 0.0
	match modo_ruptura:
		Ruptura.DESTRUIR:
			_fase = Fase.ROTA
			var tw := create_tween()
			tw.set_parallel(true)
			tw.tween_property(_visual, "modulate:a", 0.0, 0.12)
			tw.tween_property(_visual, "scale", Vector2(1.3, 1.3), 0.12)
			tw.chain().tween_callback(queue_free)
		Ruptura.CAER:
			# El collider queda activo: el jugador cae junto con la plataforma.
			_fase = Fase.CAYENDO


## Rect global del collider de esta plataforma.
func _rect_propio() -> Rect2:
	if _shape == null or _shape.shape == null:
		return Rect2()
	var s: Vector2 = _shape.shape.size
	return Rect2(_shape.global_position - s * 0.5, s)


## Overlap determinista con el collider del player (patrón de pinchos).
func _rect_toca(a: Rect2, body: Node2D) -> bool:
	var csc := _csc_de(body)
	if csc == null or csc.shape == null:
		return false
	var s: Vector2
	if csc.shape is RectangleShape2D:
		s = csc.shape.size
	elif csc.shape is CapsuleShape2D:
		s = Vector2(csc.shape.radius * 2.0, csc.shape.height)
	else:
		return false
	var b := Rect2(body.global_position + csc.position - s * 0.5, s)
	return a.intersects(b)


func _csc_de(body: Node2D) -> CollisionShape2D:
	for child in body.get_children():
		if child is CollisionShape2D:
			return child
	return null


func _crear_visual_fallback() -> Polygon2D:
	var v := Polygon2D.new()
	v.name = "Visual"
	var m := Vector2(80, 12)
	v.polygon = PackedVector2Array([
		Vector2(-m.x, -m.y), Vector2(m.x, -m.y),
		Vector2(m.x, m.y), Vector2(-m.x, m.y),
	])
	v.color = Color(0.72, 0.56, 0.38)
	add_child(v)
	return v


func _crear_collision_fallback() -> CollisionShape2D:
	var s := CollisionShape2D.new()
	var r := RectangleShape2D.new()
	r.size = Vector2(160, 24)
	s.name = "Collision"
	s.shape = r
	add_child(s)
	return s