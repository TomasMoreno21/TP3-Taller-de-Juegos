extends Node2D

signal encounter_completed

const SPAWN_POINT := preload("res://scenes/spawn_point.tscn")

enum State { INACTIVE, RUNNING, COMPLETED }

var state: int = State.INACTIVE

var waves := [
	[
		{"type": "cultista", "offset": Vector2(-70, 0), "delay": 0.0},
		{"type": "cultista", "offset": Vector2(40, 0), "delay": 0.8},
		{"type": "cultista", "offset": Vector2(130, 0), "delay": 1.6},
	],
	[
		{"type": "arquero", "offset": Vector2(-50, 0), "delay": 0.0},
		{"type": "cultista", "offset": Vector2(40, 0), "delay": 1.0},
		{"type": "cultista", "offset": Vector2(130, 0), "delay": 1.8},
		{"type": "cultista", "offset": Vector2(220, 0), "delay": 2.6, "edge": true},
	],
	[
		{"type": "chaman", "offset": Vector2(0, 0), "delay": 0.0},
		{"type": "arquero", "offset": Vector2(90, 0), "delay": 1.2},
		{"type": "cultista", "offset": Vector2(-60, 0), "delay": 2.0},
		{"type": "cultista", "offset": Vector2(200, 0), "delay": 2.8, "edge": true},
	],
]

var _wave_index := 0
var _alive := 0

@onready var trigger: Area2D = $TriggerZone
@onready var gate: StaticBody2D = $Gate
@onready var spawn_group: Node2D = $SpawnGroup


func _ready() -> void:
	add_to_group("encounter")
	trigger.body_entered.connect(_on_trigger_entered)
	gate.set_closed(false)


func _on_trigger_entered(body: Node2D) -> void:
	if state == State.INACTIVE and body.is_in_group("player"):
		activate()


func debug_activate() -> void:
	if state == State.INACTIVE:
		activate()


func activate() -> void:
	state = State.RUNNING
	gate.set_closed(true)
	trigger.set_deferred("monitoring", false)
	_start_wave(0)


func _start_wave(index: int) -> void:
	if index >= waves.size():
		_complete()
		return
	_wave_index = index
	var wave: Array = waves[index]
	for entry in wave:
		_schedule_spawn(entry)


func _schedule_spawn(entry: Dictionary) -> void:
	var sp: Node2D = SPAWN_POINT.instantiate()
	sp.position = entry.get("offset", Vector2.ZERO)
	sp.enemy_spawned.connect(_on_enemy_spawned)
	spawn_group.add_child(sp)
	sp.configure(entry)
	sp.start_spawn()


func _on_enemy_spawned(enemy: Node2D) -> void:
	_alive += 1
	enemy.died.connect(_on_enemy_died)


func _on_enemy_died() -> void:
	_alive -= 1
	if _alive <= 0:
		_start_wave(_wave_index + 1)


func _complete() -> void:
	state = State.COMPLETED
	gate.set_closed(false)
	encounter_completed.emit()
