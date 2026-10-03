extends SceneTree
## Nivel 2 (entrada de los cultistas): Murciélago por evento, presagio de murciélagos, arqueros
## flotantes (aura, sin gravedad, solo los daña el proyectil) y objetivos de la lista.

var fallos := 0


func _chk(ok: bool, msg: String) -> void:
	print(("[PASS] " if ok else "[FAIL] ") + msg)
	if not ok:
		fallos += 1


func _initialize() -> void:
	var nivel: Node = load("res://scenes/nivel2.tscn").instantiate()
	root.add_child(nivel)
	await physics_frame
	await physics_frame
	var prog: Node = root.get_node("Progresion")
	var player: CharacterBody2D = nivel.get_node("Player")
	player.set("god_mode", true)

	# Formas: Humano y Lobo al entrar; el Murciélago llega por el sello.
	_chk(prog.forma_desbloqueada(1), "Lobo disponible al entrar")
	_chk(not prog.forma_desbloqueada(3), "Murciélago bloqueado al entrar")
	var sello: Area2D = nivel.get_node("UnlockMurcielago")
	var gano := [false]
	sello.desbloqueada.connect(func() -> void: gano[0] = true)
	player.global_position = sello.global_position
	player.velocity = Vector2.ZERO
	await physics_frame
	await physics_frame
	_chk(gano[0] and prog.forma_desbloqueada(3), "el sello desbloquea el Murciélago y emite la señal")

	# Presagio: lanza murciélagos que vuelan y se liberan.
	var bats: Area2D = nivel.get_node("MurcielagosPasan")
	var antes := bats.get_child_count()
	bats.lanzar()
	_chk(bats.get_child_count() == antes + bats.cantidad, "MurcielagosPasan lanza %d murciélagos" % bats.cantidad)

	# Diálogos nuevos existen en el json.
	var datos: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://data/dialogos.json"))
	for id in ["n2_intro", "n2_aleteos", "n2_murcielago", "n2_planeo", "n2_voladores", "n2_voladores2"]:
		_chk(datos is Dictionary and (datos as Dictionary).has(id), "dialogos.json tiene " + id)
		for l in (datos as Dictionary)[id]["lineas"]:
			_chk(str(l).length() <= 48, "%s: línea corta (%d)" % [id, str(l).length()])

	# Arqueros flotantes: 2 arenas, 2 voladores cada una.
	for arena in ["Encounter2", "Encounter3"]:
		var enc: Node = nivel.get_node(arena)
		for nom in ["Volador1", "Volador2"]:
			var v: CharacterBody2D = enc.get_node(nom)
			_chk(v.flotante and v.tipo == "arquero", "%s/%s es arquero flotante" % [arena, nom])
			v.preparar_ola()
			v.activar()
			v._telegraph_timer = 0.0
			v._activo = true
			v._colision(true)
			var y0: float = v.global_position.y
			# Despeje: hay piso debajo (a ~altura_flote) y techo suficiente arriba.
			var sp := nivel.get_viewport().world_2d.direct_space_state
			var pies: float = v.collide_shape.position.y + v.collide_shape.shape.size.y * 0.5
			var q := PhysicsRayQueryParameters2D.create(v.global_position + Vector2(0, pies), v.global_position + Vector2(0, pies + 900), 1)
			var h := sp.intersect_ray(q)
			var alto_piso: float = h.position.y - (v.global_position.y + pies) if not h.is_empty() else -1.0
			_chk(absf(alto_piso - 0.0) < 1.0 or alto_piso >= 0.0, "%s/%s: hay piso debajo" % [arena, nom])
			var q2 := PhysicsRayQueryParameters2D.create(v.global_position + Vector2(0, -v.collide_shape.shape.size.y * 0.5), v.global_position + Vector2(0, -v.collide_shape.shape.size.y * 0.5 - 200), 1)
			_chk(sp.intersect_ray(q2).is_empty(), "%s/%s: techo libre sobre la cabeza" % [arena, nom])
			for i in 30:
				await physics_frame
			_chk(absf(v.global_position.y - y0) < 40.0, "%s/%s: flota (no cae) y=%d→%d" % [arena, nom, int(y0), int(v.global_position.y)])
			_chk(alto_piso > 250.0, "%s/%s: está a %d px sobre el piso (fuera del salto del Humano)" % [arena, nom, int(alto_piso)])
			_chk(v.get_node_or_null("AuraMistica") != null or v._aura != null, "%s/%s: tiene aura" % [arena, nom])
			var vida: int = v.health
			v.take_damage(40, 0.0, 1, false)
			_chk(v.health == vida, "%s/%s: el cuerpo a cuerpo rebota" % [arena, nom])
			v.golpe_proyectil = true
			v.take_damage(15, 0.0, 1, false)
			_chk(v.health == vida - 15, "%s/%s: el proyectil daña" % [arena, nom])

	# Proyectil real del Murciélago contra un volador.
	var v1: CharacterBody2D = nivel.get_node("Encounter2/Volador1")
	player.set("current_form", 3)
	player.global_position = Vector2(v1.global_position.x - 400, v1.global_position.y + 200)
	player.set("facing", 1)
	var v2: CharacterBody2D = nivel.get_node("Encounter2/Volador2")
	var vida1: int = v1.health + v2.health
	var cam: Camera2D = nivel.get_node("Camara")
	cam.position_smoothing_enabled = false
	cam.global_position = player.global_position
	player.fire_projectile()
	for i in 90:
		cam.global_position = player.global_position
		await physics_frame
	_chk(v1.health + v2.health < vida1, "el proyectil del Murciélago alcanza a un volador (%d→%d)" % [vida1, v1.health + v2.health])

	# Objetivos de la lista apuntan a señales reales.
	for o in ["ObjetivoMurcielago", "ObjetivoVolador", "ObjetivoGuardias", "ObjetivoSantuario"]:
		var on: Node = nivel.get_node(o)
		var fuente: Node = on.get_node_or_null(on.origen)
		_chk(fuente != null and fuente.has_signal(on.senal), "%s conectado a %s" % [o, on.senal])

	# Fondo de cueva natural: capas que repiten en horizontal (cubren todo el mapa), sin primer plano.
	var fondo: Node = nivel.get_node_or_null("FondoCuevaNatural")
	_chk(fondo != null and nivel.get_node_or_null("Noche") != null, "nivel2 tiene FondoCuevaNatural y Noche")
	var capas := 0
	for c in fondo.get_children():
		if c is ParallaxLayer:
			capas += 1
			_chk(c.motion_mirroring.x > 0.0 and c.get_child_count() > 0 and (c.get_child(0) as Sprite2D).texture != null, "capa %s repite y tiene textura" % c.name)
			# El fondo se escala con el zoom de la cámara (mín. ~0.7): debe cubrir 1080/0.7 px de alto, sin franja negra.
			var sp := c.get_child(0) as Sprite2D
			var alto: float = (sp.position.y + sp.texture.get_height() * sp.scale.y)
			_chk(sp.position.y <= 0.0 and alto >= 1080.0 / 0.7, "capa %s cubre el alto con zoom 0.7 (%d px)" % [c.name, int(alto)])
	_chk(capas >= 7, "fondo con %d capas" % capas)
	_chk(nivel.get_node_or_null("PrimerPlano") == null, "nivel2 sin elementos de primer plano")

	# Expansión del nivel 2: todo lo agregado apoya en piso real y los textos existen.
	var exp: Node = nivel.get_node_or_null("Expansion")
	_chk(exp != null, "nivel2 tiene el grupo Expansion")
	var espacio := nivel.get_viewport().world_2d.direct_space_state
	var piso_de := func(pos: Vector2, desde: float, hasta: float) -> float:
		var h := espacio.intersect_ray(PhysicsRayQueryParameters2D.create(pos + Vector2(0, desde), pos + Vector2(0, hasta), 1))
		return h.position.y - pos.y if not h.is_empty() else INF
	for g in exp.get_children():
		for n in g.get_children():
			var nm := String(n.name)
			if n is Area2D and n.has_signal("activado") and nm.begins_with("Checkpoint"):
				var d: float = piso_de.call(n.global_position, 0.0, 250.0)
				_chk(d >= 30.0 and d <= 260.0, "%s apoya en piso (a %d px)" % [nm, int(d)])
			elif nm.begins_with("Pinchos"):
				var d2: float = piso_de.call(n.global_position, -120.0, 120.0)
				_chk(absf(d2) <= 40.0, "%s asentado en el piso (%d px)" % [nm, int(d2)])
			elif nm.begins_with("Premio") or nm.begins_with("Vida"):
				var p := PhysicsPointQueryParameters2D.new()
				p.position = n.global_position
				p.collision_mask = 1
				_chk(espacio.intersect_point(p, 1).is_empty(), "%s no está dentro de la roca" % nm)
			elif nm.begins_with("Encuentro"):
				var d3: float = piso_de.call(n.global_position, 0.0, 600.0)
				_chk(absf(d3 - 250.0) <= 40.0, "%s: el piso está a ~250 px bajo el centro (%d)" % [nm, int(d3)])
				for e in n.get_children():
					if e is CharacterBody2D:
						var d4: float = piso_de.call(e.global_position, -100.0, 700.0)
						_chk(d4 < INF and d4 > -10.0, "%s/%s tiene piso debajo (%d px)" % [nm, e.name, int(d4)])
	var calma: Node = exp.get_node_or_null("Calma")
	_chk(calma != null and calma.get_child_count() >= 8, "Expansion/Calma tiene tramos de respiro")
	if calma != null:
		for n in calma.get_children():
			var dc: float = piso_de.call(n.global_position, 0.0, 600.0)
			_chk(dc >= 150.0 and dc <= 260.0, "%s: sobre el piso (%d px)" % [n.name, int(dc)])
			for e in nivel.find_children("*", "CharacterBody2D", true, false):
				if e.has_method("take_damage") and e.name != "Player" and e.global_position.distance_to(n.global_position) < 450.0:
					_chk(false, "%s: hay un enemigo cerca (%s)" % [n.name, e.name])
	var ids: Array[String] = []
	for g in exp.get_children():
		for n in g.get_children():
			if n.get("dialogo_id") != null and String(n.dialogo_id) != "":
				ids.append(String(n.dialogo_id))
	_chk(ids.size() >= 5, "la expansión usa %d diálogos" % ids.size())
	for id in ids:
		_chk(datos is Dictionary and (datos as Dictionary).has(id), "dialogos.json tiene " + id)
		for l in (datos as Dictionary)[id]["lineas"]:
			_chk(str(l).length() <= 48, "%s: línea corta (%d)" % [id, str(l).length()])
	# Evento de derrumbe: cableado y simulación (shake + escombros dentro de la zona, nada fuera).
	var der: Node = exp.get_node_or_null("C/Derrumbe")
	_chk(der != null and der.inicio != null and der.fin != null, "Derrumbe tiene inicio y fin")
	if der != null and der.inicio != null and der.fin != null:
		_chk(der.inicio.global_position.x < der.fin.global_position.x, "Derrumbe: inicio antes que fin")
		_chk(exp.get_node("C/DialogoDerrumbe").dialogo_id == "n2_derrumbe_fin", "Derrumbe: diálogo final")
		_chk((datos as Dictionary).has("n2_derrumbe_fin"), "dialogos.json tiene n2_derrumbe_fin")
		var camd: Camera2D = nivel.get_node("Camara")
		player.global_position = Vector2(der.inicio.global_position.x + 600.0, der.inicio.global_position.y - 100.0)
		player.velocity = Vector2.ZERO
		var shake_visto := false
		var max_esc := 0
		for f in 360:
			player.global_position.y = minf(player.global_position.y, der.inicio.global_position.y)
			camd.global_position = player.global_position
			await physics_frame
			if float(camd.get("_shake_timer")) > 0.0 and float(camd.get("_shake_strength")) >= 6.0:
				shake_visto = true
			var c := 0
			for n in der.get_parent().get_children():
				if "radio" in n and "giro" in n:
					c += 1
			max_esc = maxi(max_esc, c)
		_chk(shake_visto, "Derrumbe: shake fuerte durante la zona")
		_chk(max_esc >= 1, "Derrumbe: caen escombros (%d a la vez)" % max_esc)

	# Tablas del puente de la galería B: cadena con saltos cortos (<= 340 px entre centros).
	var xs: Array[float] = []
	for n in nivel.get_children():
		if String(n.name).begins_with("PlataformaFragil") and n.global_position.y < 2000.0 and n.global_position.y > 1600.0:
			xs.append(n.global_position.x)
	for n in exp.get_node("B").get_children():
		if String(n.name).begins_with("PlataformaFragil"):
			xs.append(n.global_position.x)
	xs.sort()
	var salto_max := 0.0
	for i in range(1, xs.size()):
		salto_max = maxf(salto_max, xs[i] - xs[i - 1])
	_chk(xs.size() >= 5 and salto_max <= 340.0, "puente B: %d tablas, salto máx %d px" % [xs.size(), int(salto_max)])

	print("FALLOS = ", fallos)
	quit(1 if fallos > 0 else 0)
