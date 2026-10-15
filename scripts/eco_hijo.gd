extends Area2D
## Eco del hijo: cerca del final del nivel se oye su voz llamando "¡papá!".
## La PRIMERA vez del juego se reproduce una escena corta: el padre pierde el control, se desespera
## y se determina a seguir. Las veces siguientes solo suena la voz (con una línea opcional).
## Colocable desde el editor: mover el nodo y ajustar el rectángulo de su CollisionShape2D.

signal terminado

@export var sonido_grito: AudioStream = preload("res://assets/audio/sfx/gen/grito_papa.wav")   ## provisorio: reemplazar por la voz real
@export var volumen_db := -3.0
@export var volumen_eco_db := -11.0         ## segundo grito, más lejano
@export var id_visto := "eco_hijo"          ## clave en Progresion.dialogos_vistos (la escena larga solo corre una vez por partida)
@export var animar_primera_vez := true
@export_group("Textos")
@export var lineas_desesperacion: Array[String] = [
	"[humano][susurro]¿...Hijo?",
	"[humano][grito]¡HIJO! ¡Ya voy, aguantá!",
]
@export var lineas_determinacion: Array[String] = [
	"Está cerca. Lo sentí.",
	"[humano]No me voy a detener.",
]
@export var lineas_repeticion: Array[String] = []   ## cuando ya se oyó antes (sin bloquear al jugador)
@export_group("Animación")
@export var pausa_antes := 0.5
@export var seg_temblor := 1.2
@export var temblor_px := 3.0
@export var seg_hasta_eco := 0.9
@export var shake_camara := 7.0
@export var color_pulso := Color(0.6, 0.85, 1.0, 0.4)
@export var seg_maximos := 30.0             ## seguro: pasado este tiempo se devuelve el control

var _usado := false
var _jugador: Node2D


func _ready() -> void:
	monitoring = true
	collision_layer = 0
	collision_mask = 4
	body_entered.connect(_on_body_entered)


func _on_body_entered(body: Node2D) -> void:
	if _usado or not body.has_method("actualizar_checkpoint"):
		return
	_usado = true
	_jugador = body
	_correr()


func _correr() -> void:
	var prog := get_node_or_null("/root/Progresion")
	var vistos: Dictionary = prog.dialogos_vistos if prog != null else {}
	var primera := not vistos.has(id_visto)
	vistos[id_visto] = true
	if DisplayServer.get_name() == "headless":
		terminado.emit()
		return
	if primera and animar_primera_vez:
		await _escena_primera_vez()
	else:
		_gritar(volumen_db)
		_sacudir(shake_camara * 0.5, 0.4)
		if not lineas_repeticion.is_empty():
			var dlg := get_node_or_null("/root/Dialogo")
			if dlg != null:
				dlg.mostrar(lineas_repeticion, "Amuleto")
	terminado.emit()


func _escena_primera_vez() -> void:
	_jugador.set("cinematica_activa", true)
	_jugador.set("cinematica_dir", 0.0)
	var amb := get_tree().get_first_node_in_group("ambiente_sonoro")
	if amb != null:
		amb.pedir_silencio(self, 1.0)
	var limite := Time.get_ticks_msec() + int(seg_maximos * 1000.0)
	await get_tree().create_timer(pausa_antes).timeout
	# 1) la voz, lejana, y el golpe de oírla
	_gritar(volumen_db)
	_sacudir(shake_camara, 0.5)
	await get_tree().create_timer(0.35).timeout
	# 2) el padre tiembla (desesperación)
	await _temblar(seg_temblor)
	# 3) segundo grito, más lejano, y lo que dice
	_gritar(volumen_eco_db)
	await get_tree().create_timer(seg_hasta_eco).timeout
	await _decir(lineas_desesperacion, limite)
	# 4) determinación: pulso del Amuleto y a seguir
	_pulso()
	_sacudir(shake_camara * 0.6, 0.35)
	await _decir(lineas_determinacion, limite)
	if amb != null:
		amb.pedir_silencio(self, 0.0)
	_entregar_control()


func _gritar(db: float) -> void:
	var audio := get_node_or_null("/root/AudioManager")
	if audio != null and sonido_grito != null:
		audio.play_sfx(sonido_grito, db)


func _sacudir(amplitud: float, seg: float) -> void:
	var cam := get_viewport().get_camera_2d()
	if cam != null and cam.has_method("shake"):
		cam.shake(amplitud, seg)


## Vibra el cuerpo del padre en el lugar (el control está bloqueado y la velocidad en 0).
func _temblar(seg: float) -> void:
	if not is_instance_valid(_jugador):
		return
	var base_x := _jugador.position.x
	var t := 0.0
	while t < seg and is_instance_valid(_jugador):
		await get_tree().process_frame
		var dt := get_process_delta_time()
		t += dt
		var fuerza := temblor_px * (1.0 - t / seg * 0.4)
		_jugador.position.x = base_x + randf_range(-fuerza, fuerza)
	if is_instance_valid(_jugador):
		_jugador.position.x = base_x


func _decir(lineas: Array[String], limite_ms: int) -> void:
	var dlg := get_node_or_null("/root/Dialogo")
	if dlg == null or lineas.is_empty():
		return
	dlg.mostrar(lineas, "Amuleto", true)
	await get_tree().process_frame
	while (dlg.esta_activo() or dlg.hay_narrativa()) and Time.get_ticks_msec() < limite_ms:
		await get_tree().process_frame


func _pulso() -> void:
	var capa := CanvasLayer.new()
	capa.layer = 9
	capa.process_mode = Node.PROCESS_MODE_ALWAYS
	get_tree().root.add_child(capa)
	var velo := ColorRect.new()
	velo.set_anchors_preset(Control.PRESET_FULL_RECT)
	velo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	velo.color = color_pulso
	capa.add_child(velo)
	var tw := capa.create_tween()
	tw.set_ignore_time_scale(true)
	tw.tween_property(velo, "color:a", 0.0, 0.7).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.tween_callback(capa.queue_free)


func _entregar_control() -> void:
	if is_instance_valid(_jugador):
		_jugador.set("cinematica_activa", false)


func _exit_tree() -> void:
	if is_instance_valid(_jugador) and _jugador.get("cinematica_activa") == true:
		_entregar_control()
