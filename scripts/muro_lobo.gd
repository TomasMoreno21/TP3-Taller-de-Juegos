extends StaticBody2D

@export var assist_altura: float = 18.0
@export var assist_distancia: float = 70.0

@onready var visual_root: Node2D = $Visual
@onready var poly: Polygon2D = $Visual/Poly
@onready var sprite: Sprite2D = $Visual/Sprite


func _ready() -> void:
	if sprite != null and sprite.texture == null:
		sprite.visible = false
	if poly != null:
		poly.visible = sprite == null or sprite.texture == null or not sprite.visible


func _physics_process(_delta: float) -> void:
	var player := get_tree().get_first_node_in_group("player") as Node2D
	if player == null or not is_instance_valid(player):
		return
	if int(player.get("current_form")) != 1:
		return
	if not (player as CharacterBody2D).is_on_wall():
		return
	var top_y: float = global_position.y - 125.0
	var dist_x: float = absf(player.global_position.x - global_position.x)
	var dist_y: float = player.global_position.y - top_y
	if dist_x > assist_distancia or dist_y < -40.0 or dist_y > 40.0:
		return
	var p_body := player as CharacterBody2D
	if p_body.test_move(Transform2D(0, Vector2(0, -assist_altura)), Vector2.ZERO):
		return
	if p_body.test_move(Transform2D(0, Vector2(0, -assist_altura)).translated(Vector2(0, 0)), Vector2(p_body.get("facing") * 4, 0)):
		return
	player.global_position.y -= assist_altura
	if p_body.velocity.y > -60.0:
		p_body.velocity.y = -90.0
