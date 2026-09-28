@tool
class_name PrimerPlano
extends CanvasGroup
## Grupo de primer plano: siluetas casi negras ENTRE la cámara y el jugador.
## - Paralaje: se mueve más rápido que el mundo (profundidad > 1). Su posición en
##   el editor es donde aparece cuando la cámara está centrada en él.
## - Si tapa al jugador o a un enemigo, se vuelve translúcido para no esconder
##   la acción. Es CanvasGroup: el alfa se aplica al conjunto (sin solapes).
## Hijos típicos: decorativo.tscn (TRONCO_FRENTE, RAMA_COLGANTE, PASTO_ALTO,
## ARBUSTO...) y bancos de niebla.

@export var profundidad := 1.35              ## >1 = más cerca de la cámara (se mueve más rápido)
@export var profundidad_vertical := 1.0      ## 1 = sigue la altura del mundo
@export_range(0.0, 1.0) var alfa_tapando := 0.3
@export var velocidad_fundido := 4.0         ## qué tan rápido se aclara / vuelve
@export var distancia_activa := 3200.0       ## px: más lejos de la cámara no se procesa

var _ancla := Vector2.ZERO
var _alfa := 1.0
var _rect_local := Rect2()


func _ready() -> void:
	_ancla = global_position
	if not Engine.is_editor_hint():
		_calcular_rect.call_deferred()


func _process(delta: float) -> void:
	if Engine.is_editor_hint():
		return
	var cam := get_viewport().get_camera_2d()
	if cam == null:
		return
	var c := cam.get_screen_center_position()
	if absf(_ancla.x - c.x) > distancia_activa * maxf(profundidad, 1.0):
		return
	global_position = Vector2(c.x + (_ancla.x - c.x) * profundidad, c.y + (_ancla.y - c.y) * profundidad_vertical)
	var tapa := _tapa_algo()
	_alfa = move_toward(_alfa, alfa_tapando if tapa else 1.0, delta * velocidad_fundido)
	self_modulate.a = _alfa


## Rectángulo (local) que ocupan los polígonos hijos, para detectar si tapan.
func _calcular_rect() -> void:
	var r := Rect2()
	var primero := true
	for p in find_children("*", "Polygon2D", true, false):
		var pol := p as Polygon2D
		if pol.polygon.is_empty() or not pol.is_visible_in_tree():
			continue
		var xf := global_transform.affine_inverse() * pol.global_transform
		for v in pol.polygon:
			var q := xf * v
			if primero:
				r = Rect2(q, Vector2.ZERO)
				primero = false
			else:
				r = r.expand(q)
	_rect_local = r


func _tapa_algo() -> bool:
	if _rect_local.size == Vector2.ZERO:
		return false
	var mio := Rect2(global_position + _rect_local.position, _rect_local.size)
	for grupo in ["player", "enemy"]:
		for n in get_tree().get_nodes_in_group(grupo):
			var cuerpo := _rect_cuerpo(n)
			if cuerpo.size != Vector2.ZERO and mio.intersects(cuerpo):
				return true
	return false


func _rect_cuerpo(n: Node) -> Rect2:
	for c in n.get_children():
		if c is CollisionShape2D and (c as CollisionShape2D).shape != null:
			return (c as CollisionShape2D).global_transform * (c as CollisionShape2D).shape.get_rect()
	return Rect2()
