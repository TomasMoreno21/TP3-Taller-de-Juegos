extends CharacterBody2D

signal died

var enemy_name: String = "Enemigo"
var health: int = 100
var max_health: int = 100
var approach_speed := 60.0
var stop_distance := 70.0
var edge_walk_in := false

var _flash_tween: Tween
var _knockback_timer := 0.0
var _knockback_velocity := Vector2.ZERO

const GRAVITY := 980.0
const MAX_FALL_SPEED := 950.0

@onready var visual: Polygon2D = $Visual
@onready var hp_label: Label = $HpLabel


func _ready() -> void:
	add_to_group("enemy")
	hp_label.text = str(health)
	var tween := create_tween()
	visual.modulate.a = 0.0
	tween.tween_property(visual, "modulate:a", 1.0, 0.25)


func apply_knockback(vec: Vector2) -> void:
	_knockback_velocity.x = vec.x
	velocity = vec
	_knockback_timer = 0.18


func configure(hp: int, tint: Color, new_name: String) -> void:
	health = hp
	max_health = hp
	enemy_name = new_name
	visual.color = tint
	hp_label.text = str(hp)
	if edge_walk_in:
		approach_speed = 120.0


func _physics_process(delta: float) -> void:
	if _knockback_timer > 0.0:
		_knockback_timer -= delta
		velocity.x = _knockback_velocity.x
		_knockback_velocity.x *= maxf(1.0 - delta * 8.0, 0.0)
	else:
		var player := get_tree().get_first_node_in_group("player")
		if player == null:
			velocity.y = min(velocity.y + GRAVITY * delta, MAX_FALL_SPEED)
			move_and_slide()
			return
		var dx: float = player.global_position.x - global_position.x
		if absf(dx) > stop_distance:
			velocity.x = signf(dx) * approach_speed
			visual.scale.x = -1.0 if dx < 0.0 else 1.0
		else:
			velocity.x = 0.0
	velocity.y = min(velocity.y + GRAVITY * delta, MAX_FALL_SPEED)
	move_and_slide()


func take_damage(amount: int) -> void:
	health -= amount
	hp_label.text = str(max(health, 0))
	if health <= 0:
		die()
	else:
		var feedback := _get_hit_feedback()
		_shake_camera(feedback)
		_flash(feedback)


func _get_hit_feedback() -> Dictionary:
	var player := get_tree().get_first_node_in_group("player")
	if player == null or player.forms.is_empty():
		return {"shake_strength": 8.0, "rotation": 14.0, "zoom": 0.0}
	var form: Forma = player.forms[player.current_form]
	return {"shake_strength": form.shake_strength, "rotation": form.hit_rotation, "zoom": form.hit_zoom}


func _flash(feedback: Dictionary) -> void:
	if _flash_tween != null and _flash_tween.is_valid():
		_flash_tween.kill()
	var base: Color = visual.color
	var direction := -1.0 if randf() < 0.5 else 1.0
	var rotation_deg: float = feedback["rotation"]
	_flash_tween = create_tween()
	_flash_tween.parallel().tween_property(visual, "color", Color(1.0, 0.25, 0.25), 0.05)
	_flash_tween.parallel().tween_property(visual, "rotation", deg_to_rad(direction * rotation_deg), 0.05)
	_flash_tween.tween_interval(0.06)
	_flash_tween.parallel().tween_property(visual, "color", base, 0.14)
	_flash_tween.parallel().tween_property(visual, "rotation", 0.0, 0.14)


func _shake_camera(feedback: Dictionary) -> void:
	var cam := get_viewport().get_camera_2d()
	if cam == null:
		return
	if cam.has_method("shake"):
		cam.shake(feedback["shake_strength"])
	var zoom: float = feedback["zoom"]
	if zoom > 0.0 and cam.has_method("zoom_punch"):
		cam.zoom_punch(zoom)


func die() -> void:
	died.emit()
	queue_free()
