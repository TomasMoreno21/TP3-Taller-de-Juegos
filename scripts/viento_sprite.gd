extends Sprite2D
## Viento + reacción para arbustos y pastos con TEXTURA (Sprite2D pelado).
## El sistema de capas del fondo (viento_capa.gd) y el procedural (decorativo.gd)
## no sirven para esto: uno rota Parallax2D enteras y el otro dibuja polígonos.
##
## Dos detalles que importan:
## - La rotación pivota sobre la BASE del sprite, no sobre el centro, para que la
##   base no "patine" al balancear. Se logra en runtime (subiendo el dibujo media
##   altura y compensando la posición), así la escena guardada no cambia y el
##   editor sigue mostrando exactamente lo mismo.
## - La fase del viento sale de la posición X: los duplicados que se hagan
##   quedan desfasados entre sí en vez de moverse todos al unísono.

@export var viento := true
@export var viento_amplitud := 0.035:
	set(value):
		viento_amplitud = absf(value)
@export var viento_velocidad := 1.4:
	set(value):
		viento_velocidad = absf(value)
## Se inclina cuando el jugador pasa cerca (resorte, no tween) y recibe los
## empujones de golpes fuertes que emite el grupo "reactivo" (ambiente.gd).
@export var reactivo := true
@export var reaccion_angulo := 0.24      # rad máx. de inclinación
@export var reaccion_margen := 50.0      # px extra de alcance más allá del ancho
@export var reaccion_rigidez := 55.0     # vuelta a la posición (más alto = más rápido)
@export var reaccion_amort := 6.5        # freno (más bajo = más bamboleo)

var _fase := 0.0
var _rx := 0.0
var _rv := 0.0
var _jugador: Node2D


func _ready() -> void:
	# En el editor no se toca nada: el sprite se dibuja tal cual está guardado.
	if Engine.is_editor_hint():
		return
	add_to_group("reactivo")
	_anclar_base()
	_fase = fposmod(position.x * 0.017, TAU)


## Pivota sobre la base sin alterar el dibujo: `offset` sube la textura media
## altura y `position` la compensa. Ambas son cambios solo en memoria.
func _anclar_base() -> void:
	if texture == null:
		return
	var media := float(texture.get_height()) * 0.5
	offset.y -= media
	position.y += media


func _process(_delta: float) -> void:
	var rot := 0.0
	if viento:
		var t := Time.get_ticks_msec() * 0.001 * viento_velocidad + _fase
		rot = sin(t) * viento_amplitud
	if reactivo:
		_reaccionar(_delta)
	rotation = rot + _rx


## Golpe fuerte en `pos` (mundo). fuerza ~0..1.
func empujar(pos: Vector2, fuerza: float) -> void:
	if not is_inside_tree():
		return
	var dx := global_position.x - pos.x
	if absf(dx) > 800.0 or absf(global_position.y - pos.y) > 500.0:
		return
	var cerca := 1.0 - absf(dx) / 800.0
	_rv += (1.0 if dx >= 0.0 else -1.0) * fuerza * cerca * 7.0


## Se dobla en el sentido en que corre el jugador y lejos de su cuerpo.
func _reaccionar(delta: float) -> void:
	var objetivo := 0.0
	if _jugador == null or not is_instance_valid(_jugador):
		_jugador = get_tree().get_first_node_in_group("player") as Node2D
	if _jugador != null:
		var dx := _jugador.global_position.x - global_position.x
		var dy := _jugador.global_position.y - global_position.y
		var alcance := _ancho() * 0.5 + reaccion_margen
		if absf(dx) < alcance and dy > -320.0 and dy < 140.0:
			var cerca := 1.0 - absf(dx) / maxf(alcance, 1.0)
			var vx := 0.0
			if "velocity" in _jugador:
				vx = clampf(float(_jugador.velocity.x) / 320.0, -1.0, 1.0)
			objetivo = clampf(vx * 0.7 - signf(dx) * 0.3, -1.0, 1.0) * cerca * reaccion_angulo
	var d := minf(delta, 1.0 / 30.0)
	_rv += (-reaccion_rigidez * (_rx - objetivo) - reaccion_amort * _rv) * d
	_rx = clampf(_rx + _rv * d, -0.6, 0.6)


func _ancho() -> float:
	return float(texture.get_width()) * absf(scale.x) if texture != null else 0.0