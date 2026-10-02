extends Node2D
## Acompaña al centro de la cámara (con un desplazamiento): sirve para bancos de niebla o
## partículas que deben cubrir siempre la vista en niveles verticales y largos.
## Las partículas hijas con local_coords = false se quedan en el mundo y forman estelas.

@export var desplazamiento := Vector2.ZERO


func _process(_delta: float) -> void:
	var cam := get_viewport().get_camera_2d()
	if cam != null:
		global_position = cam.get_screen_center_position() + desplazamiento
