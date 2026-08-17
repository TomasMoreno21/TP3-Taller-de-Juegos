class_name WaveOla
extends Resource

## Una ola de enemigos generados automáticamente.
## Para enemigos colocados a mano, usar el número de ola en el nodo Enemy.
@export var tipo: String = "cultista"      # cultista | arquero | chaman
@export var cantidad: int = 0              # 0 = no generar; solo manuales
@export var delay: float = 1.0             # pausa tras resolver la ola anterior
@export var offset: Vector2 = Vector2(140, 0)  # separación horizontal entre spawns
@export var edge: bool = false             # entran caminando desde fuera de pantalla