@tool
extends Area2D
## Losa de peso: se activa cuando el Oso la aplasta con un pisotón o cae sobre ella con fuerza.
## Al activarse se hunde, sacude la cámara y abre los objetivos (`abrir()`), p. ej. muros
## de piedra en modo compuerta. Tamaño, colores y umbral editables desde el Inspector.

signal activada

@export var tam := Vector2(220, 26):
	set(v):
		tam = v
		_sincronizar()
@export var color_losa := Color(0.5, 0.36, 0.28):
	set(v):
		color_losa = v
		queue_redraw()
@export var color_runa := Color(1.0, 0.7, 0.3):
	set(v):
		color_runa = v
		queue_redraw()
@export var forma_requerida := 2            ## 2 = Oso
@export var impacto_minimo := 520.0         ## velocidad de caída mínima para activarla al aterrizar
@export var acepta_pisoton := true
@export var objetivos: Array[NodePath] = []  ## nodos con abrir() (muro_piedra) que se abren al activarla
@export var una_sola_vez := true
@export var tip_forma := "Esta losa cede solo bajo el peso del Oso: aplastala con un pisotón."
@export var sonido: AudioStream = preload("res://assets/audio/sfx/gen/fragil_romper.wav")
@export var volumen_db := -5.0

var _hundida := 0.0
var _activa := false
var _jugador: Node


func _ready() -> void:
	_sincronizar()
	if Engine.is_editor_hint():
		return
	collision_layer = 0
	collision_mask = 4
	monitoring = true
	add_to_group("losa_peso")
	# Diferido: si el Player está más abajo en el árbol, todavía no entró al grupo en este _ready.
	_conectar_jugador.call_deferred()


func _conectar_jugador() -> void:
	_jugador = get_tree().get_first_node_in_group("player")
	if _jugador != null:
		_jugador.aterrizaje_fuerte.connect(_al_aterrizar)
		_jugador.pisoton.connect(_al_pisoton)


func _sincronizar() -> void:
	var cs := get_node_or_null("Collision") as CollisionShape2D
	if cs != null:
		if cs.shape == null or not (cs.shape is RectangleShape2D):
			cs.shape = RectangleShape2D.new()
		cs.shape.size = tam + Vector2(0, 40)
		cs.position = Vector2(0, -tam.y * 0.5 - 10.0)
	queue_redraw()


func _draw() -> void:
	var r := Rect2(Vector2(-tam.x * 0.5, -tam.y + _hundida), Vector2(tam.x, tam.y - _hundida))
	draw_rect(r, color_losa)
	draw_rect(r, color_losa.darkened(0.5), false, 3.0)
	var c := r.get_center()
	var a := 0.9 if _activa else 0.35
	var col := Color(color_runa.r, color_runa.g, color_runa.b, a)
	draw_circle(c, minf(tam.y * 0.3, 8.0), col)
	draw_line(Vector2(c.x - tam.x * 0.3, c.y), Vector2(c.x - 14.0, c.y), col, 3.0)
	draw_line(Vector2(c.x + 14.0, c.y), Vector2(c.x + tam.x * 0.3, c.y), col, 3.0)


func _encima() -> bool:
	if _jugador == null or not is_instance_valid(_jugador):
		return false
	return overlaps_body(_jugador as PhysicsBody2D)


func _es_forma() -> bool:
	return _jugador != null and (forma_requerida < 0 or int(_jugador.get("current_form")) == forma_requerida)


func _al_aterrizar(_pos: Vector2, impacto: float) -> void:
	if impacto >= impacto_minimo and _encima():
		_intentar()


func _al_pisoton(_pos: Vector2) -> void:
	if acepta_pisoton and _encima():
		_intentar()


func _intentar() -> void:
	if _activa and una_sola_vez:
		return
	if not _es_forma():
		if _jugador != null and _jugador.has_method("_tip_una_vez") and tip_forma != "":
			_jugador.call("_tip_una_vez", "losa_peso", tip_forma)
		return
	_activa = true
	activada.emit()
	var audio := get_node_or_null("/root/AudioManager")
	if audio != null and sonido != null:
		audio.play_sfx(sonido, volumen_db, 0.08)
	var cam := get_viewport().get_camera_2d()
	if cam != null and cam.has_method("shake"):
		cam.shake(7.0, 0.2)
	Burst.emitir(self, global_position + Vector2(0, -tam.y), color_losa, 18, 1.1)
	for ruta in objetivos:
		var n := get_node_or_null(ruta)
		if n != null and n.has_method("abrir"):
			n.abrir()
	if DisplayServer.get_name() == "headless":
		_hundida = tam.y * 0.5
		queue_redraw()
		return
	var tw := create_tween()
	tw.tween_method(func(v: float) -> void:
		_hundida = v
		queue_redraw(), 0.0, tam.y * 0.5, 0.18).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
