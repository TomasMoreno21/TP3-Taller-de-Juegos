class_name Lobo
extends Forma

const DASH_MULTIPLIER := 2.4

var _dash_timer := 0.0


func _init() -> void:
	form_name = "Espíritu del Lobo"
	speed = 340.0
	jump_velocity = -460.0
	gravity_scale = 0.9
	max_health = 80
	attack_damage = 5
	attack_range = 20.0
	attack_size = Vector2(42, 26)
	color = Color(0.58, 0.64, 0.75)
	collider_size = Vector2(34, 28)
	shake_strength = 4.0
	hit_zoom = 1.06


func tick(player: CharacterBody2D, delta: float) -> void:
	if _dash_timer > 0.0:
		_dash_timer -= delta
		if _dash_timer <= 0.0:
			player.end_attack()


func is_dashing() -> bool:
	return _dash_timer > 0.0


func dash_speed() -> float:
	return speed * DASH_MULTIPLIER


func perform_attack(player: CharacterBody2D) -> void:
	player.enable_melee(attack_size, attack_range)
	_dash_timer = 0.22


func reset_state() -> void:
	_dash_timer = 0.0
