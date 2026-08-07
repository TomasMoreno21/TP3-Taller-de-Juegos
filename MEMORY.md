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
5. **Tiempo limitado (OPCIONAL, sin decidir)** — barra de energía que obligue a administrar las transformaciones.

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
├── enemy.gd           # 500 HP. configure() + signal died + IA. Feedback de golpe según forma del player (tinte rojo + rotación + shake + zoom)
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
- **Olas (`encounter.gd`):** `waves: Array` de listas `{type, offset, delay, edge}`. Cada ola empieza cuando la anterior está muerta. Tipos: cultista (40hp), arquero (30hp), chamán (60hp). `edge: true` = aparece caminando desde fuera de pantalla.
- **Contador:** `_alive` sube en `enemy_spawned` y baja en `signal died`. A 0 → siguiente ola; sin olas → `COMPLETED` + portón abierto.
- **Enemigo (`enemy.gd`):** `configure(hp, color, name)`, `signal died`, IA de aproximación al player (speed 60, stop_distance 70; edge walk-in 120). **500 HP.** Al recibir golpe lee la forma activa del player (`player.forms[current_form]`) y aplica su feedback: tinte rojo + rotación + shake + (opcional) zoom.
- **Feedback por forma (atributos en `Forma`):** `shake_strength`, `shake_duration`, `hit_rotation` (grados), `hit_zoom` (1 = sin zoom). Humano 5/7° · Oso 14/14° · Lobo 4 + zoom 1.06 · Búho 8/14° (defaults).
- **Cámara (`camera.gd`):** Camera2D hija del Player (sigue con smoothing), límites 0..2000 x / -800..640 y. `shake(strength=8, duration=0.15)` con offset aleatorio que decae (el `length` puede llegar a ~√2× la fuerza por los 2 ejes). `zoom_punch(strength)` con tween que vuelve a `_base_zoom`.
- **Debug:** comando `spawn_wave` en consola activa el encuentro a mano.

### Controles del prototipo
- `← →` / `A D`: mover · `Espacio`: saltar · `J`: atacar · `T`: transformar · `` ` ``: consola

### Consola dev — comandos
`help`, `form <humano|oso|lobo|buho>`, `god`, `hp <n>`, `heal`, `spawn_enemy`, `kill_enemies`, `spawn_wave`, `speed <mult>`, `gravity <val>`, `tp <x> <y>`, `pos`, `hitbox`, `clear`, `quit`

### Pendiente para validar en Godot (probarlo a mano)
- [ ] Sensación real de cada forma (velocidad/salto/peso) — los números son placeholders iniciales
- [ ] El enemigo dummy no ataca (queda como TODO)
- [ ] Rebalancear stats según feedback del grupo

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
