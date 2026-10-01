@tool
extends StaticBody2D
## Muro de piedra de la cantera: solo lo rompe el Oso (golpe pesado, pisotón o combo).
## Con `solo_por_losa` funciona de compuerta: los golpes no lo dañan y se abre con `abrir()`
## (lo llama una losa de peso). Tamaño, colores y resistencia editables desde el Inspector.

signal roto

@export var tam := Vector2(90, 260):
	set(v):
		tam = v
		_sincronizar()
@export var color_piedra := Color(0.42, 0.3, 0.24):
	set(v):
		color_piedra = v
		queue_redraw()
@export var color_junta := Color(0.2, 0.13, 0.1):
	set(v):
		color_junta = v
		queue_redraw()
@export_group("Resistencia")
@export var forma_requerida := 2            ## 2 = Oso (-1 = cualquiera)
@export var dano_minimo := 24               ## golpes más flojos (ataque ligero) no cuentan
@export var golpes_para_romper := 3
@export var solo_por_losa := false          ## compuerta: los golpes no la rompen, solo abrir()
@export_group("Efectos")
@export var derrumbe := false               ## al romperse sacude el nivel entero (polvo del techo)
@export var shake_romper := 9.0
@export var hitstop_romper := 0.06
@export var tip_forma := "Solo el Oso puede romper esta piedra."
@export var sonido_golpe: AudioStream = preload("res://assets/audio/sfx/gen/rompible_golpe.wav")
@export var sonido_romper: AudioStream = preload("res://assets/audio/sfx/gen/rompible_romper.wav")
@export var volumen_db := -6.0
@export_group("")

var golpes := 0
var abierto := false
var _tw: Tween
var _pos_base := Vector2.ZERO


func _ready() -> void:
	_pos_base = position
	_sincronizar()
	if Engine.is_editor_hint():
		return
	add_to_group("muro_piedra")


func _sincronizar() -> void:
	var cs := get_node_or_null("Collision") as CollisionShape2D
	if cs != null:
		if cs.shape == null or not (cs.shape is RectangleShape2D):
			cs.shape = RectangleShape2D.new()
		cs.shape.size = tam
		cs.position = Vector2(0, -tam.y * 0.5)
	queue_redraw()


func _draw() -> void:
	var r := Rect2(Vector2(-tam.x * 0.5, -tam.y), tam)
	draw_rect(r, color_piedra)
	draw_rect(r, color_junta, false, 4.0)
	var fila := 64.0
	var y := r.position.y + fila
	var i := 0
	while y < r.end.y:
		draw_line(Vector2(r.position.x, y), Vector2(r.end.x, y), color_junta, 3.0)
		var x := r.position.x + (tam.x * 0.5 if i % 2 == 0 else tam.x * 0.25)
		draw_line(Vector2(x, y - fila), Vector2(x, y), color_junta, 3.0)
		y += fila
		i += 1
	# Grietas según el daño recibido.
	for g in golpes:
		var gx := r.position.x + tam.x * (0.25 + 0.25 * g)
		draw_polyline(PackedVector2Array([Vector2(gx, r.position.y + 20.0), Vector2(gx - 10.0, r.position.y + tam.y * 0.4), Vector2(gx + 8.0, r.position.y + tam.y * 0.7)]), Color(0, 0, 0, 0.55), 3.0)
	draw_line(r.position, Vector2(r.position.x + tam.x, r.position.y), color_piedra.lightened(0.3), 4.0)


func registrar_golpe(dano: int) -> void:
	if abierto or solo_por_losa:
		if solo_por_losa:
			_sacudir(4.0)
		return
	var jugador := get_tree().get_first_node_in_group("player")
	if forma_requerida >= 0 and jugador != null and int(jugador.get("current_form")) != forma_requerida:
		_sacudir(3.0)
		if jugador.has_method("_tip_una_vez") and tip_forma != "":
			jugador.call("_tip_una_vez", "muro_piedra", tip_forma)
		return
	if dano < dano_minimo:
		_sacudir(4.0)
		return
	golpes += 1
	_sonar(sonido_golpe)
	Burst.emitir(self, _punto_impacto(jugador), color_piedra, 6 + golpes * 3, 0.8)
	queue_redraw()
	if golpes >= golpes_para_romper:
		abrir()
	else:
		_sacudir(6.0)


## Rompe el muro sin comprobar forma ni daño (lo usa la losa de peso).
func abrir() -> void:
	if abierto:
		return
	abierto = true
	collision_layer = 0
	roto.emit()
	_sonar(sonido_romper)
	# Muros altos: la piedra estalla a lo largo de toda la pared (no solo en el centro).
	var tramos := clampi(int(tam.y / 220.0), 1, 5)
	for i in tramos:
		Burst.emitir(self, global_position + Vector2(0, -tam.y * (float(i) + 0.5) / float(tramos)), color_piedra, 20, 1.4)
	var cam := get_viewport().get_camera_2d()
	if cam != null and cam.has_method("shake"):
		cam.shake(shake_romper * (1.6 if derrumbe else 1.0), 0.25 if derrumbe else 0.15)
	var hs := get_node_or_null("/root/Hitstop")
	if hs != null and hitstop_romper > 0.0:
		hs.freeze(hitstop_romper)
	var amb := get_node_or_null("/root/Ambiente")
	if amb != null:
		amb.empujar(global_position, 0.6)
		if derrumbe:
			amb.sacudida(1.0)
	if DisplayServer.get_name() == "headless":
		queue_free()
		return
	if _tw != null and _tw.is_valid():
		_tw.kill()
	_tw = create_tween().set_parallel(true)
	_tw.tween_property(self, "scale", Vector2(1.08, 0.2), 0.22).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	_tw.tween_property(self, "modulate:a", 0.0, 0.22)
	_tw.chain().tween_callback(queue_free)


## Dónde saltan las esquirlas al golpear: a la altura del jugador (el golpe real), dentro del muro.
func _punto_impacto(jugador: Node) -> Vector2:
	var y := -tam.y * 0.5
	if jugador is Node2D:
		y = clampf((jugador as Node2D).global_position.y - global_position.y, -tam.y + 40.0, -40.0)
	return global_position + Vector2(0, y)


func _sacudir(fuerza: float) -> void:
	_sonar(sonido_golpe)
	if DisplayServer.get_name() == "headless":
		return
	if _tw != null and _tw.is_valid():
		_tw.kill()
	position = _pos_base
	var base := _pos_base
	_tw = create_tween()
	_tw.tween_property(self, "position", base + Vector2(fuerza, 0), 0.03)
	_tw.tween_property(self, "position", base - Vector2(fuerza * 0.7, 0), 0.04)
	_tw.tween_property(self, "position", base, 0.05)


func _sonar(s: AudioStream) -> void:
	var audio := get_node_or_null("/root/AudioManager")
	if audio != null and s != null:
		audio.play_sfx(s, volumen_db, 0.08)
