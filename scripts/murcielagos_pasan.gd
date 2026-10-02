extends Area2D
## Murciélagos que cruzan rápido por la cueva (animación de presagio). Se dispara una vez al entrar
## el jugador; los murciélagos nacen fuera de pantalla y vuelan lejos del camino, con aleteos.
## Colocable en el editor: mover el nodo = dónde dispara; `altura`/`distancia` ajustan el vuelo.

@export var cantidad := 5
@export var altura := 380.0               ## px sobre el nodo por donde cruzan (el nodo va a nivel del suelo)
@export var dispersion_y := 160.0
@export var distancia := 3200.0           ## recorrido horizontal total
@export var velocidad_min := 1100.0
@export var velocidad_max := 1700.0
@export var hacia_la_izquierda := true
@export var escala := 1.4
@export var color := Color(0.1, 0.07, 0.18)
@export var sonidos: Array[AudioStream] = [
	preload("res://assets/audio/sfx/gen/aleteo_1.wav"),
	preload("res://assets/audio/sfx/gen/aleteo_2.wav"),
	preload("res://assets/audio/sfx/gen/aleteo_3.wav"),
]
@export var volumen_db := -8.0
@export var una_vez := true

var _disparado := false

signal paso


func _ready() -> void:
	collision_layer = 0
	collision_mask = 4
	body_entered.connect(_on_body_entered)


func _on_body_entered(body: Node2D) -> void:
	if _disparado or not body.is_in_group("player"):
		return
	_disparado = una_vez
	lanzar()


func lanzar() -> void:
	paso.emit()
	var dir := -1.0 if hacia_la_izquierda else 1.0
	var origen := global_position + Vector2(-dir * distancia * 0.5, -altura)
	var audio := get_node_or_null("/root/AudioManager")
	for i in cantidad:
		var m := _MurcielagoVolador.new()
		m.top_level = true
		m.color = color
		m.scale = Vector2(escala, escala) * randf_range(0.8, 1.2)
		m.velocidad = Vector2(dir * randf_range(velocidad_min, velocidad_max), randf_range(-60.0, 60.0))
		m.vida = distancia / absf(m.velocidad.x)
		m.global_position = origen + Vector2(-dir * float(i) * 180.0, randf_range(-dispersion_y, dispersion_y))
		add_child(m)
		if audio != null and not sonidos.is_empty():
			var snd: AudioStream = sonidos[i % sonidos.size()]
			var retraso := float(i) * 0.12
			get_tree().create_timer(retraso).timeout.connect(func() -> void: audio.play_sfx(snd, volumen_db, 0.15))


class _MurcielagoVolador extends Node2D:
	var color := Color.BLACK
	var velocidad := Vector2.ZERO
	var vida := 3.0
	var _t := randf() * TAU

	func _process(delta: float) -> void:
		_t += delta * 22.0
		global_position += velocidad * delta
		global_position.y += sin(_t * 0.3) * 40.0 * delta
		vida -= delta
		if vida <= 0.0:
			queue_free()
		queue_redraw()

	func _tri(a: Vector2, b: Vector2, c: Vector2) -> void:
		if absf((b - a).cross(c - a)) > 1.0:   # evita triángulos degenerados (fallan al triangular)
			draw_colored_polygon(PackedVector2Array([a, b, c]), color)

	func _draw() -> void:
		var f := sin(_t)                       # aleteo: las alas suben y bajan
		var dx := signf(velocidad.x)
		var ala_y := -28.0 * f
		_tri(Vector2(0, -8), Vector2(7, 0), Vector2(-7, 0))
		_tri(Vector2(7, 0), Vector2(0, 12), Vector2(-7, 0))
		for lado in [-1.0, 1.0]:
			var raiz := Vector2(lado * 4.0, -2.0)
			var p1 := Vector2(lado * 30.0, ala_y - 10.0)
			var p2 := Vector2(lado * 52.0, ala_y + 6.0)
			var p3 := Vector2(lado * 30.0, ala_y + 14.0)
			var p4 := Vector2(lado * 12.0, 8.0)
			_tri(raiz, p1, p2)
			_tri(raiz, p2, p3)
			_tri(raiz, p3, p4)
		draw_circle(Vector2(dx * 3.0, -3.0), 1.6, Color(1.0, 0.85, 0.5, 0.9))
