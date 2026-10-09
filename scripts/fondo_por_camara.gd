extends ParallaxBackground
## Oculta el fondo mientras la cámara no llega a ver por debajo de `y_visible_desde` (mundo). Evita dibujar
## cientos de polígonos del subsuelo cuando el piso de la superficie los tapa por completo.

@export var y_visible_desde := 1160.0   ## el fondo aparece cuando el borde inferior de la cámara pasa de esta y


func _process(_delta: float) -> void:
	var cam := get_viewport().get_camera_2d()
	if cam == null:
		return
	var borde_inferior := cam.get_screen_center_position().y + get_viewport().get_visible_rect().size.y * 0.5 / cam.zoom.y
	var ver := borde_inferior > y_visible_desde
	if ver != visible:
		visible = ver
