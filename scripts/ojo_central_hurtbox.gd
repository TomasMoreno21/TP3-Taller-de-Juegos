extends StaticBody2D
## Parte golpeable del ojo central (body para que el melee y el sónico la detecten).
## Reenvía el golpe al jefe, que decide si cuenta (solo durante la ventana de castigo).

var jefe: Node


func take_damage(cantidad: int, _kb: float = 0.0, dir: int = 1, critico: bool = false) -> void:
	if jefe != null and jefe.has_method("golpe_ojo"):
		jefe.golpe_ojo(cantidad, dir, critico)
