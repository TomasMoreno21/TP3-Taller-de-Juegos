extends Area2D

var direction := Vector2.RIGHT
var speed := 700.0
var damage := 15
var enemy_shot := false
var homing := false
var homing_strength := 4.0
var homing_range := 500.0
var _life := 2.5

@onready var visual: Polygon2D = $Visual
@onready var hitbox: CollisionShape2D = $Hitbox


func _ready() -> void:
	collision_mask = 4 if enemy_shot else 3
	body_entered.connect(_on_body_entered)
	monitoring = true


func _physics_process(delta: float) -> void:
	if homing and not enemy_shot:
		var target: Node2D = _buscar_enemigo_cercano()
		if target != null:
			var dir_deseada := (target.global_position - global_position).normalized()
			direction = direction.lerp(dir_deseada, homing_strength * delta).normalized()
	global_position += direction * speed * delta
	_life -= delta
	if _life <= 0.0:
		queue_free()


func _buscar_enemigo_cercano() -> Node2D:
	var mejor: Node2D = null
	var mejor_dist := homing_range
	for n in get_tree().get_nodes_in_group("enemy"):
		if not is_instance_valid(n) or not n.has_method("take_damage"):
			continue
		if "health" in n and n.health <= 0:
			continue
		var d := global_position.distance_to(n.global_position)
		if d < mejor_dist:
			mejor_dist = d
			mejor = n
	return mejor


func _on_body_entered(body: Node2D) -> void:
	if body.has_method("take_damage"):
		body.take_damage(damage, 120.0, int(direction.x))
	queue_free()
