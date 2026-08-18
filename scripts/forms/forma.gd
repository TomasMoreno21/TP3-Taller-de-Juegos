class_name Forma
extends Resource

@export var form_name: String = "Forma"
@export var speed: float = 200.0
@export var jump_velocity: float = -420.0
@export var gravity_scale: float = 1.0
@export var max_health: int = 100
@export var jumps: int = 1

var _jumps_usados := 0

# Combo ligero (repetición de J)
@export var attack_damage: int = 10
@export var attack_range: float = 26.0
@export var attack_size: Vector2 = Vector2(30, 24)
@export var light_combo_steps: int = 3
@export var light_knockback: float = 80.0

# Combo fuerte (repetición de K)
@export var heavy_damage: int = 20
@export var heavy_range: float = 36.0
@export var heavy_size: Vector2 = Vector2(44, 34)
@export var heavy_combo_steps: int = 2

# Ataque especial (L)
@export var special_damage: int = 25

# Combos por secuencia (desbloqueables al subir de nivel)
# Cada entry: {"nombre", "secuencia" (Array de "light"/"heavy"/"special"), "dano", "knockback", "tamano", "rango"}
@export var combos: Array[Dictionary] = []

@export var color: Color = Color(1, 1, 1)
@export var collider_size: Vector2 = Vector2(16, 40)
@export var shake_strength: float = 8.0
@export var shake_duration: float = 0.15
@export var hit_rotation: float = 14.0
@export var hit_zoom: float = 1.02
@export var transform_duration: float = 14.0
@export var turn_tilt: float = 0.0


func tick(_player: CharacterBody2D, _delta: float) -> void:
	pass


func is_dashing() -> bool:
	return false


func dash_speed() -> float:
	return 0.0


func is_gliding(_player: CharacterBody2D) -> bool:
	return false


func try_jump(player: CharacterBody2D) -> void:
	if _jumps_usados >= jumps:
		return
	player.velocity.y = jump_velocity
	_jumps_usados += 1
	if _jumps_usados >= 2:
		on_second_jump(player)


func on_second_jump(_player: CharacterBody2D) -> void:
	pass


func can_jump() -> bool:
	return _jumps_usados < jumps


func on_floor(_player: CharacterBody2D) -> void:
	_jumps_usados = 0


func on_landing(_player: CharacterBody2D, _fall_impact: float) -> void:
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


func perform_combo(player: CharacterBody2D, combo: Dictionary) -> void:
	player.enable_melee(
		combo.get("tamano", attack_size),
		combo.get("rango", attack_range),
		combo.get("dano", attack_damage),
		combo.get("knockback", 200.0)
	)


func perform_jump_attack(player: CharacterBody2D, heavy: bool) -> void:
	if heavy:
		player.enable_melee(heavy_size, heavy_range, heavy_damage)
	else:
		player.enable_melee(attack_size, attack_range, attack_damage)


func reset_form_state() -> void:
	_jumps_usados = 0
