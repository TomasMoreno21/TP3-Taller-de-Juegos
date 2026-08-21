extends StaticBody2D

@export var invencible := true
@export var golpes_para_romper := 20
@export var mostrar_contador := true

var golpes := 0
var dano_total := 0

@onready var visual: Node2D = $Visual
@onready var contador: Label = $Contador


func _ready() -> void:
	add_to_group("dummy_entrenamiento")
	contador.visible = mostrar_contador
	_actualizar_texto()


func registrar_golpe(dano: int) -> void:
	golpes += 1
	dano_total += dano
	_actualizar_texto()
	_flash()
	if not invencible and golpes >= golpes_para_romper:
		_romper()


func _actualizar_texto() -> void:
	contador.text = "%d golpes · %d daño" % [golpes, dano_total]


func _flash() -> void:
	if DisplayServer.get_name() == "headless":
		return
	visual.modulate = Color(1.7, 1.7, 1.7)
	visual.scale = Vector2(1.08, 0.92)
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(visual, "modulate", Color.WHITE, 0.15)
	tw.tween_property(visual, "scale", Vector2.ONE, 0.15)


func _romper() -> void:
	if DisplayServer.get_name() != "headless":
		var p: CPUParticles2D = (load("res://scenes/burst.tscn") as PackedScene).instantiate()
		p.global_position = global_position + Vector2(0, -110)
		get_tree().root.add_child(p)
		p.restart()
		p.emitting = true
	queue_free()
