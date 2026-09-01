extends Area2D

var direction := Vector2.RIGHT
var speed := 700.0
var damage := 15
var enemy_shot := false
var homing := false
var homing_strength := 6.5
var homing_range := 500.0
var _life := 2.5

@onready var visual: Polygon2D = $Visual
@onready var hitbox: CollisionShape2D = $Hitbox


func _ready() -> void:
	collision_mask = 4 if enemy_shot else 2
	body_entered.connect(_on_body_entered)
	monitoring = true


func _physics_process(delta: float) -> void:
	if homing and not enemy_shot:
		var target: Node2D = _buscar_enemigo_cercano()
		if target != null:
			var to_target: Vector2 = target.global_position - global_position
			if to_target.length_squared() > 0.01:
				var dir_deseada: Vector2 = to_target.normalized()
				var blended: Vector2 = direction.lerp(dir_deseada, homing_strength * delta)
				if blended.length_squared() > 0.01:
					direction = blended.normalized()
	global_position += direction * speed * delta
	if _fuera_de_camara():
		queue_free()
		return
	_life -= delta
	if _life <= 0.0:
		queue_free()


func _fuera_de_camara() -> bool:
	var cam := get_viewport().get_camera_2d()
	if cam == null:
		return false
	var view_size: Vector2 = get_viewport_rect().size / cam.zoom
	var cam_pos: Vector2 = cam.global_position
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
	if body.has_method("take_damage"):
		body.take_damage(damage, 120.0, int(direction.x))
		if homing and not enemy_shot and body.is_in_group("enemy"):
			var v := body.get_node_or_null("Visual")
			if v != null:
				v.modulate = Color(0.78, 0.55, 1.0)
				var tw := v.create_tween()
				tw.tween_property(v, "modulate", Color(1, 1, 1), 0.12)
	queue_free()
