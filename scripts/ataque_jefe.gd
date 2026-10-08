extends Area2D
## Ataque de escenario del Arzobispo (onda de choque / barrido). Primero AVISO (silueta
## parpadeante, sin daño) y después ACTIVO: avanza en línea recta y daña una sola vez.
## Los configura boss.gd antes de add_child (mismo patrón que el proyectil).

var dano := 18
var velocidad := 480.0
var dir := 1
var tamano := Vector2(120, 90)   # caja del ataque (centrada en la posición)
var color := Color(0.75, 0.5, 0.25)
var aviso := 0.7                 # s de aviso antes de hacer daño
var recorrido_max := 2200.0      # px antes de desaparecer
var empuje := 260.0

var _t := 0.0
var _activo := false
var _golpeo := false
var _recorrido := 0.0
var _poly: Polygon2D


func _ready() -> void:
	collision_layer = 0
	collision_mask = 4   # solo el jugador
	monitoring = false
	z_index = 5
	add_to_group("ataque_jefe")
	var forma := CollisionShape2D.new()
	var caja := RectangleShape2D.new()
	caja.size = tamano
	forma.shape = caja
	add_child(forma)
	_poly = Polygon2D.new()
	var m := tamano * 0.5
	_poly.polygon = PackedVector2Array([Vector2(-m.x, m.y), Vector2(-m.x * 0.3, -m.y), Vector2(m.x, -m.y * 0.6), Vector2(m.x, m.y)]) if dir > 0 \
		else PackedVector2Array([Vector2(m.x, m.y), Vector2(m.x * 0.3, -m.y), Vector2(-m.x, -m.y * 0.6), Vector2(-m.x, m.y)])
	_poly.color = Color(color.r, color.g, color.b, 0.25)
	add_child(_poly)
	body_entered.connect(_on_body_entered)


func _physics_process(delta: float) -> void:
	_t += delta
	if not _activo:
		# Aviso: parpadeo cada vez más rápido hasta activarse.
		var f := 18.0 + 24.0 * (_t / maxf(aviso, 0.01))
		_poly.color.a = 0.18 + 0.2 * (0.5 + 0.5 * sin(_t * f))
		if _t >= aviso:
			_activo = true
			_poly.color = Color(color.r, color.g, color.b, 0.9)
			monitoring = true
		return
	var paso := velocidad * delta
	global_position.x += dir * paso
	_recorrido += paso
	if _recorrido >= recorrido_max:
		queue_free()


func _on_body_entered(body: Node2D) -> void:
	if _golpeo or not _activo:
		return
	if body.has_method("take_damage"):
		_golpeo = true   # un solo golpe por ataque
		body.take_damage(dano, empuje, dir)
		_poly.color.a = 0.35
