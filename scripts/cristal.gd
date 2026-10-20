extends StaticBody2D

const Jugador := preload("res://scripts/player.gd")

signal cristal_destruido

@export var cristal_color: Color = Color(0.62, 0.42, 0.92)
@export var float_amplitude: float = 6.0
@export var float_speed: float = 2.0
# Cuántos golpes lo rompen y si solo el sónico del Murciélago puede. Tuneables
# para reusar el cristal como escudo del jefe (ej: 2 golpes).
@export var golpes_para_romper := 3
@export var solo_murcielago := true

## true = los golpes cuerpo a cuerpo no lo dañan, solo el proyectil sónico (lo marca la barrera o el Inspector).
@export var solo_proyectil := false

## Lo enciende projectile.gd justo antes de llamar a take_damage (igual que en los enemigos flotantes).
var golpe_proyectil := false
var _roto := false
var _golpes := 0
var _base_y := 0.0
var _offset := 0.0
var _escala_base := Vector2.ONE   # escala de reposo (los golpes rápidos no la acumulan)
var _tw_golpe: Tween
var _facetas_listas := false
var _brillo: Polygon2D   # destello que titila en la punta

@onready var visual_root: Node2D = $Visual
@onready var poly: Polygon2D = $Visual/Poly
@onready var halo: Polygon2D = $Visual/Halo
@onready var sprite: Sprite2D = $Visual/Sprite
@onready var collision: CollisionShape2D = $Collision


func _ready() -> void:
	add_to_group("cristal")
	_base_y = visual_root.position.y if visual_root != null else 0.0
	_escala_base = visual_root.scale if visual_root != null else Vector2.ONE
	_offset = randf() * TAU
	_actualizar_visual()


func _actualizar_visual() -> void:
	if poly != null:
		poly.color = cristal_color
		poly.polygon = PackedVector2Array([Vector2(0, -30), Vector2(14, -14), Vector2(12, 16), Vector2(0, 28), Vector2(-12, 16), Vector2(-14, -14)])
		_armar_facetas()
	if halo != null:
		halo.color = Color(cristal_color.r, cristal_color.g, cristal_color.b, 0.18)
		halo.polygon = PackedVector2Array([Vector2(0, -42), Vector2(24, -12), Vector2(20, 22), Vector2(0, 40), Vector2(-20, 22), Vector2(-24, -12)])
	if sprite != null and sprite.texture != null:
		sprite.visible = true
		if poly != null:
			poly.visible = false
		if halo != null:
			halo.visible = false
	else:
		if sprite != null:
			sprite.visible = false
		if poly != null:
			poly.visible = true
		if halo != null:
			halo.visible = true


## Caras del cristal: capas claras/oscuras semitransparentes sobre `poly` (siguen su color, incluso en el flash de golpe).
func _armar_facetas() -> void:
	if _facetas_listas or poly == null:
		return
	_facetas_listas = true
	var caras := [
		[[Vector2(0, -30), Vector2(-14, -14), Vector2(-12, 16), Vector2(0, 28)], Color(1, 1, 1, 0.20)],    # cara izquierda iluminada
		[[Vector2(0, -30), Vector2(14, -14), Vector2(12, 16), Vector2(0, 28)], Color(0, 0, 0.1, 0.22)],     # cara derecha en sombra
		[[Vector2(0, -30), Vector2(14, -14), Vector2(0, -6), Vector2(-14, -14)], Color(1, 1, 1, 0.30)],      # corona
		[[Vector2(0, -6), Vector2(6, 4), Vector2(0, 20), Vector2(-6, 4)], Color(1, 1, 1, 0.34)],             # núcleo brillante
	]
	for c in caras:
		var f := Polygon2D.new()
		f.polygon = PackedVector2Array(c[0])
		f.color = c[1]
		poly.add_child(f)
	var borde := Line2D.new()
	borde.points = PackedVector2Array([Vector2(0, -30), Vector2(14, -14), Vector2(12, 16), Vector2(0, 28), Vector2(-12, 16), Vector2(-14, -14), Vector2(0, -30)])
	borde.width = 1.6
	borde.default_color = Color(cristal_color.r * 0.35, cristal_color.g * 0.25, cristal_color.b * 0.6, 0.9)
	poly.add_child(borde)
	_brillo = Polygon2D.new()
	_brillo.polygon = PackedVector2Array([Vector2(-7, -18), Vector2(-2, -20), Vector2(0, -28), Vector2(2, -20), Vector2(7, -18), Vector2(2, -16), Vector2(0, -8), Vector2(-2, -16)])
	_brillo.color = Color(1, 1, 1, 0.9)
	_brillo.position = Vector2(-4, 2)
	_brillo.scale = Vector2(0.55, 0.55)
	poly.add_child(_brillo)


func _process(_delta: float) -> void:
	if _roto:
		# Congelar la animación de flote: de lo contrario sobrescribe el fade
		# (modulate.a) y escala del tween de destrucción en take_damage.
		return
	if visual_root == null:
		return
	var t := Time.get_ticks_msec() * 0.001 * float_speed + _offset
	visual_root.position.y = _base_y + sin(t) * float_amplitude
	visual_root.modulate.a = 0.92 + sin(t * 1.7) * 0.08
	if halo != null:
		var hs := 1.0 + sin(t * 0.9) * 0.08
		halo.scale = Vector2(hs, hs)
		halo.modulate.a = 0.16 + sin(t * 1.3) * 0.06
	if _brillo != null:
		_brillo.modulate.a = clampf(0.25 + 0.75 * pow(0.5 + 0.5 * sin(t * 2.3), 3.0), 0.0, 1.0)   # destello que titila
	if sprite != null and sprite.visible:
		sprite.modulate.a = visual_root.modulate.a


func _diamante_poligono(ax: float, ay: float) -> PackedVector2Array:
	return PackedVector2Array([Vector2(0, -ay), Vector2(ax, 0), Vector2(0, ay), Vector2(-ax, 0)])


func take_damage(_cant: int, _kb: float = 0.0, _dir: int = 1, _critico: bool = false) -> void:
	var por_proyectil := golpe_proyectil
	golpe_proyectil = false
	if _roto:
		return
	if solo_proyectil and not por_proyectil:
		return
	var player := get_tree().get_first_node_in_group("player")
	if player == null or (solo_murcielago and int(player.get("current_form")) != Jugador.Form.MURCIELAGO):
		return
	_golpes += 1
	if _golpes < golpes_para_romper:
		_flash_golpe()
		return
	_roto = true
	cristal_destruido.emit()
	_burst()
	JuiceFx.nota_cristal(get_tree())
	JuiceFx.escombros(get_tree(), global_position, cristal_color, 7, 0.8)
	var hs := get_node_or_null("/root/Hitstop")
	if hs != null and DisplayServer.get_name() != "headless":
		hs.freeze(0.05)
	var tw := create_tween()
	tw.tween_property(visual_root, "scale", Vector2(1.4, 1.4), 0.12)
	tw.parallel().tween_property(visual_root, "modulate:a", 0.0, 0.12)
	tw.tween_callback(queue_free)
	if collision != null:
		collision.set_deferred("disabled", true)


func _flash_golpe() -> void:
	if visual_root == null:
		return
	var cam := get_viewport().get_camera_2d()
	if cam != null and cam.has_method("shake"):
		cam.shake(2.5, 0.08)
	var base_col: Color = cristal_color
	if poly != null and poly.visible:
		poly.color = Color(1, 0.85, 0.85)
		if _tw_golpe != null and _tw_golpe.is_valid():
			_tw_golpe.kill()
		_tw_golpe = create_tween()
		_tw_golpe.tween_property(poly, "color", base_col.lerp(Color(1, 1, 1), 0.35), 0.14)
		_tw_golpe.parallel().tween_property(visual_root, "scale", _escala_base * 1.18, 0.06)
		_tw_golpe.tween_property(visual_root, "scale", _escala_base, 0.08)
	if halo != null and halo.visible:
		halo.color = Color(1, 0.6, 0.6, 0.32)
		var tw2 := create_tween()
		tw2.tween_property(halo, "color", Color(cristal_color.r, cristal_color.g, cristal_color.b, 0.18), 0.14)
	_crack_visual()


func _crack_visual() -> void:
	if poly == null or not poly.visible:
		return
	var t := float(_golpes) / float(golpes_para_romper)
	poly.modulate = Color(1, 1 - t * 0.15, 1 - t * 0.15)


func _burst() -> void:
	if DisplayServer.get_name() == "headless":
		return
	var p: CPUParticles2D = (preload("res://scenes/burst.tscn") as PackedScene).instantiate()
	p.global_position = global_position
	p.self_modulate = cristal_color
	p.amount = 14
	get_tree().root.add_child(p)
	p.restart()
	p.emitting = true
