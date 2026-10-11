extends Control
## Dial de forma del HUD (inspirado en el dial del Omnitrix de Alien Force, arte propio).
## Muestra la silueta de la forma SELECCIONADA dentro de un medallón; al pasar de una
## forma a otra el ícono sale deslizándose y el nuevo entra desde el lado opuesto.
## El aro exterior es la energía de transformación (con "fantasma" al gastarse) y su
## color es el de la forma ACTIVA. Todo vectorial, editable desde el Inspector.

const ICONO_ESCENA := preload("res://scenes/form_icon.tscn")

@export var color_tinta := Color(0.04, 0.047, 0.063, 1.0)      ## contorno y silueta (estilo cómic de tinta)
@export var color_borde := Color(0.93, 0.90, 0.84)             ## línea fina blanca del contorno
@export var color_disco := Color(0.93, 0.90, 0.84)             ## disco claro donde va la silueta
@export var color_aro_fondo := Color(0.16, 0.18, 0.22, 1.0)
@export var color_humano := Color(0.30, 0.82, 0.96)   ## color del aro de energía en forma humana (cian, para que se lea como energía)
@export var color_bajo := Color(0.95, 0.25, 0.25)     ## aro con energía baja
@export var color_cooldown := Color(1.0, 0.7, 0.3)
@export var ancho_aro := 12.0
@export_range(0.0, 1.0) var umbral_bajo := 0.25
@export var duracion_transicion := 0.22
@export_range(0.2, 1.5) var recorrido := 0.95          ## cuánto se desliza el ícono (fracción del recorte)
@export_range(0.3, 2.5) var tamano_icono := 2.3         ## lado del ícono respecto del recorte interior (>1 = dibujo más grande)
@export var giro_por_cambio := 0.5                      ## rad que gira el aro de marcas por cambio
@export var cooldown_total := 3.0

var energia := 100.0
var energia_max := 100.0
var forma_actual := 0
var forma_sel := 0
var cooldown := 0.0
var colores: Array[Color] = [Color(0.8, 0.85, 0.9), Color(0.6, 0.6, 0.65), Color(0.7, 0.5, 0.35), Color(0.5, 0.4, 0.7)]

var _fantasma := 100.0
var _giro := 0.0
var _flash := 0.0
var _t := 0.0
var _recorte: Control
var _icono: Control
var _salientes: Array[Control] = []
var _tw_trans: Tween
var _tw_fantasma: Tween
var _tw_flash: Tween
var _tw_pulso: Tween


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	pivot_offset = size * 0.5
	_recorte = Control.new()
	_recorte.name = "Recorte"
	_recorte.clip_contents = true
	_recorte.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_recorte)
	resized.connect(_reacomodar)
	_reacomodar()
	_icono = _crear_icono(forma_sel)
	_recorte.add_child(_icono)
	_ajustar_icono(_icono)


func _process(delta: float) -> void:
	_t += delta
	if _icono != null and (_tw_trans == null or not _tw_trans.is_running()):
		_icono.modulate.a = 0.4 if cooldown > 0.0 else 1.0
	queue_redraw()


func _radio() -> float:
	return minf(size.x, size.y) * 0.5 - 2.0


func _reacomodar() -> void:
	pivot_offset = size * 0.5
	if _recorte == null:
		return
	var interior := (_radio() - ancho_aro - 9.0) * 2.0
	var lado := interior * 0.7   # cuadrado inscrito en el disco claro
	_recorte.size = Vector2(lado, lado)
	_recorte.position = (size - _recorte.size) * 0.5
	for n in _recorte.get_children():
		_ajustar_icono(n)


func _ajustar_icono(ic: Control) -> void:
	var lado := _recorte.size.x
	var t := lado * tamano_icono
	ic.size = Vector2(t, t)
	ic.pivot_offset = ic.size * 0.5
	ic.position = Vector2((lado - t) * 0.5, (lado - t) * 0.5)


func _crear_icono(idx: int) -> Control:
	var ic: Control = ICONO_ESCENA.instantiate()
	ic.forma = idx
	ic.color_icono = color_tinta
	ic.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return ic


func _color_forma(idx: int) -> Color:
	return colores[idx] if idx >= 0 and idx < colores.size() else color_humano


func set_formas(lista: Array) -> void:
	colores.clear()
	for c in lista:
		colores.append(c)
	if _icono != null:
		_icono.color_icono = color_tinta


## Cambia la forma seleccionada con transición: el ícono viejo sale y el nuevo entra.
func fijar_seleccion(idx: int, animar := true) -> void:
	if idx == forma_sel:
		return
	var n := maxi(colores.size(), 2)
	var d := posmod(idx - forma_sel, n)
	var dir := 1.0 if d <= n / 2 else -1.0
	forma_sel = idx
	if _recorte == null:
		return
	# Cambios rápidos: descarta los íconos que aún estaban saliendo.
	for s in _salientes:
		if is_instance_valid(s):
			s.queue_free()
	_salientes.clear()
	if _tw_trans != null and _tw_trans.is_valid():
		_tw_trans.kill()
	var saliente := _icono
	_icono = _crear_icono(idx)
	_recorte.add_child(_icono)
	_ajustar_icono(_icono)
	if not animar:
		if saliente != null:
			saliente.queue_free()
		return
	var w := _recorte.size.x * recorrido
	_icono.position.x += dir * w
	_icono.modulate.a = 0.0
	_salientes.append(saliente)
	var base_x := (_recorte.size.x - _icono.size.x) * 0.5
	_tw_trans = create_tween().set_parallel(true)
	_tw_trans.tween_property(_icono, "position:x", base_x, duracion_transicion).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_tw_trans.tween_property(_icono, "modulate:a", 1.0, duracion_transicion * 0.8)
	if saliente != null:
		_tw_trans.tween_property(saliente, "position:x", saliente.position.x - dir * w, duracion_transicion).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
		_tw_trans.tween_property(saliente, "modulate:a", 0.0, duracion_transicion * 0.8)
	_tw_trans.tween_property(self, "_giro", _giro + dir * giro_por_cambio, duracion_transicion * 1.4).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_tw_trans.chain().tween_callback(_limpiar_salientes)
	_flash = 1.0
	if _tw_flash != null and _tw_flash.is_valid():
		_tw_flash.kill()
	_tw_flash = create_tween()
	_tw_flash.tween_property(self, "_flash", 0.0, duracion_transicion * 1.8)


func _limpiar_salientes() -> void:
	for s in _salientes:
		if is_instance_valid(s):
			s.queue_free()
	_salientes.clear()


## Pulso de escala al confirmar una transformación.
func pulso_transformacion() -> void:
	if _tw_pulso != null and _tw_pulso.is_valid():
		_tw_pulso.kill()
	scale = Vector2.ONE * 1.18
	_flash = 1.0
	_tw_pulso = create_tween().set_parallel(true)
	_tw_pulso.tween_property(self, "scale", Vector2.ONE, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_tw_pulso.tween_property(self, "_flash", 0.0, 0.4)


## Pulso corto al ganar energía (matar, parry, alma): más chico que el de transformación.
func pulso_energia() -> void:
	if _tw_pulso != null and _tw_pulso.is_valid():
		_tw_pulso.kill()
	scale = Vector2.ONE * 1.08
	_flash = maxf(_flash, 0.55)
	_tw_pulso = create_tween().set_parallel(true)
	_tw_pulso.tween_property(self, "scale", Vector2.ONE, 0.22).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_tw_pulso.tween_property(self, "_flash", 0.0, 0.3)


## Sacudida corta lateral cuando una transformación se deniega (cooldown / sin energía / sin espacio).
func rechazo() -> void:
	if _tw_pulso != null and _tw_pulso.is_valid():
		_tw_pulso.kill()
	scale = Vector2.ONE
	rotation = 0.0
	_tw_pulso = create_tween()
	for r in [0.12, -0.12, 0.07, -0.05, 0.0]:
		_tw_pulso.tween_property(self, "rotation", r, 0.045)


func set_energia(valor: float, maximo := 100.0) -> void:
	energia_max = maximo
	if valor < _fantasma:
		if _tw_fantasma != null and _tw_fantasma.is_valid():
			_tw_fantasma.kill()
		_tw_fantasma = create_tween()
		_tw_fantasma.tween_interval(0.32)
		_tw_fantasma.tween_property(self, "_fantasma", valor, 0.45).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	else:
		if _tw_fantasma != null and _tw_fantasma.is_valid():
			_tw_fantasma.kill()
		_fantasma = valor
	energia = valor


func set_cooldown(segundos: float) -> void:
	cooldown = maxf(segundos, 0.0)


func _draw() -> void:
	var c := size * 0.5
	var R := _radio()
	var r_aro := R - ancho_aro * 0.5 - 4.0
	# Tinta + línea blanca fina (doble contorno de cómic).
	draw_circle(c, R, color_tinta)
	draw_arc(c, R - 2.5, 0.0, TAU, 72, color_borde, 1.6, true)
	draw_arc(c, r_aro, 0.0, TAU, 72, color_aro_fondo, ancho_aro, true)
	var frac := clampf(energia / maxf(energia_max, 0.01), 0.0, 1.0)
	var frac_f := clampf(_fantasma / maxf(energia_max, 0.01), 0.0, 1.0)
	var col_aro := color_humano if forma_actual == 0 else _color_forma(forma_actual)
	var bajo := frac <= umbral_bajo and forma_actual != 0
	if bajo:
		var onda := 0.5 + 0.5 * sin(_t * 9.0)
		col_aro = col_aro.lerp(color_bajo, 0.55 + 0.45 * onda)
	if frac_f > frac:
		draw_arc(c, r_aro, -PI * 0.5 + TAU * frac, -PI * 0.5 + TAU * frac_f, 48, Color(color_borde.r, color_borde.g, color_borde.b, 0.55), ancho_aro, true)
	if frac > 0.001:
		draw_arc(c, r_aro, -PI * 0.5, -PI * 0.5 + TAU * frac, 72, col_aro, ancho_aro, true)
	# Cuatro cortes de tinta que giran al cambiar de forma.
	var r_marca := r_aro + ancho_aro * 0.5 + 1.0
	for i in 4:
		var u := Vector2.from_angle(_giro + TAU * float(i) / 4.0)
		draw_line(c + u * (r_marca - 1.0), c + u * (r_marca + 3.0), color_borde, 2.0)
	# Disco claro con la silueta de la forma en tinta (los íconos se dibujan encima como hijos).
	var r_in := r_aro - ancho_aro * 0.5 - 2.0
	var tinte := _color_forma(forma_sel)
	draw_circle(c, r_in, color_tinta)
	draw_circle(c, r_in - 3.0, color_disco.lerp(tinte, 0.16))
	var r_pts := r_in - 6.0
	var paso := 7.0
	var y := paso
	while y < r_pts:
		var x := -r_pts
		while x < r_pts:
			var p := Vector2(x + (paso * 0.5 if int(y / paso) % 2 == 1 else 0.0), y)
			if p.length() < r_pts - 2.0:
				draw_circle(c + p, 0.7 + 1.3 * (y / r_pts), Color(color_tinta.r, color_tinta.g, color_tinta.b, 0.22))
			x += paso
		y += paso
	if _flash > 0.0:
		draw_circle(c, r_in - 3.0, Color(tinte.r, tinte.g, tinte.b, 0.45 * _flash))
	# Cooldown de la forma seleccionada: arco naranja y segundos en el centro.
	if cooldown > 0.0:
		var f := clampf(cooldown / maxf(cooldown_total, 0.01), 0.0, 1.0)
		draw_arc(c, r_in - 7.0, -PI * 0.5, -PI * 0.5 + TAU * f, 48, color_cooldown, 4.0, true)
		var fuente := ThemeDB.fallback_font
		var txt := "%d" % int(ceil(cooldown))
		var ancho := fuente.get_string_size(txt, HORIZONTAL_ALIGNMENT_CENTER, -1, 30).x
		draw_string(fuente, c + Vector2(-ancho * 0.5, 10.0), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 30, color_tinta)
	# Punto de "forma activa distinta de la seleccionada".
	if forma_actual != forma_sel:
		var pp := c + Vector2(0, R - ancho_aro - 11.0)
		draw_circle(pp, 6.0, color_tinta)
		draw_circle(pp, 4.0, _color_forma(forma_actual))
