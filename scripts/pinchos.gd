extends Area2D
## Pinchos modulares: matan de un toque al jugador.
## Colocá varios o ajustá `cantidad`/`ancho` para cubrir la franja que necesites.

@export var cantidad := 4       # cuántos pinchos en fila (modular)
@export var ancho_pincho := 40.0 # ancho de cada pincho (px)
@export var alto := 32.0         # altura del pincho desde la base (px)
@export var dano := 9999         # daño al tocar (por defecto mata de un toque)

var _kill_zone_size := Vector2.ZERO
var _hit_cd := 0.0


func _ready() -> void:
	add_to_group("pinchos")
	collision_layer = 0
	collision_mask = 4
	_dibujar()


func _physics_process(delta: float) -> void:
	if _hit_cd > 0.0:
		_hit_cd -= delta
	var player: Node2D = get_tree().get_first_node_in_group("player")
	if player == null or _hit_cd > 0.0:
		return
	if _cuerpo_en_zona(player):
		# Al golpear saltamos el cooldown para no repetir el daño cada frame.
		_hit_cd = 0.15 if dano < 9999 else 0.0
		player.take_damage(dano, 0.0, 0)


## Superpone el rect del collider del body con el área de daño (determinista,
## sin depender del monitoreo del Area2D que no re-barre al re-dibujar).
func _cuerpo_en_zona(body: Node2D) -> bool:
	var csc := _csc_de(body)
	if csc == null or csc.shape == null:
		return false
	var s: Vector2
	if csc.shape is RectangleShape2D:
		s = csc.shape.size
	elif csc.shape is CapsuleShape2D:
		s = Vector2(csc.shape.radius * 2.0, csc.shape.height)
	else:
		return false
	var rect_body := Rect2(body.global_position + csc.position - s * 0.5, s)
	var alto_zona := _kill_zone_size.y + 46.0
	var rect_zona := Rect2(
		global_position.x - _kill_zone_size.x * 0.5,
		global_position.y - alto_zona,
		_kill_zone_size.x,
		alto_zona
	)
	return rect_zona.intersects(rect_body)


func _csc_de(body: Node2D) -> CollisionShape2D:
	for child in body.get_children():
		if child is CollisionShape2D:
			return child
	return null


func _dibujar() -> void:
	_kill_zone_size = Vector2(maxf(cantidad * ancho_pincho, 10.0), maxf(alto, 10.0))
	# Collider visible/depurable (no se usa para detección, pero ayuda a ver el área)
	var killzone: Node2D = get_node_or_null("KillZone")
	if killzone != null:
		for c in killzone.get_children():
			killzone.remove_child(c)
			c.queue_free()
		var nuevo := CollisionShape2D.new()
		var sh := RectangleShape2D.new()
		sh.size = Vector2(_kill_zone_size.x, _kill_zone_size.y + 46.0)
		nuevo.shape = sh
		nuevo.position = Vector2(0, -(_kill_zone_size.y + 46.0) * 0.5)
		nuevo.name = "Collision"
		killzone.add_child(nuevo)
	# Dibujar los pinchos triangulares
	var visual: Node2D = get_node_or_null("Visual")
	if visual == null:
		return
	for child in visual.get_children():
		child.queue_free()
	for i in range(int(cantidad)):
		var p := Polygon2D.new()
		var cx := -_kill_zone_size.x * 0.5 + (i + 0.5) * ancho_pincho
		p.color = Color(0.72, 0.74, 0.8)
		p.position = Vector2(cx, 0)
		p.polygon = PackedVector2Array([
			Vector2(ancho_pincho * -0.5, 0),
			Vector2(ancho_pincho * 0.5, 0),
			Vector2(0, -alto),
		])
		visual.add_child(p)