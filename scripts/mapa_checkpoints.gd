extends Control
## Mapa chico del nivel para el modo prueba: un punto por checkpoint (con su número de la lista), el enfocado
## resaltado y la posición del jugador. Verde = ya activado, dorado = tu punto de reaparición.

var puntos: Array[Vector2] = []
var activados: Array[bool] = []
var actual := -1        ## índice del checkpoint donde reaparecés
var enfocado := -1      ## índice del checkpoint elegido en la lista
var jugador := Vector2.ZERO

var color_fondo := Color(0.04, 0.05, 0.07)
var color_borde := Color(0.35, 0.38, 0.45)
var color_punto := Color(0.55, 0.6, 0.72)
var color_activo := Color(0.35, 0.9, 0.6)
var color_actual := Color(0.95, 0.85, 0.4)
var color_jugador := Color(1, 1, 1)


func _init() -> void:
	custom_minimum_size = Vector2(420, 420)


func fijar_enfocado(i: int) -> void:
	enfocado = i
	queue_redraw()


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), color_fondo)
	draw_rect(Rect2(Vector2.ZERO, size), color_borde, false, 2.0)
	if puntos.is_empty():
		return
	var mn := jugador
	var mx := jugador
	for p in puntos:
		mn = mn.min(p)
		mx = mx.max(p)
	var ext := (mx - mn).max(Vector2.ONE)
	var area := size - Vector2.ONE * 72.0
	var esc := minf(area.x / ext.x, area.y / ext.y)
	var off := (size - ext * esc) * 0.5
	var fuente := ThemeDB.fallback_font
	for i in puntos.size():
		var c := off + (puntos[i] - mn) * esc
		var col := color_activo if i < activados.size() and activados[i] else color_punto
		var radio := 7.0
		if i == actual:
			draw_arc(c, 12.0, 0.0, TAU, 24, color_actual, 3.0)
		if i == enfocado:
			radio = 11.0
			draw_arc(c, 17.0, 0.0, TAU, 24, Color.WHITE, 3.0)
		draw_circle(c, radio, col)
		draw_string(fuente, c + Vector2(14, -10), str(i + 1), HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color.WHITE if i == enfocado else Color(0.85, 0.88, 0.92))
	var j := off + (jugador - mn) * esc
	draw_colored_polygon(PackedVector2Array([j + Vector2(0, -9), j + Vector2(9, 0), j + Vector2(0, 9), j + Vector2(-9, 0)]), color_jugador)
	draw_string(fuente, j + Vector2(12, 22), "VOS", HORIZONTAL_ALIGNMENT_LEFT, -1, 15, color_jugador)
