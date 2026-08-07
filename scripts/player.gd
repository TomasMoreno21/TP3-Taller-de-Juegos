extends CharacterBody2D

signal form_changed(form_name: String)

enum Form { HUMAN, OSO, LOBO, BUHO }

const GRAVITY := 980.0
const MAX_FALL_SPEED := 950.0
const GLIDE_FALL_MULTIPLIER := 0.35
const TINT_ALPHA := 0.45

var forms: Array[Forma] = []
var current_form: int = Form.HUMAN
var health: int = 100
var god_mode := false
var facing := 1

var _attacking := false
var _attack_timer := 0.0
var _gravity_override: float = -1.0

@onready var visual: Sprite2D = $Sprite2D
@onready var tint: Sprite2D = $Sprite2D/Tint
@onready var collision_shape: CollisionShape2D = $Collision
@onready var attack_area: Area2D = $AttackArea
@onready var attack_hitbox: CollisionShape2D = $AttackArea/AttackHitbox


func _ready() -> void:
	add_to_group("player")
	forms = [Humano.new(), Oso.new(), Lobo.new(), Buho.new()]
	health = forms[current_form].max_health
	attack_area.body_entered.connect(_on_attack_body_entered)
	_apply_form()


func _physics_process(delta: float) -> void:
	var data: Forma = forms[current_form]
	data.tick(self, delta)

	var dir := Input.get_axis("move_left", "move_right")
	if data.is_dashing():
		velocity.x = facing * data.dash_speed()
	else:
		velocity.x = dir * data.speed
		if dir != 0.0:
			facing = 1 if dir > 0 else -1

	if Input.is_action_just_pressed("jump"):
		data.try_jump(self)

	var g: float = GRAVITY * data.gravity_scale
	if _gravity_override >= 0.0:
		g = _gravity_override
	if data.is_gliding(self):
		g *= GLIDE_FALL_MULTIPLIER

	velocity.y = min(velocity.y + g * delta, MAX_FALL_SPEED)
	move_and_slide()

	if is_on_floor():
		data.on_floor(self)

	_handle_attack(delta)
	_handle_transform()


func _handle_attack(delta: float) -> void:
	if Input.is_action_just_pressed("attack"):
		forms[current_form].perform_attack(self)
	if _attacking and _attack_timer > 0.0:
		_attack_timer -= delta
		if _attack_timer <= 0.0:
			end_attack()


func enable_melee(size: Vector2, range: float) -> void:
	_attacking = true
	_attack_timer = 0.15
	var shape: RectangleShape2D = attack_hitbox.shape
	shape.size = size
	attack_hitbox.shape = shape
	attack_hitbox.disabled = false
	attack_area.position = Vector2(facing * range, 0.0)
	attack_area.monitoring = true


func end_attack() -> void:
	_attacking = false
	attack_area.monitoring = false
	attack_hitbox.disabled = true


func fire_projectile() -> void:
	var projectile: Area2D = preload("res://scenes/projectile.tscn").instantiate()
	projectile.position = global_position + Vector2(facing * 26.0, -4.0)
	projectile.setup(facing, forms[current_form].attack_damage)
	get_parent().add_child(projectile)


func _on_attack_body_entered(body: Node2D) -> void:
	if _attacking and body.is_in_group("enemy"):
		body.take_damage(forms[current_form].attack_damage)


func _handle_transform() -> void:
	if Input.is_action_just_pressed("transform"):
		current_form = (current_form + 1) % Form.size()
		health = forms[current_form].max_health
		_apply_form()
		form_changed.emit(forms[current_form].form_name)


func _apply_form() -> void:
	var data: Forma = forms[current_form]
	var shape: RectangleShape2D = collision_shape.shape
	shape.size = data.collider_size
	collision_shape.shape = shape
	var c: Color = data.color
	c.a = TINT_ALPHA
	tint.self_modulate = c
	data.reset_state()
	end_attack()


func get_form_name() -> String:
	return forms[current_form].form_name


func set_form(form_id: int) -> void:
	if form_id >= 0 and form_id < Form.size():
		current_form = form_id
		health = forms[current_form].max_health
		_apply_form()
		form_changed.emit(forms[current_form].form_name)


func take_damage(amount: int) -> void:
	if god_mode:
		return
	health = max(health - amount, 0)


func heal_full() -> void:
	health = forms[current_form].max_health


func set_health(value: int) -> void:
	health = max(value, 0)


func set_gravity_override(value: float) -> void:
	_gravity_override = value


func clear_gravity_override() -> void:
	_gravity_override = -1.0
