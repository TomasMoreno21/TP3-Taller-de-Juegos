class_name Buho
extends Forma

var _double_jump_available := true


func _init() -> void:
	form_name = "Espíritu del Búho"
	speed = 215.0
	jump_velocity = -400.0
	gravity_scale = 0.8
	max_health = 90
	attack_damage = 15
	attack_range = 0.0
	attack_size = Vector2(1, 1)
	color = Color(0.52, 0.4, 0.62)
	collider_size = Vector2(28, 30)


func try_jump(player: CharacterBody2D) -> void:
	if player.is_on_floor():
		player.velocity.y = jump_velocity
	elif _double_jump_available:
		player.velocity.y = jump_velocity * 0.9
		_double_jump_available = false


func is_gliding(player: CharacterBody2D) -> bool:
	return Input.is_action_pressed("jump") and not player.is_on_floor()


func on_floor(_player: CharacterBody2D) -> void:
	_double_jump_available = true


func perform_attack(player: CharacterBody2D) -> void:
	player.fire_projectile()


func reset_state() -> void:
	_double_jump_available = true
