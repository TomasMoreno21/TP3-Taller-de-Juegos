# MEMORY.md — Spirit Keeper (ex proyecto Guardabosques / Espíritus del Bosque)

---

## 🔴 REALINEAMIENTO SPIRIT KEEPER (13/08 — ESTADO ACTUAL, LEER ANTES QUE EL HISTORIAL)

> Todo el código de juego fue **reconstruido desde cero** y alineado al **Documento de Concepto** (`Documento_de_Concepto_TP3_GRUPO9.pdf`, extraído con PyMuPDF a `temp/concepto.txt`). Las secciones de abajo con mecánicas viejas (enemigos/Encounter/Ben 10) son **historial**, no el estado actual.

- **Título:** `config/name = "Spirit Keeper"` en `project.godot`.
- **Formas (enum `Form` en player.gd):** `HUMAN(0)`, `LOBO(1)`, `OSO(2)`, `MURCIELAGO(3)`. Se cargan desde `scripts/forms/*.gd` vía `FORM_SCRIPTS` (preload + `.new()`) en `player.gd` — **NO hay `.tres` de formas** (se borraron el 13/08: eran envolturas vacías que solo apuntaban al script, los valores viven en el `_init()` de cada `.gd`).
  - **Humano:** 200 px/s · melee balanceado · combo único "Remate" (J→K, 42).
  - **Lobo:** 340 px/s · salto alto (-500) · **doble salto (2 saltos)** · melee veloz · combo "Mordida".
  - **Oso:** 140 px/s (lento) · daño alto (30) · salto bajo (-360) · **rompe el Tronco** · combo "Garra".
  - **Murciélago:** 215 px/s · **disparo sónico** (`scenes/projectile.tscn` + `fire_projectile()`) · **planeo** (J sostenido en el aire) · combo "Ala Cortante".
- **Vida compartida (`VIDA_MAX=100`):** `health` NO se resetea al transformar (NO es por forma). `max_health` de cada forma existe pero es informativo.
- **Energía de transformación:** drena 8/s transformado, a 0 → vuelve a Humano; Humano regenera 5/s; romper rompibles/pickups recargan.
- **Progresión:** `Progresion` autoload. 3 fragmentos/nivel. `forma_desbloqueada = form_index < nivel` (nivel 2→Lobo, 3→Oso, 4→Murciélago). 1 combo por forma, desbloqueable al subir de nivel.
- **Comandos consola (`console.gd`):** `help`, `form <humano|lobo|oso|murcielago>`, `god`, `mv`, `frags <n>`, `nivel <n>`, `kill`. (El método de ejecutar es `_ejecutar(PackedStringArray([...]))`; abrir/cerrar es `toggle()`.)
- **Escenas core:** `scenes/player.tscn`, `scenes/main.tscn`, `scenes/rompible.tscn`, `scenes/tronco.tscn` (+`interactable.gd`), `scenes/pickup.tscn`, `scenes/hud.tscn`, `scenes/console.tscn`, `scenes/levelup.tscn`, `scenes/projectile.tscn`.
- **Scripts:** `scripts/player.gd`, `progresion.gd`, `rompible.gd`, `interactable.gd`, `pickup.gd`, `camera.gd`, `hud.gd`, `console.gd`, `levelup.gd`, `projectile.gd`, `forms/{forma,humano,lobo,oso,murcielago}.gd`.
- **Tests (todos verdes, FALLOS = 0):** `tests/autotest.gd`, `tests/diag_formas.gd`, `tests/diag_hud.gd`, `tests/diag_feedback.gd` + helper `tests/dummy.gd` (StaticBody2D para medir daño melee).
  - Correr: `godot --headless --path . --script res://tests/autotest.gd` etc.
- **Enemigos sectarios (Documento §05/§06, IMPLEMENTADO):** `scripts/enemigos/enemigo.gd` (`class_name Enemigo extends Resource`, usado como contenedor de stats) + `scripts/enemy.gd` (nodo `CharacterBody2D`, IA: acercarse / parar en `stop_distance` / telegrafiar–atacar melee o disparar proyectil). **NO hay `resources/enemigos/*.tres`** (se borraron el 13/08): los stats de cada tipo están **hardcodeados** en `enemy.gd::config_por_tipo(tipo)` con `@export var tipo: String` ("cultista" 40hp melee, "arquero" 35hp proyectil 420, "chaman" 90hp proyectil 480 con `knockback_resist 0.3`); en `_ready()`, si `enemy_data == null` se arma desde `config_por_tipo(tipo)`. Escena `scenes/enemy.tscn` (layer 2, para que el `AttackArea` del player con mask 3 lo detecte). Instanciados 3 en `main.tscn` (2 cultistas + 1 arquero, cada uno con `tipo = ...`). Al morir → `player.on_enemy_killed()` recarga energía (Documento: "la energía se recarga conectando golpes en combate"). Para tests: `_limpiar_enemigos()` libera al grupo `enemy`, y los stats se leen con `preload("res://scripts/enemy.gd").config_por_tipo("tipo")`. **Con sprites desde 15/08:** cultista → GraveRobber, arquero → SteamMan, chamán → polígono (ver sección "Sesión 15/08").
- **Tronco (`interactable.gd`):** `required_form=2` (Oso), `interact_range=220.0` (el coloso de 200×300 exige rango mayor; con 90 el player no llegaba a 90 del centro sin pisar el cuerpo). Solo el **Oso** lo rompe con `L`.
- **Animación del personaje (`resources/jugador_frames.tres` + `AnimatedSprite2D`):** el `Sprite2D` de `player.tscn` pasó a `AnimatedSprite2D` (mismo nodo `Sprite2D` para no romper `$Sprite2D`). El `SpriteFrames` es un `.tres` EDITABLE con las hojas del leñador (frames 48×48): `idle`(4f/6fps), `run`(6/12), `walk`(6/8), `jump`(6/12), `attack1/2/3`(6/14, loop off), `fly`(reusa jump), `hurt`, `death`, `climb`, `push`, `craft`. El **flip horizontal** es `visual.flip_h = facing < 0`. El tinte por forma (ahora sin nodo `Tint` en la escena) se aplica vía `visual.self_modulate` con el color de la forma. `_update_animacion()` elige: ataque (`attack1/2/3` según tipo/step), en el aire `fly`, moviéndose `run`/`walk` según velocidad, si no `idle`.
- **Escala REAL en px del mundo (13/08):** el nodo raíz `Player` ya NO tiene `scale=(3,3)` (eso agrandaba la hitbox a ~74×89 reales; la colisión no coincidía con el editor). Ahora `scale=(1,1)` y la escala visual (`2.98,3`) está en el `AnimatedSprite2D` (pos `21,-20`). Los valores de las formas (`collider_size`, `attack_range`, `attack/heavy_size`, `combos.tamano/rango`, `special`) están **multiplicados ×3 = px reales del mundo** (humano: collider 48×120, rango ligero 78, special 198×126/156). Velocidades, knockbacks y físicas NO cambian. `_slash_poligono` y el offset de `fire_projectile` (90,-60) también en px reales. Regla: **el nodo raíz del player NO debe tener scale; el scale visual va en el sprite**.

### Sesión 15/08 — Sprites de enemigos, doble salto del Lobo y carteles de progresión
- **Sprites de enemigos:** cultista → GraveRobber, arquero → SteamMan, chamán → polígono (decisión del usuario, sin sprite). SpriteFrames embebidos en `resources/enemigo1_frames.tres` y `resources/enemigo2_frames.tres` (patrón de `jugador_frames.tres`, no AtlasTexture). Animaciones: idle/run/walk/jump/fly(→jump)/attack1/attack2/attack3/hurt/death/climb/push/craft (hojas 48 px/frame: idle 4f, hurt 3f, resto 6f).
- **`enemy.tscn` reescrito:** estructura `Visual` (Node2D) > `Poly` (Polygon2D, chamán) + `Animated` (AnimatedSprite2D, scale 3, pos (0,-42)). `enemy.gd`: `FRAMES_POR_TIPO` (preloads), elige poly o animated según tipo, `_update_animacion()`, `_reproducir_animacion_ataque()` (attack1 melee / attack2 disparo), flip en `visual.scale.x`. Generador: `scripts/generar_frames_enemigos.gd`.
- **Doble salto:** `forma.gd` tiene `jumps` (Humano 1, Lobo 2), `try_jump()` limita por `_jumps_usados`, `on_floor()` y `reset_form_state()` resetean el contador.
- **Carteles de progresión:** `hud.gd` conecta `nivel_subio` y muestra "¡NIVEL X ALCANZADO!" + "¡FORMA DESBLOQUEADO!" con una cola `_cola_avisos` (fade 0.6 s + timer 2.2 s) para que no se pisen.
- **Corrección de estado roto preexistente:** `enemy.tscn` tenía un `Sprite2D` estático (de una sesión previa) pero `enemy.gd` referenciaba `$Visual` → error "Node not found: Visual" en smoke. Se resolvió con la estructura Visual/Poly/Animated.
- **`tests/diag_golpe.gd` actualizado:** ya no busca `Camera2D` (la cámara ya no es hija del player) ni rotación; chequea daño (30 tras golpe ligero al Cultista1, 40−10) y tinte rojo. Ojo: el daño conecta ~2 frames después del `attack` (el overlap tarda en actualizarse tras `monitoring = true`).
- **Pendiente de verificar visualmente:** alineación de sprites enemigos en el editor (144 px de alto ×3 vs collider 27×60).

### Sesión 16/08 — Selección de transformación con flechas (↑/↓ preseleccionan, T confirma)
- **`progresion.gd`:** `forma_desbloqueada()` ahora **siempre devuelve `true`** → todas las formas desbloqueadas desde el inicio (decisión del usuario en la rama prototipo). Nota: esto deja sin efecto los carteles de desbloqueo de forma al subir de nivel (ya no hay forma por desbloquear).
- **`player.gd`:** `T` ya NO cicla (`current_form+1` salvando bloqueadas). Ahora `var forma_seleccionada` marca la forma preseleccionada; **↑/↓** (`move_up`/`move_down`, ya existían con flechas/W/S/D-pad) la mueven solo entre formas **desbloqueadas** (`_progresion().forma_desbloqueada`, wrapping con `posmod`), y **`T` transforma** a `forma_seleccionada`. `_transformar()` sincroniza `forma_seleccionada = nueva` (consola/formas por energía también la actualizan). Nueva señal `forma_selectada_cambiada(forma_index)`.
- **`hud.gd` + `hud.tscn`:** nuevo `SelLabel` (abajo-izq, verde) que lista las formas desbloqueadas: la **actual** con `◈`, la **preseleccionada** con `[ ]`. Se actualiza por señales (`_on_forma_selectada`) y al cambiar nivel (`_on_nivel`).
- **Verificación:** autotest FALLOS = 0 (ajustado el check "Lobo bloqueado en nivel 1" → ahora verifica desbloqueado), smoke limpio, `tests/diag_select.gd` OK **desde nivel 1 sin set_nivel**. Ojo en diag `extends SceneTree`: usar `root.get_node_or_null("Progresion")`, no `get_node`.
- **RESUELTO (anim "fly"):** `fallaba` "there is no animation with name fly" cuando el Lobo/Murciélago cae en el aire (`player.gd` pedía `nombre = "fly"` pero `jugador_frames.tres` no tiene esa anim). Fix: `player.gd::_update_animacion` reutiliza `"jump"` (que sí existe en el SpriteFrames) para el estado aéreo.

### Sesión 16/08 (b) — Sistema de oleadas de enemigos (Encounter)
- **Reconstruido desde cero** (el viejo `encounter.gd`/`gate`/`spawn_point` se habían eliminado en el rewrite). Ahora respeta la REGLA DE EDICIÓN: las olas se editan en el inspector y los enemigos se colocan a mano.
- **`scripts/encounters/wave_ola.gd` → `class_name WaveOla extends Resource`:** `@export tipo`(cultista/arquero/chaman), `cantidad` (0 = solo manuales), `delay`, `offset`, `edge` (entran caminando desde fuera de pantalla).
- **`scenes/encounter.tscn` + `scripts/encounters/encounter.gd` (Area2D):** `@export olas: Array[WaveOla]`, `camara: Camera2D`, `arena_center`, `arena_medio_ancho`. Estados `INACTIVE→RUNNING→COMPLETED`. Al cruzar (`body_entered` del grupo "player") arranca: activa el cerco + cámara a `modo_arena`, y resuelve olas con contador `_vivos_ola` vía señal `died`; al terminar → `completado`, `modo_normal`, suelta la arena. API: `empezar()`, `_liberar_enemigos()` (tests).
  - **Cerco de arena (Plan B) — separar TRIGGER de ZONA:** el `Area2D` del Encounter es SOLO el trigger de **inicio** (CollisionShape chico central). La **zona de pelea** se define aparte con el nodo visual **`Arena`** (Node2D → `ArenaShape` rectángulo editable + `ArenaVisual` Polygon2D translúcido). `_derivar_arena_desde_nodo()` deduce `arena_center = ArenaShape.global_position` y `arena_medio_ancho = rect.size.x*0.5`. `_generar_paredes()` crea 2 `StaticBody2D` altos a `center.x ± (medio+separacion)`; `_mostrar_bounds`/`_ocultar_bounds` los encienden al empezar y apagan al completar. **Qué se edita:** el trigger con el área pequeña del Encounter; la zona/cámara/paredes estirándo el rectángulo `Arena`. No mezclar (estirar el Area2D ANTAdelanta el inicio).
  - **Lección (bug de coordenadas del cerco):** las 2 paredes se crean como hijos del `Encounter` (que está desplazado, p. ej. en `(803,751)`), pero `arena_center` es GLOBAL. Al asignar `pared.position` (relativo) con `arena_center` global se **duplica el offset** y ambas paredes quedaban desplazadas a la derecha (la izquierda terminaba sobre el borde derecho de la arena). Fix: usar `pared.global_position = ...` (centro ± medio+separación), no `position`.
  - **Lección (paredes flotando):** centrar la pared en `arena_center.y` dejaba su **base en el centro del rect `Arena`** (arriba del piso → hueco por donde se escapaba). Fix: `_arena_base_y = arena_center.y + rect.size.y*0.5` (borde inferior del `ArenaShape`) y la pared se posiciona con `_arena_base_y - altura_pared*0.5`, quedando anclada/enterrada al piso.
  - **Agrandar la arena desde otra escena:** el `Encounter` es una instancia; para editar sus hijos desde `main` usar `editable_children` (Godot lo guarda como `[editable path="Encounter"]` al final del `.tscn`). Además, `_derivar_arena_desde_nodo()` DEBE incluir `global_scale` del `ArenaShape` (`arena_medio_ancho = rect.size.x*0.5*absf(esc.x)`, `_arena_base_y = ... + rect.size.y*0.5*absf(esc.y)`): si no, estirar/escalar la hitbox (scale del nodo) NO cambiaba la zona (solo el `rect.size` cuenta), y las paredes no seguían al tamaño visual. Verifar con scale 2x → medio 360→720.
  - **Lección (cámara no se fijaba):** un `@export camara: Camera2D` seteado con `camara = NodePath("../Camara")` en un `.tscn` NO se resuelve cuando el `Encounter` es una instancia de otra escena (`enemy` <-> `Camara` están en escenas distintas bajo `main`). El export quedaba en `<null>` y `_empezar` nunca llamaba `modo_arena` → la cámara seguía siguiendo al player. **Fix:** en `encounter.gd::_ready`, `if camara == null: camara = get_viewport().get_camera_2d()` (autodetección de la cámara activa del viewport). Es más robusto que conectar NodePath manualmente.
- **Enemigos a mano:** se agrupan por `@export ola_asignada` y `preparar_ola()` los desactiva en `_ready`. `_agrupar_manuales()` los busca **como hijos directos del Encounter O dentro del nodo `Enemies`** (cualquiera con método `activar`) — así el usuario puede arrastrar `enemy.tscn` bajo el Encounter directo y no sólo en `Enemies`. **Ojo:** un enemigo manual colocado como hijo directo del Encounter (fuera de `Enemies`) antes no se agrupaba y quedaba **activo desde el inicio** — por eso se amplió `_agrupar_manuales()`.
  - **Enemigos ocultos hasta su ola:** `preparar_ola()` (cuando se agrupa) hace `visual.visible = false` + desactiva la colisión (`_colision(false)`); `activar()` los muestra (`visual.visible = true`) y reactiva colisión al terminar el círculo ritual si `spawn_telegrafiado`. Así los enemigos **no se ven ni chocan** hasta que el jugador cruza la zona del Encounter y se dispara su ola. Los enemigos *sueltos* de `main.tscn` no pasan por `preparar_ola()` (siguen visibles desde el inicio).
  - **Lección (bug de telegrafiado):** en `enemy.gd::_physics_process` hay que chequear/avanzar `_telegraph_timer` **ANTES** de `if not _activo: return`; si el `if not _activo` va primero, el timer nunca baja y el enemigo con `spawn_telegrafiado` queda **congelado para siempre** (no se mueve y su colisión sigue desactivada, por lo que tampoco se le puede pegar). Orden correcto: telegrafiado primero, luego inactivo.
  - **Lección (enemigo no ataca):** para el **melee** la parada/ataque debe decidirse con **`attack_range`**, NO con `stop_distance`: la física frena a los cuerpos a una distancia real de contacto (suma de semianchos, p. ej. el jugador deja al cultista a `dist≈46px`). Si se usa `stop_distance` (< `attack_range`) el enemigo queda en `elif dist > stop` persiguiendo para siempre y nunca llega al `else` de atacar. Fix en `enemy.gd::_physics_process`: `elif dist > attack_range: mover`, si no `atacar` (con cooldown). `attack_range` del cultista = **62** (cubre el ~46 de contacto). El proyectil usa `shoot_range`.
  - **Lección (sprite que se sale al girar):** `AnimatedSprite2D.flip_h` espeja alrededor del **origen local del nodo sprite**, NO del centro del cuerpo/hitbox. Si el sprite está descentrado (en `player.tscn` estaba en `(21,-20)`), al girar la figura saltaba fuera de la hitbox. Solución: envolver el sprite en un nodo pivote centrado en el cuerpo (`VisualRoot` en `(0,0)`) y voltear con `visual_root.scale.x = ∓abs()` en vez de `flip_h`; el sprite conserva su `position`/`scale`/`offset` internos. Helper `_aplicar_facing()` en `player.gd`, llamado en `_apply_form()` y `_update_animacion()`.
  - **Lección (enemy_data vacío de la demo):** al arrastrar `enemy.tscn` Godot materializa `enemy_data` como una sub_resource **`Enemigo` vacía** (defaults: `tipo_nombre="Sectario"`, `stop_distance=55>attack_range=40`, `projectile=false`). Como `_ready` solo fabricaba stats si `enemy_data == null`, los enemigos de la demo usaban esos **defaults**, repitiendo el bug de no-ataque para todos (y el arquero ni siquiera era proyectil). Fix en `_ready`: si `enemy_data == null` **o** `enemy_data.tipo_nombre` está vacío/`"Sectario"` (no editado), se regenera con `config_por_tipo(tipo)`; un `enemy_data` realmente editado por el usuario se respeta.
- **`enemy.gd`:** nuevo estado `_activo` (default true, para no romper los enemigos sueltos de main.tscn) + `@export spawn_telegrafiado` + `@export ola_asignada` + **`@export ritual_duracion` (tiempo del círculo ritual, por defecto 0.7, editable en el inspector)**. `activar()` con `spawn_telegrafiado` muestra el **círculo ritual** (Polygon2D generado por código, agregado a `self` y no a `visual` para que se vea) durante `ritual_duracion` s antes de activar la IA; **el sprite (`visual`) NO se ve durante el ritual** (queda `visual.visible=false` de `preparar_ola` y solo se muestra al terminar, cuando ya puede moverse/atacar y reactiva la colisión). Mientras inactivo no se mueve/ataca.
- **`camera.gd`:** se reescribió para seguir al jugador (lerp + límites `export`) y tener `modo_arena(centro)` (fija) / `modo_normal()` (sigue), señal `modo_cambio`. Antes solo tenía `shake`. La cámara ahora se instancia explícitamente en cada escena.
- **`scenes/demo_olas.tscn`:** escena demo (suelo + Player + `Camara` + Encounter + guía). **La demo NO trae enemigos automáticos** (el array `olas` está vacío): sólo aparecen los enemigos que el usuario coloca a mano. La guía (Label "Guia") explica el flujo. Correr: `godot --headless ... res://scenes/demo_olas.tscn --quit-after 6`.
- **Verificación:** import limpio (registra `WaveOla`), autotest FALLOS=0, `tests/diag_encuentro.gd` OK (INACTIVE→RUNNING→spawn 2→matar→COMPLETED), smokes de `demo_olas` y `main` sin errores.
- **Lecciones de esta sesión:** (1) en diag/tests NO usar `:=` con `load().instantiate()` (no infiere tipo con recursos) → tipar como `Node`; (2) un `Array[WaveOla]` no acepta `[ola]` plano → usar `[ola] as Array[WaveOla]`; (3) los arrays exportados de recursos se escriben en el `.tscn` como `Array[Tipo]([SubResource(...)])` y los nodos exportados como `NodePath(...)`; para nodos exportados "múltiples" conviene usar contenedores hijos en vez de `Array[Node]`.

### Build/Run y verificación
```powershell
# import (regenera UIDs, registra class_name)
& "C:\Users\Usuario\Downloads\Godot_v4.7-stable_win64_console.exe" --headless --import
# smoke del juego
& "...Godot_v4.7-stable_win64_console.exe" --headless --path . --quit-after 5
# tests
& "...exe" --headless --path . --script res://tests/autotest.gd
```

---

## Visión del Juego

**Action Adventure 2D Side Scroller** desarrollado en **Godot**, inspirado en las **mecánicas** de *Ben 10: Alien Force* (PS2/Wii, 2008) pero con identidad totalmente propia: otra ambientación, narrativa, arte, personajes y estética.

> La inspiración viene exclusivamente de las mecánicas. No se copian personajes, historia ni estética.

**Pregunta central de diseño:** "¿Qué transformación es la mejor para esta situación?"

---

## ⚠️ REGLA DE DISEÑO (prioritaria)

**Siempre que debamos decidir algo**, tener presente el juego de referencia **Ben 10: Alien Force** en **todas sus dimensiones** (combate, progresión, niveles, ritmo, cámara, interfaz, enemigos, jefes, co-op, coleccionables, etc.), con el objetivo de hacer nuestro juego **lo más parecido mecánicamente** al original, aunque cambie la ambientación.

Esto significa que al evaluar cualquier decisión de diseño, primero preguntarse: **"¿cómo lo resolvía Ben 10: Alien Force?"** y partir de ahí, adaptando solo lo que la ambientación/sigilo/scope obligue a cambiar.

---

## ⚠️ REGLA DE EDICIÓN (usuario, 13/08 — prioritaria)

**Todo elemento del juego (interfaz, personaje, objeto, nivel) debe poder moverse y modificarse desde el editor de Godot**, para que el usuario acomode el mundo y los niveles por su cuenta sin quedar atado al código.

Normas prácticas para el asistente:
- **No enterrar valores de gameplay/espaciales en constantes de scripts** que el usuario querrá tocar. Usar `@export` y layouts en `.tscn` (las posiciones de nodo ya son editables). Nota (13/08): decisión del usuario — eliminar los `.tres` de formas y enemigos y usar **scripts** (`FORM_SCRIPTS` en `player.gd`, `config_por_tipo` en `enemy.gd`), a pesar de que esto quita la edición de stats desde el editor. Los `.tres` SOLO se mantienen cuando aportan datos reales no triviales (como `jugador_frames.tres` con el SpriteFrames).
- Antes de hardcodear un valor, preguntarse: *"¿lo querrá mover el usuario desde el editor?"* Si la respuesta es sí → exportado/recurso/escena. Pero los `.tres` que son meras envolturas de un script (sin datos propios) se deben evitar.
- Los datos que ya viven en `.tscn` (posiciones, tamaños de colisión, `tipo` de enemigo, colores de rompibles) **no se deben replicar en código**; la escena es la fuente.
- Pendiente de migrar a edición desde editor: **las olas** de `encounter.gd` (datos → recursos/escenas). **(RESUELTO 16/08:** implementado con `WaveOla` editable en el inspector + enemigos manuales en el editor — ver sección "Sesión 16/08 (b)".)**

---

## Concepto General

> **NOTA (13/08):** La narrativa es **provisional** y se irá modificando hasta la versión final. No tomar los detalles de historia como definitivos.

- **Protagonista:** Guardabosques con un antiguo contrato espiritual con los guardianes del bosque.
- **Mecánica principal:** Invoca el espíritu de animales y se transforma temporalmente en ellos para usar sus habilidades.
- **Antagonista:** Secta que corrompe el bosque mediante rituales para despertar un antiguo poder oculto.
- **Justificación narrativa:** Los espíritus animales ya no pueden intervenir directamente; el guardabosques es su representante.
- **Transformaciones:** espíritus animales (aún por diseñar desde cero).
- **Narrativa TEMPORAL (diseñada con la IA, 09/08; inicio corregido por el usuario):**
  1. La familia pasa un día en el bosque. El hijo ve algo que le da curiosidad: **la secta haciendo algo para atraerlo** (lo "pescan" activamente, no se pierde por azar).
  2. El padre se da cuenta de que el nene se perdió y sale a buscarlo; ahí ocurre el viaje: **va peleando y obteniendo los poderes de los animales** (los espíritus se le presentan) mientras avanza por la zona mágica.
  3. En la zona mágica trabaja una **secta**. Concepto: **A. Cosecha de almas** — atrapa espíritus animales y a los "sensibles" (el nene oye/ve espíritus = señal) para alimentar un ritual que vuelve inmortal al líder. Riesgo: la corrupción de los espíritus posee a los sectarios (esos son los enemigos cultista/arquero/chamán) y drena la magia del bosque.
  4. El jugador supera enemigos de la secta y obstáculos naturales, y llega al **jefe de la secta**, que tenía al nene **para experimentos y sacrificios**. Lo vence y rescata al hijo.
- **Decisión (09/08 → CORREGIDA en Lote 2):** inicialmente se decidió transformación **ilimitada** por fidelidad al original. Pero al probar el original (notas del usuario), se confirmó que la transformación **es limitada** (vuelve a la forma base al agotarse el tiempo). **IMPLEMENTADO en Lote 2:** gauge de espíritu que drena (22/s), a 0 → vuelve a Humano; matar enemigos y romper recipientes recargan; Humano regenera lento. **NO volver a ilimitada.**
- **Ideas anotadas para futuro:** fragmentos de espíritu (reflavor de los orbes amarillos) que caen de enemigos y desbloquean pasos de combo; checkpoints = santuarios de espíritu; jefe en 3 fases que obligue a alternar formas (síntesis de la pregunta central).
- **Dirección de combate (decidido):** side-scroller con sensación beat 'em up (OPCIÓN A). Cámara **zoom 2x** (todo más grande/cerca) + **oleadas más numerosas con flanqueo** (ola1 = 4 cultistas, ola2 = 2 arqueros + 4 cultistas con bordes, ola3 = chamán + 2 arqueros + 4 cultistas) — 33/33 PASS.
- **Belt-scroller:** se probó en rama `gameplay-prueba` (escena aislada con movimiento X+Y, enemigos que rodean, sin salto, Humano+Oso) y **el usuario decidió descartarla** y borrar la rama. Se eliminaron `scenes/belt_{prueba,player,enemy}.tscn`, `scripts/belt/` y los inputs `belt_up`/`belt_down`. La lección técnica quedó registrada (abajo).

---

## Dirección Artística

- Arte vectorial, minimalista, colores planos.
- Siluetas fáciles de reconocer.
- Mucha vegetación, bosque místico.
- Interfaz limpia.
- No realismo — estética simple viable para equipo pequeño.

---

## Mecánicas a Conservar de Ben 10

1. **Transformación instantánea** — rápida, satisfactoria, útil en combate y exploración.
2. **Cada transformación cambia todo el gameplay** — no simples stats; cada forma se siente como un personaje distinto (movilidad, ataques, utilidades, fortalezas y debilidades propias).
3. **Resolver situaciones con la transformación correcta** — sin transformación superior; cada una resuelve problemas diferentes.
4. **Cambio constante durante el combate** — enemigos y jefes incentivan transformar varias veces en una misma pelea (decisión estratégica, no animación decorativa).
5. **Tiempo limitado — IMPLEMENTADO (Lote 2):** transformación **limitada por gauge de espíritu** (drena al transformarse; se recarga matando enemigos, rompiendo recipientes, pickups y regenerando lento en Humano), fiel a cómo lo juega el original. Antes estaba marcado DESCARTADO (09/08) con transformación ilimitada; rectificado tras las notas del usuario.

## Mecánicas que NO Copiar

- Omnitrix, ADN alien, aliens originales, ciencia ficción, historia y diseño visual de Ben 10.

---

## Transformaciones (POR DISEÑAR)

- Pocas, muy diferenciadas entre sí, cada una con rol claro de combate + exploración.
- Inspiradas en espíritus animales del bosque.
- No disponibles desde el inicio: se desbloquean conforme avanza la historia.
- Cada nueva transformación abre desafíos nuevos y enemigos distintos.

## Progresión

- Transformaciones desbloqueables por avance de historia.
- Recompensas por nivel.

---

## Diseño de Niveles

- **Completamente lineal** (no metroidvania ni mundo abierto).
- **4-5 niveles.**
- Estructura típica por nivel:
  1. Introducción narrativa
  2. Exploración
  3. Primer combate
  4. Desafío ambiental
  5. Segundo combate
  6. Mini jefe (opcional)
  7. Tramo final
  8. Jefe
  9. Recompensa
- Caminos lineales con pequeños desvíos (coleccionables o mejoras).

### Side Scroller (similar al original: plataformas + interacción con el entorno)

- Plataformas con saltos precisos (evitar la imprecisión del original).
- Romper troncos / obstáculos (equivalente a romper objetos para obtener pickups).
- Mover rocas.
- Cruzar ríos / secciones acuáticas.
- Infiltrarse por grietas o huecos.
- Activar mecanismos.
- Abrir caminos.
- Cada situación favorece una transformación distinta.

---

## Cámara

- **Side-scrolling** (lateral), como el original.
- Seguimiento suave del jugador.
- Pequeño desplazamiento hacia la dirección del movimiento.
- Límites dentro del mapa.
- Ligero zoom en transformaciones importantes o jefes.
- Debe favorecer la lectura del combate.
- **CAMBIADO (13/08):** se eliminó el **zoom 2x** → la cámara quedó en **zoom 1, resolución nativa 1920×1080**. Ahora **1 unidad del mundo = 1 px en pantalla** (los sprites se ven a su tamaño real; lo "grande" se logra agrandando sprites/nivel manualmente, no con zoom). Límites actuales en `player.tscn` (Camera2D): left -400, top -800, right 3400, bottom 1080. `zoom_punch` sigue siendo relativo a `_base_zoom` (camera.gd).

---

## Combate

- Dinámico; los enemigos incentivan distintas transformaciones:
  - Rápidos
  - Pesados
  - A distancia
  - Que bloquean ataques
  - Que obligan a sigilo
- Jefes con **fases** que obligan a transformar varias veces en la misma pelea.

## Enemigos

Secta que corrompe el bosque:

- Cultistas básicos
- Arqueros
- Chamanes
- Guardianes pesados
- Animales corrompidos

---

## Ritmo del Juego

Exploración → Combate → Desafío → Exploración → Combate → Jefe (alternancia constante; nunca demasiado tiempo en una sola actividad).

---

## Alcance (2 meses, 3 personas)

- 4-5 niveles lineales.
- Pocas transformaciones, priorizando calidad.
- Pocos enemigos, bien diferenciados.
- 1-2 jefes importantes.
- **Pulido por encima de cantidad** — divertido, sólido y con buen nivel de calidad aunque corto.

---

## Estado Actual del Proyecto

### Prototipo de Core Feel (implementado ✓)

- **Perspectiva:** Side Scroller 2D, fiel al original.
- **4 formas diferenciadas:** Guardabosques (melee), Oso (golpe fuerte), Lobo (dash veloz), Búho (proyectil + doble salto + planeo).
- **Transformación:** tecla `T` cicla entre formas; cambia stats, sprite (placeholder icono de Godot con capa de color `Tint` por forma) y ataque.
- **Combate:** melee/heavy con `Area2D` + señal `body_entered`; dash con impulso; búho dispara proyectil.
- **Enemigo dummy:** recibe daño, muestra vida, muere.
- **Nivel de prueba:** suelo + 3 plataformas + 1 enemigo.
- **Consola dev:** tecla `` ` `` (backtick) abre panel con recuadro de comandos y prompt. Pausa el juego al abrir.

### Estructura del prototipo
```
scenes/
├── main.tscn          # Nivel de prueba (suelo, plataformas, enemigo, player, UI)
├── player.tscn        # CharacterBody2D + Sprite2D(icono) + Tint(capa de color) + Collision + AttackArea
├── enemy.tscn         # Dummy con vida/HpLabel
├── projectile.tscn    # Proyectil del búho
├── console.tscn       # CanvasLayer: panel + recuadro de comandos + prompt
├── hud.tscn           # CanvasLayer: forma activa + controles (top-left, señal form_changed)
├── encounter.tscn     # Zona beat 'em up: TriggerZone + SpawnGroup + Gate (portón)
├── spawn_point.tscn   # Telegrafiado de aparición (círculo ritual) + spawn de enemigo
├── gate.tscn          # Portón visible que bloquea durante el encuentro
├── rompible.tscn      # Objeto destructible (caja/urna/tótem): resiste 3 golpes (feedback tipo enemigo); suelta pickups y fragmentos
├── pickup.tscn        # Item flotante (vida/espíritu) que el jugador recoge al tocarlo
└── levelup.tscn       # Pantalla de elección de mejora (combo) al subir de nivel
scripts/
├── progresion.gd      # AUTOLOAD Progresion: fragmentos → nivel → desbloqueos (formas y pasos de combo)
├── player.gd          # Node que delega en la forma activa (OOP); gauge de espíritu + muerte/respawn + romper rompibles
├── enemy.gd           # 100 HP. configure() + signal died + IA + ATAQUES (cultista melee/arquero/chamán a distancia, con telegrafiado). Feedback de golpe por forma del player
├── rompible.gd        # class_name Rompible (StaticBody2D): golpear() (3 golpes + feedback tipo enemigo) + suelta pickups/fragmentos
├── pickup.gd          # class_name Pickup (Area2D): tipo vida/espíritu; recarga al tocar al player
├── camera.gd          # Camera2D que sigue al player (smoothing) + shake() por offset aleatorio
├── projectile.gd      # setup(dir, dmg, target_group, tint): proyectil del búho (a "enemy") o de enemigos (a "player")
├── console.gd         # Diccionario central COMMANDS (fuente única panel+help)
├── hud.gd             # HUD: barras VIDA/ESPÍRITU verticales (izq.) + contador de progreso + combo
├── encounter.gd       # Olas de enemigos + portón + contador (INACTIVE/RUNNING/COMPLETED)
├── spawn_point.gd     # Círculo ritual (telegrafiado ~0.7s) + spawn con fade-in
├── levelup.gd         # Menú de elección de combo (pausa) al subir de nivel
├── gate.gd            # set_closed() alterna visual + colisión + label "SECTOR CERRADO"
└── forms/             # OOP: base abstracta + 4 formas
    ├── forma.gd       # class_name Forma (RefCounted): atributos + métodos virtuales
    ├── humano.gd      # Solo atributos (melee por default)
    ├── oso.gd         # Solo atributos (stats pesados)
    ├── lobo.gd        # Override: dash (tick/is_dashing/dash_speed/perform_attack)
    └── buho.gd        # Override: doble salto + planeo + proyectil
tests/
└── autotest.gd        # Simula gameplay (13 checks). Correr: godot --headless --script res://tests/autotest.gd
```

### OOP de las formas (refactor ✓)
- **`Forma` (base abstracta):** atributos `form_name, speed, jump_velocity, gravity_scale, max_health, attack_damage, attack_range, attack_size, color, collider_size` + métodos virtuales `tick()`, `is_dashing()`, `dash_speed()`, `is_gliding()`, `try_jump()`, `on_floor()`, `perform_attack()` (melee por default), `reset_state()`.
- Cada animal extiende `Forma`: sobreescribe **atributos** (stats) y solo sobreescribe **métodos** cuando cambia el comportamiento.
- El player conserva `current_form: int` (id, para no romper consola/autotest) + `forms: Array[Forma]` (instancias). Delega en `forms[current_form]`.
- Las formas NO son nodos (`RefCounted`); acceden al player vía mini-API pública: `enable_melee(size, range)`, `fire_projectile()`, `end_attack()`.

### Sistema de encuentros (beat 'em up, estilo del original ✓)
- **Aparición de enemigos:** el nivel se divide en zonas con `Encounter`. Al cruzar el `TriggerZone`, se activa: olas de enemigos con **telegrafiado** (círculo ritual que brilla ~0.7s) y **portón visible** ("SECTOR CERRADO"). Evita el muro invisible del original.
- **Olas (`encounter.gd`):** `waves: Array` de listas `{type, offset, delay, edge}`. Cada ola empieza cuando la anterior está muerta. Tipos: cultista, arquero, chamán (todos **100hp**). `edge: true` = aparece caminando desde fuera de pantalla.
- **Contador:** `_alive` sube en `enemy_spawned` y baja en `signal died`. A 0 → siguiente ola; sin olas → `COMPLETED` + portón abierto.
- **Enemigo (`enemy.gd`):** `configure(hp, color, name)`, `signal died`, IA de aproximación al player (speed 60, stop_distance 70; edge walk-in 120). **100 HP** (default y en `spawn_point.gd`). Al recibir golpe lee la forma activa del player (`player.forms[current_form]`) y aplica su feedback: tinte rojo + rotación + shake + zoom.
- **Feedback por forma (atributos en `Forma`):** `shake_strength`, `shake_duration`, `hit_rotation` (grados), `hit_zoom` (1 = sin zoom). **Todos los ataques que conectan hacen un zoom pequeño (`hit_zoom` default 1.02 en la base; lobo idem), menor al 1.06 original.** Humano 5/7° · Oso 14/14° · Lobo 4 + zoom · Búho 8/14°.
- **Cámara (`camera.gd`):** Camera2D hija del Player (sigue con smoothing), límites 0..2200 x / -800..640 y. `shake(strength=8, duration=0.15)` con offset aleatorio que decae (el `length` puede llegar a ~√2× la fuerza por los 2 ejes). `zoom_punch(strength)` con tween que vuelve a `_base_zoom`.
- **Debug:** comando `spawn_wave` en consola activa el encuentro a mano.

### Versionado (Git) ✓
- **Repo:** `https://github.com/TomasMoreno21/TP3-Taller-de-Juegos` — remoto `origin`, rama `main`.
- **Historia:** README del repo (commit `59f3f1f`) + primer commit del prototipo `0e582d6` + merge `8a76d83` (push inicial hecho 06/08).
- **Cadencia:** un commit por **lote validado** (verificación: `--headless --import` → autotest → `--quit-after 90`). Preguntar al usuario el mensaje antes de cada commit. Rama principal `main`.
- Identidad global configurada: Tomás Moreno `<morenotomas2112@gmail.com>`.

### Controles del prototipo
- Teclado: `← →` / `A D`: mover · `Espacio`: saltar · `J`: combo ligero (repetición escala daño) · `K`: combo fuerte · `L`: especial/interactuar · `Shift`: bloquear (reduce daño 25%) · `T`: transformar · `` ` ``: consola
- Mando: stick/DPAD mover · `A` saltar · `X` ligero · `Y` fuerte · `B` especial/interactuar · `LB` bloquear · `RB` transformar
- En el aire: `J`/`K` (X/Y) hacen jump attacks (light/heavy).

### Lote 1 IMPLEMENTADO ✓ — Combate fiel al original
- **Combos por repetición de tecla** (como pidió el usuario): cada `J` repetido avanza el combo ligero (paso n = `light_damage_at(n)`, +50% por paso, tope `light_combo_steps`); `K` idem con `heavy_*`. Ventana de cadena `COMBO_WINDOW` 0.35s; cambiar de botón o dejar expirar resetea el contador del otro. **Los golpes ligeros tienen knockback pequeño** (`light_knockback` = 80, ~8px) para que el combo siga encadenando; el pesado 150 y el especial más (humano 260 / oso 320).
- **`L` = especial/interactuar:** si hay un `Interactable` en rango de la forma correcta → interacción; si no → ataque especial de la forma. Humano = barrido ancho (66x42, rango 52, knockback 260) · Oso = golpe de tierra (130x70, 320, shake 10) · Lobo = aullido AoE (`aoe_knockback(240, special_damage, 320)`) · Búho = proyectil (movido de `J` a `L`; `J` ahora es picotazo melee).
- **Feedback visual por tipo:** `AttackEffect` (Polygon2D hijo del player) — slash amarillo (light), slash naranja (heavy), ráfaga octogonal con el color de la forma (special); escala crece con el paso del combo; fade+scale tween 0.22s. `_punch_sprite(strength)` estira el sprite por tipo (light 0.15 / heavy 0.3 / special 0.4). Tinte del sprite se aclara mientras se bloquea.
- **Feedback del área de ataque:** `AttackAreaVisual` (Polygon2D) dibuja un rectángulo traslúcido que **refleja exactamente el hitbox** (`attack_hitbox.shape.size` + posición de `attack_area.position`) durante la ventana activa (0.15s) y con el color por tipo (light amarillo / heavy naranja / special color de forma). `show_aoe_area(radius)` dibuja un anillo circular (24 pts) para el aullido del lobo (0.3s). El área se oculta con timer propio (`_area_visual_timer`) y en `end_attack`.
- **Hit por sondeo** (no por `body_entered`): `_check_attack_hits()` sondea `get_overlapping_bodies()` cada frame con `_hit_applied` — 1 golpe por pulsación, determinista para combos rápidos (reemplaza al sistema de eventos que fallaba con doble pulsación). `enable_melee(size, range, damage=-1, knockback=0)`.
- **Block:** `Shift` → `take_damage` reduce a 25% (mínimo 1).
- **Interactable (`scripts/interactable.gd` + `scenes/tronco.tscn`):** `required_form` + `interact_range`; `can_interact()`/`break_interact()` (fade+scale+free). `Tronco` en main.tscn (1180,530) bloquea el paso al encuentro — **solo el Oso lo rompe** (valida la pregunta central de diseño). Hint encima: "Usa el especial con el Oso para romper".
- **Nivel (`main.tscn`):** suelo extendido (2560px, cubre x -380..2180), **7 plataformas de 200px dispersas con alturas variadas** (y 300→470, 560→360, 820→260, 1080→400, 1350→310, 1580→470, 1780→380). 2 enemigos sueltos (650,540 y 950,540) antes del Tronco. `Encounter` en (1480,540) con **3 olas más numerosas**: ola1 = 3 cultistas, ola2 = arquero + 3 cultistas, ola3 = chamán + arquero + 2 cultistas. Cámara: `limit_right = 2200`. (⚠ esta `main.tscn` fue **rediseñada por completo en Lote 2** — ver sección Lote 2.)
- **HUD:** controles actualizados + línea `COMBO LIGERO/FUERTE/ESPECIAL xN` (señal `attack_performed(type, step)`) abajo-izquierda.
- **Autotest: 13 → 31 checks PASS** (combo light escala 10→25, heavy, special, block 25%, jump attack, lobo dash, búho proyectil, feedback visible, interact humano no/oso sí, métodos de la base).

### Lote 2 IMPLEMENTADO ✓ — Progresión fiel al original (gauge, fragmentos, rompibles, enemigos y Zona 1 completa)
- **Autoload `Progresion` (`scripts/progresion.gd`):** Singleton `Progresion`. `fragmentos` y `nivel`. Cada `3` fragmentos sube `nivel` (`add_fragmentos` → `subir_nivel`). `forma_desbloqueada(form)` = `form < nivel` (Humano siempre; Oso=nivel 2, Lobo=3, Búho=4). `pasos_luz()` = `nivel`. Señales `fragmentos_cambiado`/`nivel_cambiado`/`combo_desbloqueado`. Registrado en `project.godot [autoload]`.
- **Gauge de espíritu (`player.gd`):** `energia` (0..100). Transformado drena **8/s** (antes 22/s → la transformación dura **mucho más**, ~12.5s a plena energía, a pedido del usuario); a 0 → vuelve a Humano (`transformacion_agotada`). Humano regenera 5/s. `on_enemy_killed()` da +20 (melee, AoE y proyectil del búho). `add_energia`, `set_energia`, `heal`. **Muerte/respawn:** a 0 HP (sin god) vuelve a Humano en `_spawn_position` con vida llena y 50 de energía.
- **Transformación con gating:** `T` cicla **saltando las formas bloqueadas** por `nivel` (Humano↔siguiente desbloqueada); no se puede transformar si la próxima está bloqueada. **Combo ligero limitado:** `max_step = min(light_combo_steps, nivel)` → cada nivel desbloquea el siguiente paso de combo (progresión por repetición fiel al original).
- **Rompibles (`rompible.gd` + `scenes/rompible.tscn`):** StaticBody2D en grupo `rompible` con `box_size`, `box_color` (adaptan colisión+visual en `_ready`). **Todos iguales: requieren 3 golpes** (`GOLPES_PARA_ROM=3`). En cada golpe no final hacen **feedback igual que los enemigos** (destello rojo + rotación del sprite, `_feedback_golpe`), en el 3º estallan. Al romper sueltan pickups (35% vida) y **siempre +1 fragmento**. Detección vía `_check_attack_hits` (el `AttackArea` tiene `collision_mask = 3`). NOTA color pickup vida = **rojo**, espíritu = azul.
- **Pickups (`pickup.gd` + `scenes/pickup.tscn`):** Area2D en grupo `pickup`, `colision_mask = 4` (detecta al player). `tipo` "vida" (heal 25) / "espiritu" (energía). `setup(tipo)` + color en `_ready`. Tween de pulso y despawn a 8s.
- **Enemigos que atacan (`enemy.gd`):** `@export enemy_type` (cultista/arquero/chamán) → `_apply_type_stats()` (cultista melee 80px/s stop 60, ataque 15 en rango 55; arquero 45px/s mantiene distancia ~*, proyectil 12 en rango 420; chamán 38px/s, proyectil 16 en rango 460). Ciclo: acercarse → **telegrafiado** (`_pulse_telegraph` escala visual 1.4 en 0.35s) → impacto (cultista melee cuerpo a cuerpo; arquero/chamán proyectil contra "player"). Cooldowns 1.6/2.2/2.6s. **`apply_knockback` recarga el timer y decae `velocity.x`** (se restauró el manejo de knockback que se había perdido en el rewrite). **Separación mutua (`_separacion()`):** los enemigos se repelen entre sí (rango ~46px) para no amontonarse en la oleada y evitar el "spam de un solo golpe". **Olas menos densas** (2/4/5 en lugar de 4/6/7) con offsets más amplios.
- **Proyectil mejorado (`projectile.gd`):** `setup(dir, dmg, target_group, tint)` — ahora puede atacar a "player" (proyectiles enemigos, color oscurecido del enemigo); el del búho sigue atacando "enemy" y da +energía al matar.
- **HUD (`hud.gd/.tscn`):** barras superiores VIDA y ESPÍRITU (ProgressBar) + `FRAGMENTOS x/y · NIVEL n` + label de avisos ("¡Transformación agotada!", "¡Combo n desbloqueado!"). Conecta señales de `player` y `Progresion`. **Desde 15/08:** también muestra cartel de nivel ("¡NIVEL X ALCANZADO!") y de desbloqueo de forma ("¡NOMBRE DESBLOQUEADO!") con cola de avisos para que no se pisen.
- **Consola:** comando `fragmentos <n>` (concede fragmentos/sube nivel).
- **Zona 1 completa (`main.tscn`):** rediseño en 5 secciones: inicio+combate (Player 200,540, Enemy 380,540) → 3 urnas grandes (520/700/880, rompen con heavy + fragmentos → desbloquean Oso) → Tronco (1010, enseña el especial del Oso) → **Arena 1** Encounter (1300) → **plataformeo** (5 plataformas 1460→2000, alturas 460→300; cajas chicas que rompen; Urna4 en 1560) → **Arena 2** (E1..E5 en 1980→2320: arquero/cultista/cultista/arquero/chamán — mezcla distinta a la arena 1) → **Santuario** (Tótem en 2280: grande, da fragmentos; label "SANTUARIO"). Suelo extendido a 3000px, `limit_right` del player a 2400.
- **Autotest: 45 checks PASS** (0 fallos). Nuevos tests: transformar bloqueado en nivel 1, combo limitado a 1 paso, 3 fragmentos→nivel 2→desbloquea Oso, energía drena y vuelve a Humano, rompibles (1 golpe no rompe, 3er golpe rompe + pickup + fragmento), pickup recarga energía. **Importante:** usa `_progresion()` (por ruta) en vez del identificador global (ver lección abajo).

### Lote 2.5 — Sistema de combos por secuencia + elección de nivel (IMPLEMENTADO ✓)
- **Combos por secuencia (`forma.gd` + cada forma):** cada forma tiene `combos: Array[Dictionary]` — **SIMPLIFICADO: 1 solo combo por forma** (el primero, `secuencia = ["light", "heavy"]`, es decir `J → K`): `{"nombre", "secuencia", "dano", "knockback", "tamano", "rango"}`. `forma.perform_combo(player, combo)` = `enable_melee` con los stats del combo. (Se eliminaron los combo2 "K→L" y sus overrides de `perform_combo` por forma que quedaban muertos.)
  - Humano: Remate (J→K, 42).
  - Oso: Garra (J→K, 84).
  - Lobo: Mordida (J→K, 22, dash en combo).
  - Búho: Ala Cortante (J→K, 28).
- **Elección al subir de nivel (`scenes/levelup.tscn` + `scripts/levelup.gd`):** `Progresion` emite `nivel_subio` **solo en `subir_nivel()`** (no en `set_nivel`, para no abrir el menú en tests/consola). Autoload `LevelUp` escucha: **pausa** el juego y muestra un panel con las formas desbloqueadas que aún pueden aprender su **único combo**; elegís con ↑/↓ + J/Enter → `Progresion.elegir_mejora(form_index)` desbloquea el combo de esa forma (`combos_desbloqueados` queda capado en `combos.size()`, o sea 1). API: `abrir()/cerrar()/seleccionar(i)/opciones()`.
- **Player (`player.gd`):** rastrea la secuencia `_seq` (últimos 3 inputs dentro de `COMBO_WINDOW`); `_detectar_combo(tipo)` la coteja contra los combos **desbloqueados** de la forma (de mayor a menor longitud); si coincide → `_ejecutar_finisher` (`performa_combo` + FX `SLASH_COMBO` + `attack_performed("combo", nombre)`), prioridad sobre el escalado por repetición. `_seq` se limpia al expirar la ventana y al cambiar de forma. `attack_performed` ahora es `(String, Variant)`.
- **HUD:** muestra el nombre del combo; aviso "¡Forma aprendió 'Combo'!".
- **Consola:** `nivel <n>` (fuerza nivel sin abrir el menú) y `combos` (lista desbloqueados por forma).
- **Autotest:** `nivel_subio` se auto-elege opción 0 (handler conectado temprano para no pausar). Nuevos tests: humano sin combos → `elegir_mejora(0)` desbloquea combo1 → J→K hace 42 (el finisher en el 2º golpe) → K→J no dispara → combo2 desbloquea K→L hace 60 → formas no elegidas bloqueadas. **(Nota test:** `_spawn_enemy_near` toma `group[0]`; hay que `kill_enemies` antes de cada spawn para que no devuelva un enemigo viejo/liberado.)
- **Verificación:** import limpio, autotest **FALLOS = 0**, smoke limpio.

### Lote 2.7 IMPLEMENTADO ✓ — Ritmo de combate (cooldowns + gateo) y textos de ataque del HUD
- **Gateo real del combate (`player.gd`):** `_handle_attack` hace **early-return** si `_attacking and _attack_timer > 0` (decrementa el timer; al llegar a 0 llama `end_attack()`). Antes cada golpe **reseteaba** el timer, por lo que se podía spamear sin límite. Ahora el cooldown sí limita el ritmo. **Importante:** con este gateo, los tests que presionan ataques en frames consecutivos quedan bloqueados → hay que esperar la recuperación entre golpes en el autotest.
- **Buffer de entrada en `player.gd`:** al presionar un botón de ataque **durante la recuperación** del ataque previo (gate activo), se guarda (`_buffered_attack`) y se ejecuta **apenas termina la recuperación** (`_lanzar_buffered`), con `_seq` intacto. Evita que el 2º botón de un combo se pierda por el gateo (sin esto, J→K fallaba y parecía que había que apretar los botones "a la vez"). Refactor: la lógica de golpe se extrajo a `_procesar_ataque(tipo, data, airborne)`; `_handle_attack` delega en ella (vía live o buffer); `_buffered_attack` se limpia al cambiar de forma.
- **Cooldowns por tipo (`_recovery_for()` en `enable_melee`):** `RECOVERY_LIGHT 0.3 / RECOVERY_HEAVY 0.5 / RECOVERY_SPECIAL 0.8 / RECOVERY_COMBO 1.0` (subidos en la sesión para simular la animación del original, y luego **bajados en dos pasos** a estos valores actuales). `COMBO_WINDOW` **subido de 0.35 a 1.10** para que J→K / K→L sigan encadenando pese a la recuperación.
- **Textos de ataque del HUD (fiel al diseño iterado con el usuario):**
  - Nombres: ligero → **"Golpe"**, fuerte → **"Fuerte"**, especial → **"Especial"**; finisher → **solo el nombre del combo** (sin la palabra "COMBO"). Sin colores (texto **blanco**).
  - Máx. **2 golpes** visibles en una **única fuente `FONT_BIG = 34`**.
  - Posición a la izquierda: offsets **-560..-160** (hud.gd y hud.tscn), `SLOT_TOP = -128`, `BASE_TOP = -80`.
  - Rotación: base vacía → texto + **fade-in 0.25s** (`_animar_aparicion`, TRANS_QUAD/EASE_OUT); si hay base → free top, promueve base a slot, nuevo texto abajo. Tras `TOP_FADE_DUR = 0.7s` el top se **desvanece en su lugar** (`_fade_top`: interval 0.05 + fade 0.35). En inactividad (`IDLE_CLARO = 2.5s`, `_limpiar_idle`) el bottom se **desliza a la izquierda** (`_animar_deslizar_izq`: x−320 en 0.35 TRANS_CUBIC/EASE_OUT) y tras `SALIDA_DUR = 0.85` libera.
  - `_on_form_changed` limpia timers/`_subida`/texto.
- **Acciones de navegación del menú de nivel:** agregadas `move_up` / `move_down` en `project.godot` (W/S + flechas + D-pad). Sin ellas el menú de elección no navegaba hacia abajo (bug de navegación).
- **`_check_attack_hits` prioriza a los enemigos** (`player.gd`): primero recorre el overlap en busca de un `enemy` (golpe + knockback + break), y solo si no hay, busca un `rompible`. Antes rompía en el **primer body del iterable** (orden arbitrario), por lo que una urna/rompible cercano podía "robarle" el golpe al enemigo (el área tomaba `_hit_applied` y el enemigo quedaba intacto → tests de daño fallaban aleatoriamente según la posición).
- **Autotest adaptado a la nueva mecánica (45 checks, FALLOS = 0):**
  - Helpers: `_esperar_recuperacion(ataque)` (light 32 / heavy 50 / special 74 / combo 92 frames) y `_esperar_seq()` (70 frames, espera que expire `COMBO_WINDOW` para vaciar `_seq`).
  - Se **flushea `_seq`** antes de los tests de heavy/especial y los combos por secuencia, para que un golpe residual de una prueba anterior no dispare un finisher equivocado (ej.: el K del test de heavy disparaba el Remate por `_seq=["light","light","heavy"]` residual).
  - `_spawn_enemy_near` ahora es precedido por `kill_enemies` en los tests aislados (heavy/especial/salto) para que `enemy[0]` sea el enemigo recién spawneado y no uno viejo/dañado/muerto.
  - Rompibles: se verifica la ruptura con `not is_instance_valid(...) or broken` (el rompible se libera al romperse); el check "suelta un pickup" usa un rompible aislado lejos del jugador (para que el pickup no se recoga al instante).
  - Búho: el check del proyectil se mide justo tras 2 frames de la pulsación (el proyectil se despawna al chocar con el terreno).
- **Verificación:** import limpio, autotest **FALLOS = 0**, smoke limpio.

### Plan pendiente — Pseudo-2.5D por capas (RECHAZADO por el usuario en build, 13/08)
- **Decisión (13/08, usuario):** NO convence. Feedback textual: *"No es el enfoque visual, siento que terminaría siendo lo mismo que lo que hay ahora."* Se descartó la "pseudo-2.5D por capas" (escalar `z` + offset sobre suelo plano).
- **Por qué falla (lección):** escalar y levantar siluetas sobre un **suelo plano** no comunica profundidad; el jugador lo lee como el mismo side-scroller 2D de siempre. La profundidad real en el original viene de **geometría que retrocede** (piso/paredes en perspectiva) o de una **cámara/escena 3D**, no de variar el tamaño de los sprites.
- **Qué era la opción por capas (para no repetirla sin cambio crítico):** eje `z` en `enemy.gd`/`spawn_point.gd`/`encounter.gd`/`projectile.gd`/`main.tscn`, dolly en `camera.gd`, `z` como presentación (no bloqueador). **Archivos de preview creados y verificados:** `scenes/pseudo2d_preview.tscn` + `scripts/pseudo2d_preview.gd` (toggle con `D`; correr con F6). Import limpio + autotest FALLOS = 0. → la preview se puede borrar si no sirve.
- **ESTADO:** la dirección sigue **abierta**. Se probaron 2 enfoques visuales con preview y ambos se descartaron por el usuario (13/08): (1) pseudo-2.5D por capas (escalar/levantar siluetas sobre suelo plano → "se ve igual que ahora"); (2) arena con piso/paredes en perspectiva + personajes en "calles" (look beat'em-up), también no convenció. **Toda la preview fue borrada** (`pseudo2d_preview.*`, `arena_preview.*`, `scripts/preview/*`, `scenes/preview/*`). Solo quedan cachés de `.godot/editor/` (inofensivos). El juego real no se tocó (autotest FALLOS=0).
- **Próximo paso:** redefinir con el usuario qué busca de "adaptar el ambiente 3D del original" antes de volver a prototipar.

### Consola dev — comandos
`help`, `form <humano|lobo|oso|murcielago>`, `god`, `mv`, `frags <n>`, `nivel <n>`, `kill`

### Idiomas
- **Preferencia del usuario (11/08):** todo **en español** — el código de interfaz del juego (labels, avisos, HUD) **y** la comunicación del asistente. Constante en adelante.

### Pendiente para validar en Godot (probarlo a mano)
- [ ] Sensación real de cada forma (velocidad/salto/peso) — los números son placeholders iniciales
- [ ] Rebalancear stats según feedback del grupo
- [ ] Sentir la Zona 1 completa y el ritmo tronco→arena→plataformeo→arena→santuario

### Lote 1 APROBADO — Combate fiel al original (por implementar)
- Mapeo original → nuestro: Light=`J` (existe), Heavy=`K` (nuevo), Special/Interact=`L` (nuevo), Jump+Light/Heavy en el aire, Block=`Shift` (nuevo).
- **`forma.gd`:** atributos `heavy_damage/heavy_range/heavy_size/special_damage` + métodos `perform_light` (renombra `perform_attack`), `perform_heavy`, `perform_special`, `perform_jump_attack`, `perform_combo_finisher` + datos `combos: Array[Array[String]]`.
- **Formas:** búho proyectil pasa de `J` a `L` (special), `J` = picotazo corto; lobo light sigue siendo el dash; 2 combos por forma (Humano L→L "Empuje"; Oso L→H "Demoledor"; Lobo H→L "Avalancha"; Búho L→L "Doble flecha").
- **`player.gd`:** inputs nuevos, jump attacks, combo buffer (finisher = +daño +knockback +zoom punch), block (reduce 75%), `enable_melee(size, range, damage=-1, knockback=0)` sin romper la llamada actual de lobo.
- **Interact contextual:** `L` cerca de un interactable de la forma correcta → interacción; si no → special. Nuevo `interactable.gd` + `Tronco` en main.tscn (solo lo rompe el Oso).
- **`enemy.gd`:** `apply_knockback(vec)`. **`hud.gd`:** controles + línea de combo. **`project.godot`:** acciones `heavy`, `special`, `block`.
- **Autotest:** 13 → ~20 checks.

---

## Referencia: Ben 10: Alien Force (Juego Original)

### Ficha Técnica
| Dato | Valor |
|------|-------|
| Desarrollador | Monkey Bar Games (Vicious Cycle Software) |
| Publisher | D3 Publisher |
| Motor | Vicious Engine |
| Género | Action-adventure / Beat-'em-up 3D side-scrolling |
| Plataformas | PS2, PSP, Wii, DS |
| Lanzamiento | 28 Oct 2008 |
| Metacritic | 45/100 (desfavorable) |

### Gameplay del Original
- **Perspectiva:** 3D side-scrolling (2.5D)
- **Combate:** light + heavy + special, combos desbloqueables
- **Progresión:** orbes amarillos → combos; Plumber Badges → extras
- **Co-op:** PS2/Wii (2 jugadores, mismo personaje)
- **Historia:** búsqueda del Abuelo Max, Gorvan, array climático Highbreed (8 capítulos)

### Problemas del Original a EVITAR
- Combate repetitivo con muros invisibles que forzaban peleas
- Niveles planos y aburridos, demasiado largos
- Detección de golpes y físicas pobres
- Plataformas imprecisas
- Co-op confuso (mismo personaje sin variante)

---

## Decisiones Pendientes / Próximos Pasos

- [x] **Perspectiva: SIDE SCROLLER** (decisión tomada — fiel al original)
- [ ] Definir y nombrar el juego
- [ ] Diseñar las transformaciones (rol de combate + rol de exploración por cada una)
- [x] **Transformación limitada por gauge de espíritu: DECIDIDO e IMPLEMENTADO (Lote 2)** (drena al transformarse, se recarga con kills/rompibles/pickups y regen de Humano)
- [ ] Definir sistema de combate base del guardabosques (forma humana)
- [ ] Prototipar movimiento + transformación + 1 combate básico en Godot
- [ ] GDD orientado a producción
- [ ] Detallar roles del equipo (3 personas)
- [ ] Planificación de sprints (2 meses)

---

## Equipo

- 3 personas (pendiente detallar integrantes y roles).

---

## Cronograma

~2 meses para prototipo jugable, GDD, pitch y trailer (metodología ágil con sprints).

---

## Entregables (Unidad 3)

1. Prototipo jugable (build ejecutable)
2. Documento de Diseño (GDD orientado a producción)
3. Pitch de venta
4. Trailer del videojuego

---

## Notas / Lecciones Aprendidas

- **(13/08) Los `.tres` que son meras envolturas de un script (solo `script = ExtResource(...)` sin datos propios) se pueden borrar y cargar el script directo:** los 4 `.tres` de formas (`resources/formas/*.tres`) eran así; se reemplazaron en `player.gd` por `const FORM_SCRIPTS = [preload("...humano.gd"), ...]` + `script.new()` en `_ready()`. Los `.tres` de enemigos SÍ tenían datos (stats); se hardcodearon en `enemy.gd::config_por_tipo(tipo)` y se eliminaron, con `@export var tipo` seteado en `main.tscn` y en los tests (`en.tipo = "cultista"` ANTES de `add_child` para que `_ready()` arme el `enemy_data`). Beneficio: menos recursos que reimportan y rompen UIDs/`AtlasTexture`; costo: los stats ya no se editan desde el inspector del editor. Regla: usar `.tres` solo cuando aportan datos reales (p.ej. `jugador_frames.tres`).
- **(13/08) Los `.tres` generados "a mano" no necesitan esperar al editor:** el `SpriteFrames` (`resources/jugador_frames.tres`) se puede escribir directamente como texto con `ext_resource` de texturas (sin UID, solo `path`) + `sub_resource AtlasTexture` con `region` por frame + lista `animations`. Godot lo reimporta solo. Escribir un script generador `--script` puede colgar con timeout si no termina; verificar después si se creó el archivo.
- **(13/08) Al pasar un `Sprite2D` a `AnimatedSprite2D`:** mantener el **mismo nombre de nodo** (`Sprite2D`) para que las rutas `$Sprite2D` y `get_node_or_null("Sprite2D/Tint")` sigan funcionando. Si se elimina el `Tint` hijo, el código debe usar `visual.self_modulate` (cae en el `else`) en vez de `tint.modulate`. El flip horizontal es `visual.flip_h = facing < 0`.
- **(13/08) CAUSA REAL de "no se ve el personaje": las `AtlasTexture` de un `.tres` escrito a mano pierden la referencia a su textura al reimportar** (quedan frames vacíos, el `AnimatedSprite2D` no muestra nada pero no da error; la colisión `CollisionShape2D` sí funciona, por eso "los enemigos lo detectan"). La solución robusta: generar el `SpriteFrames` **por script** incrustando cada frame como `ImageTexture` (con `ImageTexture.create_from_image(imagen.get_region(...))`), NO usar `AtlasTexture` con `ext_resource` de textura. Verificación: `sf.get_frame_texture(anim,0).get_image() != null` y contar píxeles opacos. El "self_modulate verde" NO era la causa (solo un tinte).
- **Scripts `extends SceneTree` por `--script`: usar `_init()` NO `_initialize()` y llamar `quit()` al final** — `_initialize()` no se ejecuta, el proceso se cuelga hasta el timeout. Verificar siempre que el archivo/que el recurso se creó.
- **(13/08) Un `scale` en el nodo raíz agranda la hitbox sin que coincida con el editor:** con `Player scale=(3,3)`, la `CollisionShape2D` de 24.67×29.67 se multiplicaba a ~74×89 px reales mientras el editor (y el sprite del `AnimatedSprite2D` con su propio scale 0.993) no lo reflejaban igual. Solución: `scale=(1,1)` en el raíz, escala visual en el `AnimatedSprite2D`, y los valores de las formas expresados en **px reales del mundo** (multiplicar colisiones/rangos/tamaños por el factor que tenía el nodo, sin tocar velocidades ni fuerzas). Los tests de offsets relativos (enemigo a 60px, dummy a 40px) siguen pasando porque el alcance ligero humano pasó de 26→78 px reales (el 78 que ya era efectivo antes).
- **(13/08) En un test "matar al enemigo con melee", reposicionar al player junto al enemigo en cada golpe:** el enemigo con `stop_distance` (50px) se detiene justo fuera del alcance del attack humano (área 11–41px), así que un solo golpe inicial conecta y los siguientes fallan → el enemigo nunca muere. Al teleportar al player a `enemy.position - (20,0)` antes de cada ataque, todos conectan.
- **(13/08) Proyectiles de enemigo vs de player:** la escena `projectile.tscn` es compartida; la máscara debe distinguir quién dispara (`enemy_shot` bool → `collision_mask = 4` si es del enemigo para golpear al player, `3` si es del murciélago para golpear enemigos). El arquero/chamán apuntan al jugador: `direction = (player.global_position - global_position).normalized()` en `_disparar(player)`; los enemigos tienen gravedad (`GRAVITY=980`, `MAX_FALL_SPEED=950`) en `enemy.gd`.
- **(13/08) `enemy.tscn` sin UID válido en el header no registra `.uid`:** escribir `uid="uid://foo"` inválido evita que el import genere el archivo. Dejarlo sin `uid` en el header (o con uno real regenerado) y referenciarlo por `path` (como `hud.tscn`). (Los `.tres` de enemigos que existían entonces ya no existen — ver lección sobre borrar `.tres`-envoltura arriba.)
- **(13/08) Un objetivo de interacción grande (coloso) necesita `interact_range` que considere SU tamaño:** con un Tronco de 200px de ancho y `interact_range=90`, el jugador no puede acercarse a 90 px del centro sin pisar el cuerpo (move_and_slide lo empuja). Un `required_form` correcto + distancia "correcta" seguía fallando; la causa era puramente de alcance. Subir `interact_range` (220) resolvió. Al escribir tests de interacción con objetos grandes: usar plataforma de test controlada + `await _funcion_tronco()` (llamar la función con `await`, o los checks posteriores se cortan por `quit()`).
- **(13/08) En tests `--script`, `get_tree().current_scene` es `null`** (no hay escena principal); `fire_projectile()` y `rompible._soltar_pickup()` hacían `add_child` a null. Fix: `var destino = get_tree().current_scene if get_tree().current_scene != null else get_parent()`. Pattern a reutilizar para cualquier `add_child` de un nodo spawneado.
- **(13/08) Al reescribir tests, referenciar la API REAL:** `console._ejecutar(PackedStringArray([...]))` (1 arg) y `console.toggle()`, NO `_execute`/`_toggle`/`set_form`/`set_energia`/`get_form_name`. Los métodos heredados/asumidos rompen el autotest.
- **(13/08) El HUD se actualiza por SEÑALES, no por polling:** asignar `player.energia = 40` directamente NO baja la barra (no emite `energia_changed`); hay que transformar (drena) o emitir. Al testear el HUD, disparar señales reales (daño, heal, transformación), no tocar vars a ciegas.
- **(13/08) `_transformar(n)` retorna temprano si `n == current_form`:** si el test fija `current_form` y luego llama `_transformar` del mismo índice, la señal `form_changed` NO se emite y el aviso del HUD no aparece. Poner `current_form` a un valor distinto antes de `_transformar`.
- **Nuevos `class_name` no se registran hasta reimportar:** crear un script con `class_name` nuevo y correr `--headless --script` falla con "Could not find type". Hay que correr `godot --headless --import` primero (o abrir el editor).
- **`await physics_frame` retoma ANTES de que corra el `_physics_process`** del frame. En tests hay que esperar **2 frames** después de presionar una acción para ver su efecto (1 para procesar + 1 para leer). Y para cosas con tween/telegrafiado, esperar el tiempo completo (p.ej. ~0.7s del círculo ritual antes de ver enemigos).
- **Las señales sin argumento no se conectan a handlers con parámetros:** `signal died` (sin args) falla con "Method expected 1 argument(s)" si el handler recibe un parámetro. Los handlers deben coincidir con la firma de la señal.
- **En `enable_melee` hay que re-habilitar el hitbox** (`attack_hitbox.disabled = false`): `end_attack()` lo deshabilita y si no se reactiva, el Area2D nunca detecta al enemigo (bug silencioso, solo visible en el autotest de daño).
- La captura de pantalla headless (`root.get_texture().get_image()`) devolvía toda gris con renderer D3D12/Forward+ y con gl_compatibility; incluso con `RenderingServer.frame_post_draw`. Pendiente resolver si es límite del pipeline o del método (diagnóstico abierto).

### Lote 1 — lecciones nuevas (no repetir)
- **`PackedVector2Array([Vector2(...), ...])` NO es expresión constante** en GDScript → error "Assigned value for constant isn't a constant expression". Usar `var` con arreglo plano `PackedVector2Array([x1,y1, x2,y2, ...])`.
- **`get_nodes_in_group()` devuelve `Node` sin tipar:** al recorrer y usar `global_position`, declarar el loop tipado: `for body: Node2D in ...` (si no: "Cannot infer the type").
- **`Input.is_action_just_pressed()` se consume en la primera llamada:** no hacer `print(... is_action_just_pressed ...)` dentro del mismo frame que el jugador lo va a leer, o el borde se pierde.
- **`await physics_frame` retoma ANTES de `_physics_process`:** en tests, para que una pulsación registre hay que mantenerla presionada cruzando 2 frames (press → await → await → release) antes de soltar.
- **El jugador empieza cayendo en main.tscn (spawn en (446,245), suelo en y≈540):** en tests con escena fresca hay que aterrizar (esperar ~10 frames) o el `light` del lobo hace jump-attack en vez de dash (y cualquier ataque "de suelo" no se ejecuta).
- **`body_entered` no re-emite para cuerpos ya solapados:** para golpes de combo rápidos (re-habilitar el Area2D con el enemigo adentro), el sistema por eventos es frágil → usar **sondeo** (`get_overlapping_bodies()` + flag `_hit_applied`), 1 golpe por pulsación.
- **La detección de golpe por sondeo aplica 1 frame después** de `enable_melee` (el Area necesita un physics step para computar solapamientos): en tests medir el HP después de 3 awaits, no 2.
- **Enemigo que "flota" al recibir knockback (bug K):** el `enemy.gd` no aplicaba gravedad jamás; el impulso vertical del knockback lo dejaba levitando. Fix: aplicar gravedad **siempre** en `_physics_process` del enemigo (`velocity.y += GRAVITY * delta`, cap `MAX_FALL_SPEED`) y tratar el knockback como impulso único (`velocity = vec` una vez + decaimiento de `velocity.x`), no sobrescribir `velocity` cada frame.
- **Joystick:** cada acción de input necesita su `InputEventJoypadButton`/`InputEventJoypadMotion` en `project.godot`. `Input.get_axis("move_left","move_right")` ya lee el eje del stick automáticamente (axis 0). Mapeo: A=0, B=1, X=2, Y=3, LB=9, RB=10, DPAD=13/14.
- **`configure()` no puede correr antes de `add_child()`:** los `@onready` de un nodo instanciado recién existen cuando entra al árbol. Orden correcto: `instantiate()` → `position` → `add_child()` → `configure()`. (Aprendido en la prueba belt; aplica al spawner del prototipo si se reutiliza.)

### Lote 2 — lecciones nuevas (no repetir)
- **En modo `--script` los autoload NO se resuelven como identificador global al compilar** ("Identifier not found: Progresion") y el nodo no existe ni por ruta durante `_init`. El juego normal (`--headless --quit-after`) SÍ los resuelve. **Solución robusta en ambos modos:** acceder por ruta `get_node("/root/Progresion")` en vez del nombre global (aplica a player/rompible/hud/console y a autotest). No volver a usar el identificador global en scripts que se carguen bajo `--script`.
- **`create_tween().set_loops().tween_property(...).tween_property(...)`:** la primera `tween_property` devuelve un `PropertyTweener` (no Tween), encadenar otra falla. Encadenar solo después de la primera: guardar en var `tw := create_tween(); tw.set_loops(); tw.tween_property(...); tw.tween_property(...)`.
- **`setup()` no debe tocar `@onready`** si se puede llamar antes de entrar al árbol (en rompible se añade primero y luego setup; en tests se llamó antes → Nil). Hacer `setup` guardado con `if is_inside_tree()` o aplicar el color en `_ready`.
- **Al reescribir `enemy.gd` no perder el bloque de knockback:** si `_knockback_timer` nunca se decrementa, `_seek_player` nunca vuelve y el enemigo queda deslizándose con `velocity.x` fijo (se va del rango y los golpes siguientes fallan). Restaurar: decrementar timer + decaer `velocity.x` + `_seek_player` al terminar.
- **Si se reubican objetos, revisar el autotest:** un proyectil del búho disparado desde la posición de un test puede chocar con un rompible (StaticBody2D) recién colocado en el nivel y liberarse antes de contarse. Mantener la trayectoria de tests despejada.
- **`match` es palabra reservada en GDScript** ("Expected expression to test after match"): no usar `var match := true`; renombrar la variable (p. ej. `coincide`).
- **`_spawn_enemy_near` devuelve `get_nodes_in_group("enemy")[0]`:** si quedan enemigos vivos de tests previos, devuelve uno viejo (que puede morir → "previously freed" al leer `health`). Antes de cada spawn en tests, llamar `kill_enemies` para vaciar el grupo.
- **Al ampliar un `signal` de `int` a `String`** (p. ej. `attack_performed` ahora acepta nombre de combo), cambiar el tipo a `Variant` para admitir ambos; ajustar el handler del HUD acorde.
- **Si el rompible se instancia pegado al jugador (offset 30px), el pickup que suelta se recoge al instante** (el `body_entered` del pickup se dispara porque el player lo toca) → el check "suelta un pickup" falla por conteo. Para verificarlo, **mover al jugador lejos del pickup antes de contar los del grupo** en el test.

### Lote 2.7 — lecciones nuevas (no repetir)- **Un cooldown que solo resetea un timer no gatea nada:** si cada golpe pone `_attack_timer` en el valor de recuperación, la cadencia es spameable. Para que la recuperación limite el ritmo, `_handle_attack` debe hacer **early-return** mientras `_attacking and _attack_timer > 0` (decrementar y `end_attack()` al llegar a 0) y **no** resetear el timer en los ataques nuevos mientras esté activo.
- **En un `RichTextLabel`, el override de tamaño es `normal_font_size`, NO `font_size`:** usar `add_theme_font_size_override("normal_font_size", n)` o la propiedad del .tscn. Aplicar `font_size` no tiene efecto → el primer texto de ataque salía chico en el HUD.
- **`_check_attack_hits` no debe romper en el primer body de `get_overlapping_bodies()`** (el orden es arbitrario): una urna/rompible cercano podía recibir el golpe antes que el enemigo y dejar el enemigo intacto. **Priorizar enemigos primero** (2 pases: 1º buscar `enemy`, 2º rompible).
- **`_seq` persiste mientras `COMBO_WINDOW` esté viva y NO se limpia al terminar los ataques** (solo al expirar el timer o cambiar de forma). En tests, una secuencia residual de una prueba anterior puede disparar un finisher equivocado (p. ej. el K de un "heavy suelto" disparaba el Remate por `_seq=["light","light","heavy"]`). Flushear con `_esperar_seq()` (esperar > `COMBO_WINDOW`) antes de cada prueba de ataque/combo.
- **Cambiar la cadencia/combo rompe los tests que presionan ataques en frames consecutivos** (ahora quedan bloqueados por el gateo): hay que intercalar `_esperar_recuperacion(ataque)` entre golpes y medir el daño respetando la recuperación.
- **El rompible se libera al romperse** (tween → `queue_free`): para leer su estado usar `not is_instance_valid(x) or x.broken`. Y el proyectil del búho **se despawna al chocar con terreno** → medir el conteo justo tras spawmearlo, no al final de la recuperación.
- **El buffer de entrada resuelve los combos con cooldown:** si un `is_action_just_pressed` se ignora durante la recuperación, el 2º botón del combo se pierde y el jugador cree que hay que apretar "a la vez". Al hacer el gateo hay que **bufferear** el botón presionado y ejecutarlo al terminar `end_attack()`, manteniendo `_seq` (que vive `COMBO_WINDOW`). Los tests de combos que esperan la recuperación antes del 2º botón siguen pasando igual.
- **(13/08→16/08) Buffer de combos sin exigir mantener el botón:** antes el usuario pidió que el ataque guardado durante el cooldown SOLO se ejecute si seguís apretando al terminar (`_sigue_apretado`) y se cancelase si soltabas. Esto hacía que el combo J→K pidiera *"casi apretarlos a la vez"* (margen mínimo). **16/08** el usuario pidió dar margen → se ELIMINÓ `_sigue_apretado` y `_lanzar_buffered` ahora ejecuta el golpe bufferizado aunque ya hayas soltado el botón. `_seq` vive `COMBO_WINDOW=1.1s`. Los tests del Remate (J→K) siguen pasando (FALLOS=0).
- **(13/08) Si se reemplaza el sprite del jugador, revisar nodos internos:** el juego tenía `@onready tint = $Sprite2D/Tint`; al cambiar a un sprite propio sin ese hijo, tiraba "Node not found" en cada carga. Fix: `get_node_or_null("Sprite2D/Tint")` (`_update_tint()` ya no usa `tint`).
- **(13/08) El zoom 2x ocultaba el tamaño real:** con zoom 1 y 1920×1080, 1 unidad = 1 px; para cambiar el tamaño de lo que se ve hay que agrandar los sprites/objetos, no el zoom.
- **(16/08) Combo por transformación — flujo completo (verificado en autotest):** cada forma tiene UN combo con secuencia `["light","heavy"]` (J y K): Humano=Remate(42), Lobo=Mordida(22), Oso=Garra(84), Murciélago=Ala Cortante(28) en `scripts/forms/<forma>.gd::combos`. Desbloqueo: al subir nivel, `levelup.gd` escucha `nivel_subio`, abre el menú con las formas desbloqueadas (↑/↓ + confirmar con J/ui_accept) y llama `Progresion.elegir_mejora(form_index)` → incrementa `combos_desbloqueados[form]` y emite `combo_desbloqueado`. `player.gd::_detectar_combo` / `_ejecutar_finisher` lo ejecutan si `combos_desbloqueados_forma(form)` >0. Checks nuevos en autotest: menú cerrado → subir nivel lo abre → ofrece las 4 → confirmar cierra → desbloquea el combo (Remate) → cuenta 1.
- **(16/08) El menú LevelUp NO estaba instanciado en `main.tscn`** (solo pasaba el test porque el autotest lo pre-cargaba a mano) → en el juego real al subir de nivel no aparecía ningún menú. Se agregó `LevelUp` (instancia de `levelup.tscn`, `ext_resource` por `path` porque ese `.tscn` no declara `uid` en su header) a `main.tscn`.
  - **(16/08) Pausa al elegir combo — con flag para tests:** el usuario quería que el juego se pause en el menú de elección. `levelup.gd::abrir()` ahora hace `if pausar_al_abrir: get_tree().paused = true` y `cerrar()` lo quita. `process_mode = PROCESS_MODE_ALWAYS` (en `_ready`) para que el menú input/render siga activo con el árbol pausado. **Clave:** `@export var pausar_al_abrir := true` (default juego real). El autotest lo setea `false` al instanciar `main` (`.set("pausar_al_abrir", false)`) porque cada `add_fragmentos` que cruza nivel abre el menú y pausar el árbol congelaba todos los tests de combate (los `await process_frame` nunca avanzan con `paused`). Ojo: en un script `--script` (SceneTree) NO existe `self.get_tree()`; se usa `paused` directo (property del SceneTree).
- **(16/08) Parse error latente en `levelup.gd`:** `var op := _opciones[i]` / `=_opciones[_indice]` daban "Cannot infer the type of op" porque `_opciones` es un `Array` sin tipo (elementos Variant). Al recién pre-cargar `levelup.tscn` en el autotest el error salió a la luz. Fix: tipar `var op: Dictionary = _opciones[...]`. (Lección general: al acceder a elementos de un `Array` no tipado con `:=`, tipar la variable explícitamente.)
- **(16/08) En `--script` (extends SceneTree) `self.get_node()` no existe:** usar `root.get_node("Progresion")` (el helper `_progresion()` del autotest) o `get_node` no está en SceneTree. En nodos normales sí existe.
- **(16/08) Ataque melee como "línea" enfrente del personaje (BANDA VERTICAL uniforme, pegada al cuerpo):** en `player.gd::enable_melee` se ignora `size`/`range` de la forma (solo se usan `damage`/`knockback`) y se arma una banda vertical IDÉNTICA para light/heavy/special: `shape.size = Vector2(LINEA_ESPESOR=40, collision_shape.shape.size.y)` (longitud horizontal = constante, alto = cubre el collider del player). Se ancla justo al límite de la hitbox del player con `attack_area.position.x = facing*(coll.size.x*0.5 + LINEA_ESPESOR*0.5)` → cubre `[half_width, half_width+espesor]` desde el borde. Para humano (collider 48px) cubre `[24,64]`. Regla: los ataques de una forma solo difieren en daño, no en longitud.
- **(16/08) Test de daño melee con hitbox delgada/pegada: el objetivo debe reposar en el piso y quedar dentro del frente que cubre el ataque.** (a) Instanciar al enemigo en plena caída (offset vertical alto, pocos frames) → la hitbox delgada no lo alcanza; esperar a que player y enemigo reposen (`_wait_frames(40)`+`_wait_frames(30)`) antes de golpear. (b) La banda cubre `[half_collider, half_collider+espesor]`; los objetivos de prueba deben quedar dentro: dummy melee y del combo del humano a `40` (espesor 40, collider 48). No usar offset global en y (rompe objetivos a `y≈0`).
- **(16/08) Label de golpes del HUD — pila vertical estilo Ben 10 (macro):** `ComboLabel` (= fila 0) + `GOLPES_MAX=6` filas RichTextLabel clonadas por código, apiladas hacia ARRIBA cada `FILA_PASO=44` (ticos `anchor_left/right=1`, `anchor_top/bottom=1`, `offset_left=-560`, `offset_right=-160`; infer base `-80..-32`, fila i `-80-44i..`). Cada golpe muestra el TIPO sin "xN" (`LIGERO`/`FUERTE`/`ESPECIAL`, finishers con nombre) y se acumula en `_historial` (push_front, cap `GOLPES_MAX`). degradé `objetivo = clampf(1 - 0.16*i, 0.08, 1)` por índice (inferior sólido, superiores translúcidos), animado en 0.25s. `_idle_timer` (1.5s): si no se vuelve a golpear, la fila 0 se desliza a la IZQUIERDA (`position.x - 220`, CUBIC/IN, 0.6s) y luego `_limpiar_todo()` (vacía `_historial`, oculta filas, restaura `_combo_base_pos` de la fila 0 — el `position` de nodos anclados es calculado, guardarlo en `_ready`). Las filas superiores solo cambian `modulate.a`, nunca `position`.
