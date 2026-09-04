extends Node
## Configura la progresión al iniciar un nivel: fuerza un nivel mínimo y/o
## una lista de formas desbloqueadas (configurable desde el editor).
## Si `formas_forzadas` queda vacía, el nivel usa la regla estándar por nivel.

@export var nivel_minimo := 1          # si el nivel traído es menor, se sube a este
@export var formas_forzadas: Array[int] = []  # indices de Form (Humano=0, Lobo=1, Oso=2, Murciélago=3)


func _ready() -> void:
	var prog: Node = get_node("/root/Progresion")
	if nivel_minimo > 1 and int(prog.nivel) < nivel_minimo:
		prog.set_nivel(nivel_minimo)
	prog.formas_forzadas = formas_forzadas