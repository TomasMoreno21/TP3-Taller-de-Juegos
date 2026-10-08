class_name JefeCine
## Momentos de cine del jefe: barras negras con su nombre (entrada), grieta de luz (cambio de fase)
## y destello blanco final (muerte). Todo en reloj real y sin bloquear el control del jugador.


static func _capa(arbol: SceneTree, layer: int) -> CanvasLayer:
	var c := CanvasLayer.new()
	c.layer = layer
	c.process_mode = Node.PROCESS_MODE_ALWAYS
	arbol.root.add_child(c)
	return c


static func _tween(nodo: Node) -> Tween:
	var tw := nodo.create_tween()
	tw.set_ignore_time_scale(true)
	return tw


## Barras de cine arriba y abajo + nombre del jefe con una línea que se abre.
static func entrada(arbol: SceneTree, nombre: String, color: Color, duracion: float) -> void:
	if DisplayServer.get_name() == "headless" or arbol == null:
		return
	var capa := _capa(arbol, 9)
	var tam := capa.get_viewport().get_visible_rect().size
	var alto := tam.y * 0.17
	var arriba := ColorRect.new()
	var abajo := ColorRect.new()
	for b in [arriba, abajo]:
		b.color = Color(0, 0, 0, 1)
		b.mouse_filter = Control.MOUSE_FILTER_IGNORE
		b.size = Vector2(tam.x, alto)
		capa.add_child(b)
	arriba.position = Vector2(0, -alto)
	abajo.position = Vector2(0, tam.y)
	var titulo := Label.new()
	titulo.text = nombre
	titulo.add_theme_font_size_override("font_size", 96)
	titulo.add_theme_color_override("font_color", Color(1, 1, 1))
	titulo.add_theme_color_override("font_outline_color", color.darkened(0.5))
	titulo.add_theme_constant_override("outline_size", 14)
	titulo.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	titulo.size = Vector2(tam.x, 130)
	titulo.position = Vector2(0, tam.y * 0.66)
	titulo.modulate.a = 0.0
	capa.add_child(titulo)
	var linea := ColorRect.new()
	linea.color = color.lightened(0.3)
	linea.mouse_filter = Control.MOUSE_FILTER_IGNORE
	linea.size = Vector2(tam.x * 0.5, 4)
	linea.position = Vector2(tam.x * 0.25, tam.y * 0.66 + 128)
	linea.pivot_offset = linea.size * 0.5
	linea.scale = Vector2(0.0, 1.0)
	capa.add_child(linea)
	var tw := _tween(capa)
	tw.set_parallel(true)
	tw.tween_property(arriba, "position:y", 0.0, 0.25).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(abajo, "position:y", tam.y - alto, 0.25).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(titulo, "modulate:a", 1.0, 0.3).set_delay(0.2)
	tw.tween_property(linea, "scale:x", 1.0, 0.45).set_delay(0.25).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.chain().tween_interval(maxf(duracion - 0.9, 0.2))
	tw.chain().set_parallel(true)
	tw.tween_property(arriba, "position:y", -alto, 0.3)
	tw.tween_property(abajo, "position:y", tam.y, 0.3)
	tw.tween_property(titulo, "modulate:a", 0.0, 0.3)
	tw.tween_property(linea, "modulate:a", 0.0, 0.3)
	tw.chain().tween_callback(capa.queue_free)


## Grieta de luz que parte la pantalla (cambio de fase).
static func grieta(arbol: SceneTree, color: Color) -> void:
	if DisplayServer.get_name() == "headless" or arbol == null:
		return
	var capa := _capa(arbol, 8)
	var dibujo := Grieta.new()
	dibujo.color = color
	dibujo.tam = capa.get_viewport().get_visible_rect().size
	capa.add_child(dibujo)
	var velo := ColorRect.new()
	velo.set_anchors_preset(Control.PRESET_FULL_RECT)
	velo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	velo.color = Color(1, 1, 1, 0.6)
	capa.add_child(velo)
	var tw := _tween(capa)
	tw.tween_property(velo, "color:a", 0.0, 0.18)
	tw.tween_property(dibujo, "modulate:a", 0.0, 0.7).set_delay(0.25)
	tw.tween_callback(capa.queue_free)


## Destello blanco que cubre la pantalla y se va despacio (muerte del jefe).
static func destello_final(arbol: SceneTree, retraso: float) -> void:
	if DisplayServer.get_name() == "headless" or arbol == null:
		return
	var capa := _capa(arbol, 99)
	var velo := ColorRect.new()
	velo.set_anchors_preset(Control.PRESET_FULL_RECT)
	velo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	velo.color = Color(1, 1, 1, 0.0)
	capa.add_child(velo)
	var tw := _tween(capa)
	tw.tween_interval(retraso)
	tw.tween_property(velo, "color:a", 1.0, 0.35).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.tween_interval(0.25)
	tw.tween_property(velo, "color:a", 0.0, 1.4).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.tween_callback(capa.queue_free)


class Grieta extends Control:
	var color := Color.WHITE
	var tam := Vector2(1920, 1080)
	var _rayos: Array = []

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		set_anchors_preset(Control.PRESET_FULL_RECT)
		var centro := tam * Vector2(randf_range(0.35, 0.65), randf_range(0.35, 0.65))
		for i in 7:
			var ang := TAU * float(i) / 7.0 + randf_range(-0.25, 0.25)
			var pts := PackedVector2Array([centro])
			var p := centro
			while Rect2(Vector2.ZERO, tam).grow(80.0).has_point(p):
				ang += randf_range(-0.45, 0.45)
				p += Vector2(cos(ang), sin(ang)) * randf_range(50.0, 120.0)
				pts.append(p)
			_rayos.append(pts)
		queue_redraw()

	func _draw() -> void:
		for pts in _rayos:
			draw_polyline(pts, Color(color.r, color.g, color.b, 0.6), 18.0, true)
			draw_polyline(pts, Color(1, 1, 1, 1), 5.0, true)
