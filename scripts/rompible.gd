extends StaticBody2D

@export var box_size := Vector2(30, 34)
@export var box_color := Color(0.5, 0.35, 0.2)

const GOLPES_PARA_ROMPER := 3

var golpes := 0
var broken := false

@onready var visual: CanvasItem = get_node_or_null("Visual")
@onready var sprite: Sprite2D = get_node_or_null("Sprite2D")
@onready var collision: CollisionShape2D = $Collision


func _ready() -> void:
	if visual == null and sprite != null:
		visual = sprite
	add_to_group("rompible")


func registrar_golpe(_dano: int) -> void:
	if broken:
		return
	golpes += 1
	if golpes >= GOLPES_PARA_ROMPER:
		_romper()
	else:
		visual.modulate = Color(0.7, 0.7, 0.7)


func _romper() -> void:
	broken = true
	_soltar_pickup()
	get_node("/root/Progresion").add_fragmentos(1)
	queue_free()


func _soltar_pickup() -> void:
	var pickup: Area2D = preload("res://scenes/pickup.tscn").instantiate()
	pickup.global_position = global_position - Vector2(0, 20)
	var destino: Node = get_tree().current_scene if get_tree().current_scene != null else get_parent()
	destino.add_child(pickup)
