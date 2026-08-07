class_name Forma
extends RefCounted

var form_name: String = "Forma"
var speed: float = 200.0
var jump_velocity: float = -420.0
var gravity_scale: float = 1.0
var max_health: int = 100

# Combo ligero (repetición de J)
var attack_damage: int = 10
var attack_range: float = 26.0
var attack_size: Vector2 = Vector2(30, 24)
var light_combo_steps: int = 3
var light_knockback: float = 80.0

# Combo fuerte (repetición de K)
var heavy_damage: int = 20
var heavy_range: float = 36.0
var heavy_size: Vector2 = Vector2(44, 34)
var heavy_combo_steps: int = 2

# Ataque especial (L)
var special_damage: int = 25

var color: Color = Color(1, 1, 1)
var collider_size: Vector2 = Vector2(16, 40)
var shake_strength: float = 8.0
var shake_duration: float = 0.15
var hit_rotation: float = 14.0
var hit_zoom: float = 1.02


func tick(_player: CharacterBody2D, _delta: float) -> void:
	pass


func is_dashing() -> bool:
	return false


func dash_speed() -> float:
	return 0.0


func is_gliding(_player: CharacterBody2D) -> bool:
	return false


func try_jump(player: CharacterBody2D) -> void:
	player.velocity.y = jump_velocity


func on_floor(_player: CharacterBody2D) -> void:
	pass


func light_damage_at(step: int) -> int:
	return attack_damage + attack_damage / 2 * (step - 1)


func heavy_damage_at(step: int) -> int:
	return heavy_damage + heavy_damage / 2 * (step - 1)


func perform_light(player: CharacterBody2D, step: int) -> void:
	player.enable_melee(attack_size, attack_range, light_damage_at(step), light_knockback)


func perform_heavy(player: CharacterBody2D, step: int) -> void:
	player.enable_melee(heavy_size, heavy_range, heavy_damage_at(step), 150.0)


func perform_special(_player: CharacterBody2D) -> void:
	pass


func perform_jump_attack(player: CharacterBody2D, heavy: bool) -> void:
	if heavy:
		player.enable_melee(heavy_size, heavy_range, heavy_damage)
	else:
		player.enable_melee(attack_size, attack_range, attack_damage)


func reset_state() -> void:
	pass
