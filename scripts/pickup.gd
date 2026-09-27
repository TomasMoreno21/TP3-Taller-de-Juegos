extends Area2D
## Alma recolectable: flota y late en reposo; al recogerla da energía + fragmento
## y deja un estallido azul con "pop" (el efecto vive aparte: el pickup se libera ya).

@export var flote_amplitud := 6.0        ## px de subida/bajada en reposo
@export var flote_velocidad := 2.2
@export var pulso_velocidad := 3.0       ## latido del halo y la luz
@export var color_burst := Color(0.45, 0.72, 1.0)
@export var sonido_recoger: AudioStream = preload("res://assets/audio/sfx/gen/pickup.wav")
@export var volumen_recoger_db := -8.0

var _t := randf() * TAU
var _recogido := false
var _base_visual := Vector2.ZERO
var _base_halo := Vector2.ZERO
var _alpha_halo := 1.0
var _energia_luz := 1.0

@onready var visual: Polygon2D = $Visual
@onready var halo: Sprite2D = get_node_or_null("Halo")
@onready var luz: PointLight2D = get_node_or_null("Luz")


func _ready() -> void:
	monitoring = true
	collision_mask = 4
	body_entered.connect(_on_body_entered)
	_base_visual = visual.position
	if halo != null:
		_base_halo = halo.position
		_alpha_halo = halo.modulate.a
	if luz != null:
		_energia_luz = luz.energy


func _process(delta: float) -> void:
	if _recogido:
		return
	_t += delta
	var dy := sin(_t * flote_velocidad) * flote_amplitud
	visual.position = _base_visual + Vector2(0, dy)
	var latido := 0.8 + 0.2 * sin(_t * pulso_velocidad)
	if halo != null:
		halo.position = _base_halo + Vector2(0, dy)
		halo.modulate.a = _alpha_halo * latido
	if luz != null:
		luz.energy = _energia_luz * latido


func _on_body_entered(body: Node2D) -> void:
	if _recogido or not body.has_method("recoger_energia"):
		return
	_recogido = true
	body.recoger_energia()
	# El alma contribuye a subir de nivel (fragmentos → desbloqueo de combos).
	get_node("/root/Progresion").add_fragmentos(1)
	_efecto_recoger()
	queue_free()


func _efecto_recoger() -> void:
	var audio := get_node_or_null("/root/AudioManager")
	if audio != null:
		audio.play_sfx(sonido_recoger, volumen_recoger_db, 0.08)
	if DisplayServer.get_name() == "headless":
		return
	Burst.emitir(self, visual.global_position, color_burst, 14)
	# Copia del rombo + halo que se infla y desvanece donde estaba el alma.
	var fx := Node2D.new()
	fx.global_position = global_position
	fx.z_index = z_index + 1
	var rombo := visual.duplicate() as Polygon2D
	fx.add_child(rombo)
	var h: Sprite2D = null
	if halo != null:
		h = halo.duplicate() as Sprite2D
		fx.add_child(h)
	get_tree().current_scene.add_child(fx)
	var tw := fx.create_tween().set_parallel(true)
	tw.tween_property(rombo, "scale", Vector2.ONE * 1.9, 0.2).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(rombo, "modulate:a", 0.0, 0.2)
	if h != null:
		tw.tween_property(h, "scale", h.scale * 2.4, 0.3)
		tw.tween_property(h, "modulate:a", 0.0, 0.3)
	tw.chain().tween_callback(fx.queue_free)
