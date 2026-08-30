extends Node2D

@export var barrera_id: String = "barrera_1"

var _destruidos := 0
var _abierta := false
var _t := 0.0

@onready var barrera: StaticBody2D = $Barrera
@onready var barrera_visual_root: Node2D = $Barrera/Visual
@onready var barrera_poly: Polygon2D = $Barrera/Visual/Poly
@onready var barrera_sprite: Sprite2D = $Barrera/Visual/Sprite
@onready var barrera_collision: CollisionShape2D = $Barrera/Collision
@onready var ray: Line2D = $Ray
@onready var luz_barrera: PointLight2D = $Barrera/Visual/LuzBarrera


func _ready() -> void:
	var prog := _progresion()
	if prog != null and prog.barreras_abiertas.has(barrera_id):
		_abrir_instantaneo()
		return
	if barrera_sprite != null and barrera_sprite.texture == null:
		barrera_sprite.visible = false
	if barrera_poly != null:
		barrera_poly.visible = barrera_sprite == null or barrera_sprite.texture == null or not barrera_sprite.visible
	for c in _cristales():
		if c.has_signal("cristal_destruido"):
			c.cristal_destruido.connect(_on_cristal_destruido)
	_actualizar_ray()


func _process(delta: float) -> void:
	if _abierta:
		return
	_t += delta
	if barrera_visual_root != null:
		var s := 1.0 + sin(_t * 0.9) * 0.012
		barrera_visual_root.scale = Vector2(s, s)
		if barrera_poly != null:
			barrera_poly.modulate.a = 0.62 + sin(_t * 1.2) * 0.09
		if luz_barrera != null:
			luz_barrera.energy = 1.6 + sin(_t * 1.1) * 0.35
	_actualizar_ray()
	_brillo_proximidad()


func _cristales() -> Array:
	var res: Array = []
	for child in get_children():
		if child.has_method("take_damage") and child.is_in_group("cristal"):
			res.append(child)
	return res


func _on_cristal_destruido() -> void:
	if _abierta:
		return
	_destruidos += 1
	_actualizar_ray()
	if barrera_visual_root != null:
		var tw := create_tween()
		tw.tween_property(barrera_visual_root, "scale", Vector2(1.06, 1.06), 0.08)
		tw.tween_property(barrera_visual_root, "scale", Vector2(1.0, 1.0), 0.12)
		if barrera_poly != null:
			barrera_poly.modulate = Color(0.9, 0.75, 1.0)
			tw.parallel().tween_property(barrera_poly, "modulate", Color(0.45, 0.3, 0.65, 0.55), 0.18)
	if _destruidos >= 3:
		_abrir_animado()


func _actualizar_ray() -> void:
	if ray == null:
		return
	var vivos: Array = []
	for c in _cristales():
		if is_instance_valid(c) and not c.get("_roto"):
			vivos.append(c)
	if vivos.size() < 2:
		ray.visible = false
		return
	ray.visible = true
	var pts := PackedVector2Array()
	for c in vivos:
		pts.append(c.position)
	if vivos.size() == 3:
		pts.append(vivos[0].position)
	ray.points = pts
	ray.width = 3.5
	ray.default_color = Color(0.62, 0.42, 0.92, 0.32)


func _brillo_proximidad() -> void:
	var player := get_tree().get_first_node_in_group("player") as Node2D
	if player == null or barrera_poly == null:
		return
	var d := global_position.distance_to(player.global_position)
	var near := d < 260.0 and int(player.get("current_form")) == 3
	if near:
		barrera_poly.modulate = barrera_poly.modulate.lerp(Color(0.58, 0.42, 0.78, 0.65), 0.08)
		if ray != null:
			ray.default_color = Color(0.62, 0.42, 0.92, 0.42)


func _abrir_instantaneo() -> void:
	_abierta = true
	if barrera != null:
		barrera.visible = false
		if barrera_collision != null:
			barrera_collision.disabled = true
	if luz_barrera != null:
		luz_barrera.enabled = false
	if ray != null:
		ray.visible = false
	for c in _cristales():
		if is_instance_valid(c):
			c.queue_free()


func _abrir_animado() -> void:
	if _abierta:
		return
	_abierta = true
	var prog := _progresion()
	if prog != null:
		prog.barreras_abiertas[barrera_id] = true
	if barrera_collision != null:
		barrera_collision.set_deferred("disabled", true)
	if luz_barrera != null:
		var twl := create_tween()
		twl.tween_property(luz_barrera, "energy", 0.0, 0.35)
	_burst_barrera()
	if ray != null:
		var twr := create_tween()
		twr.tween_property(ray, "modulate:a", 0.0, 0.22)
	if barrera_visual_root != null:
		var tw := create_tween()
		tw.tween_property(barrera_visual_root, "modulate:a", 0.0, 0.35)
		tw.parallel().tween_property(barrera_visual_root, "scale", Vector2(1.08, 1.08), 0.35)
		tw.tween_callback(func() -> void:
			if is_instance_valid(barrera):
				barrera.visible = false
		)
	var cam := get_viewport().get_camera_2d()
	if cam != null and cam.has_method("shake"):
		cam.shake(7.0, 0.28)


func _burst_barrera() -> void:
	if DisplayServer.get_name() == "headless":
		return
	var p: CPUParticles2D = (load("res://scenes/burst.tscn") as PackedScene).instantiate()
	p.global_position = barrera.global_position if barrera != null else global_position
	p.self_modulate = Color(0.55, 0.35, 0.85)
	p.amount = 32
	get_tree().root.add_child(p)
	p.restart()
	p.emitting = true


func _progresion() -> Node:
	return get_node_or_null("/root/Progresion")
