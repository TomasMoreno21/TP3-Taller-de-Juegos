@tool
extends Node2D
## Herramienta de autoría de niveles: dibuja en el editor (y opcionalmente en
## el juego) lo que verá la cámara, las trayectorias de salto de cada forma y
## una cuadrícula para alinear elementos. Solo lectura/dibujo: NO afecta el juego.

const PlayerScript := preload("res://scripts/player.gd")
const SCRIPTS_FORMAS := [
	preload("res://scripts/forms/humano.gd"),
	preload("res://scripts/forms/lobo.gd"),
	preload("res://scripts/forms/oso.gd"),
	preload("res://scripts/forms/murcielago.gd"),
]

const TAMANO_VIEWPORT := Vector2(1920.0, 1080.0)

@export_group("General")
@export var activo_en_editor := true
@export var activo_en_juego := false

@export_group("Camara / vista")
@export var mostrar_vista := true              # rect de lo que se ve en pantalla
@export var zoom_vista := 1.0                  # ajusta el rect si la cámara cambia de zoom
@export var desplazamiento_cam := Vector2(0, -310)  # offset de la cámara sobre el player (camera.gd)
@export var seguir_player := true              # sigue al nodo "Player" de la escena
@export var punto_vista := Vector2(960, 540)   # posición libre para el rect si no sigue al player
@export var mostrar_limites := false
@export var limites_camara := Rect2(-100, -2000, 16200, 3100)

@export_group("Saltos")
@export var formas_activas := [true, true, false, false]  # Humano, Lobo, Oso, Murciélago
@export var mostrar_altura := true
@export var mostrar_distancia := true
@export var doble_salto_lobo := true
@export var marcas_cada_tile := 0.0            # >0 dibuja marcas cada N px sobre la distancia

@export_group("Grid")
@export var mostrar_grid := true
@export var grid_size := 32.0

var _cache_formas: Array = []


const ACTION_TOGGLE := "toggle_herramienta"

func _process(_delta: float) -> void:
	if Engine.is_editor_hint():
		if activo_en_editor:
			queue_redraw()
		return
	if Input.is_action_just_pressed(ACTION_TOGGLE):
		activo_en_juego = not activo_en_juego
	if activo_en_juego:
		queue_redraw()


func _draw() -> void:
	if Engine.is_editor_hint() and not activo_en_editor:
		return
	if not Engine.is_editor_hint() and not activo_en_juego:
		return
	var area_vista := _rect_vista()
	if mostrar_grid:
		_draw_grid(area_vista)
	if mostrar_vista:
		_draw_rect_vista(area_vista)
	if mostrar_limites:
		_draw_rect(limites_camara, Color(1, 0.35, 0.3, 0.08), Color(1, 0.35, 0.3, 0.5))
	_draw_saltos()
	if not Engine.is_editor_hint():
		_draw_indicador(area_vista)


## Rect que verá la cámara (en coordenadas locales del nodo).
func _rect_vista() -> Rect2:
	var centro := _posicion_camara()
	var tam := TAMANO_VIEWPORT / maxf(zoom_vista, 0.01)
	return Rect2(centro - tam * 0.5 - global_position, tam)


func _posicion_camara() -> Vector2:
	if seguir_player:
		var jugador := _find_player()
		if jugador != null:
			return jugador.global_position + desplazamiento_cam
	return punto_vista


func _find_player() -> Node2D:
	var arbol := get_tree()
	if arbol == null:
		return null
	if not Engine.is_editor_hint():
		var p := arbol.get_first_node_in_group("player")
		return p as Node2D
	var raiz: Node = arbol.edited_scene_root
	if raiz == null:
		raiz = get_parent()
	return _find_node_by_name(raiz, "Player") as Node2D


func _find_node_by_name(n: Node, nombre: String) -> Node:
	if n.name == nombre:
		return n
	for c in n.get_children():
		var r := _find_node_by_name(c, nombre)
		if r != null:
			return r
	return null


func _draw_rect_vista(area: Rect2) -> void:
	_draw_rect(area, Color(0.3, 0.95, 0.5, 0.05), Color(0.3, 0.95, 0.5, 0.65))


func _draw_rect(rect: Rect2, relleno: Color, borde: Color) -> void:
	draw_rect(rect, relleno, true)
	draw_rect(rect, borde, false, 2.0)


func _draw_grid(area: Rect2) -> void:
	var gs := maxf(grid_size, 4.0)
	var color := Color(1, 1, 1, 0.12)
	var x := floorf(area.position.x / gs) * gs
	while x <= area.end.x:
		draw_line(Vector2(x, area.position.y), Vector2(x, area.end.y), color, 1.0)
		x += gs
	var y := floorf(area.position.y / gs) * gs
	while y <= area.end.y:
		draw_line(Vector2(area.position.x, y), Vector2(area.end.x, y), color, 1.0)
		y += gs


func _draw_saltos() -> void:
	if _cache_formas.is_empty():
		for s in SCRIPTS_FORMAS:
			_cache_formas.append(s.new())
	for i in _cache_formas.size():
		if i >= formas_activas.size() or not formas_activas[i]:
			continue
		var f: Variant = _cache_formas[i]
		var res: Array = _simular_salto(f)
		var puntos: PackedVector2Array = res[0]
		var altura: float = res[1]
		var distancia: float = res[2]
		var color: Color = f.color
		var nombre := str(f.form_name)
		draw_polyline(puntos, color, 2.5)
		if mostrar_distancia:
			draw_line(Vector2.ZERO, Vector2(distancia, 0), color * Color(1, 1, 1, 0.55), 1.0)
			_etiqueta(Vector2(distancia * 0.5, 12), "%s %d px" % [nombre, int(distancia)], color)
		if mostrar_altura:
			draw_line(Vector2.ZERO, Vector2(0, -altura), color * Color(1, 1, 1, 0.55), 1.0)
			_etiqueta(Vector2(8, -altura * 0.5), "%d px" % int(altura), color)
		if marcas_cada_tile > 0.0:
			_draw_marcas(distancia, color)


func _draw_marcas(distancia: float, color: Color) -> void:
	var paso := marcas_cada_tile
	var x := paso
	while x < distancia:
		draw_line(Vector2(x, -8), Vector2(x, 8), color * Color(1, 1, 1, 0.4), 1.0)
		x += paso


func _etiqueta(pos: Vector2, texto: String, color: Color) -> void:
	draw_string(ThemeDB.fallback_font, pos, texto, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, color)


## Aviso en pantalla (solo en juego) indicando que la herramienta está activa.
func _draw_indicador(area: Rect2) -> void:
	draw_rect(Rect2(area.position + Vector2(4, 4), Vector2(230, 20)), Color(0, 0, 0, 0.55), true)
	draw_string(ThemeDB.fallback_font, area.position + Vector2(10, 19),
			"HERRAMIENTA DE NIVEL activa [B]", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(0.6, 1, 0.7))


## Simula un salto completo con la física real de player.gd (sin glide).
## Devuelve [puntos_locales, altura_max, distancia_total].
func _simular_salto(f) -> Array:
	var pts := PackedVector2Array()
	var pos := Vector2.ZERO
	var vel_x: float = f.speed * minf(1.0, f.jump_h_speed_mult)
	var vel := Vector2(vel_x, f.jump_velocity)
	var altura := 0.0
	var doble_usado := false
	var doble_posible: bool = f.jumps > 1 and doble_salto_lobo
	var dt := 1.0 / 60.0
	pts.append(pos)
	for _i in 420:
		var g: float = PlayerScript.GRAVITY * f.gravity_scale
		if absf(vel.y) < PlayerScript.APEX_CORE_THRESHOLD:
			g *= PlayerScript.APEX_CORE_MULT
		elif absf(vel.y) < PlayerScript.APEX_THRESHOLD:
			g *= PlayerScript.APEX_GRAVITY_MULT
		if vel.y > 0.0:
			g *= PlayerScript.FALL_GRAVITY_MULT
		vel.y = minf(vel.y + g * dt, PlayerScript.MAX_FALL_SPEED)
		pos += vel * dt
		pts.append(pos)
		altura = maxf(altura, -pos.y)
		if doble_posible and not doble_usado and vel.y >= 0.0 and pos.y < -6.0:
			vel.y = f.jump_velocity
			doble_usado = true
		if pos.y >= 0.0 and vel.y > 0.0 and _i > 2:
			break
	return [pts, altura, pos.x]