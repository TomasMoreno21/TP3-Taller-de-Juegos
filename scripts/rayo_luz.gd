@tool
extends Node2D

## Haz de luz que cae desde una grieta del techo de la cueva (suave, con vida propia).
## Se coloca en el techo (el origen del nodo es la grieta) y cae hacia abajo, un poco inclinado.
## Se dibuja en aditivo: solo aclara la roca, no tapa nada. Sin colisión ni gameplay.

@export var alto := 900.0:
	set(v): alto = v; queue_redraw()
@export var ancho_arriba := 60.0:
	set(v): ancho_arriba = v; queue_redraw()
@export var ancho_abajo := 240.0:
	set(v): ancho_abajo = v; queue_redraw()
@export var inclinacion := 0.12:          ## desplazamiento horizontal por px de caída (+ = hacia la derecha)
	set(v): inclinacion = v; queue_redraw()
@export var haces := 3:                   ## 1 = un solo haz; más = haces finos dentro del principal
	set(v): haces = maxi(1, v); queue_redraw()
@export var color := Color(0.62, 0.86, 0.95, 1.0):
	set(v): color = v; queue_redraw()
@export_range(0.0, 1.0) var opacidad := 0.16:
	set(v): opacidad = v; queue_redraw()
@export_range(0.0, 1.0) var titileo := 0.35      ## cuánto "respira" la luz
@export var velocidad_titileo := 0.45
@export var semilla := 1

var _t := 0.0


func _ready() -> void:
	var m := CanvasItemMaterial.new()
	m.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	material = m
	_t = float(semilla) * 1.7
	queue_redraw()


func _process(delta: float) -> void:
	_t += delta * velocidad_titileo
	var s := 0.5 + 0.5 * sin(_t * TAU + float(semilla))
	var s2 := 0.5 + 0.5 * sin(_t * TAU * 0.37 + float(semilla) * 2.3)
	modulate.a = 1.0 - titileo * (0.6 * s + 0.4 * s2)


func _draw() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = semilla
	var d := alto * inclinacion
	for i in haces:
		# El primero es el haz ancho y tenue; los siguientes son hilos más finos y brillantes.
		var k := 1.0 if i == 0 else rng.randf_range(0.2, 0.45)
		var off := 0.0 if i == 0 else rng.randf_range(-0.3, 0.3)
		var wa := ancho_arriba * k
		var wb := ancho_abajo * k
		var cx_a := off * ancho_arriba
		var cx_b := d + off * ancho_abajo
		var a := opacidad * (1.0 if i == 0 else 0.7)
		var c_top := Color(color.r, color.g, color.b, a)
		var c_bot := Color(color.r, color.g, color.b, 0.0)
		draw_polygon(
			PackedVector2Array([Vector2(cx_a - wa * 0.5, 0), Vector2(cx_a + wa * 0.5, 0),
				Vector2(cx_b + wb * 0.5, alto), Vector2(cx_b - wb * 0.5, alto)]),
			PackedColorArray([c_top, c_top, c_bot, c_bot]))
