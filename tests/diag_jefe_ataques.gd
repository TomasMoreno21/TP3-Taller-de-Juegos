extends SceneTree
## Ataques del Arzobispo: cada uno tiene su respuesta (forma) + valles + parry que devuelve orbes.

var _failures := 0


func _init() -> void:
	var scene = load("res://scenes/nivel_jefe.tscn").instantiate()
	_quitar_dialogos_automaticos(scene)
	root.add_child(scene)
	await process_frame
	await process_frame

	var player = scene.get_node("Player")
	var encounter = get_first_node_in_group("encounter")
	var boss = get_first_node_in_group("boss")
	_check(boss != null and encounter != null and player != null, "La arena carga jefe, encuentro y jugador")
	if boss == null or encounter == null:
		_fin()
		return

	boss._centro_arena = encounter.arena_center.x
	boss._medio_arena = encounter.arena_medio_ancho
	boss._gate = "valle"
	boss._activo = true   # sin _ronda: probamos las piezas sueltas
	boss._medir_suelo()
	player.global_position = Vector2(encounter.arena_center.x, boss._suelo_y - 200)
	await _wait_frames(40)
	print("[info] jugador y=%.0f, suelo y=%.0f, origen del jefe y=%.0f" % [player.global_position.y, boss._suelo_y, boss._piso_y])
	_check(boss._suelo_y < boss._piso_y, "El suelo medido estÃ¡ sobre el origen del jefe")

	# --- Barrido a la altura de la cabeza: Humano y Oso lo sufren, Lobo y MurciÃ©lago pasan por debajo. ---
	var esperado := {0: true, 1: false, 2: true, 3: false}
	var nombres := {0: "Humano", 1: "Lobo", 2: "Oso", 3: "MurciÃ©lago"}
	for f in [0, 1, 2, 3]:
		player._restaurar_forma(f)
		_check(player.current_form == f, "Forma %s activa" % nombres[f])
		await _wait_frames(30)
		player.global_position.x = encounter.arena_center.x
		await _wait_frames(30)
		player.health = player.VIDA_MAX
		player._invuln_timer = 0.0
		var a: Area2D = boss._crear_ataque(Vector2(150.0, boss.barrido_alto), Color.WHITE, 10, 0.0, 0.05)
		a.dir = 1
		a.global_position = Vector2(player.global_position.x, boss._suelo_y - boss.barrido_base - boss.barrido_alto * 0.5)
		boss._agregar_ataque(a)
		await _wait_frames(20)
		var golpeado: bool = a._golpeo   # el flag del propio ataque: la vida puede moverse por otras causas al transformar
		_check(golpeado == esperado[f], "Barrido: %s %s" % [nombres[f], "lo sufre" if esperado[f] else "pasa por debajo"])
		if is_instance_valid(a):
			a.queue_free()

	# --- Onda baja: pega al que estÃ¡ en el piso (se salta). ---
	player._restaurar_forma(0)
	await _wait_frames(30)
	player.health = player.VIDA_MAX
	player._invuln_timer = 0.0
	var onda: Area2D = boss._crear_ataque(Vector2(120.0, 90.0), Color.WHITE, 10, 0.0, 0.05)
	onda.dir = 1
	onda.global_position = Vector2(player.global_position.x, boss._suelo_y - 45.0)
	boss._agregar_ataque(onda)
	await _wait_frames(20)
	_check(player.health < player.VIDA_MAX, "Onda de piso: pega al Humano que no salta")
	onda.queue_free()

	# --- Aviso de ataque: sin daÃ±o durante el aviso. ---
	player.health = player.VIDA_MAX
	player._invuln_timer = 0.0
	var aviso: Area2D = boss._crear_ataque(Vector2(150.0, 200.0), Color.WHITE, 10, 0.0, 5.0)
	aviso.global_position = Vector2(player.global_position.x, boss._suelo_y - 300.0)
	boss._agregar_ataque(aviso)
	await _wait_frames(20)
	_check(player.health == player.VIDA_MAX, "El aviso del ataque no hace daÃ±o")
	aviso.queue_free()

	# --- Aviso mÃ­nimo en fase alta. ---
	boss.fase = 2
	boss._vuelta = 50
	_check(boss._aviso_para(0.9) >= boss.aviso_minimo, "El aviso nunca baja del mÃ­nimo (%.2f)" % boss._aviso_para(0.9))
	boss.fase = 0
	boss._vuelta = 0

	# --- Parry: el orbe devuelto le pega al jefe aunque tenga escudo. ---
	boss._shield_active = true
	var hp0: int = boss.health
	var proj = boss.PROYECTIL_SCENE.instantiate()
	proj.set("enemy_shot", false)
	proj.set("direction", Vector2.UP)
	proj.set("speed", 0.0)
	scene.add_child(proj)
	proj.global_position = boss.global_position + Vector2(0, -120)
	boss._orbes.append(proj)
	await _wait_frames(5)
	_check(boss.health == hp0 - boss.dano_reflejo, "Orbe devuelto con parry quita %d (atraviesa el escudo)" % boss.dano_reflejo)

	# Un orbe enemigo sin devolver no le hace nada al jefe.
	hp0 = boss.health
	var proj2 = boss.PROYECTIL_SCENE.instantiate()
	proj2.set("enemy_shot", true)
	proj2.set("direction", Vector2.UP)
	proj2.set("speed", 0.0)
	scene.add_child(proj2)
	proj2.global_position = boss.global_position + Vector2(0, -120)
	boss._orbes.append(proj2)
	await _wait_frames(5)
	_check(boss.health == hp0, "Un orbe sin devolver no daÃ±a al jefe")
	if is_instance_valid(proj2):
		proj2.queue_free()

	# --- Garra del Oso en la zona: daño doble y cuenta como dos toques. ---
	boss._shield_active = false
	boss._gate = "zona"
	boss._zona_toques = 5
	boss.zona_shape.disabled = false
	hp0 = boss.health
	boss.zona.take_damage(70, 0, 1, false)
	_check(hp0 - boss.health == int(boss.dano_zona * boss.mult_garra), "La Garra (70) en la zona quita %d" % (hp0 - boss.health))
	_check(boss._zona_toques == 3, "La Garra cuenta como dos toques de zona")
	hp0 = boss.health
	boss.zona.take_damage(20, 0, 1, false)
	_check(hp0 - boss.health == boss.dano_zona, "Un golpe común en la zona quita %d" % boss.dano_zona)
	boss._gate = "valle"
	boss._shield_active = true


	# --- Valle: pausa mÃ­nima respetada y cura si la vida estÃ¡ baja. ---
	boss._vuelta = 40   # el descuento por vuelta no puede bajar del mÃ­nimo
	boss._valle_largo = false
	player.health = 20
	var frames := 0
	var t := _valle_contar(boss)
	while not t.listo and frames < 600:
		await physics_frame
		frames += 1
	_check(frames >= int(boss.valle_minimo * 60.0) - 10, "El valle dura al menos el mÃ­nimo (%d frames)" % frames)
	_check(player.health > 20, "El valle cura al jugador con la vida baja (%d)" % player.health)
	_check(boss._gate == "valle", "Durante el valle no hay barrera activa")

	_fin()


class Contador:
	var listo := false


func _valle_contar(boss: Node) -> Contador:
	var c := Contador.new()
	_correr_valle(boss, c)
	return c


func _correr_valle(boss: Node, c: Contador) -> void:
	await boss._valle()
	c.listo = true


func _wait_frames(n: int) -> void:
	for i in range(n):
		await physics_frame


func _quitar_dialogos_automaticos(nodo: Node) -> void:
	for hijo in nodo.get_children():
		_quitar_dialogos_automaticos(hijo)
	var script: Script = nodo.get_script()
	if script != null and script.resource_path == "res://scripts/dialog_trigger.gd":
		nodo.get_parent().remove_child(nodo)
		nodo.free()


func _check(cond: bool, msg: String) -> void:
	if cond:
		print("[PASS] " + msg)
	else:
		print("[FAIL] " + msg)
		_failures += 1


func _fin() -> void:
	print("DIAG JEFE ATAQUES: FALLOS = " + str(_failures))
	if _failures == 0:
		print("DIAG JEFE ATAQUES: OK")
		quit(0)
	else:
		quit(1)

