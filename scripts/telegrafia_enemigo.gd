extends Node2D
## Efectos de telegrafiado de los enemigos, dibujados por código (sin texturas):
##  - RITUAL: círculo de invocación en el piso (anillos que giran, motas y un pilar de luz) antes de que
##    un enemigo aparezca (`spawn_telegrafiado`).
##  - DESTELLO: el aviso de ataque es SUTIL y sin marcas en el piso: la pose de anticipación (el enemigo se
##    echa atrás y se achata, ver `enemy.gd::_anticipacion_*`) + un brillito en el arma que crece justo
##    antes del golpe (esta clase). Sirve para cuerpo a cuerpo, embestida y disparo.
## Los crea `enemy.gd` con las funciones estáticas de abajo; se liberan solos (o con `cancelar()` si el
## enemigo es aturdido). En headless no se crean (los tests no los necesitan).

enum Modo { RITUAL, TAJO, EMBESTIDA, DISPARO }

const PELIGRO := Color(1.0, 0.36, 0.26)
const CULTO := Color(0.72, 0.32, 0.95)
const COLA := 0.3   ## s extra tras el final para el destello de salida

var modo := Modo.RITUAL
var dur := 0.7
var dir := 1
var alcance := 100.0
var color := CULTO
var centro := Vector2.ZERO        ## cuerpo (ataque) o pies (ritual), en coordenadas del enemigo
var cabeza_y := -80.0
var objetivo := Vector2.ZERO      ## punto de mira (disparo), en coordenadas del enemigo
var _t := 0.0
var _cancelado := false
var _brillo: Node2D
var seguir: Node2D = null          ## nodo cuya pose acompaña el destello (el sprite del enemigo)
var seguir_local := Vector2.ZERO   ## punto de la mano, en el espacio local de `seguir`


static func ritual(padre: Node2D, pies_y: float, col: Color, duracion: float) -> Node2D:
	if DisplayServer.get_name() == "headless" or padre == null:
		return null
	var n: Node2D = (load("res://scripts/telegrafia_enemigo.gd") as GDScript).new()
	n.modo = Modo.RITUAL
	n.dur = maxf(duracion, 0.2)
	n.color = CULTO.lerp(col, 0.25)
	n.centro = Vector2(0, pies_y)
	padre.add_child(n)
	return n


static func ataque(padre: Node2D, cuerpo: Vector2, y_cabeza: float, mirada: int, rango: float, duracion: float, embiste: bool, sigue: Node2D = null, punto_local := Vector2.ZERO) -> Node2D:
	if DisplayServer.get_name() == "headless" or padre == null:
		return null
	var n: Node2D = (load("res://scripts/telegrafia_enemigo.gd") as GDScript).new()
	n.modo = Modo.EMBESTIDA if embiste else Modo.TAJO
	n.dur = maxf(duracion, 0.1)
	n.dir = mirada
	n.alcance = rango
	n.color = PELIGRO
	n.centro = cuerpo
	n.cabeza_y = y_cabeza
	if sigue != null:   # el destello viaja con el sprite: se inclina y retrocede con la pose, como la mano
		n.seguir = sigue
		n.seguir_local = punto_local
		n.centro = Vector2.ZERO
	padre.add_child(n)
	n._seguir_mano()
	return n


static func disparo(padre: Node2D, arma: Vector2, y_cabeza: float, mira: Vector2, duracion: float) -> Node2D:
	if DisplayServer.get_name() == "headless" or padre == null:
		return null
	var n: Node2D = (load("res://scripts/telegrafia_enemigo.gd") as GDScript).new()
	n.modo = Modo.DISPARO
	n.dur = maxf(duracion, 0.1)
	n.color = PELIGRO
	n.centro = arma
	n.cabeza_y = y_cabeza
	n.objetivo = mira
	n.dir = 1 if mira.x >= arma.x else -1
	padre.add_child(n)
	return n


func cancelar() -> void:
	if _cancelado:
		return
	_cancelado = true
	create_tween().tween_property(self, "modulate:a", 0.0, 0.1)
	await get_tree().create_timer(0.12).timeout
	queue_free()


func _ready() -> void:
	z_index = 8
	_brillo = Node2D.new()
	var mat := CanvasItemMaterial.new()
	mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	mat.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
	_brillo.material = mat
	add_child(_brillo)
	_brillo.draw.connect(_dibujar_brillo)
	var base := CanvasItemMaterial.new()
	base.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
	material = base


func _process(delta: float) -> void:
	_t += delta
	_seguir_mano()
	if _t >= dur + COLA:
		queue_free()
		return
	queue_redraw()
	_brillo.queue_redraw()


func _seguir_mano() -> void:
	if seguir != null and is_instance_valid(seguir):
		global_position = seguir.to_global(seguir_local)


func _k() -> float:
	return clampf(_t / dur, 0.0, 1.0)


func _salida() -> float:
	return clampf(1.0 - maxf(_t - dur, 0.0) / COLA, 0.0, 1.0)


# ------------------------------------------------------------------ cuerpo (opaco)

func _draw() -> void:
	match modo:
		Modo.RITUAL:
			_dibujar_ritual()
		Modo.TAJO, Modo.EMBESTIDA, Modo.DISPARO:
			_destello_nucleo()   # el núcleo dorado va con mezcla normal para verse también sobre la túnica blanca


func _elipse_pts(c: Vector2, rx: float, ry: float, n := 40) -> PackedVector2Array:
	var p := PackedVector2Array()
	for i in n + 1:
		var a := TAU * float(i) / float(n)
		p.append(c + Vector2(cos(a) * rx, sin(a) * ry))
	return p


func _dibujar_ritual() -> void:
	var k := _k()
	var s := _salida()
	var crece := 1.0 - pow(1.0 - minf(k * 1.6, 1.0), 3.0)   # el círculo se abre rápido y luego respira
	var r := 96.0 * crece
	var plano := 0.3
	var c := centro
	# Relleno suave y anillo exterior.
	draw_colored_polygon(_elipse_pts(c, r, r * plano), Color(color, 0.16 * s))
	draw_polyline(_elipse_pts(c, r, r * plano), Color(color, 0.95 * s), 3.0, true)
	draw_polyline(_elipse_pts(c, r * 1.12, r * 1.12 * plano), Color(color, 0.35 * s), 1.5, true)
	# Anillo interior de arcos que giran.
	var gira := _t * 2.2
	for i in 4:
		var a0 := gira + float(i) * TAU / 4.0
		var pts := PackedVector2Array()
		for j in 9:
			var a := a0 + float(j) * (TAU / 4.0 * 0.62) / 8.0
			pts.append(c + Vector2(cos(a) * r * 0.62, sin(a) * r * 0.62 * plano))
		draw_polyline(pts, Color(color, 0.9 * s), 2.5, true)
	# Puntas triangulares en el borde (giran al revés).
	for i in 8:
		var a := -gira * 0.7 + float(i) * TAU / 8.0
		var p := c + Vector2(cos(a) * r, sin(a) * r * plano)
		var n := Vector2(cos(a), sin(a) * plano).normalized()
		var t := Vector2(-n.y, n.x)
		draw_colored_polygon(PackedVector2Array([p + n * 9.0, p + t * 5.0, p - t * 5.0]), Color(color, 0.95 * s))












# ------------------------------------------------------------------ brillo (suma de luz)

func _dibujar_brillo() -> void:
	var k := _k()
	var s := _salida()
	match modo:
		Modo.RITUAL:
			_brillo_ritual(k, s)
		Modo.TAJO, Modo.EMBESTIDA, Modo.DISPARO:
			_destello_arma(k, s)


## Destellito en la mano (dos capas): halo aditivo suave + núcleo dorado de mezcla normal (se ve sobre lo blanco).
func _progreso_destello() -> float:
	var u := clampf((_k() - 0.3) / 0.7, 0.0, 1.0)
	return 1.0 - pow(1.0 - u, 2.0) if u > 0.0 else 0.0


func _destello_nucleo() -> void:
	var pop := _progreso_destello()
	if pop <= 0.0:
		return
	var a := _salida() * (0.5 + 0.5 * pop)
	var r := 4.0 + 8.0 * pop
	var latido := 1.0 + 0.12 * sin(_t * 40.0)
	draw_circle(centro, r * 1.5 * latido, Color(1.0, 0.62, 0.15, 0.30 * a))
	draw_circle(centro, r * 1.0, Color(1.0, 0.78, 0.25, 0.75 * a))
	draw_circle(centro, r * 0.5, Color(1.0, 0.97, 0.8, a))


func _destello_arma(_k_: float, s: float) -> void:
	var pop := _progreso_destello()
	if pop <= 0.0:
		return
	var r := 5.0 + 10.0 * pop
	var a := s * (0.4 + 0.6 * pop)
	var latido := 1.0 + 0.12 * sin(_t * 40.0)
	_brillo.draw_circle(centro, r * 2.8 * latido, Color(1.0, 0.7, 0.35, 0.07 * a))
	_brillo.draw_circle(centro, r * 1.8 * latido, Color(1.0, 0.8, 0.45, 0.12 * a))
	for n in 3:
		var ang := float(n) * 2.1 + _t * 5.0
		var d := r * (1.2 + 1.6 * pop) + 2.0 * float(n)
		_brillo.draw_circle(centro + Vector2(cos(ang), sin(ang)) * d, 1.5 + 0.4 * float(n % 2), Color(1.0, 0.85, 0.5, 0.9 * a * pop))


func _brillo_ritual(k: float, s: float) -> void:
	var c := centro
	var plano := 0.3
	var r := 96.0 * (1.0 - pow(1.0 - minf(k * 1.6, 1.0), 3.0))
	var pts := PackedVector2Array()
	for i in 24:
		var a := TAU * float(i) / 24.0
		pts.append(c + Vector2(cos(a) * r, sin(a) * r * plano))
	_brillo.draw_colored_polygon(pts, Color(color, 0.12 * s))
	# Motas que suben desde el anillo.
	for i in 10:
		var u := fposmod(_t * 0.9 + float(i) * 0.1, 1.0)
		var a := float(i) * 2.399
		var x := c.x + cos(a) * r * 0.85
		var y := c.y + sin(a) * r * 0.85 * plano - u * 90.0
		_brillo.draw_circle(Vector2(x, y), 2.0 + float(i % 3) * 0.6, Color(color, sin(u * PI) * 0.8 * s * minf(k * 3.0, 1.0)))
	# Pilar de luz al terminar: sube y se desvanece.
	if k > 0.8 or _t > dur:
		var u := clampf((_t - dur * 0.8) / (dur * 0.2 + COLA), 0.0, 1.0)
		var alto := 240.0 * (0.4 + 0.6 * minf(u * 3.0, 1.0))
		var ancho := 42.0 * (1.0 - u * 0.7)
		var a := (1.0 - u) * 0.75
		_brillo.draw_polygon(PackedVector2Array([c + Vector2(-ancho, 0), c + Vector2(ancho, 0), c + Vector2(ancho * 0.4, -alto), c + Vector2(-ancho * 0.4, -alto)]),
			PackedColorArray([Color(color, a), Color(color, a), Color(color, 0.0), Color(color, 0.0)]))
		_brillo.draw_circle(c, 40.0 * (1.0 - u * 0.5), Color(1, 1, 1, a * 0.35))
