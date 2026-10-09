extends StaticBody2D
## Plataforma/piso frágil: al pisarla tiembla durante `tiempo_temblor` y luego
## se destruye o se cae (configurable). La colisión ("Collision") y el visual
## ("Visual") son nodos editables dentro de la escena.

enum Ruptura { DESTRUIR, CAER }

## -1 = cede con cualquier forma; 2 = solo cede bajo el peso del Oso (el resto cruza sin romperla).
@export var forma_requerida := -1
@export var tiempo_temblor := 1.0
@export var modo_ruptura := Ruptura.DESTRUIR
@export var temblor_max := 3.0       # px de vaivén al temblar (crece hacia la ruptura)
@export var gravedad_caida := 2400.0 # aceleración al caer (modo CAER)
## Reaparición: tras `tiempo_reaparicion` s la plataforma vuelve (si el jugador no está encima).
## También vuelve siempre que el jugador reaparece en un checkpoint. 0 = solo por checkpoint.
@export var reaparece := true
@export var tiempo_reaparicion := 10.0
## true = una vez rota queda rota toda la partida (comportamiento anterior, vía Progresion).
@export var persistente_rota := false
## Clave de persistencia: si queda vacía se genera sola (escena + ruta del nodo).
## Ponerla a mano permite agrupar/referenciar plataformas de forma estable.
@export var clave_persistencia := ""
@export var color_escombros := Color(0.45, 0.38, 0.3)
@export var sonido_crujir: AudioStream = preload("res://assets/audio/sfx/gen/fragil_crujir.wav")      ## al empezar a temblar
@export var sonido_romper: AudioStream = preload("res://assets/audio/sfx/gen/fragil_romper.wav")
@export var volumen_db := -8.0

enum Fase { ESPERA, TEMBLOR, CAYENDO, ROTA }

var _fase: int = Fase.ESPERA
var _jugador_cache: Node2D
var _t := 0.0
var _vel_caida := 0.0
var _visual: Polygon2D
var _shape: CollisionShape2D
var _pos_inicial := Vector2.ZERO
var _t_rota := 0.0
var _tween_vuelta: Tween
var _tween_rotura: Tween


func _clave() -> String:
	if not clave_persistencia.is_empty():
		return clave_persistencia
	var escena: Node = get_tree().current_scene
	if escena == null:
		return str(get_path())
	return "%s|%s" % [escena.scene_file_path, str(get_path())]


func _ready() -> void:
	add_to_group("plataforma_fragil")
	collision_layer = 1
	_pos_inicial = position
	_visual = get_node_or_null("Visual") as Polygon2D
	_shape = get_node_or_null("Collision") as CollisionShape2D
	if _visual == null:
		_visual = _crear_visual_fallback()
	if _shape == null:
		_shape = _crear_collision_fallback()
	var prog := get_node_or_null("/root/Progresion")
	if persistente_rota and prog != null and prog.plataforma_rota(_clave()):
		_romper(true)


func _physics_process(delta: float) -> void:
	match _fase:
		Fase.ESPERA:
			if not is_instance_valid(_jugador_cache):
				_jugador_cache = get_tree().get_first_node_in_group("player") as Node2D
			var player: Node2D = _jugador_cache
			if player != null and global_position.distance_squared_to(player.global_position) > 4000000.0:
				return   # lejos: nadie la pisa
			if player is CharacterBody2D and player.is_on_floor():
				if _pisa_plataforma(player) and (forma_requerida < 0 or int(player.get("current_form")) == forma_requerida):
					_fase = Fase.TEMBLOR
					_escombros(6, 0.6, sonido_crujir)
		Fase.TEMBLOR:
			_t += delta
			var prog := clampf(_t / maxf(tiempo_temblor, 0.01), 0.0, 1.0)
			_visual.position.x = randf_range(-temblor_max, temblor_max) * prog
			if _t >= tiempo_temblor:
				_romper()
		Fase.CAYENDO:
			_vel_caida = minf(_vel_caida + gravedad_caida * delta, 2600.0)
			position.y += _vel_caida * delta
			if position.y > _pos_inicial.y + 3000.0:
				_fase = Fase.ROTA
				_t_rota = 0.0
				_visual.visible = false
				_shape.set_deferred("disabled", true)
		Fase.ROTA:
			if reaparece and tiempo_reaparicion > 0.0:
				_t_rota += delta
				if _t_rota >= tiempo_reaparicion and not _jugador_encima():
					restaurar()


func _romper(sin_animacion := false) -> void:
	if _fase == Fase.ROTA:
		return
	var prog := get_node_or_null("/root/Progresion")
	if persistente_rota and prog != null:
		prog.marcar_plataforma_rota(_clave())
	_t_rota = 0.0
	if sin_animacion:
		_shape.set_deferred("disabled", true)
		_fase = Fase.ROTA
		_visual.visible = false
		return
	_shape.set_deferred("disabled", true)
	_visual.position.x = 0.0
	_escombros(20, 1.1, sonido_romper)
	match modo_ruptura:
		Ruptura.DESTRUIR:
			_fase = Fase.ROTA
			if _tween_rotura != null and _tween_rotura.is_valid():
				_tween_rotura.kill()
			_tween_rotura = create_tween()
			_tween_rotura.set_parallel(true)
			_tween_rotura.tween_property(_visual, "modulate:a", 0.0, 0.12)
			_tween_rotura.tween_property(_visual, "scale", Vector2(1.3, 1.3), 0.12)
			_tween_rotura.chain().tween_callback(func() -> void: _visual.visible = false)
		Ruptura.CAER:
			# El collider queda activo: el jugador cae junto con la plataforma.
			_fase = Fase.CAYENDO


## Vuelve a aparecer (fundido corto). Se llama por tiempo o al reaparecer el jugador.
## Al reaparecer el jugador tras morir: las plataformas "persistentes" siguen rotas (como dice su export).
func restaurar_tras_muerte() -> void:
	if persistente_rota:
		return
	restaurar()


func restaurar() -> void:
	if _fase == Fase.ESPERA:
		return
	if _tween_rotura != null and _tween_rotura.is_valid():
		_tween_rotura.kill()   # su callback dejaba la plataforma invisible con colisión si restaurar() caía dentro de los 0.12 s
	if _tween_vuelta != null and _tween_vuelta.is_valid():
		_tween_vuelta.kill()
	_fase = Fase.ESPERA
	_t = 0.0
	_t_rota = 0.0
	_vel_caida = 0.0
	position = _pos_inicial
	_shape.set_deferred("disabled", false)
	_visual.position.x = 0.0
	_visual.scale = Vector2.ONE
	_visual.visible = true
	_visual.modulate.a = 0.0
	_tween_vuelta = create_tween()
	_tween_vuelta.tween_property(_visual, "modulate:a", 1.0, 0.35)


## True si el jugador está tocando el rect de la plataforma (no reaparecer encima suyo).
func _jugador_encima() -> bool:
	var p: Node2D = get_tree().get_first_node_in_group("player")
	if p == null:
		return false
	var b := _rect_body(p)
	return b != Rect2() and b.intersects(_rect_propio().grow(6.0))


## Polvillo/escombros desde el borde superior de la plataforma.
func _escombros(cantidad: int, escala: float, sonido: AudioStream) -> void:
	var audio := get_node_or_null("/root/AudioManager")
	if audio != null:
		audio.play_sfx(sonido, volumen_db, 0.1)
	var r := _rect_propio()
	var pos := global_position if r == Rect2() else Vector2(r.get_center().x, r.position.y)
	Burst.emitir(self, pos, color_escombros, cantidad, escala)


## Rect global del collider de esta plataforma.
func _rect_propio() -> Rect2:
	if _shape == null or _shape.shape == null:
		return Rect2()
	var s: Vector2 = _shape.shape.size
	return Rect2(_shape.global_position - s * 0.5, s)


## El jugador debe estar PISANDO la plataforma (sus pies ~ sobre el tope de la
## caja), no rozarla por el costado parado en otra superficie: el overlap con
## el rect COMPLETO del collider daba falsos positivos (player 190x318 / oso
## 470x324 vs plataformas finas) y la rompía apoyándose en su lateral.
func _pisa_plataforma(body: Node2D) -> bool:
	var b := _rect_body(body)
	if b == Rect2():
		return false
	var a := _rect_propio()
	var tope := a.position.y
	var pies := b.position.y + b.size.y
	if pies < tope - 8.0 or pies > tope + 6.0:
		return false
	return a.position.x < b.end.x and b.position.x < a.end.x


## Rect global del collider del body (patrón de pinchos).
func _rect_body(body: Node2D) -> Rect2:
	var csc := _csc_de(body)
	if csc == null or csc.shape == null:
		return Rect2()
	var s: Vector2
	if csc.shape is RectangleShape2D:
		s = csc.shape.size
	elif csc.shape is CapsuleShape2D:
		s = Vector2(csc.shape.radius * 2.0, csc.shape.height)
	else:
		return Rect2()
	return Rect2(body.global_position + csc.position - s * 0.5, s)


func _csc_de(body: Node2D) -> CollisionShape2D:
	for child in body.get_children():
		if child is CollisionShape2D:
			return child
	return null


func _crear_visual_fallback() -> Polygon2D:
	var v := Polygon2D.new()
	v.name = "Visual"
	var m := Vector2(80, 12)
	v.polygon = PackedVector2Array([
		Vector2(-m.x, -m.y), Vector2(m.x, -m.y),
		Vector2(m.x, m.y), Vector2(-m.x, m.y),
	])
	v.color = Color(0.72, 0.56, 0.38)
	add_child(v)
	return v


func _crear_collision_fallback() -> CollisionShape2D:
	var s := CollisionShape2D.new()
	var r := RectangleShape2D.new()
	r.size = Vector2(160, 24)
	s.name = "Collision"
	s.shape = r
	add_child(s)
	return s