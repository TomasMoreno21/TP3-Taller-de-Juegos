@tool
extends Node2D

## Vena luminosa en la pared de la cueva: late con el corazón (latido_cueva.gd, grupo "latido_cueva").
## `puntos` son locales a este nodo (editables en el Inspector). Brilla más cuanto más intensa es la zona.

@export var puntos := PackedVector2Array([Vector2.ZERO, Vector2(90, 40), Vector2(170, 20)]):
	set(v):
		puntos = v
		queue_redraw()
@export var ancho := 6.0:
	set(v):
		ancho = v
		queue_redraw()
@export var color := Color(0.78, 0.45, 1.0):
	set(v):
		color = v
		queue_redraw()
@export_range(0.0, 1.0, 0.01) var brillo_base := 0.22   ## brillo en reposo
@export_range(0.0, 3.0, 0.05) var fuerza_latido := 1.0   ## cuánto se enciende en cada latido

var _latido: Node


func _ready() -> void:
	var m := CanvasItemMaterial.new()
	m.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	material = m
	if Engine.is_editor_hint():
		modulate.a = 0.8
	else:
		modulate.a = brillo_base


func _process(_delta: float) -> void:
	if Engine.is_editor_hint():
		return
	if not is_instance_valid(_latido):
		_latido = get_tree().get_first_node_in_group("latido_cueva")
		if _latido == null:
			return
	var k := clampf(float(_latido.intensidad_actual()) * 6.0, 0.0, 1.0)
	modulate.a = clampf(brillo_base + float(_latido.pulso_actual()) * k * fuerza_latido, 0.0, 1.0)


func _draw() -> void:
	var n := puntos.size()
	for i in range(n - 1):
		var t := float(i) / float(maxi(n - 1, 1))
		var w := ancho * lerpf(1.0, 0.35, t)
		var a := puntos[i]
		var b := puntos[i + 1]
		draw_line(a, b, Color(color.r, color.g, color.b, 0.16), w * 3.2, true)
		draw_line(a, b, Color(color.r, color.g, color.b, 0.45), w * 1.6, true)
		draw_line(a, b, Color(1.0, 0.85, 1.0, 0.9), w * 0.55, true)
	for i in n:
		var t2 := float(i) / float(maxi(n - 1, 1))
		draw_circle(puntos[i], ancho * lerpf(0.9, 0.3, t2), Color(color.r, color.g, color.b, 0.5))
