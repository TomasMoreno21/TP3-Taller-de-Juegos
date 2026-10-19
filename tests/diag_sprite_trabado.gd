extends SceneTree
## Sprite del jugador visible tras quedar pegado a un enemigo en el nivel del jefe (todas las formas).

var fallos := 0
var _nivel: Node
var _p: CharacterBody2D


func _chk(ok: bool, msg: String) -> void:
	if ok:
		print("ok   ", msg)
	else:
		fallos += 1
		print("FAIL ", msg)


func _esperar(n: int) -> void:
	for i in n:
		await physics_frame


func _estado(etq: String) -> void:
	var v: Node2D = _p.get("visual")
	print(etq, " visible=", v.visible, " en_arbol=", v.is_visible_in_tree(), " mod=", v.modulate, " self_mod=", v.self_modulate,
		" pos=", v.position, " scale=", v.scale, " invuln=", _p.get("_invuln_timer"), " sin_parp=", _p.get("_invuln_sin_parpadeo"))


func _init() -> void:
	_nivel = load("res://scenes/nivel_jefe.tscn").instantiate()
	root.add_child(_nivel)
	await _esperar(40)
	_p = get_first_node_in_group("player") as CharacterBody2D
	var prog := root.get_node_or_null("Progresion")
	if prog != null:
		prog.formas_forzadas = [0, 1, 2, 3]
	_p.set("_cooldown_transform", 0.0)
	_p.set("energia", 100.0)
	_estado("inicio")

	for forma in [0, 1, 2, 3]:
		_p.call("_transformar", forma, true)
		await _esperar(10)
		var e: CharacterBody2D = load("res://scenes/enemy.tscn").instantiate()
		e.tipo = "cultista"
		e.spawn_telegrafiado = false
		_nivel.add_child(e)
		e.global_position = _p.global_position + Vector2(40, 0)
		e.activar()
		var oculto := 0
		for i in 240:
			await physics_frame
			var v: Node2D = _p.get("visual")
			if not v.is_visible_in_tree() or v.modulate.a < 0.5:
				oculto += 1
		_estado("forma %d" % forma)
		_chk(oculto < 120, "forma %d: sprite oculto %d/240 frames" % [forma, oculto])
		e.queue_free()
		await _esperar(10)

	# Estado de suavizado envenenado con NaN (colisión degenerada): el sprite debe recuperarse solo.
	var v: Node2D = _p.get("visual")
	for campo in ["_suave_s", "_hundido_rampa", "_suave_entero"]:
		_p.set(campo, NAN)
		await _esperar(10)
		_chk(is_finite(v.position.y) and is_finite(_p.get("_suave_s")), "recupera el sprite tras NaN en %s (y=%s)" % [campo, v.position.y])

	print("FALLOS: ", fallos)
	quit(fallos)
