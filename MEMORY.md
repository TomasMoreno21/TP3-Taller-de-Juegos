# MEMORY.md — Proyecto (sin nombre aún): Guardabosques / Espíritus del Bosque

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
- **Decisión (09/08):** transformación **ilimitada**, fiel a la mecánica del original. El riesgo temático de "posesión/abuso de la forma" queda solo como lore, NO como gauge de recurso.
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
5. **Tiempo limitado — DESCARTADO (09/08):** la transformación es **ilimitada**, fiel al original; el riesgo de posesión queda como lore.

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
└── gate.tscn          # Portón visible que bloquea durante el encuentro
scripts/
├── player.gd          # Node que delega en la forma activa (OOP)
├── enemy.gd           # 100 HP. configure() + signal died + IA. Feedback de golpe según forma del player (tinte rojo + rotación + shake + zoom)
├── camera.gd          # Camera2D que sigue al player (smoothing) + shake() por offset aleatorio
├── projectile.gd
├── console.gd         # Diccionario central COMMANDS (fuente única panel+help)
├── hud.gd             # Label top-left: forma activa (señal form_changed) + controles
├── encounter.gd       # Olas de enemigos + portón + contador (INACTIVE/RUNNING/COMPLETED)
├── spawn_point.gd     # Círculo ritual (telegrafiado ~0.7s) + spawn con fade-in
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
- **Nivel (`main.tscn`):** suelo extendido (2560px, cubre x -380..2180), **7 plataformas de 200px dispersas con alturas variadas** (y 300→470, 560→360, 820→260, 1080→400, 1350→310, 1580→470, 1780→380). 2 enemigos sueltos (650,540 y 950,540) antes del Tronco. `Encounter` en (1480,540) con **3 olas más numerosas**: ola1 = 3 cultistas, ola2 = arquero + 3 cultistas, ola3 = chamán + arquero + 2 cultistas. Cámara: `limit_right = 2200`.
- **HUD:** controles actualizados + línea `COMBO LIGERO/FUERTE/ESPECIAL xN` (señal `attack_performed(type, step)`) abajo-izquierda.
- **Autotest: 13 → 31 checks PASS** (combo light escala 10→25, heavy, special, block 25%, jump attack, lobo dash, búho proyectil, feedback visible, interact humano no/oso sí, métodos de la base).

### Consola dev — comandos
`help`, `form <humano|oso|lobo|buho>`, `god`, `hp <n>`, `heal`, `spawn_enemy`, `kill_enemies`, `spawn_wave`, `speed <mult>`, `gravity <val>`, `tp <x> <y>`, `pos`, `hitbox`, `clear`, `quit`

### Pendiente para validar en Godot (probarlo a mano)
- [ ] Sensación real de cada forma (velocidad/salto/peso) — los números son placeholders iniciales
- [ ] El enemigo dummy no ataca (queda como TODO)
- [ ] Rebalancear stats según feedback del grupo

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
- [ ] Definir si habrá barra de tiempo limitado para transformaciones
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
