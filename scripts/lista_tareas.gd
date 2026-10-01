extends Control

## Lista de tareas estilo cómic (tutorial y objetivos de nivel). Cada tarea se tacha con un
## ✓ y un destello al completarse. Se desliza desde el borde y se guarda al terminar todas.
## La maneja `Dialogo` (lista_agregar / lista_completar / ...).

const PAPEL := Color(0.97, 0.95, 0.89)
const TINTA := Color(0.05, 0.05, 0.06)
const ANCHO := 360.0
const PAD := 14.0
const TAM := 19

enum Estado { PENDIENTE, ACTUAL, HECHA }

var _items: Array[Dictionary] = []   # {id, texto, estado, total, cuenta, t_hecho}
var _fuente: Font
var _t := 0.0
var _cerrando := false
var _tw: Tween


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sf := SystemFont.new()
	sf.font_names = PackedStringArray(["Comic Sans MS", "Comic Neue", "Arial Black"])
	sf.font_weight = 700
	_fuente = sf
	visible = false


func hay_items() -> bool:
	return not _items.is_empty() and not _cerrando


func existe(id: String) -> bool:
	return _buscar(id) >= 0


func _buscar(id: String) -> int:
	for i in _items.size():
		if _items[i]["id"] == id:
			return i
	return -1


func agregar(id: String, texto: String, total := 1) -> void:
	if _buscar(id) >= 0:
		return
	if _cerrando:
		_items.clear()
		_cerrando = false
	_items.append({"id": id, "texto": texto, "estado": Estado.PENDIENTE, "total": total, "cuenta": 0, "t_hecho": -1.0})
	_refrescar()
	_entrar()


func marcar_actual(id: String) -> void:
	for it in _items:
		if it["estado"] == Estado.ACTUAL:
			it["estado"] = Estado.PENDIENTE
	var i := _buscar(id)
	if i >= 0 and _items[i]["estado"] != Estado.HECHA:
		_items[i]["estado"] = Estado.ACTUAL
	queue_redraw()


func progreso(id: String, cuenta: int) -> void:
	var i := _buscar(id)
	if i >= 0:
		_items[i]["cuenta"] = cuenta
		_refrescar()


func completar(id: String) -> void:
	var i := _buscar(id)
	if i < 0 or _items[i]["estado"] == Estado.HECHA:
		return
	_items[i]["estado"] = Estado.HECHA
	_items[i]["t_hecho"] = _t
	var audio := get_node_or_null("/root/AudioManager")
	if audio != null:
		audio.play_ui("ui_confirmar", -6.0)
	queue_redraw()
	if _todas_hechas():
		_cerrar_luego()


func _todas_hechas() -> bool:
	for it in _items:
		if it["estado"] != Estado.HECHA:
			return false
	return not _items.is_empty()


func _cerrar_luego() -> void:
	_cerrando = true
	await get_tree().create_timer(1.6, false).timeout
	if not _cerrando:
		return   # entró una tarea nueva mientras tanto
	if _tw != null and _tw.is_valid():
		_tw.kill()
	_tw = create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	_tw.tween_property(self, "position:x", -size.x - 40.0, 0.35)
	_tw.tween_callback(func() -> void:
		if _cerrando:
			_items.clear()
			_cerrando = false
			visible = false)


func _entrar() -> void:
	if visible and not _cerrando:
		return
	visible = true
	if _tw != null and _tw.is_valid():
		_tw.kill()
	position = Vector2(-size.x - 40.0, 250.0)
	if DisplayServer.get_name() == "headless":
		position.x = 20.0
		return
	_tw = create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_tw.tween_property(self, "position:x", 20.0, 0.45)


func _texto_fila(it: Dictionary) -> String:
	var txt: String = String(it["texto"]).to_upper()
	if int(it["total"]) > 1:
		txt += "  (%d/%d)" % [int(it["cuenta"]), int(it["total"])]
	return txt


func _alto_texto(txt: String, ancho: float) -> float:
	return _fuente.get_multiline_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, ancho, TAM).y


func _refrescar() -> void:
	if _fuente == null:
		return
	var alto := 44.0
	for it in _items:
		alto += maxf(36.0, _fuente.get_multiline_string_size(_texto_fila(it), HORIZONTAL_ALIGNMENT_LEFT, ANCHO - 2.0 * PAD - 44.0, TAM).y + 12.0)
	size = Vector2(ANCHO, alto + PAD)
	queue_redraw()


func _process(delta: float) -> void:
	if not visible:
		return
	_t += delta
	for it in _items:
		if it["t_hecho"] >= 0.0 and _t - float(it["t_hecho"]) < 1.2:
			queue_redraw()
			return


func _draw() -> void:
	if _fuente == null or _items.is_empty():
		return
	var r := Rect2(Vector2.ZERO, size)
	draw_rect(Rect2(r.position + Vector2(6, 6), r.size), Color(0, 0, 0, 0.8))
	draw_rect(r, PAPEL)
	draw_rect(Rect2(0, 0, size.x, 38), TINTA)
	draw_string(_fuente, Vector2(PAD, 28), "TAREAS", HORIZONTAL_ALIGNMENT_LEFT, -1, 21, PAPEL)
	var y := 44.0
	for it in _items:
		var txt := _texto_fila(it)
		var ancho_txt := ANCHO - 2.0 * PAD - 44.0
		var alto_fila := maxf(36.0, _fuente.get_multiline_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, ancho_txt, TAM).y + 12.0)
		var estado: int = it["estado"]
		var dt := _t - float(it["t_hecho"]) if it["t_hecho"] >= 0.0 else 99.0
		# destello al completar
		if dt < 0.5:
			draw_rect(Rect2(2, y, size.x - 4, alto_fila), Color(0, 0, 0, 0.25 * (1.0 - dt / 0.5)))
		var caja := Rect2(PAD, y + alto_fila * 0.5 - 13.0, 26, 26)
		draw_rect(caja, PAPEL)
		draw_rect(caja, TINTA, false, 3.0)
		if estado == Estado.ACTUAL:
			var s := 1.0 + 0.12 * sin(_t * 6.0)
			draw_colored_polygon(PackedVector2Array([Vector2(PAD - 10, y + alto_fila * 0.5 - 7.0 * s), Vector2(PAD - 3, y + alto_fila * 0.5), Vector2(PAD - 10, y + alto_fila * 0.5 + 7.0 * s)]), TINTA)
		var col := TINTA if estado != Estado.PENDIENTE else Color(0.45, 0.45, 0.47)
		draw_multiline_string(_fuente, Vector2(PAD + 38.0, y + (alto_fila - _alto_texto(txt, ancho_txt)) * 0.5 + _fuente.get_ascent(TAM)), txt, HORIZONTAL_ALIGNMENT_LEFT, ancho_txt, TAM, -1, col)
		if estado == Estado.HECHA:
			# ✓ con "pop" y tachado que avanza
			var k := clampf(dt / 0.25, 0.0, 1.0)
			var e := 1.0 + 0.5 * sin(k * PI) * (1.0 - k)
			var c0 := caja.get_center()
			var pts := PackedVector2Array([c0 + Vector2(-8, 0) * e, c0 + Vector2(-2, 7) * e, c0 + Vector2(10, -9) * e])
			draw_polyline(pts, TINTA, 5.0, true)
			var largo := minf(ancho_txt, _fuente.get_string_size(txt.get_slice("\n", 0), HORIZONTAL_ALIGNMENT_LEFT, ancho_txt, TAM).x)
			var tachado := clampf(dt / 0.3, 0.0, 1.0) * largo
			draw_line(Vector2(PAD + 38.0, y + alto_fila * 0.5), Vector2(PAD + 38.0 + tachado, y + alto_fila * 0.5), TINTA, 3.0)
		y += alto_fila
	draw_rect(r, TINTA, false, 5.0)
