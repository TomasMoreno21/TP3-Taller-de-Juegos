extends SceneTree
## (Usa un jugador simulado: el evento solo necesita un nodo del grupo "player" con take_damage.)
## Derrumbe: ritmo del shake (antes constante), daño de las rocas dirigidas, aviso con grieta, sonido de
## impactos y cierre del evento (retumbo apagado, sin más sacudidas).

class _Cam extends Camera2D:
	var golpes: Array[float] = []
	var t_ult := 0.0
	func shake(f: float, _d = 0.0, _a = null, _b = null) -> void:
		golpes.append(f)
		t_ult = Time.get_ticks_msec() / 1000.0
	func fijar_zoom(_a = null, _b = null) -> void:
		pass

class _Jugador extends CharacterBody2D:
	var health := 100
	func _ready() -> void:
		add_to_group("player")
	func take_damage(cant: int, kb: float = 0.0, dir: int = 1, _ign: bool = false) -> void:
		health -= cant
		velocity.x = dir * kb

var fallos := 0

func _chk(ok: bool, msg: String) -> void:
	if ok:
		print("ok   ", msg)
	else:
		fallos += 1
		print("FAIL ", msg)


func _mundo() -> Dictionary:
	var raiz := Node2D.new()
	root.add_child(raiz)
	var suelo := StaticBody2D.new()
	var cs := CollisionShape2D.new()
	var r := RectangleShape2D.new()
	r.size = Vector2(20000, 200)
	cs.shape = r
	suelo.add_child(cs)
	suelo.position = Vector2(3000, 700)
	raiz.add_child(suelo)
	var techo := StaticBody2D.new()
	var ct := CollisionShape2D.new()
	var rt := RectangleShape2D.new()
	rt.size = Vector2(20000, 100)
	ct.shape = rt
	techo.add_child(ct)
	techo.position = Vector2(3000, 50)
	raiz.add_child(techo)
	var cam := _Cam.new()
	raiz.add_child(cam)
	cam.make_current()
	var fin := Marker2D.new()
	fin.position = Vector2(9000, 600)
	raiz.add_child(fin)
	var ev: Node2D = load(OS.get_environment("DERR") if OS.get_environment("DERR") != "" else "res://scripts/derrumbe_evento.gd").new()
	ev.set("fin", fin)
	raiz.add_child(ev)
	var p := _Jugador.new()
	p.position = Vector2(1000, 560)
	raiz.add_child(p)
	return {"raiz": raiz, "cam": cam, "ev": ev, "p": p, "fin": fin}


func _ritmo(constante: bool) -> Array:
	var m := _mundo()
	var ev: Node2D = m["ev"]
	var cam = m["cam"]
	ev.set("rocas_dirigidas", false)   # solo se mide el ritmo propio del evento (las rocas meten su shake)
	if constante:
		ev.set("shake_valle", 1.0)
		ev.set("shake_pico", 1.0)
		ev.set("subida_s", 0.0)
	for i in 30:
		await physics_frame
	cam.golpes.clear()
	ev.call("iniciar")
	var dim_max := 0.0
	for i in 600:
		await physics_frame
		dim_max = maxf(dim_max, float(ev.get("_dim")))
	var mn := 1e9
	var mx := 0.0
	for g in cam.golpes:
		mn = minf(mn, g)
		mx = maxf(mx, g)
	var res := [mn, mx, cam.golpes.size(), dim_max]
	m["raiz"].queue_free()
	await physics_frame
	return res



## `fin_por_altura` vale para bajar (final más abajo que el arranque) y para trepar (final más arriba).
func _direccion(fin_y: float, y_cruce: float, nombre: String) -> void:
	var m := _mundo()
	var ev: Node2D = m["ev"]
	var p: Node2D = m["p"]
	var fin: Marker2D = m["fin"]
	ev.set("fin_por_altura", true)
	fin.position = Vector2(9000.0, fin_y)
	for i in 30:
		await physics_frame
	ev.call("iniciar")
	for i in 40:
		await physics_frame
	var activo_al_arrancar := bool(ev.get("_activo"))
	p.global_position.y = y_cruce
	for i in 20:
		await physics_frame
	_chk(activo_al_arrancar and bool(ev.get("_terminado")), "%s: arranca en el punto de partida y termina al cruzar la y del final" % nombre)
	m["raiz"].queue_free()
	await physics_frame

func _initialize() -> void:
	# 1) Ritmo del shake: antes constante (18), ahora con valles y picos
	var antes: Array = await _ritmo(true)
	var ahora: Array = await _ritmo(false)
	print("shake plano (valle=pico=1): min %.1f  max %.1f  (%d sacudidas)" % [antes[0], antes[1], antes[2]])
	print("shake con ritmo:        min %.1f  max %.1f  (%d sacudidas)" % [ahora[0], ahora[1], ahora[2]])
	_chk(ahora[3] >= 0.1, "cada oleada oscurece la pantalla un instante (max %.2f)" % ahora[3])
	_chk(ahora[1] / maxf(ahora[0], 0.01) >= 1.8, "ahora: el shake varía (pico/valle = %.1f)" % (ahora[1] / maxf(ahora[0], 0.01)))

	# 2) Rocas dirigidas, aviso con grieta, sonido y cierre del evento
	var m := _mundo()
	var ev: Node2D = m["ev"]
	var p: CharacterBody2D = m["p"]
	var raiz: Node2D = m["raiz"]
	var cam = m["cam"]
	for i in 40:
		await physics_frame
	ev.set("rocas_dirigidas", false)   # solo caen las que se lanzan a mano
	ev.call("iniciar")
	for i in 10:
		await physics_frame
	var vida0: int = p.health
	ev.call("_caer_roca_dirigida", {"x": p.global_position.x + 600.0, "techo": 100.0})
	for i in 60:
		await physics_frame
	_chk(p.health == vida0, "una roca que cae a 600 px no lastima")
	var hijos0 := raiz.get_child_count()
	ev.call("_roca_dirigida")
	await physics_frame
	_chk(raiz.get_child_count() >= hijos0 + 2, "el aviso crea sombra y grieta (+%d nodos)" % (raiz.get_child_count() - hijos0))
	var vida1: int = p.health
	ev.call("_caer_roca_dirigida", {"x": p.global_position.x, "techo": 100.0})
	for i in 90:
		await physics_frame
	_chk(p.health < vida1, "una roca sobre el jugador lo lastima (vida %d → %d)" % [vida1, p.health])
	var am := root.get_node_or_null("AudioManager")
	if am != null:
		var n0 := am.get_child_count()
		ev.call("sonar_impacto", p.global_position, true)
		_chk(am.get_child_count() > n0, "un impacto grande suena")
	# Feedback: empuje al recibir una roca, "casi me da" y tope de escombros
	p.velocity = Vector2.ZERO
	ev.call("_caer_roca_dirigida", {"x": p.global_position.x - 20.0, "techo": 100.0})
	var empujado := false
	for i in 90:
		await physics_frame
		if p.velocity.x > 100.0:
			empujado = true
			break
	_chk(empujado, "la roca empuja al jugador lejos del impacto (vx=%.0f)" % p.velocity.x)
	var vida2: int = p.health
	var g0: int = cam.golpes.size()
	ev.call("_caer_roca_dirigida", {"x": p.global_position.x + 150.0, "techo": 100.0})
	for i in 90:
		await physics_frame
	var casi := false
	for k in range(g0, cam.golpes.size()):
		if absf(cam.golpes[k] - float(ev.get("fuerza_shake")) * 0.75) < 0.01:
			casi = true
	_chk(p.health == vida2 and casi, "una roca que cae cerca sin tocarte da sacudida extra (casi golpe)")
	ev.set("max_escombros", 20)
	for i in 80:
		ev.call("_soltar_escombro", 9.0, 26.0, true)
	await physics_frame
	_chk(int(ev.get("_vivos")) <= 20 + 30, "el tope limita los escombros sueltos (%d vivos)" % int(ev.get("_vivos")))
	ev.set("max_escombros", 90)
	var polvo: CPUParticles2D = ev.get("_polvo")
	_chk(polvo.emitting, "hay polvo en suspensión mientras dura el derrumbe")
	var retumbo: AudioStreamPlayer = ev.get("_retumbo")
	_chk(retumbo.playing, "el retumbo de fondo suena mientras dura el derrumbe")

	# Presión: quieto sube (sombra y retumbo), avanzando baja; los escombros caen sobre todo detrás
	p.velocity = Vector2.ZERO
	for i in 120:
		await physics_frame
	var pres_quieto: float = ev.get("_presion")
	var sombra: TextureRect = ev.get("_sombra")
	var a_quieto := sombra.modulate.a
	p.velocity = Vector2(250, 0)
	for i in 120:
		p.velocity.x = 250.0
		await physics_frame
	_chk(pres_quieto > 0.8 and float(ev.get("_presion")) < 0.2, "la presión sube quieto (%.2f) y baja al avanzar (%.2f)" % [pres_quieto, float(ev.get("_presion"))])
	_chk(a_quieto > sombra.modulate.a + 0.1, "la penumbra de atrás se intensifica al frenarte (%.2f → %.2f)" % [a_quieto, sombra.modulate.a])
	var atras := 0
	var xs0: float = p.global_position.x
	for i in 60:
		ev.call("_soltar_escombro", 9.0, 26.0, false)
	for n in raiz.get_children():
		if n.get_script() != null and n.get("vel") != null and n != ev and n.global_position.x < xs0:
			atras += 1
	_chk(atras >= 30, "la mayoría de los escombros cae detrás del jugador (%d de ~60)" % atras)

	# Cierre: el jugador pasa el final
	p.global_position.x = 9100.0
	for i in 30:
		await physics_frame
	_chk(bool(ev.get("_terminado")) and not bool(ev.get("_activo")), "al pasar el final el evento termina")
	for i in 240:
		await physics_frame
	_chk(not retumbo.playing, "el retumbo se apagó tras el cierre")
	var n_golpes: int = cam.golpes.size()
	for i in 180:
		await physics_frame
	_chk(cam.golpes.size() == n_golpes, "ya no hay sacudidas después del cierre")
	_chk(not polvo.emitting, "al terminar deja de salir polvo nuevo")
	raiz.queue_free()   # que el jugador simulado de este mundo no se cuele en los siguientes
	await physics_frame
	await _direccion(300.0, 250.0, "trepada (final más arriba)")
	await _direccion(900.0, 950.0, "bajada (final más abajo)")
	print("DIAG DERRUMBE FALLOS = ", fallos)
	quit()
