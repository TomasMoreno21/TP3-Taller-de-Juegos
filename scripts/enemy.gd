extends CharacterBody2D

signal died

const GRAVITY := 980.0
const MAX_FALL_SPEED := 950.0

@export var tipo: String = "cultista"
@export var enemy_data: Enemigo

const FRAMES_POR_TIPO := {
	"cultista": preload("res://resources/enemigo1_frames.tres"),
	"arquero": preload("res://resources/enemigo2_frames.tres"),
	"chaman": null,
}

var health: int = 40
var _attack_timer := 0.0
var _dir := -1
var _attack_anim := ""
var _attack_anim_timer := 0.0

@onready var visual: Node2D = $Visual
@onready var poly: Polygon2D = $Visual/Poly
@onready var animated: AnimatedSprite2D = $Visual/Animated
@onready var collide_shape: CollisionShape2D = $Collision


static func config_por_tipo(enemy_tipo: String) -> Enemigo:
	var d := Enemigo.new()
	match enemy_tipo:
		"cultista":
			d.tipo_nombre = "Cultista"
			d.max_health = 40
			d.speed = 75.0
			d.stop_distance = 50.0
			d.attack_damage = 8
			d.attack_range = 42.0
			d.attack_cooldown = 1.6
			d.color = Color(0.55, 0.38, 0.3)
		"arquero":
			d.tipo_nombre = "Arquero"
			d.max_health = 35
			d.speed = 55.0
			d.attack_damage = 10
			d.attack_cooldown = 2.2
			d.projectile = true
			d.shoot_range = 420.0
			d.color = Color(0.42, 0.3, 0.5)
			d.collider_size = Vector2(28, 56)
		"chaman":
			d.tipo_nombre = "Chamán"
			d.max_health = 90
			d.speed = 40.0
			d.stop_distance = 40.0
			d.attack_damage = 12
			d.attack_cooldown = 2.6
			d.projectile = true
			d.shoot_range = 480.0
			d.color = Color(0.4, 0.34, 0.24)
			d.collider_size = Vector2(34, 66)
			d.knockback_resist = 0.3
	return d


func _ready() -> void:
	add_to_group("enemy")
	if enemy_data == null:
		enemy_data = config_por_tipo(tipo)
	if enemy_data != null:
		health = enemy_data.max_health
		var frames: SpriteFrames = FRAMES_POR_TIPO.get(tipo)
		if frames != null:
			poly.visible = false
			animated.visible = true
			animated.sprite_frames = frames
			animated.play("idle")
		else:
			animated.visible = false
			poly.visible = true
			poly.color = enemy_data.color
		if collide_shape != null and enemy_data.collider_size != Vector2.ZERO:
			collide_shape.shape.size = enemy_data.collider_size
	else:
		health = 40


func _physics_process(delta: float) -> void:
	var player := get_tree().get_first_node_in_group("player")
	if _attack_timer > 0.0:
		_attack_timer -= delta
	if _attack_anim_timer > 0.0:
		_attack_anim_timer -= delta

	# gravedad
	velocity.y = minf(velocity.y + GRAVITY * delta, MAX_FALL_SPEED)

	if player == null:
		velocity.x = 0.0
		_update_animacion()
		return

	var dist := global_position.distance_to(player.global_position)
	_dir = 1 if player.global_position.x > global_position.x else -1
	visual.scale.x = absf(visual.scale.x) * _dir

	if _usar_proyectil():
		if dist <= enemy_data.shoot_range and _attack_timer <= 0.0:
			_disparar(player)
			_attack_timer = enemy_data.attack_cooldown
		velocity.x = 0.0 if dist <= enemy_data.shoot_range else _dir * enemy_data.speed
	elif dist > enemy_data.stop_distance:
		velocity.x = _dir * enemy_data.speed
	else:
		velocity.x = 0.0
		if dist <= enemy_data.attack_range and _attack_timer <= 0.0:
			_ataque_melee(player)
			_attack_timer = enemy_data.attack_cooldown

	_update_animacion()
	move_and_slide()


func _update_animacion() -> void:
	if animated == null or not animated.visible:
		return
	var nombre := "idle"
	if _attack_anim_timer > 0.0:
		nombre = _attack_anim
	elif not is_on_floor():
		nombre = "jump"
	elif absf(velocity.x) > 10.0:
		nombre = "run"
	if animated.animation != nombre:
		animated.play(nombre)


func _reproducir_animacion_ataque(nombre: String) -> void:
	_attack_anim = nombre
	_attack_anim_timer = 0.35


func _usar_proyectil() -> bool:
	return enemy_data != null and enemy_data.projectile


func _ataque_melee(player: Node2D) -> void:
	_reproducir_animacion_ataque("attack1")
	player.take_damage(enemy_data.attack_damage, 0.0, _dir)


func _disparar(player: Node2D) -> void:
	_reproducir_animacion_ataque("attack2")
	var dir := (player.global_position - global_position).normalized()
	var proj: Area2D = preload("res://scenes/projectile.tscn").instantiate()
	proj.global_position = global_position + Vector2(_dir * 25.0, -10.0)
	proj.set("direction", dir)
	proj.set("speed", 340.0)
	proj.set("damage", enemy_data.attack_damage)
	proj.set("enemy_shot", true)
	var destino: Node = get_tree().current_scene if get_tree().current_scene != null else get_parent()
	destino.add_child(proj)


func take_damage(cantidad: int, _knockback: float = 0.0, _dir: int = 1) -> void:
	if health <= 0:
		return
	health -= cantidad
	if visual != null:
		visual.modulate = Color(1, 0.6, 0.6)
		await get_tree().create_timer(0.08).timeout
		if is_instance_valid(visual):
			visual.modulate = Color(1, 1, 1)
	if health <= 0:
		_morir()


func _morir() -> void:
	var player := get_tree().get_first_node_in_group("player")
	if player != null and player.has_method("on_enemy_killed"):
		(player as Node2D).on_enemy_killed()
	died.emit()
	queue_free()
