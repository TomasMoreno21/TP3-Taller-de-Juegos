extends Node2D
class_name IntroNivel

## Intro in-game de un nivel (≈10 s): fundido desde negro, barras de cine, la cámara recorre
## los planos (hijos PlanoIntro, en orden) con narración en cartela y un globo del Amuleto.
## Se juega sobre el nivel real: jugador, fondo y ambiente son los del juego. Se ve una sola
## vez por partida (`una_vez`) y se puede saltear manteniendo `dialog_skip`.

signal terminada

@export var id_visto := "intro_nivel1"
@export var una_vez := true
@export var fundido_inicial := 0.8
@export var alto_barra := 110.0
@export var tam_cartela := 34
@export var seg_mantener_saltar := 1.0
@export var resplandor: CanvasItem            ## luz lejana: aparece con la intro y se apaga al entregar el control
@export var velocidad_caminata := 0.35     ## fracción de la velocidad del jugador al caminar solo
@export var inicio_x := -1400.0             ## el jugador arranca la intro en esta x (para que el paseo dure toda la charla)
@export var caminar_hasta_x := 0.0          ## el jugador se detiene al llegar a esta x (tope de seguridad)
@export var color_pulso := Color(0.6, 0.85, 1.0, 0.55)
@export var sonido_pulso: AudioStream         ## opcional: sonido grave del Amuleto al despertar
@export var probar_en_headless := false       ## en headless la intro se omite (los tests esperan control inmediato)

var _planos: Array[PlanoIntro] = []
var _cam: Camera2D
var _jugador: Node2D
var _hud: CanvasLayer
var _capa: CanvasLayer
var _negro: ColorRect
var _flash: ColorRect
var _barra_sup: ColorRect
var _barra_inf: ColorRect
var _barra_skip: ColorRect
var _cartela: Label
var _tw_cam: Tween
var _tw_cartela: Tween
var _activa := false
var _saltar := false
var _mantenido := 0.0
var _t := 0.0
var _seguir := false
var _camina := false
var _escala_resplandor := 1.0


func _ready() -> void:
	set_process(false)
	for h in get_children():
		if h is PlanoIntro:
			_planos.append(h)
	if _planos.is_empty():
		return
	if DisplayServer.get_name() == "headless" and not probar_en_headless:
		return
	var prog := get_node_or_null("/root/Progresion")
	if una_vez and prog != null and prog.dialogo_visto(id_visto):
		return
	_jugador = get_tree().get_first_node_in_group("player") as Node2D
	_cam = get_viewport().get_camera_2d()
	if _jugador == null or _cam == null or not _cam.has_method("modo_cine"):
		return
	if prog != null:
		prog.marcar_dialogo_visto(id_visto)   # morir o saltearla no la repite
	_activa = true
	_jugador.global_position.x = inicio_x
	_jugador.set("cinematica_activa", true)
	_hud = get_tree().get_first_node_in_group("hud") as CanvasLayer
	if _hud != null:
		_hud.visible = false
	_construir_capa()
	_cam.call("modo_cine")
	set_process(true)
	_correr()


func _process(delta: float) -> void:
	if not _activa:
		return
	_t += delta
	if _seguir:
		var meta := _jugador.global_position + (_cam.get("desplazamiento") as Vector2)
		_cam.global_position = _cam.global_position.lerp(meta, 1.0 - exp(-3.5 * delta))
	if _camina and _jugador.global_position.x >= caminar_hasta_x:
		_camina = false
		_jugador.set("cinematica_dir", 0.0)
	if resplandor != null:
		resplandor.scale = Vector2.ONE * (_escala_resplandor + 0.1 * sin(_t * 2.2))   # la luz "respira"
	if Input.is_action_pressed("dialog_skip"):
		_mantenido += delta
	else:
		_mantenido = maxf(_mantenido - delta * 2.0, 0.0)
	_barra_skip.size.x = 160.0 * clampf(_mantenido / seg_mantener_saltar, 0.0, 1.0)
	_barra_skip.visible = _mantenido > 0.05
	if _mantenido >= seg_mantener_saltar:
		_saltar = true


func _correr() -> void:
	var tw_negro := create_tween()
	tw_negro.tween_property(_negro, "color:a", 0.0, fundido_inicial)
	_barras(true)
	if resplandor != null:
		_escala_resplandor = resplandor.scale.x
		resplandor.modulate.a = 0.0
		create_tween().tween_property(resplandor, "modulate:a", 1.0, 3.0)
	for p in _planos:
		if p.devolver_control:
			break
		_arrancar_plano(p)
		await _esperar(p.duracion)
		if _saltar:
			break
	if _saltar:
		_cam.call("modo_normal", true)   # saltear: la cámara vuelve de golpe al jugador
	_entregar_control()
	for p in _planos:
		if p.devolver_control and not _saltar and not p.globo.is_empty():
			get_node("/root/Dialogo").mostrar(Array(p.globo), "Amuleto", p.globo_marcado)
			break


func _arrancar_plano(p: PlanoIntro) -> void:
	var destino := p.global_position
	if p.seguir_jugador:
		destino = _jugador.global_position + (_cam.get("desplazamiento") as Vector2)
	if p.zoom_desde > 0.0:
		_cam.global_position = destino if p.seguir_jugador else p.global_position + p.arranca_desde
		_cam.zoom = Vector2.ONE * p.zoom_desde
	if _tw_cam != null and _tw_cam.is_valid():
		_tw_cam.kill()
	_seguir = p.seguir_jugador
	_tw_cam = create_tween().set_parallel(true).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	if not _seguir:
		_tw_cam.tween_property(_cam, "global_position", destino, p.duracion)
	_tw_cam.tween_property(_cam, "zoom", Vector2.ONE * p.zoom, p.duracion)
	_mostrar_cartela(p.cartela, p.duracion)
	if p.camina and _jugador.global_position.x < caminar_hasta_x:
		_camina = true
		_jugador.set("cinematica_dir", velocidad_caminata)
	if not p.globo.is_empty():
		if p.retraso_globo > 0.0:
			get_tree().create_timer(p.retraso_globo).timeout.connect(_decir.bind(p))
		else:
			_decir(p)
	if p.pulso:
		get_tree().create_timer(p.pulso_en).timeout.connect(_pulso)


func _decir(p: PlanoIntro) -> void:
	if _saltar:
		return
	get_node("/root/Dialogo").mostrar(Array(p.globo), "Amuleto", p.globo_marcado)


func _pulso() -> void:
	if not _activa:
		return
	_flash.color = color_pulso
	create_tween().tween_property(_flash, "color:a", 0.0, 0.7).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	if _cam.has_method("shake"):
		_cam.call("shake", 6.0, 0.35)
	if sonido_pulso != null:
		var ap := AudioStreamPlayer.new()
		ap.stream = sonido_pulso
		ap.bus = &"SFX" if AudioServer.get_bus_index(&"SFX") >= 0 else &"Master"
		add_child(ap)
		ap.finished.connect(ap.queue_free)
		ap.play()


func _mostrar_cartela(texto: String, duracion: float) -> void:
	if _tw_cartela != null and _tw_cartela.is_valid():
		_tw_cartela.kill()
	_cartela.text = texto
	_cartela.visible_ratio = 0.0
	_cartela.modulate.a = 1.0
	if texto.is_empty():
		return
	var escribir := minf(1.8, duracion * 0.45)
	_tw_cartela = create_tween()
	_tw_cartela.tween_interval(0.3)
	_tw_cartela.tween_property(_cartela, "visible_ratio", 1.0, escribir)
	_tw_cartela.tween_interval(maxf(duracion - 0.3 - escribir - 0.4, 0.0))
	_tw_cartela.tween_property(_cartela, "modulate:a", 0.0, 0.4)


func _esperar(seg: float) -> void:
	var t := 0.0
	while t < seg and not _saltar:
		await get_tree().process_frame
		t += get_process_delta_time()


## Devuelve el control, retira las barras y apaga la luz lejana. La cámara sale de modo
## "cine" con su viaje suave de vuelta al jugador (modo_normal).
func _entregar_control() -> void:
	if not _activa:
		return
	_activa = false
	_seguir = false
	_camina = false
	_jugador.set("cinematica_dir", 0.0)
	set_process(false)
	if _tw_cam != null and _tw_cam.is_valid():
		_tw_cam.kill()
	if _tw_cartela != null and _tw_cartela.is_valid():
		_tw_cartela.kill()
	if not _saltar:
		_cam.call("modo_normal")
	_jugador.set("cinematica_activa", false)
	if _hud != null:
		_hud.visible = true
	_cartela.modulate.a = 0.0
	_barra_skip.visible = false
	_barras(false)
	_negro.color.a = 0.0
	if resplandor != null:
		create_tween().tween_property(resplandor, "modulate:a", 0.0, 2.0)
	terminada.emit()
	await get_tree().create_timer(0.9).timeout
	_capa.queue_free()


func _barras(entrar: bool) -> void:
	var dur := 0.7
	var tw := create_tween().set_parallel(true).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT if entrar else Tween.EASE_IN)
	var sup_top := 0.0 if entrar else -alto_barra
	var inf_top := -alto_barra if entrar else 0.0
	tw.tween_property(_barra_sup, "offset_top", sup_top, dur)
	tw.tween_property(_barra_sup, "offset_bottom", sup_top + alto_barra, dur)
	tw.tween_property(_barra_inf, "offset_top", inf_top, dur)
	tw.tween_property(_barra_inf, "offset_bottom", inf_top + alto_barra, dur)


func _construir_capa() -> void:
	_capa = CanvasLayer.new()
	_capa.layer = 80
	add_child(_capa)
	_flash = _rect(Control.PRESET_FULL_RECT, Color(0, 0, 0, 0))
	_barra_sup = _rect(Control.PRESET_TOP_WIDE, Color.BLACK)
	_barra_sup.offset_top = -alto_barra
	_barra_sup.offset_bottom = 0.0
	_barra_inf = _rect(Control.PRESET_BOTTOM_WIDE, Color.BLACK)
	_barra_inf.offset_top = 0.0
	_barra_inf.offset_bottom = alto_barra
	_negro = _rect(Control.PRESET_FULL_RECT, Color.BLACK)
	_cartela = Label.new()
	_cartela.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	_cartela.offset_top = -alto_barra
	_cartela.offset_bottom = 0.0
	_cartela.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_cartela.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_cartela.visible_ratio = 0.0
	var sf := SystemFont.new()
	sf.font_names = PackedStringArray(["Comic Sans MS", "Comic Neue", "Arial Black"])
	_cartela.add_theme_font_override("font", sf)
	_cartela.add_theme_font_size_override("font_size", tam_cartela)
	_cartela.add_theme_color_override("font_color", Color(0.96, 0.94, 0.88))
	_cartela.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	_cartela.add_theme_constant_override("outline_size", 6)
	_capa.add_child(_cartela)
	_barra_skip = ColorRect.new()
	_barra_skip.color = Color(1, 1, 1, 0.8)
	_barra_skip.position = Vector2(1920.0 - 200.0, 1080.0 - 24.0)
	_barra_skip.size = Vector2(0.0, 5.0)
	_barra_skip.visible = false
	_capa.add_child(_barra_skip)


func _rect(preset: int, color: Color) -> ColorRect:
	var r := ColorRect.new()
	r.color = color
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_capa.add_child(r)
	r.set_anchors_and_offsets_preset(preset)
	return r
