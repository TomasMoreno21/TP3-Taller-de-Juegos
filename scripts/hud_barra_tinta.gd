extends Control
## Barra del HUD en estilo tinta (cómic B/N): paralelogramo inclinado con contorno de tinta,
## línea fina blanca, relleno con rayado y "eco" claro que baja con retraso.
## No guarda valores: lee un ProgressBar fuente (que sigue siendo el que maneja hud.gd).

@export var fuente: NodePath   ## ProgressBar con el valor actual
@export var eco: NodePath      ## ProgressBar opcional con el eco (baja con retraso)
@export var color_relleno := Color(0.78, 0.22, 0.23)
@export var color_eco := Color(0.93, 0.90, 0.84, 0.85)
@export var color_fondo := Color(0.105, 0.12, 0.15)
@export var color_tinta := Color(0.04, 0.047, 0.063)
@export var color_linea := Color(0.93, 0.90, 0.84)
@export var usar_color_de_fuente := false   ## toma el color del estilo "fill" de la fuente (jefe: cambia por fase)
@export var inclinacion := 14.0
@export var grosor_tinta := 4.0
@export var grosor_linea := 1.5
@export var rayado := true
@export var separacion_rayado := 20.0
@export var marcas: PackedFloat32Array = []   ## muescas (0-1) sobre la barra, p. ej. los cambios de fase del jefe
@export var chispa := false                   ## chispa de cuatro puntas al final (fragmentos)
@export var color_chispa := Color(0.56, 0.82, 0.96)

var _src: ProgressBar
var _eco: ProgressBar
var _flash := 0.0
var _tw: Tween


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_src = get_node_or_null(fuente) as ProgressBar
	_eco = get_node_or_null(eco) as ProgressBar
	pivot_offset = Vector2(0.0, size.y * 0.5)
	resized.connect(func() -> void: pivot_offset = Vector2(0.0, size.y * 0.5))


func _process(_delta: float) -> void:
	queue_redraw()


## Pulso al sumar (fragmentos): la barra crece un poco y destella.
func pop(escala := 1.18) -> void:
	if _tw != null and _tw.is_valid():
		_tw.kill()
	scale = Vector2.ONE * escala
	_flash = 1.0
	_tw = create_tween().set_parallel(true)
	_tw.tween_property(self, "scale", Vector2.ONE, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_tw.tween_property(self, "_flash", 0.0, 0.5)


func _frac(b: ProgressBar) -> float:
	if b == null:
		return 0.0
	var rango := maxf(b.max_value - b.min_value, 0.001)
	return clampf((b.value - b.min_value) / rango, 0.0, 1.0)


## Paralelogramo "/" entre x0 y x1; `f` recorta el borde derecho con la misma inclinación.
func _forma(r: Rect2, f: float) -> PackedVector2Array:
	var inc := minf(inclinacion, r.size.x * 0.5)
	var avance := f * (r.size.x - inc)
	return PackedVector2Array([
		Vector2(r.position.x + inc, r.position.y),
		Vector2(r.position.x + inc + avance, r.position.y),
		Vector2(r.position.x + avance, r.end.y),
		Vector2(r.position.x, r.end.y),
	])


func _draw() -> void:
	var g := grosor_tinta
	var ext := Rect2(Vector2.ZERO, size)
	var inc := minf(inclinacion, size.x * 0.5)
	# Contorno de tinta + línea blanca fina un poco adentro.
	draw_colored_polygon(_forma(ext, 1.0), color_tinta)
	var linea := _forma(ext.grow(-g * 0.5), 1.0)
	linea.append(linea[0])
	draw_polyline(linea, color_linea, grosor_linea, true)
	var r := ext.grow(-g - 1.0)
	draw_colored_polygon(_forma(r, 1.0), color_fondo)
	var fe := _frac(_eco)
	var ff := _frac(_src)
	if _eco != null and fe > ff:
		draw_colored_polygon(_forma(r, fe), color_eco)
	if ff > 0.001:
		var col := color_relleno
		if usar_color_de_fuente and _src != null:
			var sb := _src.get_theme_stylebox("fill") as StyleBoxFlat
			if sb != null:
				col = sb.bg_color
		if _src != null:
			col *= _src.self_modulate
		draw_colored_polygon(_forma(r, ff), col)
		_dibujar_detalles(r, ff, col)
	for m in marcas:
		var x := r.position.x + m * (r.size.x - inc)
		draw_line(Vector2(x + inc, r.position.y - 1.0), Vector2(x, r.end.y + 1.0), color_tinta, 3.0)
	if _flash > 0.0 and ff > 0.001:
		draw_colored_polygon(_forma(r, ff), Color(1, 1, 1, 0.55 * _flash))
	if chispa:
		_dibujar_chispa(Vector2(size.x + 2.0, size.y * 0.5), size.y * 0.95)


func _dibujar_detalles(r: Rect2, f: float, col: Color) -> void:
	var inc := minf(inclinacion, r.size.x * 0.5)
	var x_fin := r.position.x + inc + f * (r.size.x - inc)
	# Brillo fino arriba (como el filo del tajo).
	var alto := maxf(r.size.y * 0.16, 1.5)
	draw_colored_polygon(PackedVector2Array([
		Vector2(r.position.x + inc, r.position.y),
		Vector2(x_fin, r.position.y),
		Vector2(x_fin - inc * alto / r.size.y, r.position.y + alto),
		Vector2(r.position.x + inc - inc * alto / r.size.y, r.position.y + alto),
	]), Color(1, 1, 1, 0.22))
	if not rayado:
		return
	var sombra := Color(color_tinta.r, color_tinta.g, color_tinta.b, 0.3)
	var x := r.position.x + inc + separacion_rayado
	while x < x_fin - 4.0:
		draw_line(Vector2(x, r.position.y + alto), Vector2(x - inc, r.end.y), sombra, 2.0)
		x += separacion_rayado


func _dibujar_chispa(c: Vector2, d: float) -> void:
	var a := d * 0.5
	var b := d * 0.16
	var pts := PackedVector2Array([
		c + Vector2(0, -a), c + Vector2(b, -b), c + Vector2(a, 0), c + Vector2(b, b),
		c + Vector2(0, a), c + Vector2(-b, b), c + Vector2(-a, 0), c + Vector2(-b, -b),
	])
	draw_colored_polygon(pts, color_chispa.lerp(Color.WHITE, _flash))
	var borde := pts.duplicate()
	borde.append(pts[0])
	draw_polyline(borde, color_tinta, 1.5, true)
