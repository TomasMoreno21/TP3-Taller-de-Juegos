extends Control

const SCENE_JUEGO := "res://scenes/comic_intro.tscn"   # intro en viÃ±etas; al terminar carga nivel1
const SCENE_CONTROLES := "res://scenes/controls.tscn"
const SCENE_OPCIONES := "res://scenes/opciones.tscn"
const SCENE_CREDITOS := "res://scenes/creditos_final.tscn"   # los mismos crÃ©ditos del final (Esc o al terminar vuelve al menÃº)
const SCENE_MODO_PRUEBA := "res://scripts/modo_prueba_panel.gd"   # panel armado por cÃ³digo

@export var ojo_cuadros: Array[Texture2D] = [
	preload("res://Sprites/Menu/ojo/entre1.png"),
	preload("res://Sprites/Menu/ojo/entre2.png"),
	preload("res://Sprites/Menu/ojo/ojo-cerrado.png"),
]   ## luna cerrándose → párpado cerrado
@export var seg_cuadro_abre := 0.07     ## s por cuadro al abrirse el ojo
@export var seg_cuadro_ojo := 0.14      ## s que dura cada cuadro intermedio
@export var pausa_ojo_cerrado := 0.5    ## s que se sostiene el ojo cerrado
@export var escala_ojo := 1.0           ## ajuste fino del tamaño de estos cuadros respecto de la luna
@export var iris_cuadros: Array[Texture2D] = [
	preload("res://Sprites/Menu/ojo/iris1.png"),
	preload("res://Sprites/Menu/ojo/iris2.png"),
	preload("res://Sprites/Menu/ojo/iris3.png"),
]
@export var pupila_cuadros: Array[Texture2D] = [
	preload("res://Sprites/Menu/ojo/pupila1.png"),
	preload("res://Sprites/Menu/ojo/pupila2.png"),
	preload("res://Sprites/Menu/ojo/pupila3.png"),
]
@export var pupila_offset := Vector2.ZERO   ## desplazamiento de la pupila respecto del centro del iris (px del arte)
@export var fps_ojo := 9.0                  ## velocidad del loop de iris y pupila
@export var abre_cuadros: Array[Texture2D] = [
	preload("res://Sprites/Menu/ojo/entre-c-o1.png"),
	preload("res://Sprites/Menu/ojo/entre-c-o2.png"),
	preload("res://Sprites/Menu/ojo/entre-c-o3.png"),
]   ## párpado abriéndose
@export var abierto_cuadros: Array[Texture2D] = [
	preload("res://Sprites/Menu/ojo/ojo-abierto1.png"),
	preload("res://Sprites/Menu/ojo/ojo-abierto2.png"),
	preload("res://Sprites/Menu/ojo/ojo-abierto3.png"),
]   ## ojo abierto en loop
@export var pausa_ojo_abierto := 1.0   ## s que se sostiene el ojo abierto
var _parpado: Sprite2D
var _iris: Sprite2D
var _pupila: Sprite2D
var _t_ojo := 0.0
var _jugando := false
var _indice := 0
var _controls: CanvasLayer

@onready var botones: Array[Button] = [
	$UI/Menu/Options/Jugar,
	$UI/Menu/Options/Niveles,
	$UI/Menu/Options/Controles,
	$UI/Menu/Options/Opciones,
	$UI/Menu/Options/Creditos,
	$UI/Menu/Options/Salir,
]


@export var musica: AudioStream = preload("res://assets/audio/menu/dark_cavern_ambient_001.ogg")
@export var musica_volumen_db: float = -18.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	if musica != null:
		var mp := AudioStreamPlayer.new()
		musica.loop = true
		mp.stream = musica
		mp.volume_db = musica_volumen_db
		add_child(mp)
		mp.play()
	var modo_prueba := get_node_or_null("/root/ModoPrueba")
	if modo_prueba == null or not modo_prueba.habilitado:   # versiÃ³n final: sin selector de nivel
		botones.erase($UI/Menu/Options/Niveles)
		$UI/Menu/Options/Niveles.hide()
	else:
		_poner_version(modo_prueba.version_texto)
	for i in botones.size():
		botones[i].pressed.connect(_on_boton_pressed.bind(i))
		botones[i].focus_entered.connect(_on_focus.bind(i))
	botones[0].grab_focus.call_deferred()
	_precargar_juego.call_deferred()
	_animar_entrada()


func _precargar_juego() -> void:
	TransicionPantalla.de(get_tree()).precargar(SCENE_JUEGO)


func _animar_entrada() -> void:
	$UI.modulate.a = 0.0
	var t := create_tween()
	t.tween_property($UI, "modulate:a", 1.0, 0.5).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)


func _unhandled_input(event: InputEvent) -> void:
	if is_instance_valid(_controls):
		return
	if (event.is_action_pressed("move_up") or event.is_action_pressed("ui_up")):
		_navegar(-1)
		get_viewport().set_input_as_handled()
	elif (event.is_action_pressed("move_down") or event.is_action_pressed("ui_down")):
		_navegar(1)
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("menu_confirm"):
		get_viewport().set_input_as_handled()
		_on_boton_pressed(_indice)


## Al cerrar un panel el foco quedó huérfano: se lo devuelve al botón elegido (feedback con mando).
func _refocar() -> void:
	if is_inside_tree():
		botones[_indice].grab_focus.call_deferred()


func _navegar(dir: int) -> void:
	if _jugando:
		return
	_ui("ui_mover")
	_indice = (_indice + dir + botones.size()) % botones.size()
	botones[_indice].grab_focus()


func _on_focus(i: int) -> void:
	_indice = i
	_resaltar(i)


## El botÃ³n con foco crece un poco y los demÃ¡s vuelven a su tamaÃ±o (feedback de selecciÃ³n).
func _resaltar(i: int) -> void:
	for k in botones.size():
		var b := botones[k]
		b.pivot_offset = b.size * 0.5
		var objetivo := Vector2.ONE * (1.06 if k == i else 1.0)
		if DisplayServer.get_name() == "headless":
			b.scale = objetivo
			continue
		var tw := b.create_tween()
		tw.tween_property(b, "scale", objetivo, 0.12).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _on_boton_pressed(i: int) -> void:
	if _jugando:
		return
	_ui("ui_confirmar")
	match botones[i].name:
		&"Jugar":
			_jugar()
		&"Niveles":
			_abrir_niveles()
		&"Controles":
			_abrir_controles()
		&"Opciones":
			_abrir_panel(SCENE_OPCIONES)
		&"Creditos":
			TransicionPantalla.de(get_tree()).cambiar_escena(SCENE_CREDITOS)
		&"Salir":
			get_tree().quit()


## VersiÃ³n de la prueba, abajo a la derecha: los reportes de los testers dicen de quÃ© build hablan.
func _poner_version(texto: String) -> void:
	var l := Label.new()
	l.text = texto
	l.add_theme_font_size_override("font_size", 18)
	l.add_theme_color_override("font_color", Color(0.95, 0.85, 0.4, 0.8))
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	l.anchor_left = 1.0
	l.anchor_right = 1.0
	l.anchor_top = 1.0
	l.anchor_bottom = 1.0
	l.offset_left = -420.0
	l.offset_right = -24.0
	l.offset_top = -52.0
	l.offset_bottom = -24.0
	add_child(l)


func _abrir_niveles() -> void:
	var c: CanvasLayer = (load(SCENE_MODO_PRUEBA) as GDScript).new()
	c.en_juego = false
	_controls = c
	c.tree_exited.connect(_refocar)
	add_child(c)


## Jugar: el menú se apaga y la luna se cierra hasta quedar el párpado cerrado del ojo (el resto de la animación
## —abrirse, resplandor saliendo del ojo— se suma después) y recién entonces arranca el juego.
func _jugar() -> void:
	if _jugando:
		return
	_jugando = true
	await _animar_ojo()
	_ir_al_juego()


func _animar_ojo() -> void:
	var luna := $UI/Luna as TextureRect
	var rapido := DisplayServer.get_name() == "headless"
	# El menú (todo menos el fondo y la luna) se desvanece.
	var apagar: Array[CanvasItem] = []
	for n in get_children():
		if n != $Background and n != $UI and n is CanvasItem:
			apagar.append(n)
	for n in $UI.get_children():
		if n != luna and n is CanvasItem:
			apagar.append(n)
	if not rapido:
		var t := create_tween().set_parallel(true)
		for n in apagar:
			t.tween_property(n, "modulate:a", 0.0, 0.35)
	# Los cuadros se centran en la luna y se escalan igual que ella en pantalla.
	var tex_luna := luna.texture
	var esc := minf(luna.size.x / tex_luna.get_width(), luna.size.y / tex_luna.get_height()) * luna.scale.x
	var sprite := Sprite2D.new()
	sprite.position = luna.get_global_transform() * (luna.size * 0.5)
	sprite.scale = Vector2.ONE * esc * escala_ojo
	$UI.add_child(sprite)
	for i in ojo_cuadros.size():
		sprite.texture = ojo_cuadros[i]
		luna.visible = false
		if not rapido:
			await get_tree().create_timer(pausa_ojo_cerrado if i == ojo_cuadros.size() - 1 else seg_cuadro_ojo).timeout
	# Detrás del párpado: iris y, encima, la pupila (en loop). Los párpados que se abren van por delante.
	_iris = _sprite_loop(iris_cuadros, sprite.position, sprite.scale)
	_pupila = _sprite_loop(pupila_cuadros, sprite.position + pupila_offset * sprite.scale, sprite.scale)
	$UI.move_child(sprite, -1)
	# El párpado se abre (entre-close-open, por delante de iris y pupila) y queda el ojo abierto en loop.
	for c in abre_cuadros:
		sprite.texture = c
		if not rapido:
			await get_tree().create_timer(seg_cuadro_abre).timeout
	_parpado = sprite
	if not rapido:
		await get_tree().create_timer(pausa_ojo_abierto).timeout


## Sprite que cicla sus cuadros (ver `_process`), centrado en `pos`.
func _sprite_loop(cuadros: Array[Texture2D], pos: Vector2, esc: Vector2) -> Sprite2D:
	var s := Sprite2D.new()
	s.texture = cuadros[0]
	s.position = pos
	s.scale = esc
	$UI.add_child(s)
	return s


func _process(delta: float) -> void:
	_t_ojo += delta
	var k := int(_t_ojo * fps_ojo)
	if is_instance_valid(_iris):
		_iris.texture = iris_cuadros[k % iris_cuadros.size()]
	if is_instance_valid(_pupila):
		_pupila.texture = pupila_cuadros[k % pupila_cuadros.size()]
	if is_instance_valid(_parpado):
		_parpado.texture = abierto_cuadros[k % abierto_cuadros.size()]


func _ir_al_juego() -> void:
	get_node("/root/Progresion").reset()
	TransicionPantalla.de(get_tree()).cambiar_escena(SCENE_JUEGO)


func _abrir_controles() -> void:
	_abrir_panel(SCENE_CONTROLES)


func _abrir_panel(ruta: String) -> void:
	var c: CanvasLayer = (load(ruta) as PackedScene).instantiate()
	_controls = c
	c.tree_exited.connect(_refocar)
	add_child(c)


func _ui(nombre: String) -> void:
	var audio := get_node_or_null("/root/AudioManager")
	if audio != null:
		audio.play_ui(nombre)
