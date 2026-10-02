extends Node2D
## Aura mística bajo un enemigo flotante: anillos que laten, runas que giran y motas que suben.
## Todo editable desde el Inspector; se dibuja en perspectiva (elipses aplastadas) y en aditivo.

@export var color := Color(0.6, 0.45, 1.0)
@export var radio := 90.0
@export var aplastado := 0.28          ## alto/ancho de las elipses (perspectiva)
@export var runas := 6
@export var velocidad_giro := 0.9      ## vueltas/s de las runas
@export var latido := 1.6              ## rad/s del pulso de los anillos
@export var motas := 10                ## partículas que suben (0 = sin partículas)
@export var altura_motas := 200.0

var _t := randf() * TAU


func _ready() -> void:
	var mat := CanvasItemMaterial.new()
	mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	mat.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
	material = mat
	if motas > 0 and DisplayServer.get_name() != "headless":
		var p := CPUParticles2D.new()
		p.amount = motas
		p.lifetime = 1.6
		p.emission_shape = CPUParticles2D.EMISSION_SHAPE_SPHERE
		p.emission_sphere_radius = radio * 0.6
		p.direction = Vector2(0, -1)
		p.spread = 8.0
		p.gravity = Vector2.ZERO
		p.initial_velocity_min = altura_motas / 1.6 * 0.6
		p.initial_velocity_max = altura_motas / 1.6
		p.scale_amount_min = 3.0
		p.scale_amount_max = 6.0
		var g := Gradient.new()
		g.set_color(0, Color(color, 0.9))
		g.set_color(1, Color(color, 0.0))
		p.color_ramp = g
		add_child(p)


func _process(delta: float) -> void:
	_t += delta
	queue_redraw()


func _elipse(r: float, c: Color, ancho: float) -> void:
	var pts := PackedVector2Array()
	for i in 33:
		var a := TAU * float(i) / 32.0
		pts.append(Vector2(cos(a) * r, sin(a) * r * aplastado))
	draw_polyline(pts, c, ancho, true)


func _draw() -> void:
	var pulso := 0.5 + 0.5 * sin(_t * latido)
	# Resplandor de base
	for k in 4:
		var r := radio * (1.15 - 0.22 * k)
		var pts := PackedVector2Array()
		for i in 24:
			var a := TAU * float(i) / 24.0
			pts.append(Vector2(cos(a) * r, sin(a) * r * aplastado))
		draw_colored_polygon(pts, Color(color, 0.06 + 0.02 * pulso))
	# Anillos
	_elipse(radio, Color(color, 0.55 + 0.3 * pulso), 3.0)
	_elipse(radio * (0.62 + 0.08 * pulso), Color(color, 0.8), 2.0)
	# Runas girando sobre el anillo exterior
	for i in runas:
		var a := _t * velocidad_giro * TAU + TAU * float(i) / float(runas)
		var base := Vector2(cos(a) * radio, sin(a) * radio * aplastado)
		var h := 6.0 + 10.0 * (0.5 + 0.5 * sin(_t * 3.0 + i))
		draw_line(base, base + Vector2(0.0, -h), Color(color, 0.9), 3.0, true)
		draw_circle(base + Vector2(0.0, -h), 3.0, Color(1, 1, 1, 0.8))
