@tool
extends StaticBody2D
## Nudo de raíz en la base del tallo de la Estrella. Solo el Oso lo rompe (golpe fuerte,
## especial o combo: `dano_minimo`). Roto, la Estrella pierde apoyo y se inclina: el ojo
## baja a la altura de un golpe. Solo se puede golpear mientras está `activo`.
## No frena al jugador (está en el centro de la arena). Todo editable en el Inspector.

signal roto

@export var tam := Vector2(170, 210):
	set(v):
		tam = v
		_sincronizar()
@export var color_raiz := Color(0.36, 0.22, 0.3):
	set(v):
		color_raiz = v
		queue_redraw()
@export var color_brillo := Color(1.0, 0.45, 0.85)   ## pulso cuando se puede romper
@export_group("Resistencia")
@export var forma_requerida := 2            ## 2 = Oso (-1 = cualquiera)
@export var dano_minimo := 24               ## el ligero del Oso (16) no alcanza
@export var golpes_para_romper := 3
@export var tip_forma := ""                 ## texto del Amuleto si lo golpea otra forma ("" = sin tip)
@export_group("Efectos")
@export var shake_romper := 10.0
@export var sonido_golpe: AudioStream = preload("res://assets/audio/sfx/gen/rompible_golpe.wav")
@export var sonido_romper: AudioStream = preload("res://assets/audio/sfx/gen/rompible_romper.wav")
@export var volumen_db := -6.0
@export_group("")
@export var mostrar_arte := true   ## false = el nudo no dibuja (lo reemplaza el cuerpo nuevo)

var activo := false
var golpes := 0
var _roto := false
var _t := 0.0
var _tw: Tween
var _pos_base := Vector2.ZERO


func _ready() -> void:
	_pos_base = position
	_sincronizar()
	if Engine.is_editor_hint():
		return
	add_to_group("nudo_tallo")
	collision_layer = 2
	collision_mask = 0
	_poner_colision(false)


func _sincronizar() -> void:
	var cs := get_node_or_null("Collision") as CollisionShape2D
	if cs != null:
		if cs.shape == null or not (cs.shape is RectangleShape2D):
			cs.shape = RectangleShape2D.new()
		(cs.shape as RectangleShape2D).size = tam
		cs.position = Vector2(0, -tam.y * 0.5)
	queue_redraw()


func _process(delta: float) -> void:
	if Engine.is_editor_hint():
		return
	if activo:
		_t += delta
		queue_redraw()


## Se puede romper (el ojo ya se abrió).
func activar() -> void:
	activo = true
	_roto = false
	golpes = 0
	visible = mostrar_arte
	scale = Vector2.ONE
	modulate.a = 1.0
	_poner_colision(true)
	var p := get_tree().get_first_node_in_group("player")
	if p is PhysicsBody2D:
		(p as PhysicsBody2D).add_collision_exception_with(self)
	queue_redraw()


## Vuelve a crecer (fin del castigo o reinicio de la pelea).
func restaurar() -> void:
	activo = false
	_roto = false
	golpes = 0
	_poner_colision(false)
	if _tw != null and _tw.is_valid():
		_tw.kill()
	visible = mostrar_arte
	position = _pos_base
	modulate.a = 1.0
	if DisplayServer.get_name() == "headless":
		scale = Vector2.ONE
	else:
		scale = Vector2(1.0, 0.1)
		_tw = create_tween()
		_tw.tween_property(self, "scale", Vector2.ONE, 0.5).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	queue_redraw()


func esta_roto() -> bool:
	return _roto


func registrar_golpe(dano: int) -> void:
	if not activo or _roto:
		return
	var jugador := get_tree().get_first_node_in_group("player")
	if forma_requerida >= 0 and jugador != null and int(jugador.get("current_form")) != forma_requerida:
		_sacudir(3.0)
		if tip_forma != "" and jugador.has_method("_tip_una_vez"):
			jugador.call("_tip_una_vez", "nudo_tallo", tip_forma)
		return
	if dano < dano_minimo:
		_sacudir(4.0)
		return
	golpes += 1
	_sonar(sonido_golpe)
	Burst.emitir(self, global_position + Vector2(0, -tam.y * 0.5), color_raiz.lightened(0.3), 6 + golpes * 3, 0.9)
	queue_redraw()
	if golpes >= golpes_para_romper:
		_romper()
	else:
		_sacudir(7.0)


## Para tests y la consola: rompe sin chequear forma.
func romper_forzado() -> void:
	if activo and not _roto:
		_romper()


func _romper() -> void:
	_roto = true
	activo = false
	_poner_colision(false)
	_sonar(sonido_romper)
	JuiceFx.escombros(get_tree(), global_position + Vector2(0, -tam.y * 0.5), color_raiz, 14, 1.1)
	var cam := get_viewport().get_camera_2d()
	if cam != null and cam.has_method("shake"):
		cam.shake(shake_romper, 0.25)
	roto.emit()
	if DisplayServer.get_name() == "headless":
		return
	if _tw != null and _tw.is_valid():
		_tw.kill()
	_tw = create_tween().set_parallel(true)
	_tw.tween_property(self, "scale", Vector2(1.2, 0.15), 0.2).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	_tw.tween_property(self, "modulate:a", 0.25, 0.2)


func _poner_colision(on: bool) -> void:
	var cs := get_node_or_null("Collision") as CollisionShape2D
	if cs != null:
		cs.set_deferred("disabled", not on)


func _sacudir(fuerza: float) -> void:
	_sonar(sonido_golpe)
	if DisplayServer.get_name() == "headless":
		return
	if _tw != null and _tw.is_valid():
		_tw.kill()
	position = _pos_base
	_tw = create_tween()
	_tw.tween_property(self, "position", _pos_base + Vector2(fuerza, 0), 0.03)
	_tw.tween_property(self, "position", _pos_base - Vector2(fuerza * 0.7, 0), 0.04)
	_tw.tween_property(self, "position", _pos_base, 0.05)


func _sonar(s: AudioStream) -> void:
	var audio := get_node_or_null("/root/AudioManager")
	if audio != null and s != null:
		audio.play_sfx(s, volumen_db, 0.08)


func _draw() -> void:
	# Bulbo de raíces apretadas, más ancho abajo; grietas según los golpes.
	var w := tam.x * 0.5
	var forma := PackedVector2Array([
		Vector2(-w, 0), Vector2(-w * 0.85, -tam.y * 0.45), Vector2(-w * 0.45, -tam.y * 0.85),
		Vector2(0, -tam.y), Vector2(w * 0.45, -tam.y * 0.85), Vector2(w * 0.85, -tam.y * 0.45), Vector2(w, 0)])
	draw_colored_polygon(forma, color_raiz)
	for i in 3:
		var x := -w * 0.5 + w * 0.5 * i
		draw_line(Vector2(x, -4.0), Vector2(x * 0.4, -tam.y * 0.9), color_raiz.darkened(0.4), 4.0)
	for g in golpes:
		var gx := -w * 0.4 + w * 0.4 * g
		draw_polyline(PackedVector2Array([Vector2(gx, -tam.y * 0.85), Vector2(gx - 12.0, -tam.y * 0.5), Vector2(gx + 8.0, -tam.y * 0.15)]), Color(0, 0, 0, 0.6), 4.0)
	if activo:
		var pulso := 0.35 + 0.35 * (0.5 + 0.5 * sin(_t * 7.0))
		var borde := forma.duplicate()
		borde.append(forma[0])
		draw_polyline(borde, Color(color_brillo.r, color_brillo.g, color_brillo.b, pulso), 6.0, true)
