extends Area2D
## Puerta de salida colocable: al tocarla, el jugador pasa a la siguiente escena.

signal alcanzada   ## el jugador llegó a la salida (los objetivos de lista del tipo "Llegá a…" se tachan con esto)
## `siguiente_escena` es editable desde el Inspector (ninguna ruta hardcodeada en el nivel).

@export var siguiente_escena: String = ""
@export var color := Color(0.8, 0.7, 0.3)
@export var sonido_salida: AudioStream = preload("res://assets/audio/sfx/gen/zona_despejada.wav")
@export var volumen_salida_db := -8.0
@export_group("Salida por la oscuridad")
@export var modo_oscuridad := false                    ## la cueva sigue y se oscurece: el jugador camina solo hasta desaparecer
@export var hacia_izquierda := false                    ## el jugador entra desde la derecha: el degradé y el negro sólido se extienden hacia la izquierda
@export var largo_oscuridad := 380.0                   ## tramo del degradé (en la dirección de entrada)
@export var velocidad_entrada := 0.4                   ## 0.35 = paso tranquilo
@export var espera_maxima := 5.0                       ## seguro por si el jugador se traba
@export var color_oscuridad := Color(0, 0, 0)          ## tinte de la oscuridad (distinto por zona)
@export var alto_oscuridad_arriba := 1400.0           ## cuánto sube la oscuridad desde la puerta (px)
@export var alto_oscuridad_abajo := 700.0             ## cuánto baja (px)
@export var ancho_oscuridad_solida := 3000.0          ## ancho del negro sólido tras el degradé (px)
@export var difuminado_vertical := 350.0              ## px en que los bordes de arriba y abajo se desvanecen (así no se ve un cuadrado)
@export var cubrir_pantalla := true                   ## al avanzar por el degradé, la oscuridad cubre TODA la pantalla (no solo el rectángulo)
@export_group("Aspecto de umbral")
@export var color_marco := Color(0.13, 0.11, 0.1)      ## piedra del arco
@export var color_interior := Color(0.02, 0.02, 0.03)  ## oscuridad al otro lado
@export var ancho_arco := 180.0
@export var alto_arco := 380.0
@export var bajar_arco := 44.0                          ## apoya el arco en el piso (el área queda donde está)
@export var pulso := 0.18                              ## cuánto respira la luz
@export var particulas := true                         ## motas de luz flotando alrededor
@export_group("")
@export var precargar_siguiente := true   ## carga la siguiente escena en segundo plano para que la transición no espere

var _usada := false
var _t := 0.0
var _velo: ColorRect
var _jugador: Node2D

@onready var visual: Polygon2D = $Visual


func _ready() -> void:
	monitoring = true
	collision_layer = 0
	collision_mask = 4
	body_entered.connect(_on_body_entered)
	if modo_oscuridad:
		z_index = 100
		if visual != null:
			visual.visible = false
		var l := get_node_or_null("Luz") as PointLight2D
		if l != null:
			l.visible = false
		if cubrir_pantalla and DisplayServer.get_name() != "headless":
			_crear_velo()
	elif visual != null:
		visual.color = Color(color, 0.15)
	if particulas and not modo_oscuridad and DisplayServer.get_name() != "headless":
		_crear_particulas()
	queue_redraw()
	var luz := get_node_or_null("Luz") as PointLight2D
	if luz != null:
		luz.color = Color(color, 1.0)
	if precargar_siguiente and not siguiente_escena.is_empty():
		await get_tree().create_timer(3.0, false).timeout
		TransicionPantalla.de(get_tree()).precargar(siguiente_escena)


func _on_body_entered(_body: Node2D) -> void:
	if _usada or siguiente_escena.is_empty():
		return
	_usada = true
	alcanzada.emit()
	if modo_oscuridad:
		_entrar_oscuridad(_body)
		return
	var audio := get_node_or_null("/root/AudioManager")
	if audio != null:
		audio.play_sfx(sonido_salida, volumen_salida_db)
	TransicionPantalla.de(get_tree()).cambiar_escena(siguiente_escena)


func _entrar_oscuridad(jugador: Node) -> void:
	jugador.set("cinematica_activa", true)
	jugador.set("cinematica_dir", velocidad_entrada * _signo())
	var x_fin := global_position.x + _signo() * largo_oscuridad * 0.8
	var t := 0.0
	while t < espera_maxima and (jugador as Node2D).global_position.x * _signo() < x_fin * _signo():
		await get_tree().process_frame
		t += get_process_delta_time()
	var audio := get_node_or_null("/root/AudioManager")
	if audio != null:
		audio.play_sfx(sonido_salida, volumen_salida_db)
	TransicionPantalla.de(get_tree()).cambiar_escena(siguiente_escena)


## +1 si la oscuridad se extiende hacia la derecha, -1 hacia la izquierda.
func _signo() -> float:
	return -1.0 if hacia_izquierda else 1.0


func _crear_velo() -> void:
	var capa := CanvasLayer.new()
	capa.layer = 30   # sobre el mundo, debajo de cartelería e intro
	add_child(capa)
	_velo = ColorRect.new()
	_velo.color = Color(color_oscuridad, 0.0)
	_velo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_velo.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	capa.add_child(_velo)


func _process(delta: float) -> void:
	if modo_oscuridad:
		if _velo != null:
			if not is_instance_valid(_jugador):
				_jugador = get_tree().get_first_node_in_group("player") as Node2D
			if _jugador != null:
				# Solo dentro del rectángulo de oscuridad (otros tramos del nivel pueden pasar por la misma x).
				var d := _jugador.global_position - global_position
				var dx := d.x * _signo()
				var dentro := d.y > -alto_oscuridad_arriba and d.y < alto_oscuridad_abajo and dx < largo_oscuridad + ancho_oscuridad_solida
				var k := clampf(dx / (largo_oscuridad * 0.8), 0.0, 1.0) if dentro else 0.0
				_velo.color.a = smoothstep(0.15, 1.0, k)
		return
	_t += delta
	var k := 0.5 + 0.5 * sin(_t * 2.0)
	if visual != null:
		visual.modulate.a = 1.0 - pulso + pulso * k
	var luz := get_node_or_null("Luz") as PointLight2D
	if luz != null:
		luz.energy = 1.4 + pulso * 2.0 * k


## Arco de piedra con el interior oscuro y un borde luminoso: se lee como "otra zona".
func _draw() -> void:
	if modo_oscuridad:
		_dibujar_oscuridad()
		return
	draw_set_transform(Vector2(0, bajar_arco))
	var hw := ancho_arco * 0.5
	var base := alto_arco * 0.5
	var r := hw
	var cuerpo := PackedVector2Array([Vector2(-hw, base), Vector2(-hw, -base + r)])
	for i in range(1, 13):
		var a := PI + PI * float(i) / 12.0
		cuerpo.append(Vector2(cos(a) * r, -base + r + sin(a) * r))
	cuerpo.append(Vector2(hw, base))
	var marco := 28.0
	draw_colored_polygon(_expandir(cuerpo, marco), color_marco)
	draw_colored_polygon(cuerpo, color_interior)
	for i in 6:
		var f := float(i) / 6.0
		draw_colored_polygon(_escalar(cuerpo, 1.0 - f * 0.5), Color(color, 0.04 + 0.03 * f))
	draw_polyline(cuerpo + PackedVector2Array([cuerpo[0]]), Color(color, 0.8), 3.0)


func _expandir(p: PackedVector2Array, m: float) -> PackedVector2Array:
	var o := PackedVector2Array()
	for v in p:
		o.append(Vector2(v.x + signf(v.x) * m, v.y - m if v.y < 0.0 else v.y))
	return o


func _escalar(p: PackedVector2Array, k: float) -> PackedVector2Array:
	var o := PackedVector2Array()
	for v in p:
		o.append(Vector2(v.x * k, v.y * k + (1.0 - k) * alto_arco * 0.5))
	return o


func _crear_particulas() -> void:
	var c := CPUParticles2D.new()
	c.amount = 24
	c.lifetime = 2.4
	c.preprocess = 2.0
	c.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	c.emission_rect_extents = Vector2(ancho_arco * 0.5 + 120.0, alto_arco * 0.4)
	c.gravity = Vector2.ZERO
	c.initial_velocity_min = 0.0
	c.initial_velocity_max = 8.0
	c.linear_accel_min = 0.0
	c.linear_accel_max = 0.0
	c.scale_amount_min = 2.0
	c.scale_amount_max = 4.0
	c.color = Color(color, 0.7)
	add_child(c)


## Degradé de transparente a negro hacia la derecha (o la izquierda), y negro sólido después: el jugador se "apaga" al entrar.
func _dibujar_oscuridad() -> void:
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(_signo(), 1.0))
	var arriba := alto_oscuridad_arriba
	var abajo := alto_oscuridad_abajo
	var c0 := Color(color_oscuridad, 0.0)
	var c1 := Color(color_oscuridad, 1.0)
	draw_polygon(PackedVector2Array([Vector2(0, -arriba), Vector2(largo_oscuridad, -arriba), Vector2(largo_oscuridad, abajo), Vector2(0, abajo)]), PackedColorArray([c0, c1, c1, c0]))
	draw_rect(Rect2(largo_oscuridad - 1.0, -arriba, ancho_oscuridad_solida, arriba + abajo), c1)
	# Bordes de arriba y abajo difuminados: la oscuridad se funde con la cueva en vez de cortarse en recto.
	var f := difuminado_vertical
	if f > 0.0:
		var xs := largo_oscuridad + ancho_oscuridad_solida
		for lado in [-1.0, 1.0]:
			var y0: float = -arriba if lado < 0.0 else abajo
			var y1: float = y0 + lado * f
			draw_polygon(PackedVector2Array([Vector2(0, y0), Vector2(largo_oscuridad, y0), Vector2(largo_oscuridad, y1), Vector2(0, y1)]), PackedColorArray([c0, c1, c0, c0]))
			draw_polygon(PackedVector2Array([Vector2(largo_oscuridad - 1.0, y0), Vector2(xs, y0), Vector2(xs, y1), Vector2(largo_oscuridad - 1.0, y1)]), PackedColorArray([c1, c1, c0, c0]))
