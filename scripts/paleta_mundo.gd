class_name PaletaMundo
extends RefCounted
## Escala de tonos del mundo, con el mismo lenguaje que el fondo del bosque
## (siluetas planas en grises). Regla: cuanto más cerca de la cámara, más oscuro.
##   fondo (parallax Boske*.png) → decoración detrás del jugador → plano de juego
##   → primer plano casi negro.
## El color queda reservado a lo jugable (jugador, enemigos, alma, checkpoint,
## peligros). La noche (CanvasModulate) tiñe todo de azul por encima.

## Decoración detrás del jugador (árboles, arbustos, pasto, piedras).
const DECO := Color(0.215, 0.22, 0.225)
## Manchas internas más claras (copas, arbustos), como las copas del fondo.
const DECO_LUZ := Color(0.25, 0.255, 0.26)  # referencia: DECO + ~0.035
## Vetas y sombras internas (troncos).
const DECO_SOMBRA := Color(0.13, 0.135, 0.14)

## Plano de juego: piso y plataformas (V2) y su borde superior iluminado.
const JUEGO := Color(0.1, 0.105, 0.11)
const JUEGO_BORDE := Color(0.24, 0.25, 0.26)

## Primer plano (entre la cámara y el jugador).
const FRENTE := Color(0.04, 0.042, 0.045)
const FRENTE_LUZ := Color(0.07, 0.072, 0.075)

## Acentos de color: solo en lo jugable.
const ACENTO_ALMA := Color(0.4, 0.68, 1.0)
const ACENTO_CHECKPOINT := Color(0.7, 1.0, 0.55)
const ACENTO_PELIGRO := Color(0.85, 0.32, 0.25)


static func aclarar(c: Color, cuanto: float) -> Color:
	return Color(minf(c.r + cuanto, 1.0), minf(c.g + cuanto, 1.0), minf(c.b + cuanto, 1.0), c.a)
