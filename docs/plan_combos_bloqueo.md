# Plan: combos de level-up, especiales y bloqueo (para ejecutar en otra sesión)

**Reglas del proyecto a respetar:** leer `MEMORY.md` (Lecciones) antes de tocar código; hablar en español; no commit sin pedirlo; todo valor que el usuario quiera mover va como `@export`/`.tres`; sin animaciones nuevas (solo efectos por código sobre los sprites existentes); verificar con `powershell -File tests/verificar.ps1 -Diag diag_formas,diag_golpe` y, tras cada tanda, la batería completa de `diag_*`. Capturas: máx. 1-2. Preguntar antes de decisiones grandes.

**Alcance:** pulir lo existente. Sin contenido nuevo grande ni rework.

**Código base:** `scripts/player.gd` (`_detectar_combo` ~1033, `_ejecutar_finisher` ~1056, ataque especial ~1001, `_physics_process` bloqueo ~510, `take_damage` ~2599, `_parry_perfecto` ~2682), `scripts/forms/{forma,humano,lobo,oso,murcielago}.gd`, `resources/formas/*.tres`, `scripts/levelup.gd` (~215-233), `scripts/progresion.gd`, `scripts/hud_dial.gd`.

## Reparto de roles (decisión tomada)
- **Combo (J→K, se elige al subir de nivel, gratis):** lleva la mecánica y el espectáculo visual. Es la recompensa.
- **Especial (L, cuesta energía):** golpe pesado de más daño, más lento, más empuje. Ya no es un golpe fuerte con otra caja.

## Combos
- **C1. Descripción en el menú** (`levelup.gd` ~232): reemplazar "Es un ataque más fuerte" por una línea por combo; agregar `descripcion` al diccionario del combo en los 4 `.tres` y en el `combos` de cada `.gd`. Hecho: el menú la muestra; autotest 0.
- **C2. Combo del Lobo: Embestida.** El Lobo sale disparado hacia delante (~400 px, ~0.28 s) atravesando enemigos; cada uno recibe el golpe una vez (sondeo `get_overlapping_bodies()` + flag, como en el resto de golpes). Reusar `_lunge_t`/`lunge_combo`. i-frames cortos (~0.15 s, `@export`). Costo: gratis (es el combo). Visual sin animaciones nuevas: sprite estirado en horizontal durante el dash (`scale.x`~1.25, `scale.y`~0.85), estela de copias semitransparentes del sprite (azul grisáceo, una cada ~0.03 s, se desvanecen en 0.2 s), rayas de velocidad y polvo (`_emitir_polvo`), `burst.tscn` + shake corto + hitstop por enemigo golpeado, destello blanco al terminar. Todo parametrizado con `@export`. Hecho: test de daño/alcance por sondeo; atraviesa y golpea una vez por enemigo.
- **C3. Combo del Humano: Tajo giratorio.** Golpea delante y detrás (basado en `onda_area` con la lógica de lado/espalda que ya usa el Oso, pero sin copiar el pisotón). Visual: arco de corte tipo media luna crema dibujado en código (`Line2D`/`Polygon2D`, estilo plano) que barre frente y espalda ~0.2 s; volteo rápido de `scale.x` (1 → -1 → 1 en ~0.15 s); destello de tinte al empezar; `burst` por enemigo y shake. Reusar `attack_full`. Hecho: test de que alcanza enemigos delante y detrás.
- **C4. Combos de Oso y Murciélago** (solo números/FX, sin mecánica nueva): Oso con más hitstop, shake y knockback; Murciélago con más rango. Parametrizar con `@export`.
- **C5. Sonido y feedback del finisher:** sonido propio (reusar un wav de `assets/audio/sfx/gen/` con otro tono). El HUD ya muestra el nombre del combo.
- **C6. Tip al elegir combo:** `_tip_una_vez("combo_<forma>", …)` "Probá J y después K en [forma]", respetando `tips_ayuda`.
- **C7. Entrada:** `COMBO_WINDOW` 1.1 s y buffer ya son generosos, no tocar. Solo confirmar que `_seq` se limpia al cambiar de forma (~1914, ~2915) y que `_detectar_combo("special")` no se rompe.
- **Nota de diseño:** el combo empieza con un ligero, así que el Lobo ya está pegado al enemigo: la Embestida es un remate que atraviesa y deja al jugador del otro lado, no un acercamiento.

## Especiales (Humano y Lobo)
- **S1. Humano:** hoy 17 de daño, caja 198×126, gratis y sin cooldown (peor que no usarlo). Darle costo de energía y/o `special_cooldown_combate` (~1.5 s), mayor daño (~24), mayor recuperación y mayor empuje. Marca visual: arco de corte más grande y shake fuerte (reusar los de C3 en versión simple).
- **S2. Lobo:** mantiene `special_cost = 4`; subir daño (~26), más empuje, recuperación algo más lenta. Marca visual: golpe pesado con shake y `burst`.
- Los números son estimaciones: validar jugando. Hecho: especial claramente mejor que el fuerte en daño, con costo, sin romper el combo.

## Bloqueo / parry
- **B1. Enseñar el bloqueo antes de que duela:** tip la primera vez que el Humano ve a un enemigo atacando (hoy el único aviso sale al recibir daño sin bloquear, `player.gd` ~2630); revisar que la tecla esté en `controls.tscn`.
- **B2. Feedback del bloqueo normal:** burst chico (`burst.tscn`) + destello de sprite en la rama `guardia` de `take_damage`; que se distinga del parry (que ya tiene su cine).
- **B3. Afinar números (uno por vez, anotar):** `parry_ventana` 0.16 s, `bloqueo_cooldown` 0.6 s, `bloqueo_toque_max` 0.25 s. No tocar costo/drenaje/energía mínima sin probar. Decisión pendiente del usuario: ¿ventana de parry 0.16 → 0.20 s?
- **B4. Aviso de guardia sin energía:** parpadeo del dial (`hud_dial.gd`) o sonido corto cuando `_bloqueo_sin_energia` rechaza el input.
- **B5. Bordes (solo confirmar):** bloquear durante un golpe, con el Oso (no puede), en el aire, de espaldas.

## Orden de ejecución
1. **C1 + C6** (texto, bajo riesgo).
2. **B1 + B2** (ayuda y feedback del bloqueo).
3. **C2** (Embestida del Lobo: es lo más grande y lo que más cambia).
4. **C3** (Tajo giratorio del Humano; reusa lo de C2 para la estela/FX).
5. **S1 + S2** (especiales) y **C4 + C5**.
6. **B3 + B4** (números y avisos, con prueba a mano).
7. **Cierre:** batería completa de `diag_*`, anotar en `MEMORY.md` y `docs/MEMORY_HISTORIAL.md`, commit solo si el usuario lo pide.

## Pendiente de decidir
1. `parry_ventana` 0.16 → 0.20 s.
2. ¿i-frames en la Embestida? (recomendado: sí, 0.15 s).
3. Segundo combo por forma: contenido nuevo, fuera de este plan.
