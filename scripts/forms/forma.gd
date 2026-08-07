class_name Forma
extends RefCounted

var form_name: String = "Forma"
var speed: float = 200.0
var jump_velocity: float = -420.0
var gravity_scale: float = 1.0
var max_health: int = 100
var attack_damage: int = 10
var attack_range: float = 26.0
var attack_size: Vector2 = Vector2(30, 24)
var color: Color = Color(1, 1, 1)
var collider_size: Vector2 = Vector2(16, 40)
var shake_strength: float = 8.0
var shake_duration: float = 0.15
var hit_rotation: float = 14.0
var hit_zoom: float = 0.0


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


func perform_attack(player: CharacterBody2D) -> void:
	player.enable_melee(attack_size, attack_range)


func reset_state() -> void:
	pass
