@tool
extends Polygon2D
## Una de las 8 puntas de la Estrella: muestra la vida del jefe en el cuerpo (la barra del HUD
## está oculta). `dano` 0..1 dibuja grietas de luz en 3 etapas; `romper()` la desprende.
## El polígono es un triángulo editable: base sobre el núcleo, vértice = la punta.

@export_range(0.0, 1.0, 0.01) var dano := 0.0:
	set(v):
		dano = v
		queue_redraw()
@export var color_grieta := Color(1.0, 0.95, 0.85)
@export var grosor_grieta := 4.0
@export var vertice_local := Vector2.ZERO   ## punta real del dibujo (la cuña texturizada se extiende más allá); 0 = el vértice más lejano

var rota := false
var _pos_base := Vector2.ZERO
var _rot_base := 0.0
var _tw: Tween


func _ready() -> void:
	_pos_base = position
	_rot_base = rotation


## Vértice más lejano del centro de la estrella (de donde salen las lanzas).
func vertice() -> Vector2:
	if vertice_local != Vector2.ZERO:
		return vertice_local
	var mejor := Vector2.ZERO
	for p in polygon:
		if p.length_squared() > mejor.length_squared():
			mejor = p
	return mejor


func romper() -> void:
	if rota:
		return
	rota = true
	dano = 1.0
	var global_punta := to_global(vertice() * 0.6)
	JuiceFx.escombros(get_tree(), global_punta, color, 12, 1.1)
	var cam := get_viewport().get_camera_2d()
	if cam != null and cam.has_method("shake"):
		cam.shake(6.0, 0.2)
	if DisplayServer.get_name() == "headless":
		visible = false
		return
	if _tw != null and _tw.is_valid():
		_tw.kill()
	var hacia := vertice().normalized()
	_tw = create_tween().set_parallel(true)
	_tw.tween_property(self, "position", _pos_base + hacia * 60.0 + Vector2(0, 260), 0.7).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	_tw.tween_property(self, "rotation", _rot_base + (0.9 if hacia.x >= 0.0 else -0.9), 0.7)
	_tw.tween_property(self, "modulate:a", 0.0, 0.7)
	_tw.chain().tween_callback(func() -> void: visible = false)


func restaurar() -> void:
	if _tw != null and _tw.is_valid():
		_tw.kill()
	rota = false
	dano = 0.0
	visible = true
	position = _pos_base
	rotation = _rot_base
	modulate.a = 1.0


func _draw() -> void:
	if dano <= 0.0 or polygon.size() < 3:
		return
	# Grietas desde la base hacia la punta: más ramas y más largas a mayor daño.
	var punta := vertice()
	var base_a := polygon[0] if polygon[0] != punta else polygon[1]
	var base_b := polygon[polygon.size() - 1] if polygon[polygon.size() - 1] != punta else polygon[1]
	var base_c := (base_a + base_b) * 0.5
	var etapas := ceili(dano * 3.0)
	var col := Color(color_grieta.r, color_grieta.g, color_grieta.b, 0.55 + 0.4 * dano)
	for e in etapas:
		var t0 := 0.15 + 0.25 * e
		var desvio := (base_b - base_a).normalized() * (14.0 if e % 2 == 0 else -14.0)
		var p0 := base_c.lerp(punta, t0 * 0.5)
		var p1 := base_c.lerp(punta, t0 + 0.2) + desvio
		var p2 := base_c.lerp(punta, minf(t0 + 0.45 * dano, 0.95)) - desvio * 0.5
		draw_polyline(PackedVector2Array([p0, p1, p2]), col, grosor_grieta * (0.7 + 0.3 * dano), true)
