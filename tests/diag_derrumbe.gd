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
	func take_damage(cant: int, _kb: float = 0.0, _dir: int = 1, _ign: bool = false) -> void:
		health -= cant

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
	for i in 600:
		await physics_frame
	var mn := 1e9
	var mx := 0.0
	for g in cam.golpes:
		mn = minf(mn, g)
		mx = maxf(mx, g)
	var res := [mn, mx, cam.golpes.size()]
	m["raiz"].queue_free()
	await physics_frame
	return res


func _initialize() -> void:
	# 1) Ritmo del shake: antes constante (18), ahora con valles y picos
	var antes: Array = await _ritmo(true)
	var ahora: Array = await _ritmo(false)
	print("shake plano (valle=pico=1): min %.1f  max %.1f  (%d sacudidas)" % [antes[0], antes[1], antes[2]])
	print("shake con ritmo:        min %.1f  max %.1f  (%d sacudidas)" % [ahora[0], ahora[1], ahora[2]])
	_chk(ahora[1] / maxf(ahora[0], 0.01) >= 1.8, "ahora: el shake varía (pico/valle = %.1f)" % (ahora[1] / maxf(ahora[0], 0.01)))

	# 2) Rocas dirigidas, aviso con grieta, sonido y cierre del evento
	var m := _mundo()
	var ev: Node2D = m["ev"]
	var p: CharacterBody2D = m["p"]
	var raiz: Node2D = m["raiz"]
	var cam = m["cam"]
	for i in 40:
		await physics_frame
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
	var retumbo: AudioStreamPlayer = ev.get("_retumbo")
	_chk(retumbo.playing, "el retumbo de fondo suena mientras dura el derrumbe")

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
	print("DIAG DERRUMBE FALLOS = ", fallos)
	quit()
