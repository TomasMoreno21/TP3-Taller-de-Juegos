@tool
extends StaticBody2D
## Ojo verde de la sala del jefe final. La Estrella lo crea por tandas en un punto (`PuntosOjos`):
## aparece, se abre y se cierra con un golpe (da energía) y después se desvanece.
## El sónico NO lo cierra (rebota): hay que pegarle cuerpo a cuerpo.
## Acorazado (F2): solo lo cierra el golpe fuerte del Oso. El rayo lo programa la Estrella:
## `avisar()` enciende la pupila antes de disparar. Lo dibuja `_draw` (se ve en el editor).

signal cerrado

@export var color_coraza := Color(0.55, 0.55, 0.6)
@export var radio := 42.0:
	set(v):
		radio = v
		_sincronizar()
@export var color_contorno := Color(0.42, 0.78, 0.28):
	set(v):
		color_contorno = v
		queue_redraw()
@export var color_iris := Color(0.3, 0.62, 0.22):
	set(v):
		color_iris = v
		queue_redraw()
@export var color_parpado := Color(0.2, 0.7, 0.66):   ## trazo cian del boceto (párpado)
	set(v):
		color_parpado = v
		queue_redraw()
@export var color_aviso := Color(1.0, 0.3, 0.2)        ## pupila antes del rayo
@export var color_fondo := Color(0.06, 0.08, 0.06)
@export var flote_amplitud := 6.0
@export var flote_velocidad := 1.6
@export var duracion_aparecer := 0.3
@export var duracion_desaparecer := 0.35
@export var sonido_cerrar: AudioStream = preload("res://assets/audio/sfx/gen/rompible_golpe.wav")
@export var volumen_db := -6.0
@export var sonido_rebote: AudioStream = preload("res://assets/audio/sfx/gen/rebote_coraza.wav")
@export var marca_tamano := 46.0           ## marca de garra sobre la coraza (solo el Oso la parte)
@export var marca_offset := Vector2.ZERO

var energia := 12.0          # la fija el jefe al abrirlo
var abierto := false
var acorazado := false
var dano_minimo_coraza := 24
var golpe_proyectil := false   # lo marca el proyectil del jugador antes de take_damage
var sonico_cierra := false     # ojos altos: el sónico los persigue y los cierra (lo fija la Estrella antes de add_child)
var _aviso_t := 0.0
var _aviso_dur := 0.0
var _apertura := 0.0         # 0 = cerrado, 1 = abierto (anima el dibujo)
var _t := 0.0
var _base_y := 0.0
var _mirada := Vector2.ZERO
var _tw: Tween
var _saliendo := false
var _marca: Node2D


func _ready() -> void:
	_base_y = position.y
	_t = randf() * TAU
	_sincronizar()
	if Engine.is_editor_hint():
		_apertura = 1.0   # en el editor se ve abierto para ubicarlo
		return
	add_to_group("ojo_verde")
	_marca = preload("res://scripts/marca_garra.gd").new()
	_marca.tamano = marca_tamano
	_marca.position = marca_offset
	_marca.z_index = 1
	add_child(_marca)
	if sonico_cierra:
		add_to_group("cristal")   # el sónico del Murciélago lo persigue
	collision_layer = 2
	collision_mask = 0
	_poner_colision(false)


func _sincronizar() -> void:
	var cs := get_node_or_null("Collision") as CollisionShape2D
	if cs != null:
		if cs.shape == null or not (cs.shape is CircleShape2D):
			cs.shape = CircleShape2D.new()
		(cs.shape as CircleShape2D).radius = radio
	queue_redraw()


func _process(delta: float) -> void:
	if Engine.is_editor_hint():
		return
	_t += delta * flote_velocidad
	position.y = _base_y + sin(_t) * flote_amplitud
	if _aviso_t > 0.0:
		_aviso_t = maxf(_aviso_t - delta, 0.0)
	if abierto:
		var p := get_tree().get_first_node_in_group("player") as Node2D
		if p != null:
			_mirada = _mirada.lerp((p.global_position - global_position).normalized() * radio * 0.28, 6.0 * delta)
	if _marca != null:
		_marca.encendida = acorazado and abierto and not _saliendo
	queue_redraw()


## Aparece (crece desde nada) y se abre tras `retraso` s. Golpeable recién al abrirse.
func aparecer(energia_al_cerrar: float, con_coraza: bool, retraso: float) -> void:
	energia = energia_al_cerrar
	acorazado = con_coraza
	if DisplayServer.get_name() == "headless":
		scale = Vector2.ONE
		_abrir()
		return
	scale = Vector2.ZERO
	_tw = create_tween()
	_tw.tween_interval(maxf(retraso, 0.0))
	_tw.tween_property(self, "scale", Vector2.ONE, duracion_aparecer).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_tw.tween_callback(_abrir)


func _abrir() -> void:
	if _saliendo:
		return
	abierto = true
	_poner_colision(true)
	var p := get_tree().get_first_node_in_group("player")
	if p is PhysicsBody2D:
		(p as PhysicsBody2D).add_collision_exception_with(self)   # flota en el aire: no frena al jugador
	if DisplayServer.get_name() == "headless":
		_apertura = 1.0
		return
	var tw := create_tween()
	tw.tween_property(self, "_apertura", 1.0, 0.3)


## La pupila se enciende `seg` s: el rayo sale de este ojo.
func avisar(seg: float) -> void:
	_aviso_t = seg
	_aviso_dur = maxf(seg, 0.01)


## Se cierra y se desvanece sin premiar (reinicio, fin de tanda o muerte del jefe).
func desaparecer() -> void:
	abierto = false
	_aviso_t = 0.0
	_poner_colision(false)
	_salir()


func take_damage(_cantidad: int, _kb: float = 0.0, _dir: int = 1, _critico: bool = false) -> void:
	if not abierto:
		return
	if golpe_proyectil:
		golpe_proyectil = false
		if not sonico_cierra or acorazado:
			_rebotar()   # los bajos/medios y la coraza no se cierran con el sónico
			return
	var p := get_tree().get_first_node_in_group("player")
	if acorazado and (p == null or int(p.get("current_form")) != 2 or _cantidad < dano_minimo_coraza):
		_rebotar()
		return
	abierto = false
	_aviso_t = 0.0
	_poner_colision(false)
	if p != null and p.has_method("on_enemy_killed") and energia > 0.0:
		p.on_enemy_killed(energia)
	Burst.emitir(self, global_position, color_contorno, 12, 1.0)
	var audio := get_node_or_null("/root/AudioManager")
	if audio != null and sonido_cerrar != null:
		audio.play_sfx(sonido_cerrar, volumen_db, 0.1)
	cerrado.emit()
	_salir()


## Cierra el párpado, se achica y se libera.
func _salir() -> void:
	if _saliendo:
		return
	_saliendo = true
	if _tw != null and _tw.is_valid():
		_tw.kill()
	if DisplayServer.get_name() == "headless":
		queue_free()
		return
	_tw = create_tween()
	_tw.tween_property(self, "_apertura", 0.0, 0.15)
	_tw.tween_property(self, "scale", Vector2.ZERO, duracion_desaparecer).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	_tw.tween_callback(queue_free)


## Golpe que no atraviesa la coraza: sacudida y chispa gris.
func _rebotar() -> void:
	Burst.emitir(self, global_position, color_coraza, 5, 0.6)
	if acorazado and _marca != null:
		_marca.destello()
	var audio := get_node_or_null("/root/AudioManager")
	if audio != null and sonido_rebote != null:
		audio.play_sfx(sonido_rebote, volumen_db - 2.0, 0.1)
	if DisplayServer.get_name() == "headless":
		return
	var tw := create_tween()
	tw.tween_property(self, "scale", Vector2(1.15, 0.9), 0.05)
	tw.tween_property(self, "scale", Vector2.ONE, 0.1)


func _poner_colision(on: bool) -> void:
	var cs := get_node_or_null("Collision") as CollisionShape2D
	if cs != null:
		cs.set_deferred("disabled", not on)


func _draw() -> void:
	var w := radio * 1.35
	var h := radio * 0.62 * maxf(_apertura, 0.06)
	# Almendra del ojo.
	var almendra := PackedVector2Array()
	for i in 24:
		var a := TAU * float(i) / 24.0
		almendra.append(Vector2(cos(a) * w, sin(a) * h * (1.0 - 0.35 * absf(cos(a)))))
	draw_colored_polygon(almendra, color_fondo)
	if _apertura > 0.2:
		var r_iris := minf(radio * 0.42, h * 0.95)
		var col_iris := color_iris
		if _aviso_t > 0.0:
			# Aviso del rayo: la pupila se enciende y crece hasta el disparo.
			var k := 1.0 - _aviso_t / _aviso_dur
			col_iris = color_aviso
			r_iris *= 1.0 + 0.35 * k
		draw_circle(_mirada, r_iris, col_iris)
		draw_circle(_mirada, r_iris * 0.45, color_fondo)
	almendra.append(almendra[0])
	draw_polyline(almendra, color_contorno, 4.0, true)
	if acorazado and abierto:
		draw_arc(Vector2.ZERO, w * 1.08, 0.0, TAU, 28, color_coraza, 9.0, true)
		for i in 6:
			var a := TAU * float(i) / 6.0
			draw_circle(Vector2(cos(a), sin(a)) * w * 1.08, 6.0, color_coraza.lightened(0.3))
		# Zarpa sobre la coraza: este ojo es del Oso.
		var c := Vector2(0, -w * 1.08 - 26.0)
		draw_circle(c + Vector2(0, 6), 11.0, color_coraza.lightened(0.45))
		for dx in [-13.0, 0.0, 13.0]:
			draw_circle(c + Vector2(dx, -10.0 - (3.0 if dx == 0.0 else 0.0)), 5.0, color_coraza.lightened(0.45))
	# Párpado: trazo cian que atraviesa el ojo (como en el boceto); cerrado tapa todo.
	var y_parpado := -h * 0.55 if _apertura > 0.5 else 0.0
	draw_line(Vector2(-w * 1.15, y_parpado - 6.0), Vector2(w * 1.15, y_parpado + 4.0), color_parpado, 5.0, true)
	draw_line(Vector2(-w * 0.9, y_parpado + 2.0), Vector2(w * 0.95, y_parpado - 5.0), color_parpado, 3.0, true)
