extends SceneTree
## La zona de daño de los pinchos debe seguir su rotación (antes era un rect horizontal en el centro del nodo:
## en la rampa inclinada del nivel 2 se moría en el aire, lejos de las puntas). También cubre el caso sin rotación.
## godot --headless --path . --script res://tests/diag_pinchos_rotados.gd

var _fallos := 0


func _check(cond: bool, msg: String) -> void:
	if cond:
		print("[PASS] " + msg)
	else:
		_fallos += 1
		print("[FAIL] " + msg)


## ¿Mata el pincho con el centro del hurtbox del jugador en `pt` (coordenadas de mundo)?
func _mata(pin: Area2D, player: Node2D, pt: Vector2) -> bool:
	var csc: CollisionShape2D = null
	for c in player.get_children():
		if c is CollisionShape2D:
			csc = c
			break
	var s: Vector2 = (csc.shape as RectangleShape2D).size if csc.shape is RectangleShape2D else Vector2(
		(csc.shape as CapsuleShape2D).radius * 2.0, (csc.shape as CapsuleShape2D).height)
	var alto_h: float = s.y * pin.hurtbox_alto_jugador
	# El hurtbox ocupa el tramo inferior del collider: se coloca al jugador para que su centro caiga en `pt`.
	player.global_position = Vector2(pt.x - csc.position.x, pt.y + alto_h * 0.5 - csc.position.y - s.y * 0.5)
	return pin._cuerpo_en_zona(player)


func _init() -> void:
	await process_frame
	var nivel: Node = load("res://scenes/nivel2.tscn").instantiate()
	root.add_child(nivel)
	await process_frame
	await process_frame
	var player: Node2D = nivel.get_node("Player")
	var rampa: Area2D = nivel.get_node("Pinchos/Pinchos")   # inclinada (≈27°) y de 39 pinchos de ancho
	_check(absf(rampa.rotation) > 0.3 and rampa.cantidad >= 30, "la rampa del nivel 2 está inclinada y es ancha")
	var kz: Vector2 = rampa._kill_zone_size
	var alto_zona: float = maxf(rampa.alto, 10.0) * rampa.fraccion_zona_dano
	var centro_zona_local := Vector2(0.0, -kz.y + alto_zona * 0.5)   # franja de daño, en el centro del tramo
	for u in [-0.4, 0.0, 0.4]:
		var local := centro_zona_local + Vector2(kz.x * u, 0.0)
		var punta: Vector2 = rampa.to_global(local)
		_check(_mata(rampa, player, punta), "mata sobre las puntas (x local %+d)" % int(local.x))
		var arriba: Vector2 = rampa.to_global(local + Vector2(0.0, -260.0))
		_check(not _mata(rampa, player, arriba), "no mata 260 px por encima de las puntas (x local %+d)" % int(local.x))
		var abajo_aire: Vector2 = rampa.to_global(local + Vector2(0.0, 500.0))
		_check(not _mata(rampa, player, abajo_aire), "no mata 500 px por debajo (x local %+d)" % int(local.x))
	# El caso que se veía en el juego: la línea horizontal que pasa por el centro del nodo (el rect viejo) ya no mata
	# lejos del centro, porque ahí la rampa está muy por encima o por debajo.
	for dx in [-600.0, 600.0]:
		var pt: Vector2 = rampa.global_position + Vector2(dx, centro_zona_local.y)
		_check(not _mata(rampa, player, pt), "no mata en la horizontal del centro, a %+d px (la rampa está %d px más arriba/abajo)" % [int(dx), int(absf(dx) * tan(rampa.rotation))])
	# Sin rotación: igual que antes (zona horizontal centrada en el nodo).
	var plano: Area2D = nivel.get_node("Pinchos/Pinchos12")
	_check(is_zero_approx(plano.rotation), "Pinchos12 sin rotación")
	var kp: Vector2 = plano._kill_zone_size
	var zp: float = maxf(plano.alto, 10.0) * plano.fraccion_zona_dano
	var c_plano := plano.global_position + Vector2(0.0, -kp.y + zp * 0.5)
	_check(_mata(plano, player, c_plano), "sin rotación: mata sobre las puntas")
	_check(not _mata(plano, player, c_plano + Vector2(0.0, -200.0)), "sin rotación: no mata 200 px arriba")
	_check(not _mata(plano, player, c_plano + Vector2(kp.x * 0.5 + 200.0, 0.0)), "sin rotación: no mata 200 px al costado")
	print("DIAG PINCHOS ROTADOS FALLOS = ", _fallos)
	quit()
