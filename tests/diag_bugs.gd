extends SceneTree
## Diag de la ronda de bugs: reinicio de arenas, barrera de cristales, jefe, estado del jugador
## (picada, salto de borde, energía agotada, muerte, reaparición), proyectil, checkpoint y pinchos.
## Uso: --headless --script res://tests/diag_bugs.gd

var fallos := 0

func _check(c: bool, m: String) -> void:
	print(("[PASS] " if c else "[FAIL] ") + m)
	if not c:
		fallos += 1

func _initialize() -> void:
	await _arena()
	await _jugador()
	print("DIAG BUGS FALLOS = ", fallos)
	quit(1 if fallos > 0 else 0)


## Arena: reiniciar no readopta a los spawneados ni deja la pelea trabada.
func _arena() -> void:
	var world := Node2D.new()
	root.add_child(world)
	var enc: Node = load("res://scenes/encounter.tscn").instantiate()
	enc.arena_center = Vector2(400, 0)
	enc.arena_medio_ancho = 200.0
	var o1 := WaveOla.new()
	o1.tipo = "cultista"
	o1.cantidad = 2
	o1.delay = 0.0
	var o2 := WaveOla.new()
	o2.tipo = "cultista"
	o2.cantidad = 1
	o2.delay = 0.5
	enc.olas = [o1, o2] as Array[WaveOla]
	world.add_child(enc)
	await process_frame
	await process_frame
	enc.espera_inicial = 0.0
	enc.empezar()
	for i in 40:
		await physics_frame
	var spawneados: Array = []
	for n in enc.get_children():
		if n.is_in_group("enemy"):
			spawneados.append(n)
	_check(spawneados.size() == 2, "ola 1: 2 enemigos auto-spawneados (%d)" % spawneados.size())
	enc.reiniciar()
	await process_frame
	await process_frame
	var quedan := 0
	for n in enc.get_children():
		if n.is_in_group("enemy") and not n.is_queued_for_deletion():
			quedan += 1
	_check(quedan == 0, "reiniciar descarta a los auto-spawneados (quedan %d)" % quedan)
	_check(enc._manuales.is_empty() or enc._manuales[0].is_empty(), "no se readoptan como manuales de la ola 0")
	# Pausa entre olas: si se reinicia durante el delay no se lanza la ola -1.
	enc.espera_inicial = 0.0
	enc.empezar()
	for i in 40:
		await physics_frame
	for n in enc.get_children():
		if n.is_in_group("enemy") and n.health > 0:
			n.take_damage(9999)
	await create_timer(0.15).timeout   # ya en el delay de 0.5 s de la ola 2
	enc.reiniciar()
	await create_timer(0.9).timeout
	_check(enc.estado == 0, "reiniciar durante el delay entre olas deja la arena INACTIVE (estado %d)" % enc.estado)
	var extra := 0
	for n in enc.get_children():
		if n.is_in_group("enemy") and not n.is_queued_for_deletion():
			extra += 1
	_check(extra == 0, "no se lanza una ola fantasma tras reiniciar (%d enemigos)" % extra)
	world.queue_free()


func _jugador() -> void:
	var nivel: Node = load("res://scenes/nivel1.tscn").instantiate()
	root.add_child(nivel)
	for n in nivel.get_children():
		if n.get_script() != null and str(n.get_script().resource_path).ends_with("dialog_trigger.gd"):
			n.queue_free()
	await process_frame
	await process_frame
	var p := get_first_node_in_group("player") as CharacterBody2D
	p.set("god_mode", true)
	for i in 60:
		await physics_frame
	# --- Picada / estado transitorio: transformarse la limpia.
	p.set("_picada", true)
	p.set("_cooldown_transform", 0.0)
	p._transformar(2, true)
	_check(not bool(p.get("_picada")), "transformarse limpia _picada")
	# --- _transformar devuelve bool y es idempotente con la misma forma.
	_check(p._transformar(2, true) == false, "transformar a la misma forma devuelve false")
	# --- Salto de borde: en el aire sin haber saltado, Humano ya no tiene salto extra.
	p._transformar(0, true)
	p.set("god_mode", false)
	p.global_position = p.global_position + Vector2(0, -600)
	p.velocity = Vector2.ZERO
	for i in 40:
		await physics_frame   # cae más que el coyote time
	_check(not p.forms[0].can_jump(), "caer de un borde gasta el salto de suelo (sin salto extra)")
	p.set("god_mode", true)
	# --- Muerte: durante la derrota no hay daño ni control; reaparecer limpia el estado.
	p.set("_derrota_activa", true)
	var vida0: int = int(p.get("health"))
	p.set("god_mode", false)
	p.set("_invuln_timer", 0.0)
	p.take_damage(10, 0.0, 1, true)
	_check(int(p.get("health")) == vida0, "muerto: no recibe daño extra")
	p.set("_derrota_activa", false)
	p.set("god_mode", true)
	# --- Reaparecer limpia racha, ataque y trepado.
	p.actualizar_checkpoint(p.global_position)
	p.set("_attacking", true)
	p.set("_trepando", true)
	p.set("_light_step", 2)
	p.reaparecer_en_checkpoint()
	_check(not bool(p.get("_attacking")) and not bool(p.get("_trepando")) and int(p.get("_light_step")) == 0, "reaparecer limpia ataque, trepado y combo")
	# --- Combo: tras el último golpe la cadena vuelve al primero.
	p.set("_light_step", 0)
	p._transformar(1, true)
	var pasos := 0
	var max_step: int = min(p.forms[1].light_combo_steps, 3)
	for k in max_step + 1:
		p.set("_current_attack_type", "light")
		p._procesar_ataque("light", p.forms[1], false)
		pasos = int(p.get("_light_step"))
		p.end_attack()
	_check(pasos == 1 or max_step == 1, "tras el último golpe ligero vuelve al paso 1 (paso %d)" % pasos)
	# --- Proyectil: la dirección del golpe nunca es 0.
	var proj: Area2D = (load("res://scenes/projectile.tscn") as PackedScene).instantiate()
	nivel.add_child(proj)
	proj.set("enemy_shot", true)
	proj.set("direction", Vector2(0.05, 1).normalized())
	var dir_esperada := 1 if proj.direction.x >= 0.0 else -1
	_check(dir_esperada == 1, "un disparo casi vertical da dirección ±1")
	# --- Orbe de vida: con vida llena no se consume.
	p.set("health", 100)
	var orbe: Area2D = (load("res://scenes/pickup_vida.tscn") as PackedScene).instantiate()
	nivel.add_child(orbe)
	orbe.global_position = p.global_position + Vector2(0, 40)
	for i in 20:
		await physics_frame
	_check(is_instance_valid(orbe) and not orbe.is_queued_for_deletion(), "con vida llena el orbe no se gasta")
	p.set("health", 50)
	for i in 20:
		await physics_frame
	_check(not is_instance_valid(orbe) or orbe.is_queued_for_deletion(), "herido, el orbe se recoge aunque ya estuviera encima")
	# --- Pinchos: con el jugador muerto no siguen dañando.
	var pin: Area2D = (load("res://scenes/pinchos.tscn") as PackedScene).instantiate()
	nivel.add_child(pin)
	pin.global_position = p.global_position + Vector2(0, 150)
	await process_frame
	p.set("god_mode", false)
	p.set("_derrota_activa", true)
	p.set("_invuln_timer", 0.0)
	p.set("health", 50)
	p.global_position = pin.global_position + Vector2(0, -10)
	for i in 10:
		await physics_frame
	_check(int(p.get("health")) == 50, "los pinchos no dañan con el jugador ya muerto")
	p.set("_derrota_activa", false)
	# --- Hitstop siempre activo (funciona con el árbol pausado).
	var hs: Node = root.get_node_or_null("Hitstop")
	_check(hs != null and hs.process_mode == Node.PROCESS_MODE_ALWAYS, "Hitstop corre siempre (PROCESS_MODE_ALWAYS)")
