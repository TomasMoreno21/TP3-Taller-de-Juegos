extends Node
## Configura la progresión al iniciar un nivel: fuerza un nivel mínimo y/o
## una lista de formas desbloqueadas (configurable desde el editor).
## Para el Nivel 1: Humanos empieza siempre, Lobo se desbloquea al recolectar 5 fragmentos,
## y Oso/Murciélago requieren progresión normal.

@export var nivel_minimo := 1          # si el nivel traído es menor, se sube a este
@export var formas_forzadas: Array[int] = [0]  # 0=Humano siempre; Lobo desbloquea al recolectar fragmentos


func _ready() -> void:
	var prog: Node = get_node("/root/Progresion")
	if nivel_minimo > 1 and int(prog.nivel) < nivel_minimo:
		prog.set_nivel(nivel_minimo)
	prog.formas_forzadas = formas_forzadas