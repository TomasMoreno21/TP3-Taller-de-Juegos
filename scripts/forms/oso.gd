class_name Oso
extends Forma


func _init() -> void:
	form_name = "Espíritu del Oso"
	speed = 140.0
	jump_velocity = -360.0
	gravity_scale = 1.45
	max_health = 160
	attack_damage = 30
	attack_range = 40.0
	attack_size = Vector2(56, 44)
	light_combo_steps = 2
	heavy_damage = 45
	heavy_range = 52.0
	heavy_size = Vector2(72, 52)
	heavy_combo_steps = 2
	special_damage = 60
	color = Color(0.55, 0.4, 0.22)
	collider_size = Vector2(48, 38)
	shake_strength = 14.0


func perform_heavy(player: CharacterBody2D, step: int) -> void:
	player.enable_melee(heavy_size, heavy_range, heavy_damage_at(step), 220.0)


func perform_special(player: CharacterBody2D) -> void:
	player.enable_melee(Vector2(130, 70), 78.0, special_damage, 320.0)
	var cam := player.get_viewport().get_camera_2d()
	if cam != null and cam.has_method("shake"):
		cam.shake(10.0)
