extends StaticBody2D

@export var box_size := Vector2(30, 34)
@export var box_color := Color(0.5, 0.35, 0.2)
@export var temblor_golpe := 6.0       ## px de sacudida al recibir un golpe que no lo rompe
@export var shake_romper := 5.0        ## sacudida de cámara al romperse
@export var hitstop_romper := 0.05
@export var sonido_golpe: AudioStream = preload("res://assets/audio/sfx/gen/rompible_golpe.wav")
@export var sonido_romper: AudioStream = preload("res://assets/audio/sfx/gen/rompible_romper.wav")
@export var volumen_db := -8.0

const GOLPES_PARA_ROMPER := 3

var golpes := 0
var broken := false
var _visual_pos_base := Vector2.ZERO
var _tw_temblor: Tween

@onready var visual: CanvasItem = get_node_or_null("Visual")
@onready var sprite: Sprite2D = get_node_or_null("Sprite2D")
@onready var collision: CollisionShape2D = $Collision


func _ready() -> void:
	if visual == null and sprite != null:
		visual = sprite
	if visual is Node2D:
		_visual_pos_base = (visual as Node2D).position
	add_to_group("rompible")


func registrar_golpe(_dano: int) -> void:
	if broken:
		return
	golpes += 1
	if golpes >= GOLPES_PARA_ROMPER:
		_romper()
	else:
		if visual != null:
			visual.modulate = Color(0.7, 0.7, 0.7)
		_feedback_golpe()


## Golpe que no lo rompe: sacudida lateral + astillas chicas (cada golpe más fuerte).
func _feedback_golpe() -> void:
	var audio := get_node_or_null("/root/AudioManager")
	if audio != null:
		audio.play_sfx(sonido_golpe, volumen_db, 0.1)
	Burst.emitir(self, global_position, box_color, 5 + golpes * 2, 0.7)
	if visual is Node2D:
		var v := visual as Node2D
		var base := _visual_pos_base   # fija: dos golpes seguidos ya no dejan el visual corrido
		if _tw_temblor != null and _tw_temblor.is_valid():
			_tw_temblor.kill()
			v.position = base
		var fuerza := temblor_golpe * (1.0 + 0.5 * (golpes - 1))
		_tw_temblor = create_tween()
		_tw_temblor.tween_property(v, "position", base + Vector2(fuerza, 0), 0.03)
		_tw_temblor.tween_property(v, "position", base - Vector2(fuerza * 0.7, 0), 0.04)
		_tw_temblor.tween_property(v, "position", base, 0.05)


func _romper() -> void:
	broken = true
	_burst_particulas()
	JuiceFx.escombros(get_tree(), global_position, box_color, 9, 1.0)
	var cam_p := get_viewport().get_camera_2d()
	if cam_p != null and cam_p.has_method("punch") and DisplayServer.get_name() != "headless":
		cam_p.punch(1.025)
	var audio := get_node_or_null("/root/AudioManager")
	if audio != null:
		audio.play_sfx(sonido_romper, volumen_db, 0.08)
	var cam := get_viewport().get_camera_2d()
	if cam != null and cam.has_method("shake"):
		cam.shake(shake_romper, 0.15)
	var hs := get_node_or_null("/root/Hitstop")
	if hs != null and hitstop_romper > 0.0:
		hs.freeze(hitstop_romper)
	# El fragmento de progresión lo otorga el alma al RECOGERLA (pickup.gd),
	# no al romper: si no la agarrás, no sumás el fragmento.
	_soltar_pickup()
	queue_free()


func _burst_particulas() -> void:
	if DisplayServer.get_name() == "headless":
		return
	var p: CPUParticles2D = (preload("res://scenes/burst.tscn") as PackedScene).instantiate()
	p.global_position = global_position
	p.self_modulate = box_color
	get_tree().root.add_child(p)
	p.restart()
	p.emitting = true


func _soltar_pickup() -> void:
	var pickup: Area2D = preload("res://scenes/pickup.tscn").instantiate()
	pickup.global_position = global_position - Vector2(0, 20)
	var destino: Node = get_tree().current_scene if get_tree().current_scene != null else get_parent()
	destino.add_child(pickup)
