# CLAUDE.md — Spirit Keeper (Godot 4.7)

Instrucciones de trabajo para el asistente en este proyecto.

## Cómo trabajar conmigo
- **Leé `MEMORY.md`** (corto: sesiones recientes, reglas, lecciones + índice). El historial completo está en `docs/MEMORY_HISTORIAL.md`: leelo SOLO por rango de líneas (índice al final de MEMORY.md).
- **Ahorro de tokens:** Grep/Glob y Read con offset/limit; no releer ni verificar con Read tras Edit; llamadas en paralelo; respuestas mínimas; sin subagentes salvo pedido; verificar solo si cambió código.
- **Comunicate SIEMPRE en español**, con respuestas concisas y directas. Sin relleno.
- **Antes de implementar algo no trivial, preguntame** y ofrecé opciones concretas (recomendando una), salvo que yo te pida el cambio explícito. No me sorprendas con cambios grandes sin consultar.
- **No hagas commits ni pushes sin que yo te lo pida.** Cuando corresponda, preguntame el mensaje.
- Si te muestro un error o algo no anda, investigá la causa real (log, `--headless`, tests) antes de proponer una solución al azar. Explicame en 1 o 2 líneas qué pasaba y qué cambiaste.

## Reglas del asistente (unificadas del AGENTS.md de escritorio)
- **Lecciones obligatorias:** toda corrección/crítica/error del usuario (código, diseño, comunicación) es una lección permanente → interpretar la causa raíz, **registrarla en `MEMORY.md` > "Lecciones Aprendidas"** y no repetirla (revisar esa sección antes de escribir código similar).
- **Diseño:** buscar referencias de videojuegos reales para mecánicas y aplicarlas bien; proponer ideas que no requieran código (game feel, sonido, ritmo, narrativa, feedback visual); mantener sistemas simples, evitar sobrediseño.
- **Investigación previa:** revisar archivos/estructura del proyecto antes de escribir código nuevo.
- **Adaptarse** al código existente: sin convenciones fijas impuestas (salvo las de este archivo).

## Reglas de diseño (prioritarias)
1. **Referencia mecánica: Ben 10: Alien Force** (PS2/Wii, 2008). Al decidir algo, primero preguntate "¿cómo lo resolvía el original?" y partí de ahí, adaptando solo lo que la ambientación/scope obligue a cambiar.
2. **Regla de edición (usuario, 13/08):** todo elemento del juego (interfaz, personaje, objeto, nivel) debe poder moverse y modificarse desde el editor de Godot. Antes de hardcodear un valor, preguntate "¿lo querrá mover el usuario desde el editor?" → si sí, usar `@export`/recurso/escena. Los `.tres` que son meras envolturas de un script se evitan; los datos ya viven en los `.tscn` y los scripts.
3. **No copiar** personajes, historia ni estética de Ben 10: solo mecánicas.
4. **Arte:** vectorial minimalista, colores planos, siluetas claras, interfaz limpia.
5. **Idioma del juego:** todo el texto visible del juego en español.

## Estado clave del proyecto
- **Perspectiva:** side-scroller 2D, cámara zoom 1, resolución 1920×1080 (1 px del mundo = 1 px en pantalla). El nodo raíz del player NO tiene `scale`; la escala visual va en el `AnimatedSprite2D`.
- **Formas:** `Form` enum en `player.gd` — Humano(0), Lobo(1), Oso(2), Murciélago(3). Se cargan desde `resources/formas/*.tres` (Resource con script de `scripts/forms/*.gd`) vía `const FORMAS`; los `.tres` aportan datos editables en el Inspector: geometría de golpe (`attack/heavy/special` + knockbacks) y los `combos`. El resto de stats (velocidad, saltos, física, collider) vive en el `_init()` de cada `.gd`. Vida compartida (`VIDA_MAX=100`); energía de transformación drena 4/s (×0.45 fuera de arena, × `drenaje_mult` de la forma) y a 0 vuelve a Humano; transformarse pide ≥25 de energía.
- **Progresión:** autoload `Progresion`; el nivel sube con fragmentos acumulados `FRAGMENTOS_NIVEL = [8, 25, 50, 74]` (4 subidas en los 3 niveles de juego ≈ 1⅓ por nivel; 11/29/42 pickups); cada subida abre el LevelUp para elegir el combo de una forma (1 combo por forma; las completas ya no aparecen; sin formas elegibles la mejora queda en `mejoras_diferidas` hasta desbloquear otra). `SetupProgresion.nivel_minimo` ya no sube el nivel: solo fija `pasos_luz_base`.
- **Enemigos:** cultista/arquero/chamán, stats en `enemy.gd::config_por_tipo(tipo)` (NO hay `.tres`). Sprites en `resources/enemigo{1,2}_frames.tres`.
- **UIX ya implementada (15/08):** menú principal (`main_menu.tscn`, main scene), pausa (`pause.tscn`), controles (`controls.tscn`), HUD (`hud.tscn`).
- **Consola dev:** `` ` `` abre consola; comandos `help`, `form <humano|lobo|oso|murcielago>`, `god`, `mv`, `frags <n>`, `nivel <n>`, `kill`.

## Verificación (solo si cambió código/escenas)
```
powershell -File tests/verificar.ps1 [-Diag diag_hud,diag_golpe]
```
Muestra solo errores y `FALLOS`. Import limpio → smoke limpio → autotest **FALLOS = 0** (+ `diag_*` que apliquen). Reportar el resultado.

## Alcance
Prototipo jugable en ~2 meses (equipo de 3). Pulido por encima de cantidad: pocas formas y enemigos, bien diferenciados, 4-5 niveles lineales, 1-2 jefes.
