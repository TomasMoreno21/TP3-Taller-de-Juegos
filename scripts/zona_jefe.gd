extends StaticBody2D
## Zona golpeable del jefe (fase de "zona marcada"). Es un StaticBody2D para que
## el ataque del jugador (get_overlapping_bodies) la detecte como a un enemigo;
## reenvía el golpe al jefe (padre), que decide cuánto daño sufre realmente.
## La posición/movimiento los controla el jefe ("slots" marcados que rotan).


func take_damage(_cantidad: int, _kb: float = 0.0, _dir: int = 1, _critico: bool = false) -> void:
	var jefe: Node = get_parent()
	if jefe != null and jefe.has_method("_golpe_en_zona"):
		jefe._golpe_en_zona(_cantidad)