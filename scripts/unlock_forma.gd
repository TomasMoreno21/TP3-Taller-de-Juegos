extends Area2D
## Desbloquea una forma de transformación cuando el jugador entra al área.
## Colocable en el editor: elegir `forma` (0=Humano, 1=Lobo, 2=Oso, 3=Murciélago).
## Se da una sola vez por partida (Progresion es autoload, persiste al morir/reintentar).

@export var forma: int = 1
@export var una_vez := true

var _dado := false


func _ready() -> void:
	collision_layer = 0
	collision_mask = 4
	monitoring = true
	body_entered.connect(_on_body_entered)


func _on_body_entered(body: Node2D) -> void:
	if _dado:
		return
	if not body.is_in_group("player"):
		return
	var prog := get_node_or_null("/root/Progresion")
	if prog == null:
		return
	_dado = true
	if una_vez:
		set_deferred("monitoring", false)
	(prog as Node).desbloquear_forma(forma)