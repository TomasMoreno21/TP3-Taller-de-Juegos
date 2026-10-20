extends Node2D
## Trailer en arena aislada (scenes/trailer.tscn): secuencia scriptada de ~80 s.
## Mueve la cámara, dispara ataques y transformaciones del jugador real y spawnea enemigos.
## Grabar: Godot --write-movie trailer.avi --fixed-fps 60 --path . res://scenes/trailer.tscn

@export var salir_al_final := true
@export var suelo_y := 150.0
@export var color_fondo := Color("1d2b24")

var player: Node2D
var cam: Camera2D
var _velo: ColorRect
var _titulo: Label
var _subtitulo: Label
var _silueta: Node2D
var _ojos_t := 0.0


func _ready() -> void:
	_armar_escenario()
	_armar_jugador()
	_armar_camara()
	_armar_ui()
	_secuencia()


func _process(delta: float) -> void:
	_ojos_t += delta
	_silueta.queue_redraw()


func _armar_escenario() -> void:
	var fondo := ColorRect.new()
	fondo.color = color_fondo
	fondo.position = Vector2(-3000, -1500)
	fondo.size = Vector2(6000, 2200)
	fondo.z_index = -20
	add_child(fondo)
	var piso := ColorRect.new()
	piso.color = Color("3b2f22")
	piso.position = Vector2(-3000, suelo_y)
	piso.size = Vector2(6000, 800)
	piso.z_index = -10
	add_child(piso)
	var cuerpo := StaticBody2D.new()
	cuerpo.position = Vector2(0, suelo_y + 100.0)
	var forma := CollisionShape2D.new()
	forma.shape = RectangleShape2D.new()
	forma.shape.size = Vector2(6000, 200)
	cuerpo.add_child(forma)
	add_child(cuerpo)
	# Silueta del jefe al fondo: sólo ojos y contorno, para no spoilear.
	_silueta = Node2D.new()
	_silueta.position = Vector2(1500, 0)
	_silueta.z_index = -5
	_silueta.draw.connect(_dibujar_silueta)
	add_child(_silueta)


func _dibujar_silueta() -> void:
	_silueta.draw_circle(Vector2(0, -200), 260, Color(0.05, 0.05, 0.07))
	var brillo := 0.75 + 0.25 * sin(_ojos_t * 3.0)
	for x in [-90.0, 90.0]:
		_silueta.draw_circle(Vector2(x, -230), 26, Color(1.0, 0.78, 0.3, brillo))


func _armar_jugador() -> void:
	player = preload("res://scenes/player.tscn").instantiate()
	player.god_mode = true          # el trailer no muere: enemigos pegan, el jugador no cae
	player.energia_infinita = true
	add_child(player)


func _armar_camara() -> void:
	cam = Camera2D.new()
	cam.set_script(preload("res://scripts/camera.gd"))
	cam.shake_entrada_arena = 0.0    # sin temblor ni punch al pasar a modo fijo
	cam.golpe_entrada_arena = 1.0
	add_child(cam)
	cam.make_current()


func _armar_ui() -> void:
	var capa := CanvasLayer.new()
	capa.layer = 50
	add_child(capa)
	_velo = ColorRect.new()
	_velo.color = Color.BLACK
	_velo.set_anchors_preset(Control.PRESET_FULL_RECT)
	_velo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	capa.add_child(_velo)
	_subtitulo = _label_centrado(capa, 64, Control.PRESET_CENTER_BOTTOM, -200.0)
	_titulo = _label_centrado(capa, 120, Control.PRESET_CENTER, -60.0)
	_titulo.modulate.a = 0.0


func _label_centrado(padre: Node, tamano: int, preset: int, y: float) -> Label:
	var l := Label.new()
	l.set_anchors_preset(preset)
	l.offset_left = -900.0
	l.offset_right = 900.0
	l.offset_top = y
	l.offset_bottom = y + 140.0
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_font_size_override("font_size", tamano)
	l.add_theme_color_override("font_outline_color", Color.BLACK)
	l.add_theme_constant_override("outline_size", 8)
	l.modulate.a = 0.0
	padre.add_child(l)
	return l


func _decir(texto: String, dur: float = 2.5) -> void:
	_subtitulo.text = texto
	var t := create_tween()
	t.tween_property(_subtitulo, "modulate:a", 1.0, 0.3)
	t.tween_interval(dur)
	t.tween_property(_subtitulo, "modulate:a", 0.0, 0.4)


func _destello(alfa: float = 0.9, dur: float = 0.4) -> void:
	_velo.color = Color(1, 1, 1, alfa)
	create_tween().tween_property(_velo, "color:a", 0.0, dur)


func _esperar(seg: float) -> void:
	await get_tree().create_timer(seg).timeout


func _atacar(tipo: String, veces: int, pausa: float) -> void:
	for i in veces:
		var data = player.forms[player.current_form]
		player._procesar_ataque(tipo, data, false)
		await _esperar(pausa)


func _transformar(forma: int) -> void:
	player._transformar(forma, true)
	await _esperar(0.5)


func _spawn_enemigo(tipo: String, x: float) -> void:
	var e: Node2D = preload("res://scenes/enemy.tscn").instantiate()
	e.tipo = tipo
	e.spawn_telegrafiado = true
	e.position = Vector2(x, 0)
	add_child(e)


func _secuencia() -> void:
	# 0-8 s: calma. Fade desde negro y paneo lento hacia el bosque.
	cam.modo_arena(Vector2(-350, -80))
	cam.fijar_zoom(Vector2(0.75, 0.75))
	create_tween().tween_property(_velo, "color:a", 0.0, 2.0)
	create_tween().tween_property(cam, "_fija_pos", Vector2(250, -80), 8.0)
	await _esperar(8.0)

	# 8-20 s: amenaza. Aparecen los cultistas con círculo ritual.
	_spawn_enemigo("cultista", 520.0)
	_spawn_enemigo("arquero", 760.0)
	_spawn_enemigo("cultista", 980.0)
	_decir("Algo despertó.")
	cam.mover_arena(Vector2(500, -80))
	cam.fijar_zoom(Vector2(0.9, 0.9))
	await _esperar(12.0)

	# 20-30 s: gancho. Zoom, flash, freeze y entrada como Lobo.
	cam.fijar_zoom(Vector2(1.3, 1.3))
	cam.mover_arena(Vector2(120, -120))
	player._freeze_slowmo(0.8, 0.25)
	_destello()
	await _esperar(0.6)
	await _transformar(1)
	cam.punch(1.1)
	cam.shake(10.0, 0.4)
	cam.fijar_zoom(Vector2(0.95, 0.95))
	await _atacar("light", 3, 0.55)

	# 30-55 s: montaje. Una forma por tramo, cada una con su golpe.
	_decir("Cuatro formas.", 2.0)
	await _transformar(2)                  # Oso
	cam.shake(14.0, 0.35)
	await _atacar("heavy", 2, 0.9)
	await _transformar(3)                  # Murciélago
	await _atacar("special", 3, 0.6)
	await _transformar(0)                  # Humano
	await _atacar("light", 4, 0.4)
	await _transformar(1)                  # Lobo, para el costo
	await _atacar("heavy", 2, 0.7)

	# 55-68 s: costo. La energía baja y vuelve a Humano.
	_decir("Pero toda forma tiene un precio.", 3.0)
	player.energia_infinita = false
	player.energia = 30.0
	cam.fijar_zoom(Vector2(1.0, 1.0))
	var t := 0.0
	while t < 9.0 and player.current_form != 0:
		await _esperar(0.2)
		t += 0.2
	await _esperar(1.0)

	# 68-80 s: jefe en silueta, luego clímax y silencio.
	cam.mover_arena(Vector2(1000, -120))
	cam.fijar_zoom(Vector2(0.75, 0.75))
	await _esperar(4.0)
	cam.mover_arena(Vector2(160, -100))
	cam.fijar_zoom(Vector2(1.2, 1.2))
	for i in 3:
		_destello(0.7, 0.2)
		cam.shake(12.0, 0.25)
		player._freeze_hitstop(0.12)
		await _esperar(0.45)
	await _atacar("heavy", 1, 0.8)
	_velo.color = Color.BLACK
	await _esperar(1.0)

	# Cierre: título con fade.
	_titulo.text = "SPIRIT KEEPER"
	create_tween().tween_property(_titulo, "modulate:a", 1.0, 1.2)
	create_tween().tween_property(_velo, "color:a", 0.0, 1.5)
	await _esperar(5.0)
	if salir_al_final:
		get_tree().quit()
