extends Area2D

@onready var visual: Polygon2D = $Visual


func _ready() -> void:
	monitoring = true
	collision_mask = 4
	body_entered.connect(_on_body_entered)


func _on_body_entered(body: Node2D) -> void:
	if body.has_method("recoger_energia"):
		body.recoger_energia()
		# El alma contribuye a subir de nivel (fragmentos → desbloqueo de combos).
		get_node("/root/Progresion").add_fragmentos(1)
		queue_free()
