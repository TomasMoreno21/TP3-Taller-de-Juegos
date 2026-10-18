@tool
class_name CirculoProteccion
extends Node2D
## Círculo de protección: aro con 6 remaches y un ícono arriba que dice qué forma lo resuelve
## ("oso" = zarpa: solo el Oso lo rompe; "murcielago" = el sónico del Murciélago lo cierra).
## `dibujar()` es la única receta del aro: la usan este nodo y los ojos verdes (se ven idénticos).

@export var encendido := false:
	set(v):
		if v == encendido:
			return
		encendido = v
		visible = v
		if v:
			scale = Vector2.ONE
			modulate.a = 1.0
		queue_redraw()
@export var radio := 120.0:
	set(v):
		radio = v
		queue_redraw()
@export var color := Color(0.55, 0.55, 0.6):
	set(v):
		color = v
		queue_redraw()
@export_enum("oso", "murcielago") var icono := "oso":
	set(v):
		icono = v
		queue_redraw()

var _tw: Tween
var rompiendo := false   # animación de rotura en curso (no apagarlo de golpe)


func _ready() -> void:
	visible = encendido


## El aro se agranda, se desvanece y suelta chispas (lo rompió el golpe correcto).
func romper() -> void:
	if not encendido:
		return
	Burst.emitir(self, global_position, color.lightened(0.3), 14, 1.0)
	if DisplayServer.get_name() == "headless":
		encendido = false
		return
	rompiendo = true
	if _tw != null and _tw.is_valid():
		_tw.kill()
	_tw = create_tween().set_parallel(true)
	_tw.tween_property(self, "scale", Vector2.ONE * 1.35, 0.25).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_tw.tween_property(self, "modulate:a", 0.0, 0.25)
	_tw.chain().tween_callback(func() -> void:
		rompiendo = false
		encendido = false)


## Golpe que no alcanza (otra forma): el aro tiembla.
func rebote() -> void:
	if not encendido or DisplayServer.get_name() == "headless":
		return
	if _tw != null and _tw.is_valid():
		_tw.kill()
	_tw = create_tween()
	_tw.tween_property(self, "scale", Vector2(1.12, 0.9), 0.05)
	_tw.tween_property(self, "scale", Vector2.ONE, 0.1)


func _draw() -> void:
	if encendido:
		dibujar(self, Vector2.ZERO, radio, color, icono)


## Aro de protección centrado en `c`, con el ícono de la forma arriba.
static func dibujar(ci: CanvasItem, c: Vector2, r: float, col: Color, ico: String) -> void:
	ci.draw_arc(c, r, 0.0, TAU, 28, col, 9.0, true)
	for i in 6:
		var a := TAU * float(i) / 6.0
		ci.draw_circle(c + Vector2(cos(a), sin(a)) * r, 6.0, col.lightened(0.3))
	var claro := col.lightened(0.45)
	var t := c + Vector2(0, -r - 26.0)
	if ico == "murcielago":
		# Murciélago: cuerpo + alas en zigzag.
		ci.draw_colored_polygon(PackedVector2Array([
			t + Vector2(-30, -8), t + Vector2(-18, -2), t + Vector2(-12, 6), t + Vector2(-6, 2),
			t + Vector2(0, 10), t + Vector2(6, 2), t + Vector2(12, 6), t + Vector2(18, -2),
			t + Vector2(30, -8), t + Vector2(14, -10), t + Vector2(5, -6), t + Vector2(0, -12),
			t + Vector2(-5, -6), t + Vector2(-14, -10)]), claro)
	else:
		# Zarpa del Oso: almohadilla + 3 dedos.
		ci.draw_circle(t + Vector2(0, 6), 11.0, claro)
		for dx in [-13.0, 0.0, 13.0]:
			ci.draw_circle(t + Vector2(dx, -10.0 - (3.0 if dx == 0.0 else 0.0)), 5.0, claro)
