extends Area2D

## Punto de control colocable desde el editor: al tocarlo guarda el respawn
## completo del jugador (posición, forma, vida, energía) y se enciende.
## Al morir, derrota.gd teletransporta al jugador acá SIN recargar el nivel.

signal activado

@export var offset_respawn := Vector2(0, -60)
@export var color_apagado := Color(0.45, 0.5, 0.62)
@export var color_encendido := Color(0.35, 0.9, 0.6)

var _activado := false

@onready var visual: Polygon2D = $Visual
@onready var glow: Polygon2D = $Visual/Glow


func _ready() -> void:
	monitoring = true
	collision_layer = 0
	collision_mask = 4
	body_entered.connect(_on_body_entered)
	_pintar(false)


func _on_body_entered(body: Node2D) -> void:
	if body.has_method("actualizar_checkpoint"):
		body.actualizar_checkpoint(global_position + offset_respawn)
	if not _activado:
		_activado = true
		_pintar(true)
		activado.emit()
		_burst()


func _pintar(encendido: bool) -> void:
	var c := color_encendido if encendido else color_apagado
	visual.color = c
	glow.color = Color(c, 0.35)


func _burst() -> void:
	if DisplayServer.get_name() == "headless":
		return
	var p: CPUParticles2D = (load("res://scenes/burst.tscn") as PackedScene).instantiate()
	p.global_position = global_position
	p.self_modulate = color_encendido
	get_tree().root.add_child(p)
	p.restart()
	p.emitting = true