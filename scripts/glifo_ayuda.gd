@tool
extends Node2D
## Cartel diegético sin texto: pista visual de una mecánica en el MUNDO.
## Se coloca como nodo en el nivel (mover/escalar desde el editor) y refuerza
## lo que el Amuleto explica en el tip, sin depender de leer texto.
##
## Ejemplo: un glifo "DobleSalto" junto a la enredadera o el abismo que se cruza
## en forma de Lobo, "Agarrar" bajo una liana, "Fragil" antes de las tablas que
## se rompen. Los pictogramas son vectoriales y planos, sin texto.

enum Tipo { TRANSFORMAR, DOBLE_SALTO, AGARRAR, FRAGIL, ESQUIVAR, GOLPE }

@export var tipo := Tipo.TRANSFORMAR:
	set(value):
		tipo = value
		queue_redraw()
@export var color_marco := Color(0.85, 0.87, 0.82)
@export var color_icono := Color(0.28, 0.6, 0.75)
@export var color_fondo := Color(0.06, 0.08, 0.1, 0.82)
@export var ancho := 64.0:
	set(value):
		ancho = value
		queue_redraw()

@export var radio_reaccion := 420.0   ## px: a esta distancia del jugador el cartel "despierta"
@export var pulso_escala := 0.14       ## cuánto crece al despertar
@export var brillo_cerca := 1.45       ## multiplicador de brillo con el jugador cerca

var _tmp_clave := Vector3.ZERO
var _tmp := Vector3.ZERO
var _escala_base := Vector2.ONE
var _cerca := 0.0
var _t := 0.0
var _player: Node2D


func _ready() -> void:
	z_index = 5
	_escala_base = scale
	if Engine.is_editor_hint():
		queue_redraw()


func _process(delta: float) -> void:
	if not Engine.is_editor_hint():
		_reaccionar(delta)
		return
	var clave := Vector3(float(tipo), ancho, scale.x)
	if clave != _tmp:
		_tmp = clave
		queue_redraw()


## En juego: con el jugador cerca el cartel crece un poco, late y brilla, para
## que se note sin necesidad de texto. Lejos vuelve a su tamaño y tono.
func _reaccionar(delta: float) -> void:
	if _player == null or not is_instance_valid(_player):
		_player = get_tree().get_first_node_in_group("player") as Node2D
		if _player == null:
			return
	var objetivo := 1.0 if global_position.distance_to(_player.global_position) < radio_reaccion else 0.0
	_cerca = move_toward(_cerca, objetivo, delta * 3.0)
	_t += delta
	var latido := 0.5 + 0.5 * sin(_t * 5.0)
	scale = _escala_base * (1.0 + (pulso_escala + 0.05 * latido) * _cerca)
	var b := lerpf(1.0, brillo_cerca + 0.15 * latido, _cerca)
	modulate = Color(b, b, b, 1.0)


func _draw() -> void:
	var medio := ancho * 0.5
	var radio := 26.0
	# Cartel: placa redondeada con borde claro.
	draw_circle(Vector2.ZERO, radio + 3.0, color_marco)
	draw_circle(Vector2.ZERO, radio, color_fondo)
	_dibujar_icono()


func _dibujar_icono() -> void:
	var c := color_icono
	var p: float = ancho * 0.09   # grosor de línea
	match tipo:
		Tipo.TRANSFORMAR:
			# Vórtice de energía: dos arcos de espiral + destello central.
			draw_arc(Vector2.ZERO, 18.0, 0.6, 5.2, 24, c, p, true)
			draw_arc(Vector2.ZERO, 10.0, 2.2, 5.0, 20, c, p, true)
			draw_circle(Vector2.ZERO, 3.2, c)
		Tipo.DOBLE_SALTO:
			# Dos arcos de salto (primer brinco + salto en el aire).
			var a := Vector2(-16, 4)
			var b := Vector2(0, -10)
			var d := Vector2(16, 4)
			var e := Vector2(-4, -14)
			var f := Vector2(10, -2)
			_dibujar_arco(a, b, -1.6, c, p)
			_dibujar_arco(b, d, 1.6, c, p)
			_dibujar_arco(e, f, 1.2, c, p)
		Tipo.AGARRAR:
			# Liana: tallo ondulado con hoja y punto de agarre.
			draw_polyline(PackedVector2Array([Vector2(-12, 16), Vector2(-6, 0), Vector2(-12, -16)]), c, p, true)
			draw_polyline(PackedVector2Array([Vector2(-12, -16), Vector2(-2, -6), Vector2(-12, 0)]), c, p * 0.8, true)
			draw_circle(Vector2(14, 0), 5.0, c)
		Tipo.FRAGIL:
			# Tabla con grieta: rectángulo partido por un zigzag.
			draw_rect(Rect2(-14, -8, 28, 16), c, false, p)
			draw_polyline(PackedVector2Array([Vector2(-2, 8), Vector2(4, 2), Vector2(-3, -8)]), c, p, true)
		Tipo.ESQUIVAR:
			# Flecha serpenteante que se aparta del proyectil.
			draw_polyline(PackedVector2Array([Vector2(-16, -12), Vector2(-6, -2), Vector2(-16, 8)]), c, p, true)
			draw_polyline(PackedVector2Array([Vector2(-6, -2), Vector2(4, -12), Vector2(14, -2)]), c, p, true)
			draw_circle(Vector2(16, -14), 3.0, c)
		Tipo.GOLPE:
			# Puño/golpe rápido: estrella de impacto.
			draw_polyline(PackedVector2Array([Vector2(0, -14), Vector2(0, 12)]), c, p, true)
			draw_polyline(PackedVector2Array([Vector2(-12, 0), Vector2(14, 0)]), c, p, true)
			draw_polyline(PackedVector2Array([Vector2(-9, -9), Vector2(10, 10)]), c, p * 0.8, true)


## Arco parametrizado entre dos puntos (desvía `curva` en el medio).
func _dibujar_arco(desde: Vector2, hasta: Vector2, curva: float, c: Color, grosor: float) -> void:
	var pts := PackedVector2Array()
	for i in 25:
		var t := float(i) / 24.0
		var punto := desde.lerp(hasta, t)
		punto.y += sin(t * PI) * curva * 6.0
		pts.append(punto)
	draw_polyline(pts, c, grosor, true)