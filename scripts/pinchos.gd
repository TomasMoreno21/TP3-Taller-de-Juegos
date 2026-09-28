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
@export var dano := 9999         # daño al tocar (por defecto mata de un toque)
## Aspecto: ROCA = colmillos de piedra afilada (cueva); MADERA = estacas talladas (bosque).
enum Estilo { ROCA, MADERA }
@export var estilo := Estilo.MADERA
@export var color_base := Color(0.13, 0.12, 0.17)     # escombros / base enterrada
@export var color_estaca := Color(0.6, 0.58, 0.74)   # cara iluminada de cada pincho (la sombra se deriva)
## Solo MADERA: cara iluminada de la estaca, sangre en la punta y qué fracción de estacas la lleva.
@export var color_madera := Color(0.56, 0.38, 0.21)
@export var color_sangre := Color(0.62, 0.06, 0.08)
@export_range(0.0, 1.0) var prob_sangre := 0.35
@export var enterrado := 36.0   # tramo que queda DENTRO del tile (tapado por el tilemap)
@export var z_index_detras := -1 # el nodo se dibuja detrás del tilemap (asoman las puntas)
@export var fraccion_zona_dano := 0.4  # qué porción del alto VISIBLE mata (el resto es decorativo)

var _kill_zone_size := Vector2.ZERO
var _hit_cd := 0.0
var _editor_sync := true


func _ready() -> void:
	add_to_group("pinchos")
	collision_layer = 0
	collision_mask = 4
	z_index = z_index_detras
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
	return Vector3(cantidad, ancho_pincho, alto)


# Preview editable en el editor: contorno semitransparente de la franja que vas a
# tapar, zona de daño resaltada y guía de hundimiento (hasta dónde queda enterrado).
func _draw() -> void:
	if not Engine.is_editor_hint():
		return
	var ancho_total := maxf(cantidad * ancho_pincho, 10.0)
	var alto_vis := maxf(alto, 10.0)
	var alto_zona := alto_vis * clampf(fraccion_zona_dano, 0.0, 1.0)
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
	if _hit_cd > 0.0:
		_hit_cd -= delta
	var player: Node2D = get_tree().get_first_node_in_group("player")
	if player == null or _hit_cd > 0.0:
		return
	if _cuerpo_en_zona(player):
		# Al golpear saltamos el cooldown para no repetir el daño cada frame.
		_hit_cd = 0.15 if dano < 9999 else 0.0
		if not player.get("god_mode") and player.get("_invuln_timer") <= 0.0 and not player.get("_derrota_activa"):
			var audio := get_node_or_null("/root/AudioManager")
			if audio != null:
				audio.play_ui("pinchos", -8.0)
		player.take_damage(dano, 0.0, 0)


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
	var alto_zona := alto_vis * fraccion_zona_dano
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
	_kill_zone_size = Vector2(maxf(cantidad * ancho_pincho, 10.0), maxf(alto, 10.0))
	var alto_vis := _kill_zone_size.y
	var alto_zona := alto_vis * fraccion_zona_dano
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
	if estilo == Estilo.MADERA:
		clara = color_madera
		oscura = clara.darkened(0.38)
	# Base enterrada continua (une los pinchos; asoma un poco como tierra oscura).
	visual.add_child(_poli([Vector2(-ancho_total * 0.5 - 4, enterrado + 8), Vector2(-ancho_total * 0.5 - 4, -3),
		Vector2(ancho_total * 0.5 + 4, -3), Vector2(ancho_total * 0.5 + 4, enterrado + 8)], color_base))
	for i in range(int(cantidad)):
		var cx := -ancho_total * 0.5 + (float(i) + 0.5) * ancho_pincho
		var w := ancho_pincho * rng.randf_range(0.62, 0.86)
		var h := alto * (rng.randf_range(0.86, 1.0) if i % 3 != 1 else 1.0)
		var j := w * rng.randf_range(-0.18, 0.18)          # la punta se corre un poco
		var k := rng.randf_range(0.22, 0.34)                # altura del "hombro"
		var e := enterrado
		var pinch := Node2D.new()
		pinch.position = Vector2(cx, 0)
		visual.add_child(pinch)
		if estilo == Estilo.MADERA:
			_estaca(pinch, rng, w, h, j, e, clara, oscura, rng.randf() < prob_sangre)
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
		clara: Color, oscura: Color, con_sangre: bool) -> void:
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
		return
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


func _poli(pts: PackedVector2Array, color: Color) -> Polygon2D:
	var p := Polygon2D.new()
	p.polygon = pts
	p.color = color
	return p
