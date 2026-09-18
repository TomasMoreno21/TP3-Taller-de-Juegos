extends StaticBody2D
## Torso del Arzobispo — el ATAJO con riesgo.
## Es el MISMO patrón que la zona marcada (["ZonaGolpe" = StaticBody2D capa 2] →
## el melee `get_overlapping_bodies` lo detecta como enemigo y llama take_damage),
## PERO a diferencia de la zona (SÓLO golpeable en la barrera ZONA cuando baja),
## este torso es golpeable SIEMPRE mientras el jefe esté activo.
## El jefe (padre) decide cuánto daño entra: la Legión viva absorbe el golpe
## (""_shield_active → _mostrar_absorbido""), igual que con la zona; caída la
## Legión, el daño normal del melee SÍ fluye (sin la puerta de la ZONA).
## Así el atajo es real (no hace falta esperar a que marque zona) PERO el
## ritual de la Legión sigue siendo obligatorio: no se le pega al cuerpo con
## la guardia de fieles viva. Riesgo: para golpear el torso hay que saltar
## (pelea aérea bajo el presidencial — el odio del aire).
## La cabeza redonda grande es SOLO visual (no golpeable con más daño).


func take_damage(_cantidad: int, _kb: float = 0.0, _dir: int = 1, _critico: bool = false) -> void:
	var jefe: Node = get_parent()
	if jefe != null and jefe.has_method("_golpe_en_torso"):
		jefe._golpe_en_torso(_cantidad, _kb, _dir, _critico)
