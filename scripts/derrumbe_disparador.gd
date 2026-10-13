extends Area2D
## Disparador del derrumbe del nivel 2. Se coloca y se redimensiona en el editor (CollisionShape2D hijo).
## Al entrar el jugador: barras de cine, el Humano pregunta, el Amuleto no sabe, hasta que ve el techo ceder y
## avisa; las barras se retiran, el control vuelve y arranca el derrumbe (`derrumbe`). La cinemática se ve una
## sola vez por partida: si el jugador muere y vuelve a pasar, el derrumbe arranca directo.

@export var derrumbe: Node                              ## el nodo `derrumbe_evento` que se activa
@export_group("Cinemática")
@export var id_visto := "n2_derrumbe_cine"              ## clave en Progresion: la cinemática se muestra una vez
@export var lineas_previas := PackedStringArray([
	"[humano]¿Qué está pasando?",
	"No lo sé... esto no debería moverse así.",
])
@export var lineas_alerta := PackedStringArray([
	"[grito]¡El techo se viene abajo! ¡Corré!",
])
@export var alto_barra := 110.0
@export var fuerza_temblor := 7.0                       ## temblor suave mientras el Amuleto "ve" el derrumbe
@export var fuerza_inicio := 3.0                        ## primer temblor leve al abrirse el diálogo (con alguna piedrita)
@export var piedras_inicio := 2
@export var fuerza_corre := 16.0                        ## temblor fuerte en el "¡Corré!"
@export var piedras_corre := 14
@export var pausa_antes := 0.5                          ## s entre que se frena el jugador y habla
@export var pausa_despues := 0.35                       ## s tras el aviso antes de devolver el control

var _usado := false
var _capa: CanvasLayer
var _barra_sup: ColorRect
var _barra_inf: ColorRect


func _ready() -> void:
	monitoring = true
	collision_layer = 0
	collision_mask = 4
	body_entered.connect(_on_body_entered)


func _on_body_entered(body: Node2D) -> void:
	if _usado or not body.is_in_group("player"):
		return
	_usado = true
	var prog := get_node_or_null("/root/Progresion") as Node
	var visto: bool = prog != null and prog.dialogo_visto(id_visto)
	if not visto:
		if prog != null:
			prog.marcar_dialogo_visto(id_visto)
		await _cinematica(body)
	_arrancar()


func _arrancar() -> void:
	if derrumbe != null and derrumbe.has_method("iniciar"):
		derrumbe.iniciar()


func _cinematica(jugador: Node2D) -> void:
	var dlg := get_node_or_null("/root/Dialogo")
	jugador.set("cinematica_dir", 0.0)
	jugador.set("cinematica_activa", true)
	_construir_barras()
	_mover_barras(true)
	await get_tree().create_timer(pausa_antes).timeout
	if dlg != null:
		_pulso(fuerza_inicio, 1.0, piedras_inicio, 4.0, 9.0)
		dlg.mostrar(Array(lineas_previas), "Amuleto", true)
		await dlg.dialogo_terminado
	_pulso(fuerza_temblor, 1.2, 5, 5.0, 12.0)
	await get_tree().create_timer(0.6).timeout
	if dlg != null:
		dlg.mostrar(Array(lineas_alerta), "Amuleto", true)
		_pulso(fuerza_corre, 1.6, piedras_corre, 9.0, 24.0)
		await dlg.dialogo_terminado
	await get_tree().create_timer(pausa_despues).timeout
	_mover_barras(false)
	if is_instance_valid(jugador):
		jugador.set("cinematica_activa", false)
	await get_tree().create_timer(0.8).timeout
	if is_instance_valid(_capa):
		_capa.queue_free()


func _pulso(fuerza: float, duracion: float, piedras: int, r_min: float, r_max: float) -> void:
	if derrumbe != null and derrumbe.has_method("pulso"):
		derrumbe.pulso(fuerza, duracion, piedras, r_min, r_max)
	else:
		_temblar(fuerza, duracion)


func _temblar(fuerza: float, duracion: float) -> void:
	var cam := get_viewport().get_camera_2d()
	if cam != null and cam.has_method("shake"):
		cam.shake(fuerza, duracion)


func _construir_barras() -> void:
	_capa = CanvasLayer.new()
	_capa.layer = 80
	add_child(_capa)
	_barra_sup = ColorRect.new()
	_barra_sup.color = Color.BLACK
	_barra_sup.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	_barra_sup.offset_top = -alto_barra
	_barra_sup.offset_bottom = 0.0
	_capa.add_child(_barra_sup)
	_barra_inf = ColorRect.new()
	_barra_inf.color = Color.BLACK
	_barra_inf.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	_barra_inf.offset_top = 0.0
	_barra_inf.offset_bottom = alto_barra
	_capa.add_child(_barra_inf)


func _mover_barras(entrar: bool) -> void:
	var tw := create_tween().set_parallel(true).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT if entrar else Tween.EASE_IN)
	var sup := 0.0 if entrar else -alto_barra
	var inf := -alto_barra if entrar else 0.0
	tw.tween_property(_barra_sup, "offset_top", sup, 0.7)
	tw.tween_property(_barra_sup, "offset_bottom", sup + alto_barra, 0.7)
	tw.tween_property(_barra_inf, "offset_top", inf, 0.7)
	tw.tween_property(_barra_inf, "offset_bottom", inf + alto_barra, 0.7)
