extends Control

## Globo de cómic (blanco y negro, como la intro) con cola hacia el Amuleto.
## Lo coloca y lo anima `Dialogo`; aquí solo se dibuja y se escribe el texto.
## Tonos: NORMAL (redondeado), ALERTA (con "!"), GRITO (con puntas, tembloroso),
## SUSURRO (borde punteado y más claro).

enum Tono { NORMAL, ALERTA, GRITO, SUSURRO }

const PAPEL := Color(0.97, 0.95, 0.89)
const TINTA := Color(0.05, 0.05, 0.06)

var tono: Tono = Tono.NORMAL
var cola_a := Vector2.ZERO   ## punto (coordenadas locales) al que apunta la cola

var _fuente: Font
var _label: Label
var _nombre: Label
var _t := 0.0
var _margen := Vector2(22, 16)


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sf := SystemFont.new()
	sf.font_names = PackedStringArray(["Comic Sans MS", "Comic Neue", "Arial Black"])
	sf.font_weight = 700
	_fuente = sf
	_label = Label.new()
	_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_label.add_theme_font_override("font", _fuente)
	_label.add_theme_color_override("font_color", TINTA)
	add_child(_label)
	_nombre = Label.new()
	_nombre.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_nombre.add_theme_font_override("font", _fuente)
	_nombre.add_theme_font_size_override("font_size", 16)
	_nombre.add_theme_color_override("font_color", Color(0.4, 0.4, 0.42))
	add_child(_nombre)


## Prepara el globo: calcula su tamaño para que entre todo el texto (se escribe después).
func configurar(texto: String, hablante: String, tono_nuevo: Tono, tam_fuente: int, ancho_max: float) -> void:
	tono = tono_nuevo
	var txt := texto.to_upper()
	_label.text = txt
	_label.add_theme_font_size_override("font_size", tam_fuente)
	_label.visible_ratio = 0.0
	var mostrar_nombre := not hablante.is_empty() and hablante != "Amuleto" and hablante != "Humano"
	_nombre.text = hablante.to_upper() + ":" if mostrar_nombre else ""
	_nombre.visible = mostrar_nombre
	var medida := _fuente.get_multiline_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, ancho_max, tam_fuente)
	var ancho_txt := minf(medida.x + 6.0, ancho_max)
	var alto_txt := medida.y + 4.0
	_margen = Vector2(22, 16)
	var extra_nombre := 20.0 if mostrar_nombre else 0.0
	var contenido := Vector2(ancho_txt, alto_txt + extra_nombre)
	if tono == Tono.GRITO:   # el texto debe caber dentro de la elipse con puntas
		_margen = (contenido / 0.66 + Vector2(24, 16) - contenido) * 0.5
	_label.size = Vector2(ancho_txt, alto_txt)
	_label.position = _margen + Vector2(0, extra_nombre)
	_nombre.position = _margen + Vector2(0, -2)
	size = contenido + _margen * 2.0
	pivot_offset = Vector2(size.x * 0.35, size.y + 40.0)
	queue_redraw()


func set_ratio(r: float) -> void:
	_label.visible_ratio = r


func _process(delta: float) -> void:
	if not visible:
		return
	_t += delta
	if tono == Tono.GRITO:
		_label.position = _margen + Vector2(sin(_t * 40.0), cos(_t * 37.0)) * 1.6 + Vector2(0, 20.0 if _nombre.visible else 0.0)
	queue_redraw()


func _cuerpo() -> PackedVector2Array:
	var pts := PackedVector2Array()
	if tono == Tono.GRITO:
		var c := size * 0.5
		var n := 26
		for i in n:
			var a := i * TAU / n
			var espina := 1.0 if i % 2 == 0 else 0.80
			var vibra := 1.0 + 0.03 * sin(_t * 30.0 + i * 1.7)
			pts.append(c + Vector2(cos(a) * size.x * 0.5, sin(a) * size.y * 0.5) * espina * vibra)
		return pts
	var r := minf(26.0, minf(size.x, size.y) * 0.5)
	var esquinas := [Vector2(size.x - r, r), Vector2(size.x - r, size.y - r), Vector2(r, size.y - r), Vector2(r, r)]
	for k in 4:
		for j in 7:
			var a := -PI * 0.5 + k * PI * 0.5 + j * (PI * 0.5) / 6.0
			pts.append(esquinas[k] + Vector2(cos(a), sin(a)) * r)
	return pts


func _draw() -> void:
	if _fuente == null:
		return
	var cuerpo := _cuerpo()
	var ancho_borde := 5.0 if tono == Tono.ALERTA else 4.0
	var relleno := PAPEL if tono != Tono.SUSURRO else Color(PAPEL, 0.88)
	# sombra
	var sombra := PackedVector2Array()
	for p in cuerpo:
		sombra.append(p + Vector2(5, 5))
	draw_colored_polygon(sombra, Color(0, 0, 0, 0.8))
	# cola (hacia abajo, hacia el Amuleto)
	var base_x := clampf(cola_a.x, 40.0, maxf(size.x - 40.0, 40.0))
	var base_y := size.y - 6.0
	var cola := PackedVector2Array([Vector2(base_x - 16.0, base_y - 4.0), cola_a, Vector2(base_x + 16.0, base_y - 4.0)])
	draw_colored_polygon(PackedVector2Array([cola[0] + Vector2(5, 5), cola_a + Vector2(5, 5), cola[2] + Vector2(5, 5)]), Color(0, 0, 0, 0.8))
	draw_colored_polygon(cuerpo, relleno)
	draw_colored_polygon(cola, relleno)
	var contorno := cuerpo.duplicate()
	contorno.append(cuerpo[0])
	if tono == Tono.SUSURRO:
		_punteado(contorno, TINTA, 3.0)
	else:
		draw_polyline(contorno, TINTA, ancho_borde, true)
	# el tapón de la cola tapa el borde del globo en su base
	draw_line(Vector2(base_x - 14.0, base_y - 4.0), Vector2(base_x + 14.0, base_y - 4.0), relleno, ancho_borde + 1.0)
	draw_line(cola[0], cola[1], TINTA, ancho_borde, true)
	draw_line(cola[1], cola[2], TINTA, ancho_borde, true)
	if tono == Tono.ALERTA:
		var b := Vector2(size.x - 6.0, 4.0)
		draw_circle(b, 19.0, TINTA)
		draw_circle(b, 15.0, PAPEL)
		draw_string(_fuente, b + Vector2(-5.0, 9.0), "!", HORIZONTAL_ALIGNMENT_LEFT, -1, 26, TINTA)


func _punteado(pts: PackedVector2Array, col: Color, ancho: float) -> void:
	var acumulado := 0.0
	for i in pts.size() - 1:
		var a := pts[i]
		var b := pts[i + 1]
		var largo := a.distance_to(b)
		var d := 0.0
		while d < largo:
			var desde := a.lerp(b, d / largo)
			var hasta := a.lerp(b, minf(d + 7.0, largo) / largo)
			if int((acumulado + d) / 7.0) % 2 == 0:
				draw_line(desde, hasta, col, ancho)
			d += 7.0
		acumulado += largo
