extends Area2D

signal activado

const SCENA_VICTORIA := "res://scenes/victoria.tscn"

@export var auto_curar := true
@export var activar_victoria := false
var _activado := false


func _ready() -> void:
	monitoring = true
	collision_mask = 4
	body_entered.connect(_on_body_entered)


func _on_body_entered(body: Node2D) -> void:
	if not body.has_method("actualizar_checkpoint"):
		return
	body.actualizar_checkpoint(global_position + Vector2(0, -60))
	if auto_curar and body.has_method("heal_full"):
		body.heal_full()
	if not _activado:
		_activado = true
		_mostrar_victoria()
		activado.emit()


func _mostrar_victoria() -> void:
	if not activar_victoria:
		return
	var escena: PackedScene = load(SCENA_VICTORIA)
	var victoria: CanvasLayer = escena.instantiate()
	get_tree().current_scene.add_child(victoria)
	get_tree().paused = true
