extends Node
## Configura la progresión al iniciar un nivel: fija los pasos mínimos del combo ligero y/o
## una lista de formas desbloqueadas (configurable desde el editor).
## El nivel del jugador NO se toca: solo sube con los fragmentos (cada subida = un combo).
## Para el Nivel 1: Humanos empieza siempre, Lobo se desbloquea al recolectar 5 fragmentos,
## y Oso/Murciélago requieren progresión normal.

@export var nivel_minimo := 1          # pasos del combo ligero garantizados en este nivel (no cambia el nivel)
@export var formas_forzadas: Array[int] = [0]  # 0=Humano siempre; Lobo desbloquea al recolectar fragmentos


func _ready() -> void:
	var prog: Node = get_node("/root/Progresion")
	prog.pasos_luz_base = maxi(int(prog.pasos_luz_base), nivel_minimo)
	prog.formas_forzadas = formas_forzadas