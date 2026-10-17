@tool
extends Node2D
## Ojo central de la Estrella. `apertura` 0 = cerrado, 1 = abierto.
## Con arte (lo normal): `textura_abierta` (fondo), `textura_iris` (pupila) y `textura_frente`
## (encima de todo); la pupila se desplaza con `mirada` (sigue al jugador) y al parpadear se
## `textura_cerrado` se usa con el ojo del todo cerrado. Si no hay `textura_abierta`, dibuja
## el ojo con polígonos (respaldo). Todo editable en el Inspector.

@export_range(0.0, 1.0, 0.01) var apertura := 0.0:
	set(v):
		apertura = v
		queue_redraw()
@export var radio := 95.0:
	set(v):
		radio = v
		queue_redraw()
@export var textura_cerrado: Texture2D:
	set(v):
		textura_cerrado = v
		queue_redraw()
@export var cerrado_escala := Vector2.ONE:
	set(v):
		cerrado_escala = v
		queue_redraw()
@export var cerrado_offset := Vector2.ZERO:
	set(v):
		cerrado_offset = v
		queue_redraw()
@export_group("Arte (abierto)")
@export var escala := Vector2.ONE:  ## multiplica todo el ojo (abierto, iris y cerrado): un solo valor para agrandarlo
	set(v):
		escala = v
		queue_redraw()
@export var textura_abierta: Texture2D:
	set(v):
		textura_abierta = v
		queue_redraw()
@export var abierta_escala := Vector2.ONE:
	set(v):
		abierta_escala = v
		queue_redraw()
@export var abierta_offset := Vector2.ZERO:
	set(v):
		abierta_offset = v
		queue_redraw()
@export var textura_iris: Texture2D:
	set(v):
		textura_iris = v
		queue_redraw()
@export var iris_escala := Vector2.ONE:
	set(v):
		iris_escala = v
		queue_redraw()
@export var iris_offset := Vector2.ZERO:
	set(v):
		iris_offset = v
		queue_redraw()
@export var textura_frente: Texture2D:
	set(v):
		textura_frente = v
		queue_redraw()
@export var frente_escala := Vector2.ONE:
	set(v):
		frente_escala = v
		queue_redraw()
@export var frente_offset := Vector2.ZERO:
	set(v):
		frente_offset = v
		queue_redraw()
@export_group("Respaldo (si no hay arte)")
@export var color_esclera := Color(0.85, 0.9, 1.0):
	set(v):
		color_esclera = v
		queue_redraw()
@export var color_iris := Color(0.15, 0.45, 0.85):
	set(v):
		color_iris = v
		queue_redraw()
@export var color_parpado := Color(0.78, 0.22, 0.72):
	set(v):
		color_parpado = v
		queue_redraw()
@export var mostrar_nino := true
@export var color_nino := Color(1.0, 0.95, 0.8, 0.55):
	set(v):
		color_nino = v
		queue_redraw()

var mirada := Vector2.ZERO   # la mueve el jefe (hacia el jugador)
var nino_escudo := 0.0       # 0..1: el cultista aprieta al niño contra el iris (escudo); lo agranda y lo ilumina
@export var color_escudo := Color(0.55, 0.85, 1.0)


func _draw() -> void:
	if apertura <= 0.02 and textura_cerrado != null:
		var ts := textura_cerrado.get_size() * cerrado_escala * escala
		draw_texture_rect(textura_cerrado, Rect2(cerrado_offset - ts * 0.5, ts), false)
		return
	if textura_abierta != null:
		_dibujar_arte()
		return
	# --- Respaldo: ojo dibujado con polígonos (sin arte asignado) ---
	var w := radio * 1.45
	var h := radio * 0.85
	var almendra := _almendra(w, h)
	draw_colored_polygon(almendra, color_parpado.darkened(0.35))
	if apertura > 0.02:
		var hh := h * apertura
		draw_colored_polygon(_almendra(w * (0.6 + 0.4 * apertura), hh), color_esclera)
		var r_iris := minf(radio * 0.55, hh * 0.95)
		var c := mirada * apertura
		draw_circle(c, r_iris, color_iris)
		draw_circle(c, r_iris * 0.55, Color(0.03, 0.03, 0.08))
		if mostrar_nino and apertura > 0.4:
			if nino_escudo > 0.0:
				draw_circle(c, r_iris * (0.9 + 0.5 * nino_escudo), Color(color_escudo.r, color_escudo.g, color_escudo.b, 0.35 * nino_escudo))
			_dibujar_nino(c, r_iris * (0.5 + 0.9 * nino_escudo))
	# Contorno con trazos (como el boceto).
	var borde := almendra.duplicate()
	borde.append(almendra[0])
	draw_polyline(borde, color_iris, 5.0, true)
	for i in 5:
		var a := -PI * 0.85 + PI * 0.7 * float(i) / 4.0
		var p := Vector2(cos(a) * w * 1.05, sin(a) * h * 1.15)
		draw_line(p, p * 1.18, color_iris, 4.0, true)


## Ojo con arte: fondo (`textura_abierta`) + iris (`textura_iris`) desplazado por la mirada
## + frente (`textura_frente`) encima de todo. `apertura` recorta de arriba y abajo (parpadeo).
func _dibujar_arte() -> void:
	var ah := clampf(apertura, 0.0, 1.0)
	_dibujar_recortado(textura_abierta, abierta_offset, abierta_escala * escala, ah)
	if textura_iris != null and ah > 0.02:
		var centro := iris_offset + mirada * ah
		_dibujar_recortado(textura_iris, centro, iris_escala * escala, ah)
		if mostrar_nino and ah > 0.4:
			var tsz := textura_iris.get_size() * iris_escala * escala
			var r := minf(tsz.x, tsz.y) * 0.25
			_dibujar_nino(centro, r)
	if textura_frente != null:
		_dibujar_recortado(textura_frente, frente_offset, frente_escala * escala, ah)


## Dibuja `tex` centrada en `offset`, escalada por `esc`, mostrando solo la franja central
## de alto `a` (0 = nada, 1 = entera). Así el párpado "tapa" el ojo al parpadear.
func _dibujar_recortado(tex: Texture2D, offset: Vector2, esc: Vector2, a: float) -> void:
	var ah := clampf(a, 0.0, 1.0)
	if ah <= 0.001:
		return
	var sz := tex.get_size()
	var alto := sz.y * ah
	var region := Rect2(Vector2(0.0, (sz.y - alto) * 0.5), Vector2(sz.x, alto))
	var full := Rect2(offset - sz * esc * 0.5, sz * esc)
	var dest_h := alto * esc.y
	var dest := Rect2(Vector2(full.position.x, full.position.y + (full.size.y - dest_h) * 0.5),
			Vector2(sz.x * esc.x, dest_h))
	draw_texture_rect_region(tex, dest, region)


## Silueta del niño encogido dentro de la pupila (cabeza + cuerpo).
func _dibujar_nino(c: Vector2, r: float) -> void:
	draw_circle(c + Vector2(0, -r * 0.45), r * 0.32, color_nino)
	draw_colored_polygon(PackedVector2Array([
		c + Vector2(-r * 0.35, -r * 0.1), c + Vector2(r * 0.35, -r * 0.1),
		c + Vector2(r * 0.45, r * 0.7), c + Vector2(-r * 0.45, r * 0.7)]), color_nino)


func _almendra(w: float, h: float) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in 32:
		var a := TAU * float(i) / 32.0
		pts.append(Vector2(cos(a) * w, sin(a) * h * (1.0 - 0.4 * absf(cos(a)))))
	return pts
