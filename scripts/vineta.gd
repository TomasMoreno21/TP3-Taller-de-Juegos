extends Control

## Una viñeta del cómic de introducción (estilo superhéroes clásico, blanco y negro).
## Su forma es un polígono libre (`forma`, en coordenadas locales de este nodo; vacío = rectángulo):
## el arte se recorta a esa forma con `clip_children`. Se coloca y se edita en `comic_intro.tscn`.
## Si se asigna `textura`, se dibuja esa ilustración en lugar del dibujo por código.

enum Escena { ESPIRITUS, PICNIC, ATRAIDO, BUSCA, ENTRA, AMULETO }

@export var escena: Escena = Escena.ESPIRITUS
@export var textura: Texture2D
@export var forma: PackedVector2Array = PackedVector2Array()
@export var hablante: String = ""   ## si se completa, la cartela lleva el nombre (p. ej. "Amuleto")
@export_multiline var texto: String = ""
@export var cartela_pos := Vector2(18, 18)
@export var cartela_ancho := 340.0
@export var segundos_por_letra := 0.03
@export var volumen_tipeo_db := -9.0

const PAPEL := Color(0.97, 0.95, 0.89)
const TINTA := Color(0.05, 0.05, 0.06)
const GRIS := Color(0.45, 0.45, 0.46)
const GRIS_OSC := Color(0.22, 0.22, 0.24)
const GRIS_CLARO := Color(0.80, 0.79, 0.76)

var revelada := false
var _t := 0.0
var _tipeando := false
var _forma: PackedVector2Array
var _mascara: Control
var _vacio: Control
var _fija: Control
var _anim: Control
var _marco: Control
var _c: Control   # lienzo sobre el que dibujan los helpers
var _fuente: Font
var _cartela: PanelContainer
var _label: Label
var _letras_sin_sonar := 0
var _ultimo_blip := 0


func _ready() -> void:
	var sf := SystemFont.new()
	sf.font_names = PackedStringArray(["Comic Sans MS", "Comic Neue", "Arial Black"])
	sf.font_weight = 700
	_fuente = sf
	_forma = forma
	if _forma.size() < 3:
		_forma = PackedVector2Array([Vector2.ZERO, Vector2(size.x, 0), size, Vector2(0, size.y)])
	pivot_offset = size * 0.5
	_mascara = _nuevo_lienzo(self)
	_mascara.clip_children = CanvasItem.CLIP_CHILDREN_ONLY
	_mascara.draw.connect(func(): _mascara.draw_colored_polygon(_forma, Color.WHITE))
	_vacio = _nuevo_lienzo(_mascara)
	_vacio.draw.connect(func(): _vacio.draw_rect(Rect2(Vector2.ZERO, size), Color(0.84, 0.82, 0.76)))
	_fija = _nuevo_lienzo(_mascara)
	_fija.visible = false
	_fija.draw.connect(_dibujar_fija)
	_anim = _nuevo_lienzo(_mascara)
	_anim.visible = false
	_anim.draw.connect(_dibujar_anim)
	_marco = _nuevo_lienzo(self)
	_marco.draw.connect(_dibujar_marco)
	_armar_cartela()
	_cartela.visible = false


func _nuevo_lienzo(padre: Control) -> Control:
	var n := Control.new()
	n.mouse_filter = Control.MOUSE_FILTER_IGNORE
	padre.add_child(n)
	n.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	return n


func _armar_cartela() -> void:
	_cartela = PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = PAPEL
	sb.border_color = TINTA
	sb.set_border_width_all(4)
	sb.set_content_margin_all(10)
	sb.shadow_color = Color(0, 0, 0, 0.9)
	sb.shadow_offset = Vector2(5, 5)
	sb.shadow_size = 1
	_cartela.add_theme_stylebox_override("panel", sb)
	_cartela.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_cartela)
	_cartela.position = cartela_pos
	var vb := VBoxContainer.new()
	vb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vb.add_theme_constant_override("separation", 2)
	_cartela.add_child(vb)
	if not hablante.is_empty():
		var nombre := Label.new()
		nombre.text = hablante.to_upper() + ":"
		nombre.add_theme_font_override("font", _fuente)
		nombre.add_theme_font_size_override("font_size", 17)
		nombre.add_theme_color_override("font_color", GRIS)
		vb.add_child(nombre)
	_label = Label.new()
	_label.text = texto.to_upper()
	_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_label.custom_minimum_size.x = cartela_ancho
	_label.add_theme_font_override("font", _fuente)
	_label.add_theme_color_override("font_color", TINTA)
	_label.add_theme_font_size_override("font_size", 22)
	_label.visible_ratio = 0.0
	vb.add_child(_label)


## Muestra la viñeta con un "pop" y empieza a escribir su texto.
func revelar() -> void:
	revelada = true
	_vacio.visible = false
	_fija.visible = true
	_anim.visible = true
	_cartela.visible = true
	_label.visible_ratio = 0.0
	_tipeando = not texto.is_empty()
	_ultimo_blip = 0
	_letras_sin_sonar = 0
	if DisplayServer.get_name() == "headless":
		modulate.a = 1.0
		scale = Vector2.ONE
	else:
		modulate.a = 0.0
		scale = Vector2(0.94, 0.94)
		var tw := create_tween().set_parallel(true)
		tw.tween_property(self, "modulate:a", 1.0, 0.3).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		tw.tween_property(self, "scale", Vector2.ONE, 0.45).set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)
	_fija.queue_redraw()
	_marco.queue_redraw()


func esta_tipeando() -> bool:
	return _tipeando


func completar_texto() -> void:
	_tipeando = false
	if _label != null:
		_label.visible_ratio = 1.0


## Deja la viñeta ya mostrada y con el texto completo (al omitir).
func mostrar_completa() -> void:
	if not revelada:
		revelar()
		modulate.a = 1.0
		scale = Vector2.ONE
	completar_texto()


func _process(delta: float) -> void:
	if not revelada:
		return
	_t += delta
	_anim.queue_redraw()
	if not _tipeando:
		return
	var total := maxi(texto.length(), 1)
	_label.visible_ratio = minf(_label.visible_ratio + delta / (total * segundos_por_letra), 1.0)
	var visibles := int(_label.visible_ratio * total)
	var sonar := false
	while _ultimo_blip < visibles:
		var c := texto[_ultimo_blip]
		_ultimo_blip += 1
		if c.to_lower() != c.to_upper():
			_letras_sin_sonar += 1
			if _letras_sin_sonar >= 2:
				_letras_sin_sonar = 0
				sonar = true
	if sonar:
		var audio := get_node_or_null("/root/AudioManager")
		if audio != null:
			audio.play_ui("dialogo_tecla", volumen_tipeo_db)
	if _label.visible_ratio >= 1.0:
		_tipeando = false


# ---------------------------------------------------------------- dibujo

func _dibujar_marco() -> void:
	var pts := _forma.duplicate()
	pts.append(_forma[0])
	pts.append(_forma[1])
	if revelada:
		_marco.draw_polyline(pts, TINTA, 7.0, true)
	else:
		_marco.draw_polyline(pts, GRIS, 4.0, true)


func _dibujar_fija() -> void:
	_c = _fija
	if textura != null:
		_c.draw_texture_rect(textura, Rect2(Vector2.ZERO, size), false)
		return
	_c.draw_rect(Rect2(Vector2.ZERO, size), PAPEL)
	match escena:
		Escena.ESPIRITUS: _fija_espiritus()
		Escena.PICNIC: _fija_picnic()
		Escena.ATRAIDO: _fija_atraido()
		Escena.BUSCA: _fija_busca()
		Escena.ENTRA: _fija_entra()
		Escena.AMULETO: _fija_amuleto()


func _dibujar_anim() -> void:
	_c = _anim
	if textura != null:
		return
	match escena:
		Escena.ESPIRITUS: _anim_espiritus()
		Escena.PICNIC: _anim_picnic()
		Escena.ATRAIDO: _anim_atraido()
		Escena.BUSCA: _anim_busca()
		Escena.ENTRA: _anim_entra()
		Escena.AMULETO: _anim_amuleto()


# ---- helpers de tinta

func _poli(pts: PackedVector2Array, relleno: Color, contorno := TINTA, ancho := 3.0) -> void:
	_c.draw_colored_polygon(pts, relleno)
	if ancho > 0.0:
		var p := pts.duplicate()
		p.append(pts[0])
		_c.draw_polyline(p, contorno, ancho, true)


func _circ(p: Vector2, r: float, relleno: Color, contorno := TINTA, ancho := 3.0) -> void:
	_c.draw_circle(p, r, relleno)
	if ancho > 0.0:
		_c.draw_arc(p, r, 0.0, TAU, 32, contorno, ancho, true)


## Trama de puntos (medio tono) con radio que varía de arriba (r0) a abajo (r1).
func _puntos(rect: Rect2, paso: float, r0: float, r1: float, col := TINTA) -> void:
	var fila := 0
	var y := rect.position.y
	while y < rect.end.y:
		var r := lerpf(r0, r1, (y - rect.position.y) / maxf(rect.size.y, 1.0))
		if r > 0.4:
			var x := rect.position.x + (paso * 0.5 if fila % 2 == 1 else 0.0)
			while x < rect.end.x:
				_c.draw_circle(Vector2(x, y), r, col)
				x += paso
		y += paso * 0.866
		fila += 1


## Rayado diagonal (sombreado de tinta).
func _rayado(rect: Rect2, paso: float, inclin: float, col := TINTA, ancho := 2.0) -> void:
	var pts := PackedVector2Array()
	var x := rect.position.x - absf(inclin)
	while x < rect.end.x:
		pts.append(Vector2(x, rect.end.y))
		pts.append(Vector2(x + inclin, rect.position.y))
		x += paso
	_c.draw_multiline(pts, col, ancho)


func _colina(base_y: float, amp: float, freq: float, fase: float, relleno: Color, contorno := TINTA) -> void:
	var pts := PackedVector2Array()
	var x := 0.0
	while x <= size.x + 20.0:
		pts.append(Vector2(x, base_y + sin(x * freq + fase) * amp))
		x += 20.0
	var linea := pts.duplicate()
	pts.append(Vector2(size.x + 20.0, size.y + 20.0))
	pts.append(Vector2(-20.0, size.y + 20.0))
	_c.draw_colored_polygon(pts, relleno)
	_c.draw_polyline(linea, contorno, 4.0, true)


func _pino(x: float, base: float, alto: float, relleno: Color, contorno := TINTA) -> void:
	_c.draw_rect(Rect2(x - alto * 0.03, base - alto * 0.25, alto * 0.06, alto * 0.25), relleno)
	for i in 3:
		var w := alto * 0.3 * (1.0 - i * 0.2)
		var yb := base - alto * (0.17 + 0.21 * i)
		_poli(PackedVector2Array([Vector2(x - w, yb), Vector2(x, yb - alto * 0.4), Vector2(x + w, yb)]), relleno, contorno, 2.0)


func _estrella(c: Vector2, r_ext: float, r_int: float, puntas: int, rot := 0.0) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in puntas * 2:
		var r := r_ext if i % 2 == 0 else r_int
		var a := rot + i * PI / puntas
		pts.append(c + Vector2(cos(a), sin(a)) * r)
	return pts


## Destello de espíritu: orbe blanco con halo y rayitos.
func _orbe(p: Vector2, r: float, pulso := 0.0) -> void:
	_c.draw_circle(p, r * 2.0 + pulso, Color(PAPEL, 0.35))
	for i in 8:
		var a := i * TAU / 8.0 + 0.3
		_c.draw_line(p + Vector2(cos(a), sin(a)) * (r * 1.4), p + Vector2(cos(a), sin(a)) * (r * 2.1 + pulso), PAPEL, 2.0)
	_circ(p, r, PAPEL, TINTA, 2.5)


## Silueta humana en tinta. cara: 0 = de espaldas, 1 = sonrisa, 2 = grita.
func _persona(base: Vector2, alto: float, ropa: Color, cara := 1, sentado := false, manos_boca := false, dir := 1.0, borde := TINTA, pelo := TINTA, rayas := false, barba := false) -> void:
	var cab := Vector2(base.x, base.y - alto * (0.72 if sentado else 0.87))
	var rc := alto * 0.13
	var hombro_y := cab.y + alto * 0.19
	var cadera_y := base.y - alto * (0.14 if sentado else 0.4)
	var pant := TINTA if ropa != TINTA else GRIS_OSC
	# piernas + zapatos
	if sentado:
		var a := Vector2(base.x, cadera_y)
		var b := Vector2(base.x + dir * alto * 0.42, base.y - alto * 0.06)
		_c.draw_line(a, b, borde, alto * 0.13)
		_c.draw_line(a, b, pant, alto * 0.095)
		_poli(PackedVector2Array([b + Vector2(0, -alto * 0.05), b + Vector2(dir * alto * 0.12, -alto * 0.02), b + Vector2(dir * alto * 0.12, alto * 0.05), b + Vector2(0, alto * 0.05)]), TINTA, borde, 2.0)
	else:
		for s in [-1.0, 1.0]:
			var a := Vector2(base.x + s * alto * 0.05, cadera_y)
			var b := Vector2(base.x + s * alto * 0.06, base.y - alto * 0.03)
			_c.draw_line(a, b, borde, alto * 0.13)
			_c.draw_line(a, b, pant, alto * 0.095)
			_poli(PackedVector2Array([Vector2(b.x - alto * 0.06, base.y - alto * 0.04), Vector2(b.x + alto * 0.06 + s * alto * 0.03, base.y - alto * 0.04), Vector2(b.x + alto * 0.07 + s * alto * 0.03, base.y), Vector2(b.x - alto * 0.06, base.y)]), TINTA, borde, 2.0)
	# brazos: manga de la ropa + antebrazo y mano de piel
	for s in [-1.0, 1.0]:
		var h0 := Vector2(base.x + s * alto * 0.16, hombro_y + 4.0)
		var h1 := Vector2(cab.x + s * alto * 0.09, cab.y + alto * 0.1) if manos_boca else Vector2(base.x + s * alto * 0.21, cadera_y + alto * 0.05)
		var codo := h0.lerp(h1, 0.45)
		_c.draw_line(h0, h1, borde, alto * 0.095)
		_c.draw_line(h0, codo, ropa, alto * 0.07)
		_c.draw_line(codo, h1, PAPEL, alto * 0.055)
		_circ(h1, alto * 0.04, PAPEL, borde, 2.0)
	# cuello y torso con hombros redondeados
	_c.draw_rect(Rect2(cab.x - alto * 0.04, cab.y + rc * 0.6, alto * 0.08, alto * 0.1), PAPEL)
	var torso := PackedVector2Array([
		Vector2(base.x - alto * 0.12, hombro_y - alto * 0.015), Vector2(base.x - alto * 0.17, hombro_y + alto * 0.03),
		Vector2(base.x - alto * 0.13, cadera_y),
		Vector2(base.x + alto * 0.13, cadera_y),
		Vector2(base.x + alto * 0.17, hombro_y + alto * 0.03), Vector2(base.x + alto * 0.12, hombro_y - alto * 0.015)])
	_poli(torso, ropa, borde, 3.0)
	if rayas:
		for k in 3:
			var yy := lerpf(hombro_y + alto * 0.02, cadera_y, (k + 1) / 4.0)
			_c.draw_line(Vector2(base.x - alto * 0.15, yy), Vector2(base.x + alto * 0.15, yy), TINTA, 3.0)
	else:
		var cuello := PAPEL if ropa.get_luminance() < 0.5 else TINTA
		_c.draw_colored_polygon(PackedVector2Array([Vector2(base.x - alto * 0.05, hombro_y - alto * 0.015), Vector2(base.x + alto * 0.05, hombro_y - alto * 0.015), Vector2(base.x, hombro_y + alto * 0.07)]), cuello)
		_c.draw_line(Vector2(base.x - alto * 0.13, cadera_y - alto * 0.05), Vector2(base.x + alto * 0.13, cadera_y - alto * 0.05), cuello, 3.0)
	_circ(cab, rc, PAPEL, borde, 3.0)
	if cara == 0:
		_c.draw_circle(cab, rc, pelo)
		_c.draw_arc(cab, rc, 0.0, TAU, 24, borde, 3.0, true)
		return
	var cab_pelo := PackedVector2Array()
	for i in 13:
		var a := PI + i * PI / 12.0
		cab_pelo.append(cab + Vector2(cos(a), sin(a) * 0.95) * rc * 1.06)
	cab_pelo.append(cab + Vector2(rc * 0.9, -rc * 0.1))
	cab_pelo.append(cab + Vector2(-rc * 0.9, -rc * 0.1))
	_c.draw_colored_polygon(cab_pelo, pelo)
	_c.draw_circle(cab + Vector2(-rc * 0.36, rc * 0.02), rc * 0.11, TINTA)
	_c.draw_circle(cab + Vector2(rc * 0.36, rc * 0.02), rc * 0.11, TINTA)
	if barba:
		var bp := PackedVector2Array()
		for i in 11:
			var a := 0.25 + i * (PI - 0.5) / 10.0
			bp.append(cab + Vector2(cos(a) * rc * 1.02, sin(a) * rc * 1.04))
		for i in 8:
			var a := PI - 0.6 - i * (PI - 1.2) / 7.0
			bp.append(cab + Vector2(cos(a) * rc * 0.62, sin(a) * rc * 0.55 + rc * 0.25))
		_c.draw_colored_polygon(bp, pelo)
	if cara == 1:
		_c.draw_arc(cab + Vector2(0, rc * 0.14), rc * 0.38, 0.35, PI - 0.35, 10, PAPEL if barba else TINTA, maxf(rc * 0.12, 2.0))
	else:
		_c.draw_circle(cab + Vector2(0, rc * 0.52), rc * 0.24, PAPEL if barba else TINTA)
		_c.draw_line(cab + Vector2(-rc * 0.6, -rc * 0.22), cab + Vector2(-rc * 0.2, -rc * 0.12), TINTA, 3.0)
		_c.draw_line(cab + Vector2(rc * 0.6, -rc * 0.22), cab + Vector2(rc * 0.2, -rc * 0.12), TINTA, 3.0)


## Globo de diálogo con cola apuntando a `cola_a`.
func _globo(centro: Vector2, rx: float, ry: float, cola_a: Vector2, txt: String, tam := 26) -> void:
	var pts := PackedVector2Array()
	for i in 28:
		var a := i * TAU / 28.0
		pts.append(centro + Vector2(cos(a) * rx, sin(a) * ry))
	var dir := (cola_a - centro).normalized()
	var perp := Vector2(-dir.y, dir.x)
	var cola := PackedVector2Array([centro + dir * ry * 0.7 + perp * rx * 0.18, cola_a, centro + dir * ry * 0.7 - perp * rx * 0.18])
	_poli(pts, PAPEL, TINTA, 3.5)
	_c.draw_colored_polygon(cola, PAPEL)
	_c.draw_line(cola[0], cola[1], TINTA, 3.5)
	_c.draw_line(cola[1], cola[2], TINTA, 3.5)
	var ancho := _fuente.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, tam).x
	_c.draw_string(_fuente, centro + Vector2(-ancho * 0.5, tam * 0.35), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, tam, TINTA)


func _cultista(base: Vector2, alto: float, extendido_a := Vector2.ZERO) -> void:
	var a := alto
	_poli(PackedVector2Array([
		Vector2(base.x - a * 0.3, base.y), Vector2(base.x - a * 0.12, base.y - a * 0.78), Vector2(base.x, base.y - a),
		Vector2(base.x + a * 0.12, base.y - a * 0.78), Vector2(base.x + a * 0.3, base.y)]), TINTA, PAPEL, 2.5)
	var cab := Vector2(base.x, base.y - a * 0.84)
	_c.draw_circle(cab, a * 0.085, Color(0.0, 0.0, 0.0))
	_c.draw_line(Vector2(base.x - a * 0.05, base.y - a * 0.45), Vector2(base.x - a * 0.12, base.y), GRIS_OSC, 2.0)
	_c.draw_line(Vector2(base.x + a * 0.05, base.y - a * 0.45), Vector2(base.x + a * 0.12, base.y), GRIS_OSC, 2.0)
	if extendido_a != Vector2.ZERO:
		var hombro := Vector2(base.x, base.y - a * 0.68)
		_c.draw_line(hombro, extendido_a, PAPEL, a * 0.085)
		_c.draw_line(hombro, extendido_a, TINTA, a * 0.055)
		_circ(extendido_a, a * 0.045, PAPEL, TINTA, 2.0)


func _ojos_cultista(base: Vector2, alto: float) -> void:
	var cab := Vector2(base.x, base.y - alto * 0.84)
	var k := 0.7 + 0.3 * sin(_t * 3.0 + base.x)
	_c.draw_circle(cab + Vector2(-alto * 0.03, 0), alto * 0.018 * k + 1.0, PAPEL)
	_c.draw_circle(cab + Vector2(alto * 0.03, 0), alto * 0.018 * k + 1.0, PAPEL)


func _manta(centro: Vector2, ancho: float) -> void:
	var filas := 3
	var cols := 9
	var h := ancho * 0.26
	var tl := Vector2(centro.x - ancho * 0.5 + h * 0.4, centro.y - h * 0.5)
	var tr := Vector2(centro.x + ancho * 0.5 - h * 0.4, centro.y - h * 0.5)
	var bl := Vector2(centro.x - ancho * 0.5, centro.y + h * 0.5)
	var br := Vector2(centro.x + ancho * 0.5, centro.y + h * 0.5)
	for f in filas:
		for c in cols:
			var pts := PackedVector2Array()
			for uv in [Vector2(c, f), Vector2(c + 1, f), Vector2(c + 1, f + 1), Vector2(c, f + 1)]:
				var u: float = uv.x / cols
				var v: float = uv.y / filas
				pts.append(tl.lerp(tr, u).lerp(bl.lerp(br, u), v))
			_poli(pts, TINTA if (f + c) % 2 == 0 else PAPEL, TINTA, 1.5)


func _cesta(p: Vector2, s: float) -> void:
	_c.draw_arc(Vector2(p.x, p.y - s * 0.4), s * 0.42, PI, TAU, 14, TINTA, 4.0, true)
	_poli(PackedVector2Array([Vector2(p.x - s * 0.5, p.y - s * 0.45), Vector2(p.x + s * 0.5, p.y - s * 0.45), Vector2(p.x + s * 0.4, p.y), Vector2(p.x - s * 0.4, p.y)]), GRIS_CLARO, TINTA, 3.0)
	_c.draw_line(Vector2(p.x - s * 0.45, p.y - s * 0.22), Vector2(p.x + s * 0.45, p.y - s * 0.22), TINTA, 2.0)


# ---- 1) Espíritus felices; una sombra se acerca

func _orbes_espiritus() -> Array[Vector2]:
	var res: Array[Vector2] = []
	for i in 8:
		res.append(Vector2(size.x * (0.08 + 0.085 * i) + sin(_t * 0.8 + i) * 12.0, size.y * (0.30 + 0.30 * fmod(i * 0.37, 1.0)) + sin(_t * 1.3 + i * 2.0) * 9.0))
	return res


func _fija_espiritus() -> void:
	var w := size.x
	var h := size.y
	_puntos(Rect2(0, 0, w, h * 0.66), 13.0, 5.0, 0.6)
	_c.draw_circle(Vector2(w * 0.60, h * 0.24), 62.0, PAPEL)
	_circ(Vector2(w * 0.60, h * 0.24), 46.0, PAPEL, TINTA, 4.0)
	_c.draw_arc(Vector2(w * 0.60 - 12.0, h * 0.24 + 4.0), 18.0, 0.5, 2.6, 10, GRIS_CLARO, 5.0)
	_colina(h * 0.60, 14.0, 0.011, 0.5, GRIS)
	for x in [40, 120, 210, 300, 420, 520, 620]:
		_pino(float(x), h * 0.70, 150.0 + (x % 40), GRIS_OSC, TINTA)
	_colina(h * 0.78, 12.0, 0.02, 2.0, TINTA, TINTA)
	for x in [30, 180, 340, 470, 600]:
		_pino(float(x), h * 0.96, 230.0 + (x % 50), TINTA, PAPEL)
	# sombra amenazante por el borde derecho, con garras
	var pts := PackedVector2Array()
	var y := -10.0
	while y <= h + 30.0:
		var pico := 34.0 if int(y / 30.0) % 2 == 0 else 0.0
		pts.append(Vector2(w - 92.0 - pico, y))
		y += 30.0
	pts.append(Vector2(w + 20, h + 30))
	pts.append(Vector2(w + 20, -10))
	_c.draw_colored_polygon(pts, Color(0, 0, 0))
	_c.draw_polyline(pts.slice(0, pts.size() - 2), PAPEL, 2.0, true)
	for g in 3:
		var gy := h * (0.52 + 0.1 * g)
		_c.draw_line(Vector2(w - 92.0, gy), Vector2(w - 160.0 - g * 10.0, gy + 16.0), TINTA, 10.0)


func _anim_espiritus() -> void:
	var w := size.x
	var h := size.y
	for p in _orbes_espiritus():
		_orbe(p, 7.0, 2.0 * sin(_t * 3.0 + p.x))
	var a := 0.4 + 0.6 * absf(sin(_t * 2.0))
	_c.draw_circle(Vector2(w - 100.0, h * 0.40), 7.0, Color(PAPEL, a))
	_c.draw_circle(Vector2(w - 62.0, h * 0.40), 7.0, Color(PAPEL, a))


# ---- 2) Picnic

func _fija_picnic() -> void:
	var w := size.x
	var h := size.y
	for c in [Vector2(w * 0.64, h * 0.42)]:
		for k in 3:
			_circ(c + Vector2(k * 30.0 - 30.0, (k % 2) * -10.0), 24.0, PAPEL, TINTA, 2.5)
		_c.draw_rect(Rect2(c.x - 54.0, c.y - 8.0, 108.0, 30.0), PAPEL)
		_c.draw_line(Vector2(c.x - 54.0, c.y + 22.0), Vector2(c.x + 54.0, c.y + 22.0), TINTA, 2.5)
	_circ(Vector2(w * 0.83, h * 0.20), 30.0, PAPEL, TINTA, 4.0)
	for i in 14:
		var a := i * TAU / 14.0
		_c.draw_line(Vector2(w * 0.83, h * 0.20) + Vector2(cos(a), sin(a)) * 40.0, Vector2(w * 0.83, h * 0.20) + Vector2(cos(a), sin(a)) * (54.0 + (i % 2) * 12.0), TINTA, 3.0)
	_colina(h * 0.55, 14.0, 0.010, 1.0, GRIS_CLARO)
	_rayado(Rect2(0, h * 0.58, w, h * 0.12), 10.0, 14.0, GRIS, 1.5)
	_colina(h * 0.68, 10.0, 0.016, 3.0, PAPEL)
	for i in 14:   # pasto
		var px := 20.0 + i * 41.0
		var py := h * 0.72 + (i % 3) * 22.0
		_c.draw_line(Vector2(px, py), Vector2(px - 5.0, py - 14.0), TINTA, 2.0)
		_c.draw_line(Vector2(px, py), Vector2(px + 5.0, py - 14.0), TINTA, 2.0)
	# árbol
	_poli(PackedVector2Array([Vector2(40, h * 0.76), Vector2(52, h * 0.40), Vector2(72, h * 0.40), Vector2(84, h * 0.76)]), GRIS, TINTA, 3.0)
	for c in [Vector2(62, h * 0.36), Vector2(118, h * 0.33), Vector2(20, h * 0.42), Vector2(100, h * 0.44)]:
		_circ(c, 54.0, PAPEL, TINTA, 3.5)
	for c in [Vector2(62, h * 0.36), Vector2(118, h * 0.33), Vector2(20, h * 0.42), Vector2(100, h * 0.44)]:
		_c.draw_arc(c + Vector2(6, 8), 38.0, 0.2, 1.5, 8, GRIS, 3.0)
		_c.draw_arc(c + Vector2(-6, 14), 26.0, 0.4, 1.4, 8, GRIS, 2.0)
	_manta(Vector2(w * 0.54, h * 0.83), 340.0)
	_cesta(Vector2(w * 0.80, h * 0.83), 46.0)
	_persona(Vector2(w * 0.42, h * 0.84), 210.0, TINTA, 1, true, false, 1.0, TINTA, TINTA, false, true)
	_persona(Vector2(w * 0.63, h * 0.85), 130.0, PAPEL, 1, true, false, -1.0, TINTA, TINTA, true)


func _anim_picnic() -> void:
	var w := size.x
	var h := size.y
	for i in 3:
		var p := Vector2(w * 0.52 + i * 22.0, h * 0.54 - fmod(_t * 14.0 + i * 12.0, 42.0))
		_c.draw_circle(p + Vector2(-4, 0), 5.0, TINTA)
		_c.draw_circle(p + Vector2(4, 0), 5.0, TINTA)
		_c.draw_colored_polygon(PackedVector2Array([p + Vector2(-8, 2), p + Vector2(8, 2), p + Vector2(0, 12)]), TINTA)


# ---- 3) El niño es atraído

func _cultistas_atraido() -> Array:
	var w := size.x
	var h := size.y
	return [[Vector2(w * 0.66, h * 0.90), h * 0.50], [Vector2(w * 0.80, h * 0.86), h * 0.43], [Vector2(w * 0.93, h * 0.92), h * 0.47]]


func _nino_atraido() -> Vector2:
	return Vector2(size.x * 0.38 + minf(_t * 6.0, 24.0), size.y * 0.93)


func _fija_atraido() -> void:
	var w := size.x
	var h := size.y
	_rayado(Rect2(0, 0, w, h * 0.62), 9.0, 12.0, TINTA, 2.0)
	_rayado(Rect2(0, 0, w, h * 0.30), 9.0, -12.0, TINTA, 2.0)
	_circ(Vector2(w * 0.30, h * 0.56), 50.0, PAPEL, TINTA, 4.0)
	_colina(h * 0.60, 10.0, 0.012, 0.0, TINTA)
	for x in [330, 400, 470, 540]:
		_pino(float(x), h * 0.80, 230.0 + (x % 37), TINTA, GRIS)
	_colina(h * 0.82, 7.0, 0.02, 1.5, GRIS_OSC)
	for cu in _cultistas_atraido():
		for k in 7:   # líneas de aura
			var a := -PI * 0.95 + k * PI * 0.9 / 6.0
			var o: Vector2 = cu[0] + Vector2(0, -float(cu[1]) * 0.6)
			_c.draw_line(o + Vector2(cos(a), sin(a)) * float(cu[1]) * 0.55, o + Vector2(cos(a), sin(a)) * float(cu[1]) * 0.85, GRIS, 2.0)
	_manta(Vector2(72, h * 0.93), 120.0)
	_persona(Vector2(74, h * 0.92), 100.0, GRIS, 0, true, false, 1.0, PAPEL, TINTA)
	var nino := _nino_atraido()
	var lista := _cultistas_atraido()
	_cultista(lista[2][0], lista[2][1])
	_cultista(lista[1][0], lista[1][1])
	_cultista(lista[0][0], lista[0][1], Vector2(nino.x + 34.0, nino.y - h * 0.17))


func _anim_atraido() -> void:
	for cu in _cultistas_atraido():
		_ojos_cultista(cu[0], cu[1])
	var lista := _cultistas_atraido()
	var cab0: Vector2 = lista[0][0] + Vector2(0, -float(lista[0][1]) * 0.9)
	_globo(Vector2(size.x * 0.46, size.y * 0.42 + sin(_t * 1.5) * 3.0), 74.0, 34.0, cab0 + Vector2(-14, 4), "¡VEN…!", 28)
	# el niño se dibuja en la capa animada: se mueve hacia ellos
	var nino := _nino_atraido()
	_persona(nino, size.y * 0.27, PAPEL, 0, false, false, 1.0, TINTA, TINTA, true)


# ---- 4) Lo busca

func _fija_busca() -> void:
	var w := size.x
	var h := size.y
	_c.draw_rect(Rect2(0, 0, w, h), GRIS_OSC)
	_rayado(Rect2(0, 0, w, h), 8.0, 14.0, TINTA, 2.0)
	_rayado(Rect2(0, 0, w, h), 8.0, -14.0, TINTA, 2.0)
	for x in [30, 120, 230, 350, 440]:
		_pino(float(x), h * 0.80, 230.0 + (x % 53), TINTA, GRIS)
	_colina(h * 0.88, 10.0, 0.02, 0.7, TINTA, GRIS)
	_manta(Vector2(85, h * 0.94), 130.0)
	_persona(Vector2(w * 0.52, h * 1.0), h * 0.74, TINTA, 2, false, true, 1.0, PAPEL, TINTA, false, true)


func _anim_busca() -> void:
	var w := size.x
	var h := size.y
	var cab := Vector2(w * 0.52, h * 1.0 - h * 0.74 * 0.87)
	for i in 11:
		var a := -PI * 0.98 + i * (PI * 0.96 / 10.0)
		var d := Vector2(cos(a), sin(a))
		var pulso := 7.0 * sin(_t * 8.0 + i)
		_c.draw_line(cab + d * (78.0 + pulso), cab + d * (118.0 + pulso), PAPEL, 4.0)
	var c := Vector2(w * 0.80, h * 0.42) + Vector2(sin(_t * 7.0), cos(_t * 6.0)) * 2.0
	_poli(_estrella(c, 74.0, 50.0, 11, 0.2), PAPEL, TINTA, 4.0)
	var f := _fuente
	var tam := 32
	var ancho := f.get_string_size("¡HIJO!", HORIZONTAL_ALIGNMENT_LEFT, -1, tam).x
	_c.draw_string(f, c + Vector2(-ancho * 0.5, tam * 0.35), "¡HIJO!", HORIZONTAL_ALIGNMENT_LEFT, -1, tam, TINTA)


# ---- 5) Entra al bosque

func _fija_entra() -> void:
	var w := size.x
	var h := size.y
	_c.draw_rect(Rect2(0, 0, w, h), GRIS_OSC)
	_rayado(Rect2(0, 0, w, h), 9.0, 12.0, TINTA, 2.0)
	var c := Vector2(w * 0.5, h * 0.46)
	for i in 28:   # rayos de luz desde el claro
		var a := i * TAU / 28.0
		_c.draw_line(c + Vector2(cos(a), sin(a)) * 60.0, c + Vector2(cos(a), sin(a)) * (w * 0.7), Color(PAPEL, 0.16), 6.0)
	_c.draw_circle(c, 110.0, GRIS_CLARO)
	_c.draw_circle(c, 78.0, PAPEL)
	# sendero
	_poli(PackedVector2Array([Vector2(w * 0.485, h * 0.52), Vector2(w * 0.515, h * 0.52), Vector2(w * 0.80, h), Vector2(w * 0.20, h)]), GRIS_CLARO, TINTA, 3.0)
	for k in 5:
		var f := 0.2 + k * 0.17
		_c.draw_line(Vector2(lerpf(w * 0.485, w * 0.22, f), lerpf(h * 0.52, h, f)), Vector2(lerpf(w * 0.515, w * 0.78, f), lerpf(h * 0.52, h, f)), GRIS, 2.0)
	for x in [w * 0.40, w * 0.60]:
		_pino(x, h * 0.58, 120.0, TINTA, GRIS)
	for x in [w * 0.27, w * 0.73]:
		_pino(x, h * 0.75, 240.0, TINTA, GRIS)
	for x in [w * 0.10, w * 0.20, w * 0.82, w * 0.92]:
		_pino(x, h * 1.04, 380.0, TINTA, PAPEL)
	_persona(Vector2(w * 0.5, h * 0.94), h * 0.36, TINTA, 0, false, false, 1.0, PAPEL, TINTA, false, true)


func _anim_entra() -> void:
	var w := size.x
	var h := size.y
	for i in 7:
		var p := Vector2(w * 0.12 + i * w * 0.12 + sin(_t + i) * 10.0, h * 0.4 + 40.0 * sin(_t * 0.7 + i * 1.7))
		_c.draw_circle(p, 3.5, PAPEL)
		_c.draw_circle(p, 7.0, Color(PAPEL, 0.3))


# ---- 6) El amuleto

func _centro_amuleto() -> Vector2:
	return Vector2(size.x * 0.45, size.y * 0.64)


func _fija_amuleto() -> void:
	var w := size.x
	var h := size.y
	var c := _centro_amuleto()
	_c.draw_rect(Rect2(0, 0, w, h), TINTA)
	for i in 24:   # líneas de acción
		var a := i * TAU / 24.0
		var ancho := 5.0 if i % 2 == 0 else 2.0
		_c.draw_line(c + Vector2(cos(a), sin(a)) * 70.0, c + Vector2(cos(a), sin(a)) * (w * 0.9), Color(PAPEL, 0.35), ancho)
	_puntos(Rect2(0, h * 0.72, w, h * 0.28), 12.0, 0.6, 4.0, GRIS)
	_c.draw_line(Vector2(0, h * 0.78), Vector2(w, h * 0.78), PAPEL, 3.0)
	# bota del padre pisando
	var bx := w * 0.73
	_poli(PackedVector2Array([Vector2(bx, -10), Vector2(bx + w * 0.09, -10), Vector2(bx + w * 0.09, h * 0.58), Vector2(bx, h * 0.58)]), GRIS_OSC, PAPEL, 3.0)
	_poli(PackedVector2Array([Vector2(bx - 6, h * 0.58), Vector2(bx + w * 0.10, h * 0.58), Vector2(bx + w * 0.12, h * 0.73), Vector2(bx + w * 0.26, h * 0.77),
		Vector2(bx + w * 0.26, h * 0.83), Vector2(bx - 12, h * 0.83)]), TINTA, PAPEL, 3.0)
	# amuleto
	_circ(c, 58.0, PAPEL, TINTA, 4.0)
	_circ(c, 46.0, TINTA, PAPEL, 3.0)
	var g := 26.0
	_poli(PackedVector2Array([c + Vector2(0, -g), c + Vector2(g * 0.7, 0), c + Vector2(0, g), c + Vector2(-g * 0.7, 0)]), PAPEL, PAPEL, 2.0)
	_c.draw_line(c + Vector2(0, -g), c + Vector2(0, g), TINTA, 2.0)
	_c.draw_line(c + Vector2(-g * 0.7, 0), c + Vector2(g * 0.7, 0), TINTA, 2.0)


func _anim_amuleto() -> void:
	var c := _centro_amuleto()
	for k in 3:
		var f := fmod(_t * 0.8 + k / 3.0, 1.0)
		_c.draw_arc(c, 62.0 + f * 110.0, 0.0, TAU, 40, Color(PAPEL, (1.0 - f) * 0.9), 4.0)
	_c.draw_arc(c, 66.0 + 3.0 * sin(_t * 12.0), 0.0, TAU, 40, PAPEL, 2.0)
	var o := Vector2(sin(_t * 30.0), cos(_t * 27.0)) * 2.0
	_c.draw_string(_fuente, c + Vector2(-200.0, 100.0) + o, "¡BZZZ…!", HORIZONTAL_ALIGNMENT_LEFT, -1, 34, PAPEL)
	for i in 10:
		var p := Vector2(c.x + sin(i * 2.3 + _t) * 90.0, c.y - fmod(_t * 34.0 + i * 37.0, 190.0))
		_c.draw_circle(p, 2.5, PAPEL)
