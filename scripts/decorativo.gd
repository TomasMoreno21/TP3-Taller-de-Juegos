@tool
extends Node2D
## Decorativo forestal vectorial (sin sprites): árbol, sauce, arbusto, pasto
## o piedra dibujados con Polygon2D de colores planos (regla de arte del
## proyecto). Anclado al suelo (0,0 = pie), con sombra elíptica y viento
## opcional. Va dentro de un contenedor z=-5 para quedar entre fondo y gameplay.

enum Tipo { ARBOL, SAUCE, ARBUSTO, PASTO, PIEDRA }

const COLORES := {
	0: { "tronco": Color(0.28, 0.19, 0.14), "copa": Color(0.10, 0.23, 0.14) },
	1: { "tronco": Color(0.26, 0.18, 0.13), "copa": Color(0.09, 0.21, 0.13) },
	2: { "copa": Color(0.10, 0.25, 0.15) },
	3: { "copa": Color(0.14, 0.29, 0.17) },
	4: { "copa": Color(0.30, 0.34, 0.42) },
}

@export var tipo := Tipo.ARBOL:
	set(value):
		tipo = value
		queue_redraw()
@export_range(1, 10) var variante := 1:
	set(value):
		variante = value
		queue_redraw()
@export var escala := 5.0:
	set(value):
		escala = maxf(value, 0.1)
		queue_redraw()
@export var flip_h := false:
	set(value):
		flip_h = value
		queue_redraw()
@export var color_noche := Color(0.8, 0.85, 0.97):
	set(value):
		color_noche = value
		queue_redraw()
@export var sombra := true
@export var sombra_alpha := 0.25:
	set(value):
		sombra_alpha = clampf(value, 0.0, 1.0)
		queue_redraw()
@export var viento := true
@export var viento_amplitud := 0.03:
	set(value):
		viento_amplitud = absf(value)
@export var viento_velocidad := 1.5:
	set(value):
		viento_velocidad = absf(value)

var _tmp := Vector3.ZERO
var _editor_sync := true
var _fase_viento := 0.0
var _hoja: Node2D
var _sombra: Polygon2D


func _ready() -> void:
	_fase_viento = randf() * TAU
	_rehacer()


func _process(delta: float) -> void:
	if Engine.is_editor_hint():
		if _editor_sync:
			var s := scale
			if s != Vector2.ONE:
				_editor_sync = false
				escala = maxf(escala * s.x, 0.1)
				scale = Vector2.ONE
				_editor_sync = true
				_rehacer()
		var clave := Vector3(float(tipo), float(variante), escala)
		if clave != _tmp:
			_tmp = clave
			_rehacer()
		_aplicar_config()
		return
	if viento and _hoja != null:
		var t := Time.get_ticks_msec() * 0.001 * viento_velocidad + _fase_viento
		_hoja.rotation = sin(t) * viento_amplitud


## Reconstruye la silueta en caliente: colores, flip y escala sin redibujar.
func _aplicar_config() -> void:
	if _hoja != null:
		_hoja.scale = Vector2(escala * (-1.0 if flip_h else 1.0), escala)
		_hoja.modulate = color_noche
	if _sombra != null:
		_sombra.visible = sombra
		_sombra.color.a = sombra_alpha


## Reconstruye la silueta completa (idempotente: limpia y vuelve a crear).
func _rehacer() -> void:
	for nodo in ["Hoja", "Sombra"]:
		var old := get_node_or_null(nodo)
		if old != null:
			old.queue_free()
	_hoja = Node2D.new()
	_hoja.name = "Hoja"
	add_child(_hoja)
	for pol in _generar_silueta(tipo, variante):
		_hoja.add_child(pol)
	if sombra:
		_sombra = Polygon2D.new()
		_sombra.name = "Sombra"
		_sombra.z_index = -1
		_sombra.position.y = 3.0
		_sombra.polygon = _elipse_sombra()
		add_child(_sombra)
	_aplicar_config()


## Genera los Polygon2D de la silueta según tipo/variante. Coordenadas locales
## en tamaño "base" (y<=0 hacia arriba, 0 = suelo); la escala la pone Hoja.
func _generar_silueta(t: int, v: int) -> Array[Polygon2D]:
	var colores: Dictionary = COLORES[t]
	var salida: Array[Polygon2D] = []
	var tinte := 1.0 + 0.12 * float((v - 1) % 4) - 0.06
	match t:
		Tipo.ARBOL:
			salida += [_poligono([Vector2(-9, 0), Vector2(-6, -38), Vector2(6, -38), Vector2(9, 0)], colores["tronco"] * tinte)]
			var modo := (v - 1) % 3
			if modo == 0:
				salida += [_poligono(_elipse(Vector2(0, -92), Vector2(36, 30), 14), colores["copa"] * tinte)]
				salida += [_poligono(_elipse(Vector2(-26, -78), Vector2(27, 24), 12), colores["copa"] * tinte)]
				salida += [_poligono(_elipse(Vector2(26, -78), Vector2(27, 24), 12), colores["copa"] * tinte)]
			elif modo == 1:
				salida += [_poligono(_elipse(Vector2(0, -70), Vector2(48, 34), 16), colores["copa"] * tinte)]
				salida += [_poligono(_elipse(Vector2(0, -100), Vector2(34, 26), 12), colores["copa"] * tinte)]
			else:
				salida += [_poligono(_elipse(Vector2(0, -62), Vector2(52, 40), 18), colores["copa"] * tinte)]
		Tipo.SAUCE:
			salida += [_poligono([Vector2(-6, 0), Vector2(-4, -30), Vector2(4, -30), Vector2(6, 0)], colores["tronco"] * tinte)]
			salida += [_poligono(_elipse(Vector2(0, -52), Vector2(56, 27), 16), colores["copa"] * tinte)]
			salida += [_poligono(_elipse(Vector2(-42, -22), Vector2(23, 26), 12), colores["copa"] * tinte)]
			salida += [_poligono(_elipse(Vector2(42, -22), Vector2(23, 26), 12), colores["copa"] * tinte)]
		Tipo.ARBUSTO:
			salida += [_poligono(_elipse(Vector2(0, -24), Vector2(42, 24), 16), colores["copa"] * tinte)]
			if (v - 1) % 2 == 1:
				salida += [_poligono(_elipse(Vector2(16, -16), Vector2(22, 14), 12), colores["copa"] * tinte)]
		Tipo.PASTO:
			var n := 5 + (v - 1) % 3
			var sep := 8
			for i in n:
				var h := 16.0 + float(((v - 1) + i * 3) % 6) * 4.0
				var x := -sep * (n - 1) * 0.5 + i * sep
				salida += [_poligono([Vector2(x - 2, 0), Vector2(x, -h), Vector2(x + 2, 0)], colores["copa"] * tinte)]
		Tipo.PIEDRA:
			var rx := 24.0 + float((v - 1) % 3) * 7.0
			var ry := 14.0 + float((v - 1) % 2) * 4.0
			salida += [_poligono(_elipse(Vector2(0, -ry), Vector2(rx, ry), 12), colores["copa"] * tinte)]
	return salida


func _poligono(puntos: PackedVector2Array, color: Color) -> Polygon2D:
	var p := Polygon2D.new()
	p.polygon = puntos
	p.color = color
	return p


func _elipse(centro: Vector2, radios: Vector2, n: int) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in n:
		var a := TAU * float(i) / float(n)
		pts.append(Vector2(centro.x + cos(a) * radios.x, centro.y + sin(a) * radios.y))
	return pts


func _elipse_sombra() -> PackedVector2Array:
	var ancho := maxf(_ancho_silueta_base() * escala * 0.85, 24.0)
	var alto := maxf(ancho * 0.22, 6.0)
	var pts := PackedVector2Array()
	for i in 14:
		var a := TAU * float(i) / 14.0
		pts.append(Vector2(cos(a) * ancho * 0.5, sin(a) * alto * 0.5))
	return pts


func _ancho_silueta_base() -> float:
	match tipo:
		Tipo.SAUCE:
			return 130.0
		Tipo.ARBUSTO:
			return 80.0
		Tipo.PASTO:
			return 34.0
		Tipo.PIEDRA:
			return 60.0
	return 90.0