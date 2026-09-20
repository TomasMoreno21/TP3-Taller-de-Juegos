extends SceneTree

## Verifica que los enemigos apoyan los pies sobre el piso al activarse, aunque se
## coloquen incrustados (60 px dentro del terreno) o flotando (100 px arriba).

const PISO_Y := 1000.0

var _fallos := 0


func _check(cond: bool, msg: String) -> void:
	if cond:
		print("[PASS] " + msg)
	else:
		_fallos += 1
		print("[FAIL] " + msg)


func _init() -> void:
	var piso := StaticBody2D.new()
	piso.collision_layer = 1
	var cs := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(6000, 400)
	cs.shape = rect
	piso.add_child(cs)
	piso.position = Vector2(0, PISO_Y + 200.0)
	root.add_child(piso)

	var escena: PackedScene = load("res://scenes/enemy.tscn")
	var i := 0
	for tipo in ["cultista", "arquero", "chaman"]:
		for desfase in [60.0, -100.0]:
			var e: Node2D = escena.instantiate()
			e.set("tipo", tipo)
			e.position = Vector2(-1000.0 + 500.0 * i, 0.0)
			root.add_child(e)
			await physics_frame
			var cshape: CollisionShape2D = e.get_node("Collision")
			var pies: float = cshape.position.y + cshape.shape.size.y * 0.5
			e.global_position.y = PISO_Y - pies + desfase
			e.call("preparar_ola")
			await physics_frame
			e.call("activar")
			for f in 40:
				await physics_frame
			var pies_y: float = e.global_position.y + pies
			var etiqueta := "incrustado" if desfase > 0.0 else "flotando"
			_check(absf(pies_y - PISO_Y) <= 2.0, "Spawn %s %s: pies a %.1f px del piso" % [tipo, etiqueta, pies_y - PISO_Y])
			e.queue_free()
			i += 1

	print("[TMP] SPAWN DIAG FIN fallos=", _fallos)
	quit(_fallos)
