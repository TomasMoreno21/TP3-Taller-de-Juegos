extends Area2D

## Punto de control colocable desde el editor: al tocarlo guarda el respawn
## completo del jugador (posición, forma, vida, energía) y se enciende.
## Al morir, derrota.gd teletransporta al jugador acá SIN recargar el nivel.

signal activado

@export var offset_respawn := Vector2(0, -60)
@export var color_apagado := Color(0.45, 0.5, 0.62)
@export var color_encendido := Color(0.35, 0.9, 0.6)
@export var color_luz := Color(0.7, 1.0, 0.55)  ## luz verde-dorada de bosque (aparte del color del cristal)
@export var luz_apagado := 0.3        ## energía de la luz antes de activarlo (se ve de lejos)
@export var luz_encendido := 1.4      ## energía una vez activado
@export var luz_destello := 3.0       ## pico al activarse
@export var halo_apagado := 0.25      ## opacidad del halo (brillo visible en el aire) apagado
@export var halo_encendido := 0.6
@export var texto_aviso := "Punto de control"   ## aviso en el HUD al activarse (vacío = sin aviso)
@export var sonido_activar: AudioStream = preload("res://assets/audio/sfx/gen/checkpoint.wav")
@export var volumen_activar_db := -6.0

var _activado := false

@onready var visual: Polygon2D = $Visual
@onready var glow: Polygon2D = $Visual/Glow
@onready var luz: PointLight2D = get_node_or_null("Luz")
@onready var halo: Sprite2D = get_node_or_null("Halo")


func _ready() -> void:
	monitoring = true
	collision_layer = 0
	collision_mask = 4
	body_entered.connect(_on_body_entered)
	_pintar(false)


func _on_body_entered(body: Node2D) -> void:
	if not body.has_method("actualizar_checkpoint"):
		return
	# Solo guarda si el respawn queda apoyado en suelo: evita guardar un punto
	# donde reaparecerías flotando/cayendo (mala colocación en el editor). Si no
	# hay piso, el checkpoint sigue apagado y se vuelve a intentar al re-entrar.
	if not _hay_piso_bajo(global_position + offset_respawn):
		return
	# Si ya es el respawn actual no se vuelve a guardar: pasar de nuevo con poca vida
	# no debe rebajar la vida/energía con la que reaparecés.
	if _activado and body.get("_spawn_position") == global_position + offset_respawn:
		return
	body.actualizar_checkpoint(global_position + offset_respawn)
	if not _activado:
		_activado = true
		_pintar(true)
		_encender_luz()
		_feedback_activar()
		activado.emit()
		_burst()


## Raycast corto hacia abajo (capa 1 = terreno) para validar el respawn.
func _hay_piso_bajo(pos: Vector2) -> bool:
	var space := get_world_2d().direct_space_state
	var query := PhysicsRayQueryParameters2D.create(pos, pos + Vector2(0, 400.0), 1, [self])
	return not space.intersect_ray(query).is_empty()


func _pintar(encendido: bool) -> void:
	var c := color_encendido if encendido else color_apagado
	visual.color = c
	glow.color = Color(c, 0.35)
	if luz != null:
		luz.color = color_luz
		luz.energy = luz_encendido if encendido else luz_apagado
	if halo != null:
		halo.modulate = Color(color_luz, halo_encendido if encendido else halo_apagado)


func _feedback_activar() -> void:
	var audio := get_node_or_null("/root/AudioManager")
	if audio != null:
		audio.play_sfx(sonido_activar, volumen_activar_db)
	var hud := get_tree().get_first_node_in_group("hud")
	if hud != null and not texto_aviso.is_empty():
		hud.mostrar_aviso(texto_aviso)
	# Pop del cristal: crece y vuelve con rebote.
	var tw := create_tween()
	tw.tween_property(visual, "scale", Vector2.ONE * 1.45, 0.08)
	tw.tween_property(visual, "scale", Vector2.ONE, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _encender_luz() -> void:
	if luz == null:
		return
	var t := create_tween()
	t.tween_property(luz, "energy", luz_destello, 0.08)
	t.tween_property(luz, "energy", luz_encendido, 0.6).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	if halo != null:
		var th := create_tween()
		th.tween_property(halo, "scale", halo.scale * 1.6, 0.08)
		th.tween_property(halo, "scale", halo.scale, 0.6).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)


func _burst() -> void:
	if DisplayServer.get_name() == "headless":
		return
	var p: CPUParticles2D = (preload("res://scenes/burst.tscn") as PackedScene).instantiate()
	p.global_position = global_position
	p.self_modulate = color_encendido
	get_tree().root.add_child(p)
	p.restart()
	p.emitting = true