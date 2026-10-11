extends Area2D

## Orbe rojo de vida: soltado por enemigos con 55% de chance al morir.
## Visualmente igual que el orbe de energía (rombo) pero en rojo. Flota, late, tiene imán
## y al recogerlo deja un estallido rojo y un aviso de curación (el orbe se libera ya).

@export var curacion := 24
@export var flote_amplitud := 5.0
@export var flote_velocidad := 2.4
@export var pulso_velocidad := 3.4
@export var color_burst := Color(1.0, 0.35, 0.4)
@export var iman_radio := 170.0          ## px: dentro de este radio el orbe vuela hacia el jugador (0 = sin imán)
@export var iman_velocidad := 760.0
@export var iman_aceleracion := 2000.0

var _t := randf() * TAU
var _base_visual := Vector2.ZERO
var _iman_vel := 0.0
var _jugador: Node2D
var _amb: Node
var _recogido := false

@onready var visual: Polygon2D = $Visual
@onready var halo: Sprite2D = get_node_or_null("Halo")
@onready var luz: PointLight2D = get_node_or_null("Luz")

var _base_halo := Vector2.ZERO
var _alpha_halo := 1.0
var _energia_luz := 1.0


func _ready() -> void:
	monitoring = true
	collision_mask = 4
	body_entered.connect(_on_body_entered)
	_base_visual = visual.position
	if halo != null:
		_base_halo = halo.position
		_alpha_halo = halo.modulate.a
	if luz != null:
		_energia_luz = luz.energy


func _process(delta: float) -> void:
	if _recogido:
		return
	_t += delta
	visual.position = _base_visual + Vector2(0, sin(_t * flote_velocidad) * flote_amplitud)
	var latido := 1.0 + 0.06 * sin(_t * pulso_velocidad)
	# Si estás herido, el orbe late con tu corazón (mismo pulso que la viñeta) y llama más la atención.
	if _amb == null:
		_amb = get_node_or_null("/root/Ambiente")
	var amb := _amb
	if amb != null and float(amb.latido_severidad) > 0.05:
		latido += float(amb.latido) * 0.35
	visual.scale = Vector2(latido, latido)
	# Brillo (halo aditivo + luz) que acompaña el vaivén y el latido, como el del orbe azul.
	var brillo := 0.8 + 0.2 * sin(_t * pulso_velocidad) + (latido - 1.0)
	if halo != null:
		halo.position = _base_halo + Vector2(0, visual.position.y - _base_visual.y)
		halo.modulate.a = _alpha_halo * brillo
	if luz != null:
		luz.energy = _energia_luz * brillo
	_atraer(delta)
	# Si el jugador ya lo tocaba con la vida llena y después se lastima, se recoge igual (body_entered no se repite).
	for b in get_overlapping_bodies():
		_on_body_entered(b)


func _atraer(delta: float) -> void:
	if iman_radio <= 0.0:
		return
	if _jugador == null or not is_instance_valid(_jugador):
		_jugador = get_tree().get_first_node_in_group("player") as Node2D
	var p := _jugador
	if p == null:
		return
	if p.has_method("puede_curarse") and not p.puede_curarse():
		_iman_vel = 0.0
		return   # vida llena: el imán no lo arrastra
	var d := (p.global_position + Vector2(0, -60)) - global_position
	var dist := d.length()
	if dist < iman_radio and dist > 1.0:
		_iman_vel = minf(_iman_vel + iman_aceleracion * delta, iman_velocidad)
		global_position += d / dist * minf(_iman_vel * delta, dist)
	else:
		_iman_vel = 0.0


func _on_body_entered(body: Node2D) -> void:
	if _recogido or not body.has_method("curar"):
		return
	# Con la vida llena el orbe se queda esperando (no se gasta ni avisa "Vida +N" sin curar nada).
	if body.has_method("puede_curarse") and not body.puede_curarse():
		return
	_recogido = true
	body.curar(curacion)
	Burst.emitir(self, global_position, color_burst, 14)
	queue_free()
