class_name TajoLuz
extends Node2D
## Tajo de luz: hoja roja fina y afilada (núcleo claro, halo rojo) que barre al enemigo en diagonal
## al conectar un golpe. Dura una fracción de segundo y corre en tiempo real (se ve durante el hitstop).

var largo := 320.0
var grosor := 28.0
var color_halo := Color(1, 0.9, 0.4)
var avance := 0.0:        ## punta de la hoja, 0..1 a lo largo del tajo
	set(v):
		avance = v
		queue_redraw()
var cola := 0.0:          ## cola de la hoja: al alcanzar a la punta la hoja desaparece
	set(v):
		cola = v
		queue_redraw()

const PASOS := 14


static func lanzar(padre: Node, pos: Vector2, facing: int, alterno: bool, largo_: float, grosor_: float, color: Color) -> TajoLuz:
	var t := TajoLuz.new()
	t.largo = largo_
	t.grosor = grosor_
	t.color_halo = color
	var ang := deg_to_rad(34.0)
	if alterno:
		ang = -ang
	t.rotation = ang if facing >= 0 else PI - ang
	t.position = pos
	t.z_index = 55
	t.z_as_relative = false
	padre.add_child(t)
	var tw := t.create_tween()
	tw.set_ignore_time_scale(true)
	tw.tween_property(t, "avance", 1.0, 0.05)
	tw.tween_property(t, "cola", 1.0, 0.13).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.tween_callback(t.queue_free)
	return t


func _draw() -> void:
	if cola >= avance:
		return
	_hoja(grosor * 2.2, Color(color_halo.r, color_halo.g, color_halo.b, color_halo.a * 0.6))
	_hoja(grosor, color_halo.lightened(0.55))


## Tira de trapecios (cada uno convexo, sin problemas de triangulación) con grosor máximo al medio.
func _hoja(g: float, c: Color) -> void:
	var u0 := cola
	var u1 := avance
	for i in PASOS:
		var a := lerpf(u0, u1, float(i) / PASOS)
		var b := lerpf(u0, u1, float(i + 1) / PASOS)
		var xa := (a - 0.5) * largo
		var xb := (b - 0.5) * largo
		var ga := g * 0.5 * _perfil(a)
		var gb := g * 0.5 * _perfil(b)
		draw_colored_polygon(PackedVector2Array([
			Vector2(xa, -ga), Vector2(xb, -gb), Vector2(xb, gb), Vector2(xa, ga)]), c)


func _perfil(u: float) -> float:
	return pow(maxf(0.0, 1.0 - absf(u * 2.0 - 1.0)), 0.7)
