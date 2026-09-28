extends Control
## Marcas verticales sobre una barra de vida (una cada `unidad` de valor máximo).
## Se dibuja encima del ProgressBar; sin colisión.

@export var segmentos := 10:
	set(v):
		segmentos = maxi(v, 1)
		queue_redraw()
@export var color := Color(0.03, 0.04, 0.06, 0.65):
	set(v):
		color = v
		queue_redraw()
@export var grosor := 2.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	resized.connect(queue_redraw)


func _draw() -> void:
	for i in range(1, segmentos):
		var x := size.x * float(i) / float(segmentos)
		draw_line(Vector2(x, 3.0), Vector2(x, size.y - 3.0), color, grosor)
