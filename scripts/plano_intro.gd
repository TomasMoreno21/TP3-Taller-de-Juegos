@tool
extends Marker2D
class_name PlanoIntro

## Un plano de la intro de nivel (hijo de IntroNivel). La posición del nodo es adonde
## llega la cámara: movelo en el editor. La cámara viaja hasta acá durante `duracion`.

@export var duracion := 4.0               ## segundos que dura el plano (la cámara tarda todo ese tiempo en llegar)
@export var zoom := 1.0:                  ## zoom al terminar el plano (<1 = más lejos)
	set(v):
		zoom = v
		queue_redraw()
@export var seguir_jugador := false       ## ignora la posición del nodo: la cámara sigue al jugador (también si camina)
@export var camina := false               ## el jugador echa a caminar solo desde el inicio de este plano
@export_group("Arranque (solo para el primer plano)")
@export var zoom_desde := 0.0             ## > 0: la cámara arranca con este zoom, cortada en `arranca_desde`
@export var arranca_desde := Vector2.ZERO ## desplazamiento respecto a este nodo donde empieza la cámara
@export_group("Texto y efectos")
@export_multiline var cartela := ""       ## narración en la franja inferior (máquina de escribir)
@export var globo: PackedStringArray = [] ## conversación en globos del juego; "[humano] ..." habla el jugador, el resto el Amuleto
@export var retraso_globo := 0.0          ## espera antes del primer globo (deja que la cámara llegue)
@export var globo_marcado := false        ## globo grande + cámara lenta breve
@export var pulso := false                ## destello + golpe de cámara (el Amuleto despierta)
@export var pulso_en := 1.0               ## segundos desde el inicio del plano
@export_group("Fin")
@export var devolver_control := false     ## entrega el control al jugador acá y termina la intro (ignora `duracion`)


func _draw() -> void:
	if Engine.is_editor_hint():
		var mitad := Vector2(960, 540) / maxf(zoom, 0.1)   # encuadre que verá la cámara al llegar
		draw_rect(Rect2(-mitad, mitad * 2.0), Color(1, 1, 1, 0.5), false, 3.0)
