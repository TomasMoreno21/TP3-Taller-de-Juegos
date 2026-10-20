@tool
extends StaticBody2D
## Ojo verde de la sala del jefe final. La Estrella lo crea por tandas en un punto (`PuntosOjos`):
## aparece, se abre y se cierra con un golpe (da energía) y después se desvanece.
## El sónico NO lo cierra (rebota): hay que pegarle cuerpo a cuerpo.
## Acorazado (F2): solo lo cierra el golpe fuerte del Oso. El rayo lo programa la Estrella:
## `avisar()` enciende la pupila antes de disparar. Lo dibuja `_draw` (se ve en el editor).

signal cerrado

const ORBE_VIDA_SCENE := preload("res://scenes/pickup_vida.tscn")

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
@export var sonido_aparecer: AudioStream = preload("res://assets/audio/sfx/gen/ojo_aparecer.wav")
@export var sonido_rebote: AudioStream = preload("res://assets/audio/sfx/gen/rebote_coraza.wav")
@export_range(0.0, 1.0, 0.01) var prob_vida := 0.3   ## chance de soltar un orbe de vida al cerrarlo
@export var curacion_vida := 15                       ## cuánto cura ese orbe
@export var altura_orbe := 80.0                       ## px sobre el piso donde queda flotando (los ojos altos lo dejan caer hasta acá)
@export var color_murcielago := Color(0.62, 0.45, 0.9)   ## aro de los ojos altos: el sónico del Murciélago los cierra
@export_group("Arte (ojos)")
@export var textura_fondo: Texture2D                  ## ojo1: blanco del ojo (atrás)
@export var textura_pupila: Texture2D                 ## ojo2: pupila/iris oscuro (medio, sigue al jugador)
@export var textura_frente: Texture2D                 ## ojo3: aro rojo (adelante)
@export var escala_arte := 1.0                        ## multiplica todo el ojo: para agrandarlo/achicarlo
@export_group("")

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


func _ready() -> void:
	_base_y = position.y
	_t = randf() * TAU
	_sincronizar()
	if Engine.is_editor_hint():
		_apertura = 1.0   # en el editor se ve abierto para ubicarlo
		return
	add_to_group("ojo_verde")
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
	var audio := get_node_or_null("/root/AudioManager")
	if audio != null and sonido_aparecer != null:
		audio.play_sfx(sonido_aparecer, volumen_db - 6.0, 0.15)
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
	if randf() < prob_vida:
		_soltar_vida()
	cerrado.emit()
	_salir()


func _soltar_vida() -> void:
	var orbe: Node2D = ORBE_VIDA_SCENE.instantiate()
	orbe.set("curacion", curacion_vida)
	orbe.add_to_group("orbe_jefe")   # la Estrella los borra al reintentar
	# El padre (OjosRaiz) está en el piso: el orbe cae hasta `altura_orbe`, fuera del pozo de la F2.
	var piso := get_parent() as Node2D
	var destino_pos := global_position
	if piso != null:
		destino_pos.y = maxf(global_position.y, piso.global_position.y - altura_orbe)
		var jefe := get_tree().get_first_node_in_group("boss")
		var foso = jefe.get("foso") if jefe != null else null
		if foso != null and bool(foso.get("activo")):
			var margen := float(jefe.get("lado_foso"))
			var dx := destino_pos.x - piso.global_position.x
			if absf(dx) < margen:
				destino_pos.x = piso.global_position.x + (margen if dx >= 0.0 else -margen)
	var destino: Node = get_tree().current_scene if get_tree().current_scene != null else get_tree().root   # nunca dentro de OjosRaiz
	destino.add_child(orbe)
	orbe.global_position = global_position
	if DisplayServer.get_name() == "headless" or destino_pos.distance_to(global_position) < 4.0:
		orbe.global_position = destino_pos
		return
	var tw := orbe.create_tween()
	tw.tween_property(orbe, "global_position", destino_pos, 0.7).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)


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
	if _hay_arte():
		_dibujar_arte()
	else:
		_dibujar_respaldo(w, h)
	# Aro de forma: el Oso lo rompe (acorazado) o el sónico del Murciélago lo cierra (alto).
	if acorazado and abierto:
		CirculoProteccion.dibujar(self, Vector2.ZERO, w * 1.08, color_coraza, "oso")
	elif sonico_cierra and abierto:
		CirculoProteccion.dibujar(self, Vector2.ZERO, w * 1.08, color_murcielago, "murcielago")


func _hay_arte() -> bool:
	return textura_fondo != null or textura_pupila != null or textura_frente != null


## Ojo con arte: fondo blanco (ojo1) detrás, pupila oscura (ojo2) que sigue al jugador (`_mirada`)
## y aro rojo (ojo3) delante. La pupila se enciende en rojo al avisar el rayo; `_apertura` recorta el ojo.
func _dibujar_arte() -> void:
	var base := textura_fondo if textura_fondo != null else (textura_frente if textura_frente != null else textura_pupila)
	var esc := escala_arte * (radio * 2.7) / float(base.get_size().x)
	var a := clampf(_apertura, 0.0, 1.0)
	if textura_fondo != null:
		_dibujar_textura(textura_fondo, Vector2.ZERO, esc, a)
	if textura_pupila != null and a > 0.02:
		var pe := 1.0 + 0.35 * (1.0 - _aviso_t / _aviso_dur) if _aviso_t > 0.0 else 1.0
		_dibujar_textura(textura_pupila, _mirada, esc * pe, a)
		if _aviso_t > 0.0:
			# Aviso del rayo: la pupila (oscura) se enciende con un rojo por encima.
			var r := esc * pe * minf(textura_pupila.get_size().x, textura_pupila.get_size().y) * 0.5
			draw_circle(_mirada, r, color_aviso)
			draw_circle(_mirada, r * 0.45, Color(1.0, 0.9, 0.8, 0.9))
	if textura_frente != null:
		_dibujar_textura(textura_frente, Vector2.ZERO, esc, a)


## Dibuja `tex` centrada en `offset`, escalada por `esc`, mostrando la franja central de alto
## `a` (0 = nada, 1 = entera): así el ojo "se abre y se cierra" al aparecer/salir.
func _dibujar_textura(tex: Texture2D, offset: Vector2, esc: float, a: float) -> void:
	var ah := clampf(a, 0.0, 1.0)
	if ah <= 0.001:
		return
	var sz := tex.get_size()
	var alto := sz.y * ah
	var region := Rect2(Vector2(0.0, (sz.y - alto) * 0.5), Vector2(sz.x, alto))
	var full := Rect2(offset - sz * esc * 0.5, sz * esc)
	var dh := alto * esc
	var dest := Rect2(Vector2(full.position.x, full.position.y + (full.size.y - dh) * 0.5),
			Vector2(sz.x * esc, dh))
	draw_texture_rect_region(tex, dest, region)


## Respaldo: ojo dibujado con polígonos (si no hay arte asignado).
func _dibujar_respaldo(w: float, h: float) -> void:
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
	# Párpado: trazo cian que atraviesa el ojo (como en el boceto); cerrado tapa todo.
	var y_parpado := -h * 0.55 if _apertura > 0.5 else 0.0
	draw_line(Vector2(-w * 1.15, y_parpado - 6.0), Vector2(w * 1.15, y_parpado + 4.0), color_parpado, 5.0, true)
	draw_line(Vector2(-w * 0.9, y_parpado + 2.0), Vector2(w * 0.95, y_parpado - 5.0), color_parpado, 3.0, true)
