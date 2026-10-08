class_name OndaTransformacion
extends Node2D
## Estallido de energía desde el jugador: dos aros que se expanden y rayos que salen disparados.
## Corre en tiempo real (se ve aunque el mundo esté congelado).

var color := Color.WHITE
var radio_max := 1400.0
var rayos := 18
var progreso := 0.0:
	set(v):
		progreso = v
		queue_redraw()


static func lanzar(padre: Node, pos: Vector2, color_: Color, radio: float, rayos_: int, duracion: float) -> OndaTransformacion:
	var o := OndaTransformacion.new()
	o.color = color_
	o.radio_max = radio
	o.rayos = rayos_
	o.position = pos
	o.z_index = 50
	o.z_as_relative = false
	padre.add_child(o)
	var tw := o.create_tween()
	tw.set_ignore_time_scale(true)
	tw.tween_property(o, "progreso", 1.0, duracion).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.tween_callback(o.queue_free)
	return o


func _draw() -> void:
	var p := progreso
	var a := 1.0 - p
	# Aros: uno rápido y grueso, otro más tardío.
	_aro(radio_max * p, 26.0 * a + 2.0, Color(1, 1, 1, a))
	_aro(radio_max * 0.7 * clampf(p * 1.3 - 0.1, 0.0, 1.0), 14.0 * a + 1.0, Color(color.r, color.g, color.b, a * 0.9))
	# Rayos: triángulos afilados que se alejan del centro.
	for i in rayos:
		var ang := TAU * float(i) / float(rayos) + 0.17
		var d := Vector2(cos(ang), sin(ang))
		var n := Vector2(-d.y, d.x)
		var r0 := radio_max * 0.12 + radio_max * 0.55 * p
		var r1 := r0 + radio_max * 0.35 * (1.0 - p * 0.6)
		var ancho := 16.0 * a + 1.0
		draw_colored_polygon(PackedVector2Array([d * r0 + n * ancho, d * r1, d * r0 - n * ancho]),
			Color(color.r, color.g, color.b, a * 0.85))


func _aro(radio: float, grosor: float, c: Color) -> void:
	if radio < 2.0 or c.a <= 0.01:
		return
	draw_arc(Vector2.ZERO, radio, 0.0, TAU, 72, c, grosor, true)
