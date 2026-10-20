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
var _alfa := 0.25               # opacidad del dibujo (aviso parpadeante / activo)


var _forma: CollisionShape2D


func _ready() -> void:
	collision_layer = 0
	collision_mask = 4   # solo el jugador
	monitoring = false
	z_index = 5
	add_to_group("ataque_jefe")
	var forma := CollisionShape2D.new()
	_forma = forma
	var caja := RectangleShape2D.new()
	caja.size = tamano
	forma.shape = caja
	add_child(forma)
	_alfa = 0.25
	body_entered.connect(_on_body_entered)


func _physics_process(delta: float) -> void:
	_t += delta
	if not _activo:
		# Aviso: parpadeo cada vez más rápido hasta activarse.
		var f := 18.0 + 24.0 * (_t / maxf(aviso, 0.01))
		_alfa = 0.18 + 0.2 * (0.5 + 0.5 * sin(_t * f))
		queue_redraw()
		if _t >= aviso:
			_activo = true
			_alfa = 0.9
			monitoring = true
		return
	queue_redraw()
	var paso := velocidad * delta
	global_position.x += dir * paso
	_recorrido += paso
	if _recorrido >= recorrido_max:
		queue_free()
		return
	if not _golpeo:
		for b in get_overlapping_bodies():   # body_entered no se repite: si primero entraron solo las patas, hay que seguir mirando
			_on_body_entered(b)


func _on_body_entered(body: Node2D) -> void:
	if _golpeo or not _activo:
		return
	if body.has_method("toca_cuerpo") and not body.toca_cuerpo(_forma.shape, _forma.global_transform):
		return   # solo rozó las patas invisibles (se reevalúa cada frame en _physics_process)
	if body.has_method("take_damage"):
		_golpeo = true   # un solo golpe por ataque
		body.take_damage(dano, empuje, dir)
		_alfa = 0.35


## Ola de choque: una cresta curva plana que rompe hacia delante.
func _draw() -> void:
	var m := tamano * 0.5
	var d := float(dir)
	var perfil := PackedVector2Array()
	for i in 9:
		var u := float(i) / 8.0
		perfil.append(Vector2(lerpf(-d * m.x, d * m.x * 0.7, u), lerpf(m.y, -m.y, pow(u, 2.2))))
	perfil.append(Vector2(d * m.x, -m.y * 0.5))
	var forma := perfil.duplicate()
	forma.append(Vector2(d * m.x, m.y))
	draw_colored_polygon(forma, Color(color.r, color.g, color.b, _alfa))
	draw_polyline(perfil, Color(color.lightened(0.5), _alfa), 3.0, true)
