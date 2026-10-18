extends StaticBody2D
## Blanco del sónico del Murciélago sobre la Estrella: siempre activo (le pega en cualquier momento).
## El cuerpo a cuerpo lo ignora (`ignora_melee`); solo cuentan los proyectiles (`golpe_proyectil`).

var jefe: Node
var golpe_proyectil := false   # lo marca el proyectil del jugador antes de take_damage
var ignora_melee := true


func _ready() -> void:
	add_to_group("blanco_sonico")
	collision_layer = 2
	collision_mask = 0


## Si el teledirigido del Murciélago puede apuntarle ahora.
func apuntable() -> bool:
	return jefe != null and jefe.has_method("sonico_vale") and jefe.sonico_vale()


func take_damage(cantidad: int, _kb: float = 0.0, dir: int = 1, critico: bool = false) -> void:
	var es_proyectil := golpe_proyectil
	golpe_proyectil = false
	if not es_proyectil or jefe == null:
		return
	jefe.golpe_sonico(cantidad, dir, critico)
