@tool
extends Area2D

@export var climb_speed: float = 260.0
@export var ancho: float = 32.0:
	set(v):
		ancho = v
		if is_inside_tree():
			_actualizar_visual()
@export var alto: float = 400.0:
	set(v):
		alto = v
		if is_inside_tree():
			_actualizar_visual()
@export var required_form: int = 0

func _enter_tree() -> void:
	if Engine.is_editor_hint():
		_actualizar_visual()

func _ready() -> void:
	add_to_group("enredadera")
	collision_layer = 0
	collision_mask = 4
	monitoring = true
	monitorable = true
	_actualizar_visual()

var _t: float = 0.0

func _process(delta: float) -> void:
	if Engine.is_editor_hint() and is_inside_tree():
		var cs := get_node_or_null("Collision") as CollisionShape2D
		if cs and cs.shape is RectangleShape2D:
			if (cs.shape as RectangleShape2D).size != Vector2(ancho, alto):
				_actualizar_visual()
				return
		var poly := get_node_or_null("Visual/Poly") as Polygon2D
		if poly:
			var w := ancho * 0.5
			var h := alto * 0.5
			var exp := PackedVector2Array([Vector2(-w, -h), Vector2(w, -h), Vector2(w, h), Vector2(-w, h)])
			if poly.polygon != exp:
				_actualizar_visual()
		return
	_t += delta
	var visual := get_node_or_null("Visual") as Node2D
	if visual == null:
		return
	var sway_base := sin(_t * 0.8 + global_position.y * 0.008) * 2.8
	var player := get_tree().get_first_node_in_group("player") as Node2D
	if player != null and player.get("_trepando") and player.get("_enredadera_actual") == self:
		var vy: float = float(player.get("velocity").y) if "velocity" in player else 0.0
		if absf(vy) > 80.0:
			sway_base += sin(_t * 1.8) * 3.2 * clampf(absf(vy) / 320.0, 0.0, 1.0)
	visual.position.x = sway_base

func _actualizar_visual() -> void:
	var cs := get_node_or_null("Collision") as CollisionShape2D
	if cs and cs.shape is RectangleShape2D:
		if not cs.shape.resource_local_to_scene:
			cs.shape = (cs.shape as RectangleShape2D).duplicate()
			cs.shape.resource_local_to_scene = true
		(cs.shape as RectangleShape2D).size = Vector2(ancho, alto)
	var poly := get_node_or_null("Visual/Poly") as Polygon2D
	if poly:
		var w := ancho * 0.5
		var h := alto * 0.5
		poly.polygon = PackedVector2Array([Vector2(-w, -h), Vector2(w, -h), Vector2(w, h), Vector2(-w, h)])
	var hojas_root := get_node_or_null("Visual/Hojas") as Node2D
	if hojas_root:
		for c in hojas_root.get_children():
			if Engine.is_editor_hint():
				c.free()
			else:
				c.queue_free()
		var segmentos := int(alto / 80.0)
		for i in range(maxi(segmentos, 1)):
			var hoja := Polygon2D.new()
			hoja.color = Color(0.32, 0.6, 0.26, 1)
			var y_base := -alto * 0.5 + 40.0 + i * 80.0
			var flip := 1 if i % 2 == 0 else -1
			hoja.polygon = PackedVector2Array([Vector2(-20 * flip, y_base), Vector2(-12 * flip, y_base), Vector2(-10 * flip, y_base + 40), Vector2(-22 * flip, y_base + 40)])
			hojas_root.add_child(hoja)
			if Engine.is_editor_hint():
				hoja.owner = get_tree().edited_scene_root
