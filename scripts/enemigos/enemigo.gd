class_name Enemigo
extends Resource

@export var tipo_nombre: String = "Sectario"
@export var max_health: int = 40
@export var speed: float = 70.0
@export var stop_distance: float = 55.0
@export var attack_damage: int = 8
@export var attack_range: float = 40.0
@export var attack_cooldown: float = 1.6
@export var projectile: bool = false
@export var shoot_range: float = 420.0
@export var color: Color = Color(0.55, 0.38, 0.3)
@export var collider_size: Vector2 = Vector2(30, 60)
@export var knockback_resist: float = 0.3
@export var stun_duracion: float = 0.15
