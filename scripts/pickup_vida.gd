extends Area2D

## Orbe rojo de vida: soltado por enemigos con 55% de chance al morir.
## Visualmente igual que el orbe de energía (rombo) pero en rojo. Flota, late, tiene imán
## y al recogerlo deja un estallido rojo y un aviso de curación (el orbe se libera ya).

@export var curacion := 24
@export_group("Aspecto de alma")
@export var color_cabeza := Color(1.0, 0.86, 0.8, 0.95)    ## centro de la cabeza del espíritu
@export var color_borde := Color(1.0, 0.3, 0.3, 0.85)       ## contorno de la cabeza
@export var color_cola := Color(0.85, 0.12, 0.25, 0.0)      ## punta de la cola (se desvanece)
@export var radio_cabeza := 20.0
@export var largo_cola := 58.0
@export var oleaje_cola := 9.0              ## px que se mece la cola
@export var velocidad_oleaje := 3.6
@export_group("")
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
	_dibujar_alma(0.0)
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
	_dibujar_alma(_t)
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


const _N_CABEZA := 9
const _N_COLA := 8


func _dibujar_alma(t: float) -> void:
	var cy := -radio_cabeza * 0.5
	_contorno(visual, radio_cabeza, largo_cola, oleaje_cola, t, 0.0, color_borde.lerp(color_cabeza, 0.15), color_borde, color_cola, 0.85)
	# Dos velos translúcidos más grandes que se mecen a otro ritmo: el alma parece flotar en su propia estela.
	var n := 0
	for v in visual.get_children():
		if v.name.begins_with("Velo"):
			n += 1
			_contorno(v as Polygon2D, radio_cabeza * (1.3 + 0.15 * n), largo_cola * (1.2 + 0.15 * n), oleaje_cola * (1.4 + 0.3 * n), t, 1.7 * n,
				Color(color_cabeza, 0.28), Color(color_borde, 0.2), Color(color_cola, 0.0), 1.0)
	var nucleo := visual.get_node_or_null("Nucleo") as Polygon2D
	if nucleo != null:
		nucleo.position = Vector2(0, cy)
		nucleo.scale = Vector2.ONE * (radio_cabeza / 15.0) * (1.0 + 0.08 * sin(t * pulso_velocidad))


## Contorno de espíritu (cabeza + cola ondulante) con color por vértice en `destino`.
func _contorno(destino: Polygon2D, radio: float, largo: float, oleaje: float, t: float, fase: float, c_cab: Color, c_borde: Color, c_cola: Color, opacidad: float) -> void:
	var pts := PackedVector2Array()
	var cols := PackedColorArray()
	var cy := -radio * 0.5
	for i in _N_CABEZA:   # semicírculo superior, de izquierda a derecha
		var a := PI + PI * float(i) / float(_N_CABEZA - 1)
		pts.append(Vector2(cos(a) * radio, cy + sin(a) * radio))
		cols.append(c_cab)
	var der := PackedVector2Array()
	var izq := PackedVector2Array()
	var cols_l := PackedColorArray()
	for k in range(1, _N_COLA + 1):
		var f := float(k) / float(_N_COLA)
		var ancho := radio * pow(1.0 - f, 0.75)
		var mece := sin(t * velocidad_oleaje + fase + f * 3.4) * oleaje * f
		var y := cy + f * largo
		der.append(Vector2(ancho + mece, y))
		izq.append(Vector2(-ancho + mece, y))
		var c := c_borde.lerp(c_cola, pow(f, 0.9))
		c.a *= opacidad
		cols_l.append(c)
	pts.append_array(der)
	cols.append_array(cols_l)
	for k in range(_N_COLA - 2, -1, -1):   # vuelve por el lado izquierdo (sin repetir la punta)
		pts.append(izq[k])
		cols.append(cols_l[k])
	destino.polygon = pts
	destino.vertex_colors = cols


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
