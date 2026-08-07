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
	light_combo_steps = 3
	heavy_damage = 8
	heavy_range = 26.0
	heavy_size = Vector2(46, 30)
	heavy_combo_steps = 2
	special_damage = 12
	color = Color(0.58, 0.64, 0.75)
	collider_size = Vector2(34, 28)
	shake_strength = 4.0
	hit_zoom = 1.02


func tick(player: CharacterBody2D, delta: float) -> void:
	if _dash_timer > 0.0:
		_dash_timer -= delta
		if _dash_timer <= 0.0:
			player.end_attack()


func is_dashing() -> bool:
	return _dash_timer > 0.0


func dash_speed() -> float:
	return speed * DASH_MULTIPLIER


func perform_light(player: CharacterBody2D, step: int) -> void:
	player.enable_melee(attack_size, attack_range, light_damage_at(step), light_knockback)
	_dash_timer = 0.22


func perform_special(player: CharacterBody2D) -> void:
	player.show_aoe_area(240.0)
	player.aoe_knockback(240.0, special_damage, 320.0)


func reset_state() -> void:
	_dash_timer = 0.0
