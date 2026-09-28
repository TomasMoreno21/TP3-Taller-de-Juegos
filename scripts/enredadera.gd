@tool
extends Area2D

@export var climb_speed: float = 260.0
@export var ancho: float = 32.0:
	set(v):
		ancho = v
		if is_inside_tree():
			_actualizar_visual()
@export var alto: float = 400.0:
	set(v):
		alto = v
		if is_inside_tree():
			_actualizar_visual()
@export var required_form: int = 0
@export var color_hoja := Color(0.28, 0.56, 0.26, 1):
	set(v):
		color_hoja = v
		if is_inside_tree():
			_actualizar_visual()
@export var color_tallo := Color(0.16, 0.38, 0.19, 1):
	set(v):
		color_tallo = v
		if is_inside_tree():
			_actualizar_visual()
@export var color_contorno := Color(0.07, 0.17, 0.10, 1):
	set(v):
		color_contorno = v
		if is_inside_tree():
			_actualizar_visual()
@export var fase := 0.0:  ## desfase del serpenteo del tallo
	set(v):
		fase = v
		if is_inside_tree():
			_actualizar_visual()

func _enter_tree() -> void:
	if Engine.is_editor_hint():
		_actualizar_visual()

func _ready() -> void:
	add_to_group("enredadera")
	collision_layer = 0
	collision_mask = 4
	monitoring = true
	monitorable = true
	_actualizar_visual()

var _t: float = 0.0

func _process(delta: float) -> void:
	if Engine.is_editor_hint() and is_inside_tree():
		var cs := get_node_or_null("Collision") as CollisionShape2D
		if cs and cs.shape is RectangleShape2D:
			if (cs.shape as RectangleShape2D).size != Vector2(ancho, alto):
				_actualizar_visual()
				return
		return
	_t += delta
	var visual := get_node_or_null("Visual") as Node2D
	if visual == null:
		return
	var sway_base := sin(_t * 0.8 + global_position.y * 0.008) * 2.8
	var player := get_tree().get_first_node_in_group("player") as Node2D
	if player != null and player.get("_trepando") and player.get("_enredadera_actual") == self:
		var vy: float = float(player.get("velocity").y) if "velocity" in player else 0.0
		if absf(vy) > 80.0:
			sway_base += sin(_t * 1.8) * 3.2 * clampf(absf(vy) / 320.0, 0.0, 1.0)
	visual.position.x = sway_base

func _actualizar_visual() -> void:
	var cs := get_node_or_null("Collision") as CollisionShape2D
	if cs and cs.shape is RectangleShape2D:
		if not cs.shape.resource_local_to_scene:
			cs.shape = (cs.shape as RectangleShape2D).duplicate()
			cs.shape.resource_local_to_scene = true
		(cs.shape as RectangleShape2D).size = Vector2(ancho, alto)
	var poly := get_node_or_null("Visual/Poly") as Polygon2D
	if poly:
		poly.color = color_contorno
		poly.polygon = _cinta(0.0, maxf(ancho * 0.17, 5.0) + 2.5, 0.0)
	var hojas_root := get_node_or_null("Visual/Hojas") as Node2D
	if hojas_root:
		for c in hojas_root.get_children():
			if Engine.is_editor_hint():
				c.free()
			else:
				c.queue_free()
		var g := maxf(ancho * 0.08, 3.2)
		# Dos hebras trenzadas.
		_agregar(hojas_root, _cinta(1.0, g, 0.0), color_tallo)
		_agregar(hojas_root, _cinta(-1.0, g, PI), color_tallo.lightened(0.18))
		var y := -alto * 0.5 + 34.0
		var i := 0
		while y < alto * 0.5 - 40.0:
			var lado := 1.0 if i % 2 == 0 else -1.0
			var x0 := _desvio(y)
			var largo := (34.0 + float((i * 7) % 5) * 6.0) * (ancho / 32.0) * 0.9 + 6.0
			var col := color_hoja if i % 3 != 0 else color_hoja.darkened(0.22)
			_hoja_completa(hojas_root, Vector2(x0, y), lado, largo, col)
			if i % 3 == 1:  # hoja pareja del otro lado, más chica
				_hoja_completa(hojas_root, Vector2(x0, y + 12.0), -lado, largo * 0.7, col.darkened(0.1))
			if i % 3 == 2:
				_zarcillo(hojas_root, Vector2(x0, y + 8.0), -lado)
			y += 44.0 + float((i * 13) % 4) * 6.0
			i += 1
		# Punta inferior: brote con tres hojitas.
		var yp := alto * 0.5 - 6.0
		var xp := _desvio(yp)
		_hoja_completa(hojas_root, Vector2(xp, yp - 24.0), 1.0, 26.0, color_hoja.lightened(0.1))
		_hoja_completa(hojas_root, Vector2(xp, yp - 24.0), -1.0, 26.0, color_hoja.lightened(0.1))
		_agregar(hojas_root, PackedVector2Array([Vector2(xp - 5, yp - 20), Vector2(xp + 5, yp - 20), Vector2(xp, yp + 8)]), color_tallo.lightened(0.1))


func _agregar(padre: Node2D, puntos: PackedVector2Array, color: Color) -> Polygon2D:
	var p := Polygon2D.new()
	p.polygon = puntos
	p.color = color
	padre.add_child(p)
	return p


## Desvío horizontal del eje del tallo a la altura y (serpentea suave).
func _desvio(y: float) -> float:
	return sin(y * 0.021 + fase + position.x * 0.013) * ancho * 0.14


## Cinta sinuosa a lo largo del tallo. `cruce` (±1) separa las hebras trenzadas
## (oscilan en contrafase); con 0 es el eje recto de contorno.
func _cinta(cruce: float, mitad: float, desfase: float) -> PackedVector2Array:
	var izq := PackedVector2Array()
	var der := PackedVector2Array()
	var y := -alto * 0.5
	while y <= alto * 0.5 + 0.1:
		var x := _desvio(y) + cruce * sin(y * 0.09 + fase + desfase) * ancho * 0.09
		izq.append(Vector2(x - mitad, y))
		der.append(Vector2(x + mitad, y))
		y += 14.0
	der.reverse()
	izq.append_array(der)
	return izq


## Hoja con nervadura: silueta ovalada apuntada + veta clara al centro.
func _hoja_completa(padre: Node2D, base: Vector2, lado: float, largo: float, color: Color) -> void:
	var dir := Vector2(lado, 0.6).normalized()
	var perp := Vector2(-dir.y, dir.x)
	var g := largo * 0.3
	var pts := PackedVector2Array([
		base,
		base + dir * largo * 0.25 + perp * g * 0.8,
		base + dir * largo * 0.6 + perp * g,
		base + dir * largo,
		base + dir * largo * 0.6 - perp * g * 0.9,
		base + dir * largo * 0.25 - perp * g * 0.6,
	])
	_agregar(padre, pts, color)
	var vena := PackedVector2Array([
		base + dir * 2.0 + perp * 0.9, base + dir * largo * 0.92 + perp * 0.4,
		base + dir * largo * 0.92 - perp * 0.4, base + dir * 2.0 - perp * 0.9,
	])
	_agregar(padre, vena, color.lightened(0.38))


## Zarcillo enroscado (espiral corta).
func _zarcillo(padre: Node2D, base: Vector2, lado: float) -> void:
	var l := Line2D.new()
	l.width = 2.2
	l.default_color = color_tallo.lightened(0.1)
	l.joint_mode = Line2D.LINE_JOINT_ROUND
	l.begin_cap_mode = Line2D.LINE_CAP_ROUND
	l.end_cap_mode = Line2D.LINE_CAP_ROUND
	for k in 9:
		var a := float(k) * 0.75
		var r := 3.0 + float(k) * 1.6
		l.add_point(base + Vector2(lado * (float(k) * 3.2 + sin(a) * 2.0), -cos(a) * r * 0.55 + float(k) * 1.4))
	padre.add_child(l)
