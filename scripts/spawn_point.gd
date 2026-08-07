extends Node2D

signal enemy_spawned(enemy: Node2D)

const ENEMY_SCENE := preload("res://scenes/enemy.tscn")

const ENEMY_TYPES := {
	"cultista": {"health": 100, "color": Color(0.65, 0.22, 0.22), "name": "Cultista"},
	"arquero": {"health": 100, "color": Color(0.4, 0.55, 0.85), "name": "Arquero"},
	"chaman": {"health": 100, "color": Color(0.62, 0.35, 0.7), "name": "Chamán"},
}

var enemy_type := "cultista"
var spawn_delay := 0.0
var from_edge := false

var telegraph_alpha := 0.0:
	set(value):
		telegraph_alpha = value
		queue_redraw()


func configure(entry: Dictionary) -> void:
	enemy_type = entry.get("type", "cultista")
	spawn_delay = entry.get("delay", 0.0)
	from_edge = entry.get("edge", false)


func start_spawn() -> void:
	var tween := create_tween()
	if spawn_delay > 0.0:
		tween.tween_interval(spawn_delay)
	tween.tween_property(self, "telegraph_alpha", 1.0, 0.35)
	tween.tween_interval(0.15)
	tween.tween_property(self, "telegraph_alpha", 0.0, 0.2)
	tween.tween_callback(_spawn_enemy)


func _spawn_enemy() -> void:
	var data: Dictionary = ENEMY_TYPES[enemy_type]
	var enemy: CharacterBody2D = ENEMY_SCENE.instantiate()
	enemy.edge_walk_in = from_edge
	if from_edge:
		var player := get_tree().get_first_node_in_group("player")
		var side := 1.0
		if player != null and player.global_position.x > global_position.x:
			side = -1.0
		enemy.position = Vector2(side * 500.0, 0.0)
	get_parent().add_child(enemy)
	enemy.configure(data["health"], data["color"], data["name"])
	enemy_spawned.emit(enemy)
	queue_free()


func _draw() -> void:
	if telegraph_alpha <= 0.01:
		return
	var a := telegraph_alpha
	draw_circle(Vector2.ZERO, 18.0, Color(0.7, 0.9, 0.4, 0.25 * a))
	draw_arc(Vector2.ZERO, 18.0, 0.0, TAU, 24, Color(0.8, 1.0, 0.5, 0.9 * a), 2.0)
	draw_arc(Vector2.ZERO, 26.0, 0.0, TAU, 24, Color(0.8, 1.0, 0.5, 0.6 * a), 1.5)
