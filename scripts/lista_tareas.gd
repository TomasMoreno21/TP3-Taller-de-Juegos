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
var _idx_vista := -1
var _t_cambio := 0.0
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
		_idx_vista = -1
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


## Resalta una tarea que el jugador no logra (marco que late).
func pista(id: String) -> void:
	var i := _buscar(id)
	if i >= 0:
		_items[i]["pista"] = true
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
			_idx_vista = -1
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


## Una sola tarea a la vez: la que se está haciendo (o, un instante, la recién completada).
func _idx_mostrado() -> int:
	var ultimo := -1
	var t_ultimo := -1.0
	for i in _items.size():
		var th: float = _items[i]["t_hecho"]
		if th >= 0.0 and th > t_ultimo:
			t_ultimo = th
			ultimo = i
	if ultimo >= 0 and _t - t_ultimo < 1.3:
		return ultimo
	for i in _items.size():
		if _items[i]["estado"] != Estado.HECHA:
			return i
	return _items.size() - 1


func _refrescar() -> void:
	if _fuente == null or _items.is_empty():
		return
	var it: Dictionary = _items[clampi(_idx_mostrado(), 0, _items.size() - 1)]
	var alto := 44.0 + maxf(36.0, _alto_texto(_texto_fila(it), ANCHO - 2.0 * PAD - 44.0) + 12.0)
	size = Vector2(ANCHO, alto + PAD * 0.5)
	queue_redraw()


func _process(delta: float) -> void:
	if not visible or _items.is_empty():
		return
	_t += delta
	var idx := _idx_mostrado()
	if idx != _idx_vista:
		_idx_vista = idx
		_t_cambio = _t
		_refrescar()
	self_modulate.a = clampf((_t - _t_cambio) / 0.25, 0.0, 1.0) if _t_cambio > 0.5 else 1.0
	queue_redraw()


func _draw() -> void:
	if _fuente == null or _items.is_empty():
		return
	var it: Dictionary = _items[clampi(_idx_mostrado(), 0, _items.size() - 1)]
	var r := Rect2(Vector2.ZERO, size)
	draw_rect(Rect2(r.position + Vector2(6, 6), r.size), Color(0, 0, 0, 0.8))
	draw_rect(r, PAPEL)
	draw_rect(Rect2(0, 0, size.x, 38), TINTA)
	var hechas := 0
	for x in _items:
		if x["estado"] == Estado.HECHA:
			hechas += 1
	var titulo := "TAREA" if _items.size() == 1 else "TAREA %d/%d" % [mini(hechas + 1, _items.size()), _items.size()]
	draw_string(_fuente, Vector2(PAD, 28), titulo, HORIZONTAL_ALIGNMENT_LEFT, -1, 21, PAPEL)
	var y := 44.0
	var txt := _texto_fila(it)
	var ancho_txt := ANCHO - 2.0 * PAD - 44.0
	var alto_fila := maxf(36.0, _alto_texto(txt, ancho_txt) + 12.0)
	var estado: int = it["estado"]
	var dt := _t - float(it["t_hecho"]) if it["t_hecho"] >= 0.0 else 99.0
	if dt < 0.5:   # destello al completar
		draw_rect(Rect2(2, y, size.x - 4, alto_fila), Color(0, 0, 0, 0.25 * (1.0 - dt / 0.5)))
	var caja := Rect2(PAD, y + alto_fila * 0.5 - 13.0, 26, 26)
	if it.get("pista", false) and estado != Estado.HECHA:
		var l := 0.5 + 0.5 * sin(_t * 7.0)
		draw_rect(Rect2(3, y + 2, size.x - 6, alto_fila - 4), Color(0, 0, 0, 0.35 * l), false, 4.0)
	draw_rect(caja, PAPEL)
	draw_rect(caja, TINTA, false, 3.0)
	draw_multiline_string(_fuente, Vector2(PAD + 38.0, y + (alto_fila - _alto_texto(txt, ancho_txt)) * 0.5 + _fuente.get_ascent(TAM)), txt, HORIZONTAL_ALIGNMENT_LEFT, ancho_txt, TAM, -1, TINTA)
	if estado == Estado.HECHA:   # ✓ con "pop" y tachado que avanza
		var k := clampf(dt / 0.25, 0.0, 1.0)
		var e := 1.0 + 0.5 * sin(k * PI) * (1.0 - k)
		var c0 := caja.get_center()
		draw_polyline(PackedVector2Array([c0 + Vector2(-8, 0) * e, c0 + Vector2(-2, 7) * e, c0 + Vector2(10, -9) * e]), TINTA, 5.0, true)
		var largo := minf(ancho_txt, _fuente.get_string_size(txt.get_slice("
", 0), HORIZONTAL_ALIGNMENT_LEFT, ancho_txt, TAM).x)
		draw_line(Vector2(PAD + 38.0, y + alto_fila * 0.5), Vector2(PAD + 38.0 + clampf(dt / 0.3, 0.0, 1.0) * largo, y + alto_fila * 0.5), TINTA, 3.0)
	draw_rect(r, TINTA, false, 5.0)
