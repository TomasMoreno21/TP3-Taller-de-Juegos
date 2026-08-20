class_name Oso
extends Forma

const LANDING_IMPACT_MIN := 500.0
const LANDING_IMPACT_SHAKE := 900.0

var _landing_tween: Tween


func _init() -> void:
	form_name = "Oso"
	speed = 140.0
	jump_velocity = -420.0
	gravity_scale = 1.45
	max_health = 100
	attack_damage = 30
	attack_range = 120.0
	attack_size = Vector2(168, 132)
	light_combo_steps = 2
	heavy_damage = 45
	heavy_range = 156.0
	heavy_size = Vector2(216, 156)
	heavy_combo_steps = 2
	special_damage = 60
	color = Color(0.55, 0.4, 0.22)
	collider_size = Vector2(175, 300)
	shake_strength = 14.0
	turn_tilt = 9.0
	transform_duration = 10.0
	accel = 900.0
	friction = 700.0
	camera_zoom = Vector2(0.9, 0.9)
	turn_tilt_cam = 0.05
	combos = [
		{"nombre": "Garra", "secuencia": ["light", "heavy"], "dano": 84, "knockback": 360.0, "tamano": Vector2(288, 186), "rango": 198.0},
	]


func perform_heavy(player: CharacterBody2D, step: int) -> void:
	player.enable_melee(heavy_size, heavy_range, heavy_damage_at(step), 220.0)


func perform_special(player: CharacterBody2D) -> void:
	player.enable_melee(Vector2(390, 210), 234.0, special_damage, 320.0)
	var cam := player.get_viewport().get_camera_2d()
	if cam != null and cam.has_method("shake"):
		cam.shake(10.0)


func on_landing(player: CharacterBody2D, fall_impact: float) -> void:
	if fall_impact < LANDING_IMPACT_MIN:
		return
	player.squash_y(0.55, 0.12)
	var cam := player.get_viewport().get_camera_2d()
	if fall_impact >= LANDING_IMPACT_SHAKE and cam != null and cam.has_method("shake"):
		cam.shake(6.0)
