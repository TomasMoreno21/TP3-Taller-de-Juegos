extends StaticBody2D

signal cristal_destruido

@export var cristal_color: Color = Color(0.62, 0.42, 0.92)
@export var float_amplitude: float = 6.0
@export var float_speed: float = 2.0

var _roto := false
var _golpes := 0
const GOLPES_PARA_ROMPER := 3
var _base_y := 0.0
var _offset := 0.0

@onready var visual_root: Node2D = $Visual
@onready var poly: Polygon2D = $Visual/Poly
@onready var halo: Polygon2D = $Visual/Halo
@onready var sprite: Sprite2D = $Visual/Sprite
@onready var collision: CollisionShape2D = $Collision


func _ready() -> void:
	add_to_group("cristal")
	_base_y = visual_root.position.y if visual_root != null else 0.0
	_offset = randf() * TAU
	_actualizar_visual()


func _actualizar_visual() -> void:
	if poly != null:
		poly.color = cristal_color
		poly.polygon = _diamante_poligono(16, 22)
	if halo != null:
		halo.color = Color(cristal_color.r, cristal_color.g, cristal_color.b, 0.18)
		halo.polygon = _diamante_poligono(22, 30)
	if sprite != null and sprite.texture != null:
		sprite.visible = true
		if poly != null:
			poly.visible = false
		if halo != null:
			halo.visible = false
	else:
		if sprite != null:
			sprite.visible = false
		if poly != null:
			poly.visible = true
		if halo != null:
			halo.visible = true


func _process(_delta: float) -> void:
	if visual_root == null:
		return
	var t := Time.get_ticks_msec() * 0.001 * float_speed + _offset
	visual_root.position.y = _base_y + sin(t) * float_amplitude
	visual_root.modulate.a = 0.92 + sin(t * 1.7) * 0.08
	if halo != null:
		var hs := 1.0 + sin(t * 0.9) * 0.08
		halo.scale = Vector2(hs, hs)
		halo.modulate.a = 0.16 + sin(t * 1.3) * 0.06
	if sprite != null and sprite.visible:
		sprite.modulate.a = visual_root.modulate.a


func _diamante_poligono(ax: float, ay: float) -> PackedVector2Array:
	return PackedVector2Array([Vector2(0, -ay), Vector2(ax, 0), Vector2(0, ay), Vector2(-ax, 0)])


func take_damage(_cant: int, _kb: float = 0.0, _dir: int = 1) -> void:
	if _roto:
		return
	var player := get_tree().get_first_node_in_group("player")
	if player == null or int(player.get("current_form")) != 3:
		return
	_golpes += 1
	if _golpes < GOLPES_PARA_ROMPER:
		_flash_golpe()
		return
	_roto = true
	cristal_destruido.emit()
	_burst()
	var tw := create_tween()
	tw.tween_property(visual_root, "scale", Vector2(1.4, 1.4), 0.12)
	tw.parallel().tween_property(visual_root, "modulate:a", 0.0, 0.12)
	tw.tween_callback(queue_free)
	if collision != null:
		collision.set_deferred("disabled", true)


func _flash_golpe() -> void:
	if visual_root == null:
		return
	var cam := get_viewport().get_camera_2d()
	if cam != null and cam.has_method("shake"):
		cam.shake(2.5, 0.08)
	var base_col: Color = cristal_color
	if poly != null and poly.visible:
		poly.color = Color(1, 0.85, 0.85)
		var tw := create_tween()
		tw.tween_property(poly, "color", base_col.lerp(Color(1, 1, 1), 0.35), 0.14)
		var sc := visual_root.scale
		tw.parallel().tween_property(visual_root, "scale", sc * 1.18, 0.06)
		tw.tween_property(visual_root, "scale", sc, 0.08)
	if halo != null and halo.visible:
		halo.color = Color(1, 0.6, 0.6, 0.32)
		var tw2 := create_tween()
		tw2.tween_property(halo, "color", Color(cristal_color.r, cristal_color.g, cristal_color.b, 0.18), 0.14)
	_crack_visual()


func _crack_visual() -> void:
	if poly == null or not poly.visible:
		return
	var t := float(_golpes) / float(GOLPES_PARA_ROMPER)
	poly.modulate = Color(1, 1 - t * 0.15, 1 - t * 0.15)


func _burst() -> void:
	if DisplayServer.get_name() == "headless":
		return
	var p: CPUParticles2D = (load("res://scenes/burst.tscn") as PackedScene).instantiate()
	p.global_position = global_position
	p.self_modulate = cristal_color
	p.amount = 14
	get_tree().root.add_child(p)
	p.restart()
	p.emitting = true
