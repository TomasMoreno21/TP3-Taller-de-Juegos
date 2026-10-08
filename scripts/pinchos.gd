@tool
extends Area2D
## Pinchos modulares: matan de un toque al jugador.
## Colocá varios o ajustá `cantidad`/`ancho` para cubrir la franja que necesites.
##
## En el EDITOR se dibuja un contorno semitransparente de la franja total y de la
## zona de daño, y estirar el nodo con la herramienta de escala sincroniza
## `ancho_pincho`/`alto` en vivo (WYSIWYG).

@export var cantidad := 4       # cuántos pinchos en fila (modular)
@export var ancho_pincho := 40.0 # ancho de cada pincho (px)
@export var alto := 24.0         # altura VISIBLE de cada estaca (px, asoma del terreno)
@export_range(0.5, 3.0, 0.05) var altura_mult := 1.8  # estira la altura visible (la zona de daño NO crece: mantiene su tamaño)
@export var enemigos_mueren := true         # un enemigo empujado (en hitstun) contra los pinchos muere
@export var dano_a_enemigos := 200          # daño que reciben al empalarse
@export var dano := 9999       # daño al tocar (por defecto mata de un toque)
## Aspecto: ROCA = colmillos de piedra afilada (cueva); MADERA = estacas talladas (bosque).
## TRIBAL = estacas de una tribu: troncos atados con cuerda, banda de pintura ocre y puntitos de hueso.
enum Estilo { ROCA, MADERA, TRIBAL }
@export var estilo := Estilo.MADERA
@export var color_base := Color(0.13, 0.12, 0.17)     # escombros / base enterrada
@export var color_estaca := Color(0.74, 0.72, 0.86)  # cara iluminada de cada pincho (la sombra se deriva)
## Solo MADERA: cara iluminada de la estaca, sangre en la punta y qué fracción de estacas la lleva.
@export var color_madera := Color(0.68, 0.49, 0.29)
@export var color_sangre := Color(0.62, 0.06, 0.08)
## Solo TRIBAL: tronco, cuerda del atado, pintura y puntos de hueso.
@export var color_tribal := Color(0.55, 0.38, 0.23)
@export var color_cuerda := Color(0.80, 0.70, 0.46)
@export var color_pintura := Color(0.66, 0.16, 0.10)
@export var color_hueso := Color(0.90, 0.86, 0.72)
@export_range(0.0, 1.0) var prob_sangre := 0.35
## Musgo en el pie de cada pincho: los une con el pasto del suelo y los asienta en el ambiente.
@export var color_musgo := Color(0.30, 0.52, 0.26)
@export_range(0.0, 1.0) var prob_musgo := 0.8          # fracción de pinchos con musgo (0 = ninguno)
@export_range(0.0, 1.0) var luz_punta := 0.35          # cuánto aclara la punta (madera/piedra "descubierta")
@export var enterrado := 36.0  # tramo que queda DENTRO del tile (tapado por el tilemap)
@export var z_index_detras := -1 # el nodo se dibuja detrás del tilemap (asoman las puntas)
@export var fraccion_zona_dano := 0.4  # qué porción del alto VISIBLE mata (el resto es decorativo)

var _kill_zone_size := Vector2.ZERO
var _jugador: Node2D
var _empalados := {}                       # id de enemigo -> ms del último empalado
var _fase_chequeo := randi() % 4           # escalona el chequeo de enemigos entre pinchos
var _hit_cd := 0.0
var _editor_sync := true


func _ready() -> void:
	add_to_group("pinchos")
	collision_layer = 0
	collision_mask = 4
	z_index = z_index_detras
	if not Engine.is_editor_hint():
		set_process(false)   # el _process solo sirve en el editor (hay cientos de pinchos)
	if Engine.is_editor_hint():
		queue_redraw()
		return
	_dibujar()


# En el editor: (1) estirar el nodo con la herramienta de escala sincroniza los
# exports (WYSIWYG: vuelvo scale a 1 y guardo el tamaño real en ancho/alto), y
# (2) si cambian los exports (Inspector o escala) se redibuja el preview.
func _process(_delta: float) -> void:
	if not Engine.is_editor_hint():
		return
	if _editor_sync:
		var s := scale
		if s != Vector2.ONE:
			_editor_sync = false
			ancho_pincho = maxf(ancho_pincho * s.x, 1.0)
			alto = maxf(alto * s.y, 4.0)
			scale = Vector2.ONE
			_editor_sync = true
			queue_redraw()
	var clave := _clave_visual()
	if clave != _tmp:
		_tmp = clave
		queue_redraw()


var _tmp := Vector3.ZERO


func _clave_visual() -> Vector3:
	return Vector3(cantidad, ancho_pincho, alto * altura_mult * _factor_estilo())


## Las estacas tribales se dibujan más altas (×1.3): la zona de daño sigue a su punta real.
func _factor_estilo() -> float:
	return 1.3 if estilo == Estilo.TRIBAL else 1.0


# Preview editable en el editor: contorno semitransparente de la franja que vas a
# tapar, zona de daño resaltada y guía de hundimiento (hasta dónde queda enterrado).
func _draw() -> void:
	if not Engine.is_editor_hint():
		return
	var ancho_total := maxf(cantidad * ancho_pincho, 10.0)
	var alto_vis := maxf(alto * altura_mult * _factor_estilo(), 10.0)
	var alto_zona := maxf(alto, 10.0) * clampf(fraccion_zona_dano, 0.0, 1.0)
	# Franja total visible (asoma del terreno hacia arriba; y negativo arriba).
	draw_rect(Rect2(-ancho_total * 0.5, -alto_vis, ancho_total, alto_vis), Color(1, 0.75, 0.2, 0.14), false, 2.0)
	# Zona de daño: la porción superior (fair: tocar el tallo no mata).
	draw_rect(Rect2(-ancho_total * 0.5, -alto_vis, ancho_total, alto_zona), Color(1, 0.2, 0.2, 0.35))
	# Guía del hundimiento + línea de superficie: muestra cuánto queda tapado.
	draw_line(Vector2(-ancho_total * 0.5, 0), Vector2(ancho_total * 0.5, 0), Color(0.9, 0.9, 0.9, 0.7), 2.0)
	draw_rect(Rect2(-ancho_total * 0.5, 0, ancho_total, enterrado), Color(0.4, 0.3, 0.2, 0.18), false, 1.0)
	# Divisiones de cada estaca.
	for i in range(int(cantidad) + 1):
		var x := -ancho_total * 0.5 + i * ancho_pincho
		draw_line(Vector2(x, -alto_vis), Vector2(x, 0), Color(1, 0.8, 0.4, 0.25), 1.0)


func _physics_process(delta: float) -> void:
	if Engine.is_editor_hint():
		return   # en el editor no hay daño (y _kill_zone_size está en 0)
	if _hit_cd > 0.0:
		_hit_cd -= delta
	if _kill_zone_size == Vector2.ZERO:
		return
	# Hay cientos de pinchos: el empalado de enemigos se chequea a ~15 Hz (escalonado por instancia)
	# y el jugador solo se evalúa si está cerca (en vez de recorrer grupos cada frame en cada uno).
	if enemigos_mueren and (Engine.get_physics_frames() + _fase_chequeo) % 4 == 0:
		_empalar_enemigos()
	if _jugador == null or not is_instance_valid(_jugador):
		_jugador = get_tree().get_first_node_in_group("player")
	var player: Node2D = _jugador
	if player == null or _hit_cd > 0.0 or player.get("_derrota_activa"):
		return
	if global_position.distance_to(player.global_position) > _kill_zone_size.length() + 400.0:
		return
	if _cuerpo_en_zona(player):
		# Al golpear saltamos el cooldown para no repetir el daño cada frame.
		_hit_cd = 0.15 if dano < 9999 else 0.0
		if not player.get("god_mode") and player.get("_invuln_timer") <= 0.0 and not player.get("_derrota_activa"):
			var audio := get_node_or_null("/root/AudioManager")
			if audio != null:
				audio.play_ui("pinchos", -8.0)
			Burst.emitir(self, player.global_position + Vector2(0, 50), Color(0.95, 0.9, 0.85), 10, 0.6)
		player.take_damage(dano, 0.0, 0, true)


## Un enemigo lanzado contra los pinchos (en hitstun) queda empalado. Los que caminan solos no mueren.
func _empalar_enemigos() -> void:
	if not enemigos_mueren:
		return
	for e in get_tree().get_nodes_in_group("enemy"):
		if not is_instance_valid(e) or e.is_in_group("boss") or not (e is Node2D):
			continue
		if float(e.get("_stun_timer")) <= 0.0 or int(e.get("health")) <= 0:
			continue
		if global_position.distance_to((e as Node2D).global_position) > _kill_zone_size.length() + 300.0:
			continue
		if _cuerpo_en_zona(e):
			var ahora := Time.get_ticks_msec()
			if ahora - int(_empalados.get(e.get_instance_id(), -1000)) < 400:
				continue   # un escudo/invulnerable no dispara el estallido en cada chequeo
			_empalados[e.get_instance_id()] = ahora
			Burst.emitir(self, (e as Node2D).global_position, color_sangre, 12, 0.8)
			e.take_damage(dano_a_enemigos, 0.0, 1, false)


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
	# La zona de daño es SOLO la porción superior del alto visible (fair: tocar
	# el tallo/palo no mata). Está anclada a la PUNTA (cima del alto visible) y
	# baja hacia la base, no al revés: el rect anterior cubría la base/tallo.
	var alto_vis := _kill_zone_size.y
	var alto_zona := maxf(alto, 10.0) * fraccion_zona_dano
	var rect_zona := Rect2(
		global_position.x - _kill_zone_size.x * 0.5,
		global_position.y - alto_vis,
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
	_kill_zone_size = Vector2(maxf(cantidad * ancho_pincho, 10.0), maxf(alto * altura_mult * _factor_estilo(), 10.0))
	var alto_vis := _kill_zone_size.y
	var alto_zona := maxf(alto, 10.0) * fraccion_zona_dano
	# Collider visible/depurable (no se usa para detección, pero ayuda a ver el área)
	var killzone: Node2D = get_node_or_null("KillZone")
	if killzone != null:
		for c in killzone.get_children():
			killzone.remove_child(c)
			c.queue_free()
		var nuevo := CollisionShape2D.new()
		var sh := RectangleShape2D.new()
		sh.size = Vector2(_kill_zone_size.x, alto_zona)
		nuevo.shape = sh
		nuevo.position = Vector2(0, -alto_vis + alto_zona * 0.5)
		nuevo.name = "Collision"
		killzone.add_child(nuevo)
	# Detrás del tilemap: el cuerpo queda enterrado y solo asoman las puntas.
	var visual: Node2D = get_node_or_null("Visual")
	if visual == null:
		return
	for child in visual.get_children():
		child.queue_free()
	var ancho_total := _kill_zone_size.x
	var rng := RandomNumberGenerator.new()
	rng.seed = int(absf(global_position.x) * 7.0 + absf(global_position.y) * 3.0) + int(cantidad) * 131
	var clara := color_estaca
	var oscura := color_estaca.darkened(0.42)
	if estilo != Estilo.ROCA:
		clara = color_tribal if estilo == Estilo.TRIBAL else color_madera
		oscura = clara.darkened(0.38)
	# Base enterrada continua (une los pinchos; asoma un poco como tierra oscura).
	visual.add_child(_poli([Vector2(-ancho_total * 0.5 - 4, enterrado + 8), Vector2(-ancho_total * 0.5 - 4, -3),
		Vector2(ancho_total * 0.5 + 4, -3), Vector2(ancho_total * 0.5 + 4, enterrado + 8)], color_base))
	for i in range(int(cantidad)):
		var cx := -ancho_total * 0.5 + (float(i) + 0.5) * ancho_pincho
		var w := ancho_pincho * rng.randf_range(0.62, 0.86)
		var h := alto * altura_mult * (rng.randf_range(0.86, 1.0) if i % 3 != 1 else 1.0)
		if estilo == Estilo.TRIBAL:                         # más finas y altas: se leen como troncos afilados
			w *= 0.55
			h *= 1.3
		var j := w * rng.randf_range(-0.18, 0.18)          # la punta se corre un poco
		var k := rng.randf_range(0.22, 0.34)                # altura del "hombro"
		var e := enterrado
		var pinch := Node2D.new()
		pinch.position = Vector2(cx, 0)
		visual.add_child(pinch)
		if estilo != Estilo.ROCA:
			var ab := _estaca(pinch, rng, w, h, j, e, clara, oscura, rng.randf() < prob_sangre)
			if estilo == Estilo.TRIBAL:
				_adornos_tribales(pinch, rng, ab, h, oscura)
			_musgo_pie(pinch, rng, w, h)
			continue
		# Colmillo de roca: mitad iluminada (izq.) + mitad en sombra (der.), hombro quebrado.
		pinch.add_child(_poli([Vector2(-w * 0.5, e), Vector2(-w * 0.47, -h * k), Vector2(-w * 0.2, -h * (k + 0.3)), Vector2(j, -h), Vector2(j, e)], clara))
		pinch.add_child(_poli([Vector2(j, e), Vector2(j, -h), Vector2(w * 0.24, -h * (k + 0.22)), Vector2(w * 0.5, -h * k * 0.8), Vector2(w * 0.5, e)], oscura))
		# Filo brillante a lo largo del borde iluminado + punta clara.
		var filo := Line2D.new()
		filo.points = PackedVector2Array([Vector2(-w * 0.47, -h * k), Vector2(-w * 0.2, -h * (k + 0.3)), Vector2(j, -h)])
		filo.width = 2.2
		filo.default_color = clara.lightened(0.5)
		pinch.add_child(filo)
		pinch.add_child(_poli([Vector2(j - w * 0.11, -h * 0.8), Vector2(j, -h), Vector2(j + w * 0.1, -h * 0.8)], Color(0.86, 0.3, 0.36)))
		# Punta descubierta: la cara iluminada se aclara hacia la cima.
		pinch.add_child(_poli([Vector2(-w * 0.2 * 0.85, -h * (k + 0.3) * 0.9), Vector2(j, -h), Vector2(j, -h * 0.72)], clara.lightened(luz_punta)))
		_musgo_pie(pinch, rng, w, h)
	# Escombros al pie (piedritas oscuras): rompen la línea recta del suelo.
	var x := -ancho_total * 0.5
	while x < ancho_total * 0.5:
		var r := rng.randf_range(4.0, 9.0)
		var c := Vector2(x + r, 1.0)
		var pts := PackedVector2Array()
		for a in 7:
			var ang := PI + PI * float(a) / 6.0
			pts.append(c + Vector2(cos(ang) * r * 1.3, sin(ang) * r))
		visual.add_child(_poli(pts, color_base.lightened(0.12)))
		x += rng.randf_range(20.0, 44.0)


## Estaca de madera tallada: tronco con punta en bisel, betas, muesca y (a veces) sangre en la punta.
func _estaca(nodo: Node2D, rng: RandomNumberGenerator, w: float, h: float, j: float, e: float,
		clara: Color, oscura: Color, con_sangre: bool) -> float:
	var lean := rng.randf_range(-0.1, 0.1) * w
	var ab := w * rng.randf_range(0.9, 1.0)
	var hombro := h * rng.randf_range(0.52, 0.62)       # dónde empieza el afilado
	var tip := Vector2(j + lean, -h)
	var l0 := Vector2(-ab * 0.5 + lean * 0.5, -hombro)
	var r0 := Vector2(ab * 0.5 + lean * 0.5, -hombro)
	nodo.add_child(_poli([Vector2(-ab * 0.5, e), l0, tip, Vector2(tip.x, e)], clara))
	nodo.add_child(_poli([Vector2(tip.x, e), tip, r0, Vector2(ab * 0.5, e)], oscura))
	# Faceta del corte (madera fresca, más clara).
	nodo.add_child(_poli([l0.lerp(tip, 0.42), tip, r0.lerp(tip, 0.42)], clara.lightened(0.28)))
	# Betas de la madera.
	for b in 3:
		var bx := lerpf(-ab * 0.32, ab * 0.32, float(b) / 2.0) + rng.randf_range(-2.0, 2.0)
		var beta := Line2D.new()
		beta.points = PackedVector2Array([Vector2(bx, e), Vector2(bx + rng.randf_range(-1.5, 1.5), -hombro * rng.randf_range(0.55, 0.95))])
		beta.width = 1.6
		beta.default_color = oscura.darkened(0.15)
		nodo.add_child(beta)
	# Muesca de hachazo y borde de luz.
	var my := -h * rng.randf_range(0.12, 0.3)
	nodo.add_child(_poli([Vector2(-ab * 0.5, my), Vector2(-ab * 0.5 + w * 0.3, my - 2.0), Vector2(-ab * 0.5 + w * 0.3, my + 3.0)], oscura.darkened(0.2)))
	var filo := Line2D.new()
	filo.points = PackedVector2Array([Vector2(-ab * 0.5, e), l0, tip])
	filo.width = 1.8
	filo.default_color = clara.lightened(0.35)
	nodo.add_child(filo)
	if not con_sangre:
		return ab
	# Sangre en la punta: manto irregular + brillo + chorro.
	var s0 := rng.randf_range(0.28, 0.48)
	var a := l0.lerp(tip, s0)
	var d := r0.lerp(tip, s0)
	var largo := h * rng.randf_range(0.3, 0.45)
	var gx := lerpf(a.x, d.x, 0.45)
	nodo.add_child(_poli([a, tip, d, d + Vector2(-1.0, largo * 0.5), Vector2(lerpf(a.x, d.x, 0.7), a.y + largo * 0.25),
		Vector2(gx, a.y + largo), Vector2(lerpf(a.x, d.x, 0.25), a.y + largo * 0.35)], color_sangre))
	var brillo := Line2D.new()
	brillo.points = PackedVector2Array([a.lerp(tip, 0.25) + Vector2(1.5, 1.0), a.lerp(tip, 0.7) + Vector2(1.5, 0.0)])
	brillo.width = 1.4
	brillo.default_color = color_sangre.lightened(0.45)
	nodo.add_child(brillo)
	var chorro := Line2D.new()
	chorro.points = PackedVector2Array([Vector2(gx, a.y + largo), Vector2(gx, a.y + largo + h * rng.randf_range(0.1, 0.22))])
	chorro.width = 2.0
	chorro.default_color = color_sangre.darkened(0.1)
	nodo.add_child(chorro)
	return ab


## Adornos de tribu sobre la estaca: banda de pintura, atado de cuerda con cabos sueltos y puntos de hueso.
func _adornos_tribales(nodo: Node2D, rng: RandomNumberGenerator, ab: float, h: float, oscura: Color) -> void:
	var m := ab * 0.5
	# Banda de pintura ocre (con una cuña central) justo antes del afilado.
	var y1 := -h * 0.5
	var y0 := -h * 0.42
	nodo.add_child(_poli([Vector2(-m, y0), Vector2(-m, y1), Vector2(m, y1), Vector2(m, y0)], color_pintura))
	nodo.add_child(_poli([Vector2(-m, y0), Vector2(0, y0 - h * 0.05), Vector2(m, y0), Vector2(0, y0 - h * 0.012)], color_pintura.darkened(0.3)))
	# Atado de cuerda: faja con cruces y dos cabos que cuelgan.
	var c1 := -h * 0.34
	var c0 := -h * 0.24
	nodo.add_child(_poli([Vector2(-m - 1.5, c0), Vector2(-m - 1.5, c1), Vector2(m + 1.5, c1), Vector2(m + 1.5, c0)], color_cuerda))
	var pasos := 4
	for i in pasos:
		var x0 := lerpf(-m - 1.0, m + 1.0, float(i) / float(pasos))
		var x1 := lerpf(-m - 1.0, m + 1.0, float(i + 1) / float(pasos))
		var l := Line2D.new()
		l.points = PackedVector2Array([Vector2(x0, c0), Vector2(x1, c1)])
		l.width = 1.3
		l.default_color = oscura.darkened(0.3)
		nodo.add_child(l)
	for lado in [-1.0, 1.0]:
		var cabo := Line2D.new()
		var bx: float = lado * m * rng.randf_range(0.2, 0.7)
		cabo.points = PackedVector2Array([Vector2(bx, c0), Vector2(bx + lado * 2.0, c0 + h * rng.randf_range(0.08, 0.14))])
		cabo.width = 1.6
		cabo.default_color = color_cuerda.darkened(0.2)
		nodo.add_child(cabo)
	# Un punto de hueso en el tronco, más abajo.
	var pts := PackedVector2Array()
	var cx := rng.randf_range(-m * 0.3, m * 0.3)
	for a in 6:
		var ang := TAU * float(a) / 6.0
		pts.append(Vector2(cx + cos(ang) * 1.5, -h * 0.12 + sin(ang) * 1.5))
	nodo.add_child(_poli(pts, color_hueso))


## Mechón de musgo al pie del pincho (borde festoneado, con una hebra más clara).
func _musgo_pie(nodo: Node2D, rng: RandomNumberGenerator, w: float, h: float) -> void:
	if rng.randf() >= prob_musgo:
		return
	var ancho := w * rng.randf_range(0.9, 1.25)
	var alto_m := clampf(h * rng.randf_range(0.16, 0.26), 4.0, 12.0)
	var n := 5
	var pts := PackedVector2Array([Vector2(-ancho * 0.5, 4.0)])
	for i in n + 1:
		var f := float(i) / float(n)
		var x := lerpf(-ancho * 0.5, ancho * 0.5, f)
		var y := -alto_m * (1.0 if i % 2 == 1 else 0.55) * rng.randf_range(0.8, 1.05)
		pts.append(Vector2(x, y))
	pts.append(Vector2(ancho * 0.5, 4.0))
	nodo.add_child(_poli(pts, color_musgo))
	nodo.add_child(_poli(PackedVector2Array([Vector2(-ancho * 0.3, 1.0), Vector2(-ancho * 0.1, -alto_m * 0.85), Vector2(ancho * 0.05, 1.0)]), color_musgo.lightened(0.25)))


func _poli(pts: PackedVector2Array, color: Color) -> Polygon2D:
	var p := Polygon2D.new()
	p.polygon = pts
	p.color = color
	return p
