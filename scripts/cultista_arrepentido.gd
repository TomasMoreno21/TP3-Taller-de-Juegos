extends Area2D

## Evento narrativo en estilo cinemática de intro (barras de cine, cámara que se acerca, jugador quieto y sin daño):
## un cultista aparece de la nada, habla y se desvanece. El origen del nodo son los PIES del cultista.
## Texto en res://data/dialogos.json (`dialogo_id`).

const DIALOGOS_PATH := "res://data/dialogos.json"

@export var dialogo_id := "n3_cultista"
@export var una_vez := true
@export var color_humo := Color(0.55, 0.35, 0.85, 1)
@export_group("Cinemática")
@export var alto_barra := 110.0
@export var zoom_cine := 1.18
@export var caminata_seg := 1.5            ## s que el jugador sigue caminando hacia el cultista antes de frenar
@export var caminata_fraccion := 0.5        ## fracción de su velocidad al caminar solo
@export var tiempo_camara := 2.2            ## s que tarda la cámara en acercarse al encuadre
@export var pausa_antes := 0.5              ## s de silencio tras frenar, antes de que aparezca el cultista
@export var tiempo_aparicion := 2.2         ## s del fundido de entrada del cultista
@export var pausa_antes_de_hablar := 0.9    ## s que se queda mirando antes de la primera línea
@export var pausa_final := 1.2              ## s que sigue ahí después de la última línea
@export var tiempo_desaparicion := 1.8
@export var altura_vuelo := 130.0           ## px que flota sobre el punto donde lo pusiste (un poco sobre el suelo, no tan alto como los voladores)
@export var amplitud_vaiven := 14.0         ## px del vaivén vertical al flotar
@export var velocidad_vaiven := 1.8         ## rad/s del vaivén
@export var aura_escena: PackedScene = preload("res://scenes/aura_mistica.tscn")   ## el diagrama que lo sostiene (igual al de los voladores)
@export var altura_globo := 330.0           ## px sobre sus pies (ya flotando) donde nace la cola del globo
@export var encuadre_y := -150.0            ## altura (respecto de los pies) del centro de la cámara
@export var seg_maximos := 40.0             ## red de seguridad: pasado este tiempo se devuelve el control

@onready var _animado: AnimatedSprite2D = $Animado

var _lineas: Array = []
var _lineas_despues: Array = []   ## charla del Amuleto y el Humano cuando el cultista ya se fue
var _en_curso := false
var _jugador: Node2D
var _cam: Camera2D
var _hud: CanvasLayer
var _hud_visible := true
var _capa: CanvasLayer
var _barra_sup: ColorRect
var _barra_inf: ColorRect
var _aura: Node2D
var _tw_cam: Tween
var _t := 0.0


func _ready() -> void:
	collision_layer = 0
	collision_mask = 4
	_animado.modulate.a = 0.0
	_animado.frame_changed.connect(_anclar_pies)
	_anclar_pies()
	if aura_escena != null:
		_aura = aura_escena.instantiate() as Node2D
		_aura.position = Vector2(0.0, -altura_vuelo + 8.0)
		add_child(_aura)
		move_child(_aura, 0)   # dibuja detrás del cultista
		_aura.modulate.a = 0.0
	var datos: Variant = JSON.parse_string(FileAccess.get_file_as_string(DIALOGOS_PATH))
	if datos is Dictionary and datos.get(dialogo_id) is Dictionary:
		_lineas = datos[dialogo_id].get("lineas", [])
		_lineas_despues = datos[dialogo_id].get("lineas_despues", [])
	else:
		push_error("CultistaArrepentido: no existe el diálogo '%s'" % dialogo_id)
	var prog := get_node_or_null("/root/Progresion")
	if una_vez and prog != null and prog.dialogo_visto(dialogo_id):
		queue_free()
		return
	body_entered.connect(_on_body_entered)


func _process(delta: float) -> void:
	_t += delta
	_animado.position.y = -altura_vuelo + sin(_t * velocidad_vaiven) * amplitud_vaiven
	if _aura != null:
		_aura.modulate.a = _animado.modulate.a   # el diagrama aparece y se va junto con él


func _on_body_entered(body: Node2D) -> void:
	if _en_curso or _lineas.is_empty() or not body.is_in_group("player"):
		return
	_en_curso = true
	set_deferred("monitoring", false)
	_jugador = body
	get_tree().create_timer(seg_maximos, false).timeout.connect(_entregar_control)   # nada deja al jugador bloqueado para siempre
	var prog := get_node_or_null("/root/Progresion")
	if una_vez and prog != null:
		prog.marcar_dialogo_visto(dialogo_id)   # morir no la repite
	_correr()


func _correr() -> void:
	var dialogo := get_node("/root/Dialogo")
	# Jugador quieto y sin daño (igual que en las intros).
	_jugador.set("cinematica_dir", 0.0)
	_jugador.set("cinematica_activa", true)
	_cam = get_viewport().get_camera_2d()
	if _cam != null and not _cam.has_method("modo_cine"):
		_cam = null
	_hud = get_tree().get_first_node_in_group("hud") as CanvasLayer
	if _hud != null:
		_hud_visible = _hud.visible
		_hud.visible = false
	dialogo.lista_ocultar(true)
	_animado.flip_h = _jugador.global_position.x > global_position.x   # el sprite base mira a la izquierda
	_barras(true)
	# La cámara se acerca despacio al encuadre entre los dos.
	if _cam != null:
		_cam.call("modo_cine")
		var mitad := (_jugador.global_position.x + global_position.x) * 0.5
		var destino := Vector2(mitad, global_position.y + encuadre_y - altura_vuelo * 0.5 + alto_barra * 0.4)
		_tw_cam = create_tween().set_parallel(true).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		_tw_cam.tween_property(_cam, "global_position", destino, tiempo_camara)
		_tw_cam.tween_property(_cam, "zoom", Vector2.ONE * zoom_cine, tiempo_camara)
	# El jugador camina un momento hacia el cultista, frena de golpe y recién ahí lo sorprende.
	var hacia := 1.0 if global_position.x >= _jugador.global_position.x else -1.0
	_jugador.set("cinematica_dir", hacia * caminata_fraccion)
	await _esperar(caminata_seg)
	_jugador.set("cinematica_dir", 0.0)
	await _esperar(pausa_antes)
	# Aparece: humo violeta y fundido lento.
	_humo()
	if _cam != null and _cam.has_method("shake"):
		_cam.call("shake", 3.0, 0.4)
	var tw := create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tw.tween_property(_animado, "modulate:a", 1.0, tiempo_aparicion)
	await _esperar(tiempo_aparicion + pausa_antes_de_hablar)
	# Habla.
	dialogo.ancla_hablante = self
	dialogo.nombre_ancla = ""   # sin hablante: el globo es igual al de los demás, sin rótulo
	dialogo.altura_ancla = altura_globo + altura_vuelo
	dialogo.mostrar(_lineas, "", true)
	await dialogo.dialogo_terminado
	await _esperar(pausa_final)
	# Se desvanece.
	dialogo.ancla_hablante = null
	_humo()
	var tw2 := create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tw2.tween_property(_animado, "modulate:a", 0.0, tiempo_desaparicion)
	await _esperar(tiempo_desaparicion + 0.4)
	_entregar_control()
	if not _lineas_despues.is_empty():
		dialogo.mostrar(_lineas_despues, "Amuleto", false, true)   # ya en juego, al instante y con el globo normal
	await _esperar(0.9)   # deja salir las barras antes de liberar el nodo
	queue_free()


## Espera `seg` (los timers no corren en pausa).
func _esperar(seg: float) -> void:
	await get_tree().create_timer(seg, false).timeout


func _entregar_control() -> void:
	if not _en_curso:
		return
	_en_curso = false
	if _tw_cam != null and _tw_cam.is_valid():
		_tw_cam.kill()   # no debe pelear con modo_normal por la posición/zoom de la cámara
	if is_instance_valid(_jugador):
		_jugador.set("cinematica_activa", false)
		_jugador.set("cinematica_dir", 0.0)
	if _cam != null and is_instance_valid(_cam):
		_cam.call("modo_normal")
	if is_instance_valid(_hud):
		_hud.visible = _hud_visible
	var dialogo := get_node_or_null("/root/Dialogo")
	if dialogo != null:
		dialogo.ancla_hablante = null
		dialogo.lista_ocultar(false, 0.8)
	_barras(false)


## Si la escena se descarga a mitad (menú, cambio de nivel) no deja nada bloqueado.
func _exit_tree() -> void:
	if _en_curso:
		_entregar_control()


func _humo() -> void:
	Burst.emitir(self, global_position + Vector2(0, -150 - altura_vuelo), color_humo, 24, 1.6)


func _barras(entrar: bool) -> void:
	if DisplayServer.get_name() == "headless":
		return
	if _capa == null:
		_capa = CanvasLayer.new()
		_capa.layer = 80
		add_child(_capa)
		_barra_sup = _rect(Control.PRESET_TOP_WIDE)
		_barra_sup.offset_top = -alto_barra
		_barra_sup.offset_bottom = 0.0
		_barra_inf = _rect(Control.PRESET_BOTTOM_WIDE)
		_barra_inf.offset_top = 0.0
		_barra_inf.offset_bottom = alto_barra
	var sup_top := 0.0 if entrar else -alto_barra
	var inf_top := -alto_barra if entrar else 0.0
	var tw := create_tween().set_parallel(true).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT if entrar else Tween.EASE_IN)
	tw.tween_property(_barra_sup, "offset_top", sup_top, 0.7)
	tw.tween_property(_barra_sup, "offset_bottom", sup_top + alto_barra, 0.7)
	tw.tween_property(_barra_inf, "offset_top", inf_top, 0.7)
	tw.tween_property(_barra_inf, "offset_bottom", inf_top + alto_barra, 0.7)


func _rect(preset: int) -> ColorRect:
	var r := ColorRect.new()
	r.color = Color.BLACK
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_capa.add_child(r)
	r.set_anchors_and_offsets_preset(preset)
	return r


## Apoya la base del dibujo (sin transparencia) en el origen del nodo.
func _anclar_pies() -> void:
	var sf := _animado.sprite_frames
	if sf == null or not sf.has_animation(_animado.animation):
		return
	var tex := sf.get_frame_texture(_animado.animation, _animado.frame)
	if tex != null:
		_animado.offset.y = -(tex.get_height() * 0.5 - Pies.relleno_inferior(tex))
