extends StaticBody2D

var health := 100
var hits := 0


func _ready() -> void:
	collision_layer = 1
	collision_mask = 0


func registrar_golpe(dano: int) -> void:
	hits += 1
	health -= dano


func take_damage(cantidad: int, _knockback: float = 0.0, _dir: int = 1) -> void:
	health -= cantidad