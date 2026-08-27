extends Node2D

# main.tscn es el playground de pruebas de mecánicas: siempre debe permitir
# usar todas las formas, sin depender del desbloqueo progresivo por nivel
# que sí aplica en los niveles reales (ver progresion.gd::forma_desbloqueada).
func _ready() -> void:
	get_node("/root/Progresion").set_nivel(4)
