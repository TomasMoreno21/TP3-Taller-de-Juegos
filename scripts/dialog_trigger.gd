extends Area2D

## Disparador de diálogo colocable en el editor: narrativa o tutorial de mecánicas.
## Modo "Zona": habla cuando el jugador entra al área. Modo "Automatico": habla solo al cargar la escena.

@export var lineas: PackedStringArray = []
@export var hablante: String = "Amuleto"
@export_enum("Zona", "Automatico") var modo: String = "Zona"
@export var una_vez := true
@export var retraso := 0.6

var _disparado := false


func _ready() -> void:
	if modo == "Automatico":
		monitoring = false
		await get_tree().create_timer(retraso).timeout
		_disparar()
	else:
		monitoring = true
		collision_layer = 0
		collision_mask = 4
		body_entered.connect(_on_body_entered)


func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("player"):
		_disparar()


func _disparar() -> void:
	if una_vez and _disparado:
		return
	if lineas.is_empty():
		return
	_disparado = true
	get_node("/root/Dialogo").mostrar(Array(lineas), hablante)
