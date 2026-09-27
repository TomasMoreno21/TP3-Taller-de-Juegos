class_name Burst
extends CPUParticles2D
## Estallido one-shot reutilizable (golpes, muertes, checkpoint, rompibles...).
## Se libera solo al terminar para no acumular nodos en el árbol.

## Margen extra (s) del respaldo por si "finished" nunca llega (p.ej. nunca se emitió).
@export var margen_liberar: float = 1.5


func _ready() -> void:
	finished.connect(_liberar)
	get_tree().create_timer(lifetime * 3.0 + margen_liberar).timeout.connect(_liberar)


## Atajo para disparar un estallido desde cualquier script (no hace nada en headless).
static func emitir(ref: Node, pos: Vector2, color: Color, cantidad: int = 16, escala: float = 1.0) -> void:
	if DisplayServer.get_name() == "headless" or ref == null or not ref.is_inside_tree():
		return
	var p: CPUParticles2D = (load("res://scenes/burst.tscn") as PackedScene).instantiate()
	p.global_position = pos
	p.self_modulate = color
	p.amount = maxi(cantidad, 1)
	p.scale = Vector2.ONE * escala
	ref.get_tree().root.add_child(p)
	p.restart()
	p.emitting = true


func _liberar() -> void:
	if not is_queued_for_deletion():
		queue_free()
