extends Node2D
## Arena de pelea final contra el Arzobispo. Coordina el final del juego:
## al morir el jefe muestra la pantalla épica de victoria.

const SCENA_VICTORIA := "res://scenes/victoria_jefe.tscn"

var _victoria_mostrada := false


func _ready() -> void:
	var boss := get_tree().get_first_node_in_group("boss")
	if boss != null and boss.has_signal("died"):
		boss.died.connect(_on_boss_died)


func _on_boss_died() -> void:
	if _victoria_mostrada:
		return
	_victoria_mostrada = true
	add_to_group("victoria")   # desde la muerte del jefe ya no se puede pausar (pause.gd)
	var jugador := get_tree().get_first_node_in_group("player")
	if jugador != null and jugador.has_method("_transformar") and jugador.current_form != jugador.Form.HUMAN:
		jugador._transformar(jugador.Form.HUMAN, true)   # forzado: ignora cooldown y energía
	await get_tree().create_timer(1.2, false).timeout   # si la pausa ya estaba abierta, espera a que se cierre
	if get_tree().current_scene == null or not is_instance_valid(get_tree().current_scene):
		return
	var victoria: CanvasLayer = (load(SCENA_VICTORIA) as PackedScene).instantiate()
	get_tree().current_scene.add_child(victoria)
	get_tree().paused = true
