extends Area2D
## Desbloquea una forma de transformación cuando el jugador entra al área.
## Colocable en el editor: elegir `forma` (0=Humano, 1=Lobo, 2=Oso, 3=Murciélago).
## Se da una sola vez por partida (Progresion es autoload, persiste al morir/reintentar).
## Visible en el mundo: un sello de espíritu que flota y brilla; al tocarlo estalla
## con cámara lenta y un destello del color de la forma.

signal desbloqueada

@export_enum("Humano:0", "Lobo:1", "Oso:2", "Murcielago:3") var forma: int = 1
@export var una_vez := true
@export var orbe_offset := Vector2(0, 40)     ## posición del sello respecto del centro del área
@export var color_sello := Color(0.66, 0.8, 1.0)
@export var flote_amplitud := 10.0
@export var slowmo_duracion := 0.5
@export_range(0.05, 1.0) var slowmo_escala := 0.3
@export var sonido_desbloqueo: AudioStream = preload("res://assets/audio/sfx/gen/nivel_subido.wav")
@export var volumen_db := -4.0

var _dado := false
var _t := 0.0

@onready var orbe: Node2D = get_node_or_null("Orbe")


func _ready() -> void:
	collision_layer = 0
	collision_mask = 4
	monitoring = true
	body_entered.connect(_on_body_entered)
	if orbe != null:
		orbe.position = orbe_offset
		for n in orbe.get_children():
			if n is Polygon2D:
				(n as Polygon2D).color = Color(color_sello, (n as Polygon2D).color.a)
			elif n is Sprite2D:
				(n as Sprite2D).modulate = Color(color_sello, (n as Sprite2D).modulate.a)
			elif n is PointLight2D:
				(n as PointLight2D).color = color_sello
		# Ya desbloqueada (reintento tras morir): el sello no vuelve a aparecer.
		var prog := get_node_or_null("/root/Progresion")
		if una_vez and prog != null and "_extra_formas" in prog and prog._extra_formas.has(forma):
			orbe.visible = false
			_dado = true


func _process(delta: float) -> void:
	if orbe == null or not orbe.visible or _dado:
		return
	_t += delta
	orbe.position = orbe_offset + Vector2(0, sin(_t * 2.0) * flote_amplitud)
	orbe.rotation = sin(_t * 1.3) * 0.08
	var halo := orbe.get_node_or_null("Halo") as Sprite2D
	if halo != null:
		halo.scale = Vector2.ONE * (0.75 + 0.08 * sin(_t * 3.0))


func _on_body_entered(body: Node2D) -> void:
	if _dado:
		return
	if not body.is_in_group("player"):
		return
	var prog := get_node_or_null("/root/Progresion")
	if prog == null:
		return
	_dado = true
	if una_vez:
		set_deferred("monitoring", false)
	_efecto_desbloqueo()
	(prog as Node).desbloquear_forma(forma)
	desbloqueada.emit()


func _efecto_desbloqueo() -> void:
	var audio := get_node_or_null("/root/AudioManager")
	if audio != null:
		audio.play_sfx(sonido_desbloqueo, volumen_db)
	var hs := get_node_or_null("/root/Hitstop")
	if hs != null and slowmo_duracion > 0.0:
		hs.slowmo(slowmo_duracion, slowmo_escala)
	if DisplayServer.get_name() == "headless" or orbe == null:
		return
	var cam := get_viewport().get_camera_2d()
	if cam != null and cam.has_method("punch"):
		cam.punch(1.08)
	Burst.emitir(self, orbe.global_position, color_sello, 32, 1.8)
	# El sello se infla y se disuelve.
	var tw := orbe.create_tween().set_parallel(true)
	tw.tween_property(orbe, "scale", orbe.scale * 2.2, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(orbe, "modulate:a", 0.0, 0.4)
	tw.chain().tween_callback(func() -> void: orbe.visible = false)
	# Destello de pantalla del color de la forma.
	var capa := CanvasLayer.new()
	capa.layer = 99
	var flash := ColorRect.new()
	flash.set_anchors_preset(Control.PRESET_FULL_RECT)
	flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	flash.color = Color(color_sello, 0.55)
	capa.add_child(flash)
	get_tree().root.add_child(capa)
	var tf := flash.create_tween().set_ignore_time_scale(true)
	tf.tween_property(flash, "color:a", 0.0, 0.6)
	tf.tween_callback(capa.queue_free)
