extends SceneTree
## Solapes jugador/enemigo: un cultista que aparece encima del jugador o una transformación que agranda el
## collider contra un enemigo pegado NO deben empujar ni teletransportar al jugador (los dos se atraviesan
## hasta separarse).

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


func _enemigo(offset: Vector2) -> CharacterBody2D:
	var e: CharacterBody2D = load("res://scenes/enemy.tscn").instantiate()
	e.tipo = "cultista"
	e.spawn_telegrafiado = false
	_nivel.add_child(e)
	e.global_position = _p.global_position + offset
	return e


func _init() -> void:
	_nivel = load("res://scenes/nivel1.tscn").instantiate()
	root.add_child(_nivel)
	await _esperar(30)
	_p = get_first_node_in_group("player") as CharacterBody2D
	var prog := root.get_node_or_null("Progresion")
	if prog != null:
		prog.formas_forzadas = [0, 1, 2, 3]
	_p.set("_cooldown_transform", 0.0)

	# A) Cultista que aparece exactamente encima del jugador.
	var x0: Vector2 = _p.global_position
	var e := _enemigo(Vector2.ZERO)
	e.activar()
	var max_desv := 0.0
	for i in 40:
		await physics_frame
		max_desv = maxf(max_desv, _p.global_position.distance_to(x0))
	_chk(max_desv < 3.0, "aparecer encima: el jugador se movió %.1f px" % max_desv)
	e.queue_free()
	await _esperar(5)

	# B) Enemigo pegado al costado y transformación a Oso (collider más ancho que el Humano).
	x0 = _p.global_position
	var e2 := _enemigo(Vector2(95, 0))
	e2.activar()
	await _esperar(10)
	x0 = _p.global_position
	var ok_t: bool = _p.call("_transformar", 2, true)
	max_desv = 0.0
	for i in 40:
		await physics_frame
		max_desv = maxf(max_desv, _p.global_position.distance_to(x0))
	_chk(ok_t, "transformar a Oso con un enemigo pegado")
	_chk(max_desv < 3.0, "transformar: el jugador se movió %.1f px" % max_desv)

	# C) Alejarse del enemigo restablece la colisión (sin excepciones colgadas).
	_p.global_position += Vector2(-600, 0)
	await _esperar(5)
	var colgadas := 0
	for ex in _p.get("_exentos_solape"):
		if is_instance_valid(ex):
			colgadas += 1
	_chk(colgadas == 0, "sin excepciones de colisión colgadas (%d)" % colgadas)

	# D) Enemigo metido dentro del jugador (exentos): se despega solo en < 1 s, no se queda adentro.
	e2.queue_free()
	_p.call("_transformar", 0, true)
	await _esperar(20)
	var e3 := _enemigo(Vector2(20, 0))
	e3.activar()
	await _esperar(2)
	e3.global_position = _p.global_position + Vector2(20, 0)
	_p.eximir_solape(e3)
	var t_libre := -1
	for i in 60:
		await physics_frame
		if not (_p.get("_exentos_solape") as Array).has(e3):
			t_libre = i
			break
	_chk(t_libre >= 0, "enemigo encimado se despega solo (frames: %d)" % t_libre)

	print("FALLOS: ", fallos)
	quit(fallos)
