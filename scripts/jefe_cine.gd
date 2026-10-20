class_name JefeCine
## Momentos de cine del jefe: barras negras con su nombre (entrada), grieta de luz (cambio de fase)
## y destello blanco final (muerte). Todo en reloj real y sin bloquear el control del jugador.


static func _capa(arbol: SceneTree, layer: int) -> CanvasLayer:
	var c := CanvasLayer.new()
	c.layer = layer
	c.process_mode = Node.PROCESS_MODE_ALWAYS
	arbol.root.add_child(c)
	return c


static func _tween(nodo: Node) -> Tween:
	var tw := nodo.create_tween()
	tw.set_ignore_time_scale(true)
	return tw


## Barras de cine + viñeta oscura + nombre del jefe: las letras arrancan muy separadas y se van juntando
## despacio (como algo que se acerca), con titileos de mal augurio, un resplandor rojo detrás y un rumor
## grave de cámara. La línea inferior se abre al final.
static func entrada(arbol: SceneTree, nombre: String, color: Color, duracion: float, retraso: float = 0.0) -> void:
	if DisplayServer.get_name() == "headless" or arbol == null:
		return
	var capa := _capa(arbol, 9)
	var tam := capa.get_viewport().get_visible_rect().size
	var alto := tam.y * 0.17
	var vineta := TextureRect.new()
	var grad := Gradient.new()
	grad.colors = PackedColorArray([Color(0, 0, 0, 0), Color(0, 0, 0, 0.78)])
	grad.offsets = PackedFloat32Array([0.35, 1.0])
	var tex := GradientTexture2D.new()
	tex.gradient = grad
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	tex.fill_to = Vector2(1.0, 0.5)
	vineta.texture = tex
	vineta.stretch_mode = TextureRect.STRETCH_SCALE
	vineta.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vineta.size = tam
	vineta.modulate.a = 0.0
	capa.add_child(vineta)
	var arriba := ColorRect.new()
	var abajo := ColorRect.new()
	for b in [arriba, abajo]:
		b.color = Color(0, 0, 0, 1)
		b.mouse_filter = Control.MOUSE_FILTER_IGNORE
		b.size = Vector2(tam.x, alto)
		capa.add_child(b)
	arriba.position = Vector2(0, -alto)
	abajo.position = Vector2(0, tam.y)
	var fuente := FontVariation.new()
	var serif := SystemFont.new()   # serifa solemne y eclesiástica; si no existe, cae a la fuente por defecto
	serif.font_names = PackedStringArray(["Georgia", "Times New Roman", "serif"])
	serif.font_weight = 700
	fuente.base_font = serif
	fuente.spacing_glyph = 90
	var rojo := color.lerp(Color(0.75, 0.03, 0.05), 0.92)
	var brillo := Label.new()   # resplandor rojo detrás del nombre
	var titulo := Label.new()
	for l: Label in [brillo, titulo]:
		l.text = nombre
		l.add_theme_font_override("font", fuente)
		l.add_theme_font_size_override("font_size", 112)
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		l.size = Vector2(tam.x, 140)
		l.position = Vector2(0, tam.y * 0.64)
		l.pivot_offset = l.size * 0.5
		l.scale = Vector2(1.12, 1.12)
		l.modulate.a = 0.0
		capa.add_child(l)
	titulo.add_theme_color_override("font_color", Color(0.96, 0.92, 0.9))
	titulo.add_theme_color_override("font_outline_color", Color(0.12, 0.0, 0.02))
	titulo.add_theme_constant_override("outline_size", 8)
	brillo.add_theme_color_override("font_color", rojo)
	brillo.add_theme_color_override("font_outline_color", rojo)
	brillo.add_theme_constant_override("outline_size", 34)
	var linea := ColorRect.new()
	linea.color = rojo.lightened(0.25)
	linea.mouse_filter = Control.MOUSE_FILTER_IGNORE
	linea.size = Vector2(tam.x * 0.4, 3)
	linea.position = Vector2(tam.x * 0.3, tam.y * 0.64 + 138)
	linea.pivot_offset = linea.size * 0.5
	linea.scale = Vector2(0.0, 1.0)
	capa.add_child(linea)
	var hold := maxf(duracion - 2.6 - retraso, 0.2)
	var tw := _tween(capa)
	tw.set_parallel(true)
	tw.tween_property(vineta, "modulate:a", 1.0, 1.2)
	tw.tween_property(arriba, "position:y", 0.0, 0.9).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(abajo, "position:y", tam.y - alto, 0.9).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	# titileos de mal augurio antes de que el nombre se fije
	var fl := _tween(titulo)
	fl.tween_interval(0.9 + retraso)
	for a in [0.9, 0.0, 0.6, 0.0, 1.0]:
		fl.tween_property(titulo, "modulate:a", a, 0.05)
		fl.tween_interval(0.07)
	tw.tween_property(brillo, "modulate:a", 0.55, 1.6).set_delay(1.0 + retraso)
	tw.tween_property(titulo, "scale", Vector2.ONE, 2.4).set_delay(0.9 + retraso).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.tween_property(brillo, "scale", Vector2.ONE, 2.4).set_delay(0.9 + retraso).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.tween_method(func(v: float) -> void: fuente.spacing_glyph = int(v), 90.0, 12.0, 2.4).set_delay(0.9 + retraso).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.tween_property(linea, "scale:x", 1.0, 1.0).set_delay(1.8 + retraso).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	# rumor grave de la cámara mientras el nombre se acerca
	for i in 4:
		arbol.create_timer(0.9 + retraso + i * 0.6, true, false, true).timeout.connect(func() -> void:
			var cam := arbol.root.get_viewport().get_camera_2d()
			if cam != null and cam.has_method("shake"):
				cam.shake(4.0 + i * 2.0, 0.5))
	tw.chain().tween_interval(hold)
	tw.chain().set_parallel(true)
	tw.tween_property(arriba, "position:y", -alto, 0.8)
	tw.tween_property(abajo, "position:y", tam.y, 0.8)
	tw.tween_property(vineta, "modulate:a", 0.0, 0.8)
	tw.tween_property(titulo, "modulate:a", 0.0, 0.8)
	tw.tween_property(brillo, "modulate:a", 0.0, 0.8)
	tw.tween_property(linea, "modulate:a", 0.0, 0.8)
	tw.chain().tween_callback(capa.queue_free)


## Lente oscuro: bordes negros que vibran y se cierran mientras la cámara se acerca (reloj real).
static func lente(arbol: SceneTree, duracion: float) -> void:
	if DisplayServer.get_name() == "headless" or arbol == null:
		return
	var capa := _capa(arbol, 8)
	var l := LenteVibrante.new()
	l.dur = duracion
	l.tam = capa.get_viewport().get_visible_rect().size
	capa.add_child(l)


## Grieta de luz que parte la pantalla (cambio de fase).
static func grieta(arbol: SceneTree, color: Color) -> void:
	if DisplayServer.get_name() == "headless" or arbol == null:
		return
	var capa := _capa(arbol, 8)
	var dibujo := Grieta.new()
	dibujo.color = color
	dibujo.tam = capa.get_viewport().get_visible_rect().size
	capa.add_child(dibujo)
	var velo := ColorRect.new()
	velo.set_anchors_preset(Control.PRESET_FULL_RECT)
	velo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	velo.color = Color(1, 1, 1, 0.6)
	capa.add_child(velo)
	var tw := _tween(capa)
	tw.tween_property(velo, "color:a", 0.0, 0.18)
	tw.tween_property(dibujo, "modulate:a", 0.0, 0.7).set_delay(0.25)
	tw.tween_callback(capa.queue_free)


## Destello blanco que cubre la pantalla y se va despacio (muerte del jefe). Con `queda_negro` sube
## durante `subida` s y, al cubrir, pasa a negro y se queda (grupo "destello_final"): victoria_jefe.gd lo libera.
static func destello_final(arbol: SceneTree, retraso: float, subida := 0.35, queda_negro := false) -> void:
	if DisplayServer.get_name() == "headless" or arbol == null:
		return
	var capa := _capa(arbol, 99)
	var velo := ColorRect.new()
	velo.set_anchors_preset(Control.PRESET_FULL_RECT)
	velo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	velo.color = Color(1, 1, 1, 0.0)
	capa.add_child(velo)
	var tw := _tween(capa)
	tw.tween_interval(retraso)
	tw.tween_property(velo, "color:a", 1.0, subida).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	if queda_negro:
		capa.add_to_group("destello_final")
		tw.tween_callback(func() -> void: velo.color = Color.BLACK)
		return
	tw.tween_interval(0.25)
	tw.tween_property(velo, "color:a", 0.0, 1.4).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.tween_callback(capa.queue_free)


## Muerte épica (estilo Hollow Knight): grietas de luz cada vez más seguidas con temblor creciente
## y, justo cuando el destello blanco cubre la pantalla, estalla una lluvia de partículas.
static func estallido(arbol: SceneTree, pos: Vector2, color: Color, retraso: float) -> void:
	if DisplayServer.get_name() == "headless" or arbol == null:
		return
	var grietas := 5
	for i in grietas:
		var t := retraso * pow(float(i) / grietas, 0.8)
		var intensidad := 6.0 + float(i) * 5.0
		arbol.create_timer(t, true, false, true).timeout.connect(func() -> void:
			grieta(arbol, color)
			var cam := arbol.root.get_viewport().get_camera_2d()
			if cam != null and cam.has_method("shake"):
				cam.shake(intensidad, 0.4))
	arbol.create_timer(retraso + 0.3, true, false, true).timeout.connect(func() -> void:
		var p: CPUParticles2D = (preload("res://scenes/burst.tscn") as PackedScene).instantiate()
		p.global_position = pos
		p.self_modulate = color
		p.amount = 90
		arbol.root.add_child(p)
		p.restart()
		p.emitting = true)


class Grieta extends Control:
	var color := Color.WHITE
	var tam := Vector2(1920, 1080)
	var _rayos: Array = []

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		set_anchors_preset(Control.PRESET_FULL_RECT)
		var centro := tam * Vector2(randf_range(0.35, 0.65), randf_range(0.35, 0.65))
		for i in 7:
			var ang := TAU * float(i) / 7.0 + randf_range(-0.25, 0.25)
			var pts := PackedVector2Array([centro])
			var p := centro
			while Rect2(Vector2.ZERO, tam).grow(80.0).has_point(p):
				ang += randf_range(-0.45, 0.45)
				p += Vector2(cos(ang), sin(ang)) * randf_range(50.0, 120.0)
				pts.append(p)
			_rayos.append(pts)
		queue_redraw()

	func _draw() -> void:
		for pts in _rayos:
			draw_polyline(pts, Color(color.r, color.g, color.b, 0.6), 18.0, true)
			draw_polyline(pts, Color(1, 1, 1, 1), 5.0, true)


## Muerte caótica: el sonido se corta, el mundo casi se congela y el jefe se "glitchea" (sacudidas, colores
## y parpadeos al azar) mientras estalla en partículas y barras de ruido cruzan la pantalla. Devuelve el
## nodo: emite `terminado` al acabar (ahí vuelve el sonido). Reloj real (funciona con el tiempo frenado).
static func glitch_muerte(arbol: SceneTree, objetivo: Node2D, cuerpo: Node2D, pos: Vector2, color: Color, duracion: float, sonido: AudioStream = null) -> Node:
	var g := GlitchMuerte.new()
	g.objetivo = objetivo
	g.cuerpo = cuerpo
	g.pos = pos
	g.color = color
	g.dur = duracion
	g.sonido = sonido
	arbol.root.add_child(g)
	return g


class GlitchMuerte extends Node:
	signal terminado
	var objetivo: Node2D
	var cuerpo: Node2D
	var pos := Vector2.ZERO
	var color := Color.WHITE
	var dur := 2.4
	var sonido: AudioStream
	var _mutes := {}   # bus -> mute previo (Música y SFX se cortan; el glitch suena por su propio bus)
	var _bus_glitch := -1
	var _t0 := 0
	var _ult := 0
	var _ult_burst := 0
	var _base := Vector2.ZERO
	var _esc0 := Vector2.ONE
	var _barras: Array = []
	var _partes: Array = []   # [nodo, pos, rot] de los hijos del cuerpo: se desarman al azar
	var _capa: CanvasLayer

	func _ready() -> void:
		process_mode = Node.PROCESS_MODE_ALWAYS
		_t0 = Time.get_ticks_msec()
		_ult = _t0
		_base = cuerpo.position
		_esc0 = cuerpo.scale
		for c in cuerpo.get_children():
			if c is Node2D:
				_partes.append([c, c.position, c.rotation])
		_silenciar()
		_capa = CanvasLayer.new()
		_capa.layer = 10
		add_child(_capa)
		for i in 3:
			var b := ColorRect.new()
			b.mouse_filter = Control.MOUSE_FILTER_IGNORE
			b.visible = false
			_capa.add_child(b)
			_barras.append(b)

	func _silenciar() -> void:
		for nombre in [&"Musica", &"SFX"]:
			var i := AudioServer.get_bus_index(nombre)
			if i >= 0:
				_mutes[i] = AudioServer.is_bus_mute(i)
				AudioServer.set_bus_mute(i, true)
		if sonido != null:
			AudioServer.add_bus()
			_bus_glitch = AudioServer.bus_count - 1
			AudioServer.set_bus_name(_bus_glitch, &"GlitchJefe")
			AudioServer.set_bus_send(_bus_glitch, &"Master")
			var ap := AudioStreamPlayer.new()
			ap.stream = sonido
			ap.bus = &"GlitchJefe"
			ap.volume_db = -8.0
			add_child(ap)
			ap.play()

	func _restaurar() -> void:
		for i in _mutes:
			AudioServer.set_bus_mute(i, _mutes[i])
		_mutes.clear()
		if _bus_glitch >= 0:
			AudioServer.remove_bus(AudioServer.get_bus_index(&"GlitchJefe"))
			_bus_glitch = -1

	func _exit_tree() -> void:
		_restaurar()

	func _process(_delta: float) -> void:
		var ahora := Time.get_ticks_msec()
		var t := (ahora - _t0) / 1000.0
		if t >= dur:
			_fin()
			return
		var k := t / dur
		var tam := get_viewport().get_visible_rect().size
		# jefe: sacudidas, escala y color al azar, parpadeo
		var f := 10.0 + 70.0 * k
		cuerpo.position = _base + Vector2(randf_range(-f, f), randf_range(-f, f)) * (3.0 if randf() < 0.15 else 1.0)
		cuerpo.scale = _esc0 * Vector2(randf_range(0.85, 1.2), randf_range(0.8, 1.25))
		objetivo.modulate = [Color(3, 3, 3), color * 2.0, color.lightened(0.5) * 1.6, Color(0.05, 0.05, 0.05), color.inverted() * 2.0].pick_random()
		objetivo.visible = randf() > 0.12 + 0.2 * k
		# partes del cuerpo que se desarman: cada hijo salta y gira por su cuenta
		for pt in _partes:
			if is_instance_valid(pt[0]):
				pt[0].position = pt[1] + Vector2(randf_range(-1, 1), randf_range(-1, 1)) * (30.0 + 120.0 * k)
				pt[0].rotation = pt[2] + randf_range(-0.4, 0.4) * k
		# pocas líneas finas de interferencia
		for b: ColorRect in _barras:
			b.visible = randf() < 0.35
			if b.visible:
				b.color = [Color(1, 1, 1, 0.5), color][randi() % 2]
				b.size = Vector2(randf_range(0.2, 1.0) * tam.x, randf_range(2.0, 8.0))
				b.position = Vector2(randf_range(-0.2, 0.8) * tam.x, randf() * tam.y)
		# partículas de colores por todo el cuerpo, cada vez más densas
		if ahora - _ult_burst >= 50:
			_ult_burst = ahora
			for _i in 1 + int(k * 3.0):
				var p: CPUParticles2D = (preload("res://scenes/burst.tscn") as PackedScene).instantiate()
				p.global_position = pos + Vector2(randf_range(-380.0, 380.0), randf_range(-420.0, 160.0))
				p.self_modulate = [Color.WHITE, color, color.lightened(0.5), color.darkened(0.4)].pick_random()
				p.amount = 30
				p.speed_scale = 1.0 / maxf(Engine.time_scale, 0.05)   # compensa el mundo casi congelado
				get_tree().root.add_child(p)
				p.restart()
				p.emitting = true
			var cam := get_viewport().get_camera_2d()
			if cam != null and cam.has_method("shake"):
				cam.shake(12.0 + 40.0 * k, 0.2)

	func _fin() -> void:
		cuerpo.position = _base
		cuerpo.scale = _esc0
		for pt in _partes:
			if is_instance_valid(pt[0]):
				pt[0].position = pt[1]
				pt[0].rotation = pt[2]
		objetivo.modulate = Color.WHITE
		objetivo.visible = true
		_restaurar()
		terminado.emit()
		queue_free()


class LenteVibrante extends TextureRect:
	var dur := 6.0
	var tam := Vector2(1920, 1080)
	var _t0 := 0

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		var g := Gradient.new()
		g.colors = PackedColorArray([Color(0, 0, 0, 0), Color(0, 0, 0, 0.7), Color(0, 0, 0, 0.98)])
		g.offsets = PackedFloat32Array([0.3, 0.65, 0.95])
		var tx := GradientTexture2D.new()
		tx.gradient = g
		tx.fill = GradientTexture2D.FILL_RADIAL
		tx.fill_from = Vector2(0.5, 0.5)
		tx.fill_to = Vector2(1.0, 0.5)
		texture = tx
		stretch_mode = TextureRect.STRETCH_SCALE
		size = tam * 1.35
		position = -tam * 0.175
		pivot_offset = size * 0.5
		modulate.a = 0.0
		_t0 = Time.get_ticks_msec()

	func _process(_d: float) -> void:
		var t := (Time.get_ticks_msec() - _t0) / 1000.0
		if t >= dur:
			get_parent().queue_free()
			return
		var k := t / dur
		var amp := 7.0 + 32.0 * k
		position = -tam * 0.175 + Vector2(randf_range(-1, 1), randf_range(-1, 1)) * amp
		scale = Vector2.ONE * (1.0 - 0.16 * k + 0.025 * sin(t * 47.0) * (0.5 + k))   # se cierra y tiembla
		modulate.a = minf(t / 0.8, 1.0) * minf((dur - t) / 0.25, 1.0) * (0.8 + 0.2 * sin(t * 26.0))
