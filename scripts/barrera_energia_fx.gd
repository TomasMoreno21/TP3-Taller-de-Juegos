@tool
extends Node2D
## Efecto visual del muro de energía de la barrera: velo con degradado, bordes brillantes, corrientes que
## suben, bandas de luz que barren, motas y chisporroteos eléctricos de vez en cuando. Solo dibuja (sin
## colisión). Se cuelga bajo `Barrera/Visual`, centrado en el muro; todo es editable en el Inspector.

@export var ancho := 220.0:
	set(v):
		ancho = maxf(v, 20.0)
		queue_redraw()
@export var alto := 677.0:
	set(v):
		alto = maxf(v, 40.0)
		queue_redraw()
@export var color_base := Color(0.62, 0.38, 0.88)    ## velo y corrientes
@export var color_luz := Color(0.90, 0.78, 1.0)      ## bordes, núcleos y chispas
@export var corrientes := 8                            ## cintas de energía que suben
@export var velocidad := 70.0                          ## px/s de las corrientes
@export var bandas := 3                                ## bandas horizontales de luz que barren hacia arriba
@export var motas := 18
@export var chispas_cada := 0.9                        ## s entre chisporroteos (0 = sin chispas)
@export var semilla := 5

var _t := 0.0
var _chispa_t := 0.0
var _chispa_vida := 0.0
var _chispa_pts := PackedVector2Array()


func _process(delta: float) -> void:
	_t += delta
	if _chispa_vida > 0.0:
		_chispa_vida -= delta
		if _chispa_vida <= 0.0:
			_chispa_pts = PackedVector2Array()
	if chispas_cada > 0.0:
		_chispa_t -= delta
		if _chispa_t <= 0.0:
			_chispa_t = chispas_cada * randf_range(0.6, 1.5)
			_nueva_chispa()
	queue_redraw()


## Rayo en zigzag de lado a lado a una altura al azar.
func _nueva_chispa() -> void:
	var y0 := randf_range(-alto * 0.45, alto * 0.45)
	_chispa_pts = PackedVector2Array()
	_chispa_vida = 0.12
	var n := 9
	for i in n + 1:
		var x := lerpf(-ancho * 0.5, ancho * 0.5, float(i) / n)
		_chispa_pts.append(Vector2(x, y0 + randf_range(-16.0, 16.0) * (0.0 if i == 0 or i == n else 1.0)))


func _draw() -> void:
	var w := ancho * 0.5
	var h := alto * 0.5
	var c := color_base
	var l := color_luz
	# Velo: más opaco en los bordes y hacia el piso, casi vidrio en el centro.
	var borde := Color(c.r, c.g, c.b, 0.34)
	var medio := Color(c.r, c.g, c.b, 0.10)
	var piso := Color(c.r, c.g, c.b, 0.30)
	var techo := Color(c.r, c.g, c.b, 0.08)
	draw_polygon(PackedVector2Array([Vector2(-w, -h), Vector2(-w * 0.55, -h), Vector2(-w * 0.55, h), Vector2(-w, h)]), PackedColorArray([Color(borde, 0.14), medio, piso, borde]))
	draw_polygon(PackedVector2Array([Vector2(-w * 0.55, -h), Vector2(w * 0.55, -h), Vector2(w * 0.55, h), Vector2(-w * 0.55, h)]), PackedColorArray([techo, techo, piso, piso]))
	draw_polygon(PackedVector2Array([Vector2(w * 0.55, -h), Vector2(w, -h), Vector2(w, h), Vector2(w * 0.55, h)]), PackedColorArray([medio, Color(borde, 0.14), borde, piso]))
	# Corrientes: cintas verticales onduladas que suben y se desvanecen en los extremos.
	var g := RandomNumberGenerator.new()
	g.seed = semilla
	for i in corrientes:
		var x0 := lerpf(-w * 0.85, w * 0.85, (float(i) + 0.5) / corrientes)
		var vel := velocidad * g.randf_range(0.6, 1.4)
		var largo := g.randf_range(120.0, 240.0)
		var fase := g.randf_range(0.0, TAU)
		var ancho_c := g.randf_range(2.5, 6.0)
		var ciclo := alto + largo
		var y_cab := h - fposmod(_t * vel + g.randf_range(0.0, ciclo), ciclo)   # la cabeza sube
		var pasos := 10
		for k in pasos:
			var u0 := float(k) / pasos
			var u1 := float(k + 1) / pasos
			var ya := y_cab + u0 * largo
			var yb := y_cab + u1 * largo
			if yb < -h or ya > h:
				continue
			ya = clampf(ya, -h, h)   # las corrientes no se salen del muro
			yb = clampf(yb, -h, h)
			var xa := x0 + sin(ya * 0.018 + _t * 1.6 + fase) * 7.0
			var xb := x0 + sin(yb * 0.018 + _t * 1.6 + fase) * 7.0
			var aa := sin(u0 * PI) * 0.55
			var ab := sin(u1 * PI) * 0.55
			var ca := Color(l.r, l.g, l.b, aa)
			var cb := Color(l.r, l.g, l.b, ab)
			draw_polygon(PackedVector2Array([Vector2(xa - ancho_c, ya), Vector2(xa + ancho_c, ya), Vector2(xb + ancho_c, yb), Vector2(xb - ancho_c, yb)]), PackedColorArray([ca, ca, cb, cb]))
	# Bandas de luz que barren de abajo hacia arriba.
	for i in bandas:
		var y := h - fposmod(_t * velocidad * 0.9 + float(i) * alto / maxf(bandas, 1), alto)
		var alto_b := 46.0
		var tr := Color(l.r, l.g, l.b, 0.0)
		var cen := Color(l.r, l.g, l.b, 0.20)
		draw_polygon(PackedVector2Array([Vector2(-w, y - alto_b), Vector2(w, y - alto_b), Vector2(w, y), Vector2(-w, y)]), PackedColorArray([tr, tr, cen, cen]))
		draw_polygon(PackedVector2Array([Vector2(-w, y), Vector2(w, y), Vector2(w, y + alto_b * 0.5), Vector2(-w, y + alto_b * 0.5)]), PackedColorArray([cen, cen, tr, tr]))
	# Bordes brillantes (con halo) y remates arriba y abajo.
	for lado: float in [-1.0, 1.0]:
		var x := lado * w
		var pulso := 0.75 + 0.25 * sin(_t * 2.2 + lado)
		draw_line(Vector2(x, -h), Vector2(x, h), Color(l.r, l.g, l.b, 0.85 * pulso), 3.0, true)
		draw_line(Vector2(x - lado * 5.0, -h), Vector2(x - lado * 5.0, h), Color(c.r, c.g, c.b, 0.35 * pulso), 6.0, true)
	draw_line(Vector2(-w, -h), Vector2(w, -h), Color(l.r, l.g, l.b, 0.7), 3.0, true)
	draw_line(Vector2(-w, h), Vector2(w, h), Color(l.r, l.g, l.b, 0.9), 4.0, true)
	# Motas de energía a la deriva.
	for i in motas:
		var s := g.randf_range(0.0, 1000.0)
		var x := lerpf(-w * 0.9, w * 0.9, fposmod(sin(s * 12.9898) * 43758.5453, 1.0))
		var vy := g.randf_range(18.0, 46.0)
		var y := h - fposmod(_t * vy + fposmod(s * 37.0, alto), alto)
		var tt := 0.5 + 0.5 * sin(_t * 3.0 + s)
		draw_circle(Vector2(x + sin(_t + s) * 6.0, y), 1.6 + tt * 1.6, Color(l.r, l.g, l.b, 0.25 + 0.5 * tt))
	# Chisporroteo eléctrico.
	if _chispa_pts.size() > 1:
		draw_polyline(_chispa_pts, Color(c.r, c.g, c.b, 0.55), 7.0, true)
		draw_polyline(_chispa_pts, Color(1.0, 1.0, 1.0, 0.9), 2.2, true)
