extends PanelContainer

## Aviso discreto de HUD para controles y mecánicas (ya no los dice el Amuleto).
## Lo maneja `Dialogo.mostrar_tip`: se muestran de a uno, abajo al centro.

@export var seg_minimo := 3.5            ## tiempo mínimo en pantalla
@export var seg_por_caracter := 0.045    ## tiempo extra por letra (textos largos duran más)
@export var margen_abajo := 120.0
@export var fuente: Font = preload("res://assets/fonts/ComicNeue-Bold.ttf")
@export var tam_fuente := 24
@export var color_fondo := Color(0.05, 0.06, 0.08, 0.84)
@export var color_borde := Color(0.82, 0.72, 0.42, 0.9)
@export var color_texto := Color(0.95, 0.93, 0.86)

var _cola: Array[String] = []
var _activo := false
var _label: Label
var _tw: Tween


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var estilo := StyleBoxFlat.new()
	estilo.bg_color = color_fondo
	estilo.border_color = color_borde
	estilo.set_border_width_all(2)
	estilo.set_corner_radius_all(10)
	estilo.content_margin_left = 22
	estilo.content_margin_right = 22
	estilo.content_margin_top = 10
	estilo.content_margin_bottom = 10
	add_theme_stylebox_override("panel", estilo)
	_label = Label.new()
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_label.add_theme_font_override("font", fuente)
	_label.add_theme_font_size_override("font_size", tam_fuente)
	_label.add_theme_color_override("font_color", color_texto)
	add_child(_label)
	modulate.a = 0.0
	visible = false


func mostrar(texto: String) -> void:
	if texto.is_empty() or _cola.has(texto) or (_activo and _label.text == texto):
		return
	_cola.append(texto)
	if not _activo:
		_siguiente()


func texto() -> String:
	return _label.text if visible else ""


## Corta todo al instante (cambio de escena).
func vaciar() -> void:
	_cola.clear()
	_activo = false
	visible = false
	if _tw != null and _tw.is_valid():
		_tw.kill()


func _siguiente() -> void:
	if _cola.is_empty():
		_activo = false
		visible = false
		return
	_activo = true
	_label.text = _cola.pop_front()
	size = Vector2.ZERO   # se encoge al texto nuevo
	visible = true
	modulate.a = 0.0
	if _tw != null and _tw.is_valid():
		_tw.kill()
	_tw = create_tween()
	_tw.tween_property(self, "modulate:a", 1.0, 0.2)
	_tw.tween_interval(maxf(seg_minimo, _label.text.length() * seg_por_caracter))
	_tw.tween_property(self, "modulate:a", 0.0, 0.3)
	_tw.tween_callback(_siguiente)


func _process(_delta: float) -> void:
	if visible:
		var vp := get_viewport().get_visible_rect().size
		position = Vector2((vp.x - size.x) * 0.5, vp.y - margen_abajo - size.y).round()
