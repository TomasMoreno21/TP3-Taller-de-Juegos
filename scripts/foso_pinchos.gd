@tool
extends Node2D
## Foso con pinchos que se abre bajo la Estrella en la F2 (el piso central se rompe).
## Tocar los pinchos hace `dano` y devuelve al jugador al borde más cercano (como los
## peligros de Hollow Knight): cruzarlo pide salto largo (Lobo) o vuelo (Murciélago).
## El origen es el borde superior del foso, en el centro. Todo editable en el Inspector.

@export var ancho := 600.0:
	set(v):
		ancho = v
		queue_redraw()
@export var profundidad := 60.0:          ## desde el borde del piso hasta la base de los pinchos
	set(v):
		profundidad = v
		queue_redraw()
@export var alto_pinchos := 44.0:
	set(v):
		alto_pinchos = v
		queue_redraw()
@export var dano := 10
@export var distancia_borde := 140.0       ## px fuera del foso donde reaparece el jugador
@export var alto_jugador := 143.0          ## origen del jugador sobre sus pies
@export var pies_enemigo := 29.0           ## los pies del enemigo están este tanto por debajo de su origen
@export var color_fondo := Color(0.05, 0.03, 0.07)
@export var color_pincho := Color(0.75, 0.3, 0.68)
@export var activo := false:
	set(v):
		activo = v
		visible = v or Engine.is_editor_hint()
		queue_redraw()


func _ready() -> void:
	visible = activo or Engine.is_editor_hint()


func _physics_process(_delta: float) -> void:
	if Engine.is_editor_hint() or not activo:
		return
	_empalar_enemigos()
	var p := get_tree().get_first_node_in_group("player") as Node2D
	if p == null or p.get("_derrota_activa"):
		return
	var local := to_local(p.global_position)
	var pies := local.y + alto_jugador
	if absf(local.x) <= ancho * 0.5 and pies >= profundidad - alto_pinchos:
		_pinchar(p, local.x)


## Los enemigos que caen al foso mueren (si no, quedan atrapados y la oleada no termina).
func _empalar_enemigos() -> void:
	for e in get_tree().get_nodes_in_group("enemy"):
		if not (e is Node2D) or not e.has_method("take_damage"):
			continue
		if "health" in e and int(e.health) <= 0:
			continue
		var local := to_local((e as Node2D).global_position)
		if absf(local.x) <= ancho * 0.5 and local.y + pies_enemigo >= profundidad - alto_pinchos:
			e.take_damage(9999, 0.0, 1, true)


func _pinchar(p: Node2D, x_local: float) -> void:
	if not p.get("god_mode"):
		var audio := get_node_or_null("/root/AudioManager")
		if audio != null:
			audio.play_ui("pinchos", -8.0)
		Burst.emitir(self, p.global_position + Vector2(0, 50), color_pincho, 10, 0.7)
	p.take_damage(dano, 0.0, 0, true)
	var lado := 1.0 if x_local >= 0.0 else -1.0
	p.global_position = to_global(Vector2(lado * (ancho * 0.5 + distancia_borde), -alto_jugador))
	if "velocity" in p:
		p.velocity = Vector2.ZERO


func _draw() -> void:
	var w := ancho * 0.5
	draw_rect(Rect2(Vector2(-w, 0), Vector2(ancho, profundidad + 200.0)), color_fondo)
	var n := maxi(int(ancho / 40.0), 1)
	var paso := ancho / float(n)
	for i in n:
		var x0 := -w + paso * i
		draw_colored_polygon(PackedVector2Array([
			Vector2(x0, profundidad), Vector2(x0 + paso * 0.5, profundidad - alto_pinchos),
			Vector2(x0 + paso, profundidad)]), color_pincho)
