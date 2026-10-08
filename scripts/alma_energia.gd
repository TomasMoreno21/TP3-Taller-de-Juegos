class_name AlmaEnergia
extends Node2D
## Chispa de energía que sale despedida de un enemigo muerto, frena y es succionada hacia el jugador.
## Las llegadas hacen "pop" en el cuerpo del jugador. Se dibuja en la capa sin tinte.

var objetivo: Node2D
var vel := Vector2.ZERO
var color := Color(0.55, 0.95, 1.0)
var _t := 0.0
var _estela: Array[Vector2] = []
const FASE_SALIDA := 0.22
const MAX_ESTELA := 10


static func lanzar(arbol: SceneTree, desde: Vector2, jugador: Node2D, cantidad: int, tinte: Color) -> void:
	var capa := JuiceCapa.obtener(arbol)
	for i in cantidad:
		var a := AlmaEnergia.new()
		a.objetivo = jugador
		a.color = tinte
		var ang := randf() * TAU
		a.vel = Vector2(cos(ang), sin(ang) - 0.6) * randf_range(380.0, 760.0)
		a.position = desde
		a.z_index = 56
		a.z_as_relative = false
		capa.add_child(a)


func _process(delta: float) -> void:
	if not is_instance_valid(objetivo):
		queue_free()
		return
	_t += delta
	var meta := objetivo.global_position + Vector2(0, 40)
	if _t < FASE_SALIDA:
		vel *= pow(0.02, delta / FASE_SALIDA)   # el chorro inicial se frena
	else:
		var dir := (meta - position)
		var d := dir.length()
		if d < 60.0:
			if objetivo.has_method("_punch_sprite"):
				objetivo.call("_punch_sprite", 0.05)
			queue_free()
			return
		vel = vel.lerp(dir / d * 2300.0, clampf(8.0 * delta, 0.0, 1.0))
	position += vel * delta
	_estela.push_front(position)
	if _estela.size() > MAX_ESTELA:
		_estela.pop_back()
	queue_redraw()


func _draw() -> void:
	# Estela: se dibuja en coordenadas locales restando la posición actual.
	for i in range(_estela.size() - 1):
		var a := 1.0 - float(i) / MAX_ESTELA
		draw_line(_estela[i] - position, _estela[i + 1] - position, Color(color.r, color.g, color.b, a * 0.7), 7.0 * a + 1.0)
	draw_circle(Vector2.ZERO, 15.0, Color(color.r, color.g, color.b, 0.28))
	draw_circle(Vector2.ZERO, 8.0, Color(color.r, color.g, color.b, 0.9))
	draw_circle(Vector2.ZERO, 4.0, Color(1, 1, 1, 1))
