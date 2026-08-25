extends StaticBody2D

@export var required_form: int = 2
@export var interact_range: float = 220.0

var destroyed := false
var _t := 0.0

@onready var visual_root: Node2D = $Visual
@onready var poly: Polygon2D = $Visual/Poly
@onready var sprite: Sprite2D = $Visual/Sprite


func _ready() -> void:
	add_to_group("interactable")
	if sprite != null and sprite.texture == null:
		sprite.visible = false
	if poly != null:
		poly.visible = sprite == null or sprite.texture == null or not sprite.visible


func _process(delta: float) -> void:
	_t += delta
	if visual_root != null and poly != null and not destroyed:
		var s := 1.0 + sin(_t * 1.1) * 0.012
		visual_root.scale = Vector2(s, s)
		var player := get_tree().get_first_node_in_group("player")
		if player != null and global_position.distance_to(player.global_position) < interact_range + 40.0:
			if int(player.get("current_form")) == required_form:
				poly.modulate = Color(1.08, 1.08, 1.02)
			else:
				poly.modulate = Color(0.98, 0.96, 0.94)


func try_interact(player: Node2D) -> bool:
	if destroyed:
		return false
	if player.global_position.distance_to(global_position) > interact_range:
		return false
	if int(player.get("current_form")) != required_form:
		_flash_fallo()
		return false
	destroyed = true
	_burst()
	var tw := create_tween()
	tw.tween_property(visual_root, "scale", Vector2(1.12, 0.88), 0.08)
	tw.tween_property(visual_root, "modulate:a", 0.0, 0.18)
	tw.tween_callback(queue_free)
	var cam := get_viewport().get_camera_2d()
	if cam != null and cam.has_method("shake"):
		cam.shake(5.0, 0.14)
	return true


func _flash_fallo() -> void:
	if poly == null or DisplayServer.get_name() == "headless":
		return
	var tw := create_tween()
	var base := poly.color
	poly.color = Color(0.9, 0.45, 0.45)
	tw.tween_property(poly, "color", base, 0.18)


func _burst() -> void:
	if DisplayServer.get_name() == "headless":
		return
	var p: CPUParticles2D = (load("res://scenes/burst.tscn") as PackedScene).instantiate()
	p.global_position = global_position
	p.self_modulate = Color(0.52, 0.38, 0.22)
	p.amount = 18
	get_tree().root.add_child(p)
	p.restart()
	p.emitting = true
