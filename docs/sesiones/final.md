# Cierre del juego — guion A "Lo contuve" (elegido 10/10)

Pantalla: `scenes/victoria_jefe.tscn` + `scripts/victoria_jefe.gd`. La agrega `nivel_jefe.gd` 1,2 s después de morir el Arzobispo y pausa el árbol (la escena corre en ALWAYS).

## Secuencia
1. Destello del estallido; la arena se apaga (`oscurecer_mundo`).
2. El hijo emerge desde la luz, donde murió el jefe (`seguir_al_jefe`) — **placeholder**: silueta a contraluz. Con arte: asignar `textura_hijo`.
3. Globos (Humano sale de la cabeza del jugador, Amuleto de la gema):
   - **Humano:** [susurro] Hijo…
   - **Amuleto:** El sello cede. Él está dentro, a salvo.
   - **Humano:** Estoy aquí. Ya pasó.
   - **Amuleto:** Sostenelo. Yo contengo lo que queda.
4. Corte a negro → frase final: *"Lo que el bosque se llevó, el bosque lo devuelve."* (Confirmar la adelanta).
5. Vuelve al menú (`escena_siguiente`). **Créditos:** cuando existan, apuntar `escena_siguiente` a la escena de créditos (y que ella vuelva al menú).

## Editable desde el Inspector
Guion (`lineas`, `hablante`), hijo (`textura_hijo`, `escala_hijo`, `pos_hijo`, `color_luz`, `color_silueta`), tiempos (destello, aparición, pausas, fundidos), frase (`frase`, tamaño, colores, filetes) y `escena_siguiente`.

## Pendiente
- Arte del hijo.
- Escena de créditos.
- Probar a mano el ritmo y la posición del hijo respecto del jugador (el estallido del jefe vive en `boss.gd`, no tocado).
- Test: `tests/diag_final.gd`.
