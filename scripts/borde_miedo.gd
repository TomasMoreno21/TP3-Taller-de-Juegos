extends CanvasLayer

## Borde fino de color en el marco de la pantalla que acompaña el miedo del corazón de la cueva
## (latido_cueva.gd, grupo "latido_cueva"): casi invisible en calma, pulsa con cada latido cuando hay miedo.

@export var color := Color(0.62, 0.28, 0.78)
@export_range(0.0, 1.0, 0.01) var alfa_base := 0.0     ## opacidad con miedo = 0
@export_range(0.0, 1.0, 0.01) var alfa_max := 0.3      ## opacidad con miedo = 1
@export_range(2.0, 80.0, 1.0) var grosor := 22.0       ## ancho del borde en px
@export_range(0.0, 1.0, 0.05) var fuerza_pulso := 0.5  ## cuánto sube con cada pum

var _latido: Node
var _dibujo: Control


func _ready() -> void:
	_dibujo = Control.new()
	_dibujo.set_anchors_preset(Control.PRESET_FULL_RECT)
	_dibujo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_dibujo.draw.connect(_pintar)
	add_child(_dibujo)


func _process(_delta: float) -> void:
	if not is_instance_valid(_latido):
		_latido = get_tree().get_first_node_in_group("latido_cueva")
	_dibujo.queue_redraw()


func _pintar() -> void:
	if _latido == null or not _latido.has_method("miedo_actual"):
		return
	var m: float = _latido.miedo_actual()
	var a := alfa_base + (alfa_max - alfa_base) * m
	a *= 1.0 + fuerza_pulso * float(_latido.pulso_actual())
	if a <= 0.004:
		return
	var s := _dibujo.size
	var capas := 6
	for i in capas:
		var w := grosor * float(capas - i) / float(capas)   # capas más finas hacia el borde: degradé hacia adentro
		var c := Color(color.r, color.g, color.b, clampf(a / float(capas), 0.0, 1.0))
		_dibujo.draw_rect(Rect2(0, 0, s.x, w), c)
		_dibujo.draw_rect(Rect2(0, s.y - w, s.x, w), c)
		_dibujo.draw_rect(Rect2(0, w, w, s.y - 2.0 * w), c)
		_dibujo.draw_rect(Rect2(s.x - w, w, w, s.y - 2.0 * w), c)
