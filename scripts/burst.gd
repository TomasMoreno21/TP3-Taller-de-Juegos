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


## Onda de luz que se expande y se desvanece (aviso visual y momentáneo: zona despejada, checkpoint...).
static func onda(ref: Node, pos: Vector2, color: Color, radio: float = 220.0, dur: float = 0.8, grosor: float = 7.0) -> void:
	if DisplayServer.get_name() == "headless" or ref == null or not ref.is_inside_tree():
		return
	var n := Node2D.new()
	n.z_index = 50
	n.set_meta("k", 0.0)
	n.draw.connect(func() -> void:
		var k: float = n.get_meta("k")
		var a := 1.0 - k
		n.draw_arc(Vector2.ZERO, radio * k, 0.0, TAU, 56, Color(color, 0.85 * a), 1.0 + grosor * a, true)
		n.draw_arc(Vector2.ZERO, radio * k * 0.7, 0.0, TAU, 48, Color(color, 0.35 * a), 1.0 + grosor * 0.5 * a, true))
	ref.get_tree().root.add_child(n)
	n.global_position = pos
	var tw := n.create_tween().set_ignore_time_scale(true)
	tw.tween_method(func(v: float) -> void:
		n.set_meta("k", v)
		n.queue_redraw(), 0.0, 1.0, dur).set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)
	tw.tween_callback(n.queue_free)


## Chorro direccional de chispas (golpes): salen hacia `dir` (±1) con un abanico angosto.
static func chispas(ref: Node, pos: Vector2, dir: int, color: Color, cantidad: int = 6, fuerza: float = 1.0) -> void:
	if DisplayServer.get_name() == "headless" or ref == null or not ref.is_inside_tree():
		return
	var p: CPUParticles2D = (load("res://scenes/burst.tscn") as PackedScene).instantiate()
	p.global_position = pos
	p.self_modulate = color
	p.amount = maxi(cantidad, 1)
	p.lifetime = 0.28
	p.direction = Vector2(float(dir), -0.25)
	p.spread = 28.0
	p.emission_sphere_radius = 4.0
	p.gravity = Vector2(0.0, 520.0)
	p.initial_velocity_min = 220.0 * fuerza
	p.initial_velocity_max = 420.0 * fuerza
	p.damping_min = 90.0
	p.damping_max = 200.0
	p.scale_amount_min = 0.5
	p.scale_amount_max = 0.9
	ref.get_tree().root.add_child(p)
	p.restart()
	p.emitting = true


func _liberar() -> void:
	if not is_queued_for_deletion():
		queue_free()
