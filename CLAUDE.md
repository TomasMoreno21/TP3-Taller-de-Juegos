# CLAUDE.md — Spirit Keeper (Godot 4.7)

Instrucciones de trabajo para el asistente en este proyecto.

## Cómo trabajar conmigo
- **Leé `MEMORY.md` completo antes de tocar cualquier cosa.** Es la fuente de verdad del estado del proyecto (qué está implementado, qué no, decisiones tomadas y lecciones). Empezá por la sección "REALINEAMIENTO SPIRIT KEEPER" y la "Sesión 15/08" más reciente.
- **Comunicate SIEMPRE en español**, con respuestas concisas y directas. Sin relleno.
- **Antes de implementar algo no trivial, preguntame** y ofrecé opciones concretas (recomendando una), salvo que yo te pida el cambio explícito. No me sorprendas con cambios grandes sin consultar.
- **No hagas commits ni pushes sin que yo te lo pida.** Cuando corresponda, preguntame el mensaje.
- Si te muestro un error o algo no anda, investigá la causa real (log, `--headless`, tests) antes de proponer una solución al azar. Explicame en 1 o 2 líneas qué pasaba y qué cambiaste.

## Reglas de diseño (prioritarias)
1. **Referencia mecánica: Ben 10: Alien Force** (PS2/Wii, 2008). Al decidir algo, primero preguntate "¿cómo lo resolvía el original?" y partí de ahí, adaptando solo lo que la ambientación/scope obligue a cambiar.
2. **Regla de edición (usuario, 13/08):** todo elemento del juego (interfaz, personaje, objeto, nivel) debe poder moverse y modificarse desde el editor de Godot. Antes de hardcodear un valor, preguntate "¿lo querrá mover el usuario desde el editor?" → si sí, usar `@export`/recurso/escena. Los `.tres` que son meras envolturas de un script se evitan; los datos ya viven en los `.tscn` y los scripts.
3. **No copiar** personajes, historia ni estética de Ben 10: solo mecánicas.
4. **Arte:** vectorial minimalista, colores planos, siluetas claras, interfaz limpia.
5. **Idioma del juego:** todo el texto visible del juego en español.

## Estado clave del proyecto
- **Perspectiva:** side-scroller 2D, cámara zoom 1, resolución 1920×1080 (1 px del mundo = 1 px en pantalla). El nodo raíz del player NO tiene `scale`; la escala visual va en el `AnimatedSprite2D`.
- **Formas:** `Form` enum en `player.gd` — Humano(0), Lobo(1), Oso(2), Murciélago(3). Se cargan desde `scripts/forms/*.gd` vía `FORM_SCRIPTS` (NO hay `.tres` de formas). Vida compartida (`VIDA_MAX=100`); energía de transformación drena 8/s y a 0 vuelve a Humano.
- **Progresión:** autoload `Progresion`, 3 fragmentos por nivel; `forma_desbloqueada = form_index < nivel` (2→Lobo, 3→Oso, 4→Murciélago); 1 combo por forma desbloqueable al subir de nivel.
- **Enemigos:** cultista/arquero/chamán, stats en `enemy.gd::config_por_tipo(tipo)` (NO hay `.tres`). Sprites en `resources/enemigo{1,2}_frames.tres`.
- **UIX ya implementada (15/08):** menú principal (`main_menu.tscn`, main scene), pausa (`pause.tscn`), controles (`controls.tscn`), HUD (`hud.tscn`).
- **Consola dev:** `` ` `` abre consola; comandos `help`, `form <humano|lobo|oso|murcielago>`, `god`, `mv`, `frags <n>`, `nivel <n>`, `kill`.

## Verificación (siempre al terminar un cambio)
Usar el ejecutable de Godot (ajustá la ruta si cambió):
```
& "C:\Users\UNRaf_Libre\Downloads\Godot_v4.7.1-stable_win64.exe" --headless --import
& "C:\Users\UNRaf_Libre\Downloads\Godot_v4.7.1-stable_win64.exe" --headless --path . --quit-after 5
& "C:\Users\UNRaf_Libre\Downloads\Godot_v4.7.1-stable_win64.exe" --headless --path . --script res://tests/autotest.gd
```
- Import limpio → smoke limpio → autotest **FALLOS = 0** (y `diag_formas` / `diag_hud` / `diag_feedback` / `diag_golpe` cuando el cambio aplique).
- Reportame el resultado de la verificación al terminar.

## Alcance
Prototipo jugable en ~2 meses (equipo de 3). Pulido por encima de cantidad: pocas formas y enemigos, bien diferenciados, 4-5 niveles lineales, 1-2 jefes.
