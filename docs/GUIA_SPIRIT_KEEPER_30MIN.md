# Guía Maestra — Spirit Keeper
### De prototipo jugable a experiencia redonda de 30 minutos

> **Para quién es:** equipo de 3, 2 meses, Godot 4.7. Todo explicado en criollo, sin jerga. Cada capítulo tiene *qué falta*, *por qué importa*, *3 variaciones* (fácil / equilibrada / pro) y *pasos concretos* para hacerlo hoy mismo. Al final hay checklist y roadmap.
>
> **Regla de oro del proyecto:** ante cada decisión, preguntarse *“¿cómo lo resolvía Ben 10: Alien Force?”* y adaptar solo lo que la ambientación obligue.

---

## Cómo leer esta guía

- **Si tenés 5 minutos:** lee solo el [Resumen visual](#0-resumen-visual) y el [Checklist final](#anexo-a-checklist-priorizado).
- **Si tenés 30 minutos:** lee los títulos y las tablas de *Variaciones*.
- **Si vas a picar código:** seguí los *Pasos concretos* de cada capítulo (archivos y líneas exactas).

---

## 0. Resumen visual — dónde estamos y a dónde vamos

### Estado actual (commit `53b5713`, rama `main`)

| Sistema | Estado | Detalle concreto |
|---|---|---|
| **Niveles** | 2 zonas jugables | Zona 1 (`main.tscn`, ~4390px, 3 rompibles, 1 arena con 3 enemigos, 1 tronco, 4 plataformas) = **4-6 min**. Zona 2 (`nivel_2.tscn`, ~11000px, 8 arenas, 27 enemigos, torre opcional, 1 tronco, 4 diálogos, santuario) = **8-12 min**. Total real **12-18 min** sin repetir. |
| **Formas** | 4 formas con stats únicos | Humano 520 / Lobo 560 + doble salto / Oso 160 / Murciélago 330 + planeo y proyectil. 1 combo por forma. Vida compartida 100, energía 8/s drena. |
| **Enemigos** | 3 tipos | Cultista 40hp melee 62 rango, Arquero 35hp proyectil 420, Chamán 90hp proyectil 480. Oleadas con `encounter.tscn` + `WaveOla` + paredes + ritual. |
| **Cámara** | Pulida | `camera.gd` con lookahead 0.28 (umbral 80), deadzone vertical 150 (subida 1.8 / bajada 7.0), suavizado 6, zoom punch, shake, tilt. Parallax 4 capas (`fondo_bosque.tscn` 0.02-0.40). Snap a píxel activo. |
| **UI/Flujo** | Loop cerrado | Main menu → Jugar → HUD (vida/energía/fragmentos/racha/combo) → Pausa → Controles → LevelUp → Victoria/Derrota → Santuario checkpoint. Diálogo amuleto con typewriter. Consola dev. |
| **Falta para 30 min** | ~12 min de contenido + sistemas de cierre | 1-2 zonas más (8+7 min), 1-2 jefes con fases, puzzles por forma, audio, guardado, tutorial completo. |

### Meta 30 minutos — estructura de 5 zonas

```
Zona 1 Bosque Exterior (tutorial)  6 min  | Humano + Lobo enseñado
Zona 2 Quebrada (ya hecha)          10 min | Lobo + Oso enseñado, 8 arenas
Zona 3 Aldea Corrompida             6 min  | Oso + Murciélago enseñado
Zona 4 Templo Interior              7 min  | Síntesis de las 3 formas + puzzles
Zona 5 Altar Final (boss)           4 min  | Jefe secta 3 fases + rescate
                                    ─────
                                    33 min brutos → 28-30 netos (muertes/reintentos)
```

**Curva de dificultad:** Tutorial (sin enemigos) → Fácil (1 tipo) → Media (2 tipos + 2ª ola) → Difícil (3 tipos + 3ª ola + jefe). Ritmo interno de cada zona: **Exploración → Combate → Plataforma → Descanso/Diálogo → Combate** (no dos combates seguidos sin respirar).

---

## 1. Pulido y sensación (JUICE) — lo que separa “anda” de “se siente bien”

**Qué es:** micro-feedback que tu cerebro registra sin darte cuenta. No añade mecánicas, hace que las que ya tenés se sientan ricas.

### 1.1 Lo que ya tenés (no tocar)
- Turn boost ×2.2, apex hang escalonado (35×0.45 / 70×0.7), coyote 0.12 / buffer 0.15, speed_scale + freeze <10px/s, lean por skew (1.5°-4.5°), lookahead progresivo, deadzone vertical asimétrica, hitstop, zoom punch 1.02, shake por tipo de golpe, polvo de pasos, squash de aterrizaje (Oso), flash de derrota, pixel snapping.

### 1.2 Lo que falta y vale mucho por poco esfuerzo

| # | Mejora | Qué hace en criollo | Esfuerzo | Pasos concretos |
|---|---|---|---|---|
| 1 | **Gravedad de caída ×1.18** | Subís flotando, caés con peso. El arco clásico. | Muy fácil (2 líneas) | En `player.gd` después de `g *= APEX...`, agregar `if velocity.y > 0: g *= 1.18` |
| 2 | **Salto escalado con velocidad** | Saltar corriendo rinde ~8% más. Premia el impulso. | Fácil | `try_jump()` usa `jump_velocity * (1 + 0.08 * clamp(velocity.x/speed,0,1))` |
| 3 | **Jump cut suavizado** | Soltar el botón no corta de golpe, decae. Menos “a tirones”. | Fácil | En vez de `velocity.y *= 0.5`, hacer `velocity.y *= lerpf(0.5,1, clamp(velocity.y/-200,0,1))` |
| 4 | **Stretch al despegar para todos** | Hoy solo el doble salto del Lobo estira. Generalizar a todo salto da punch. | Fácil | En `forma.gd try_jump()` agregar `player.stretch_y(0.18,0.2)` |
| 5 | **Anticipación (squash antes de saltar)** | Agacharse 2 frames antes de despegar. Cine. | Fácil | En `try_jump()` antes de asignar velocidad: `player.squash_y(0.12,0.08)` |
| 6 | **Polvo al despegar** | Ya hay polvo al aterrizar. Falta al saltar. | Muy fácil | `emitir_polvo(0.6)` en `try_jump()` |
| 7 | **Shake de aterrizaje para todos** | Hoy solo el Oso sacude. Generalizar por impacto. | Muy fácil | En `on_landing`: `if fall_impact > 600: cam.shake(lin(impact),0.12)` |
| 8 | **Lean ya hecho** | Cuerpo se inclina 1.5°-4.5° según velocidad (skew). | Hecho | `lean_angulo` en `forma.gd`, lerp en `_update_animacion()` |
| 9 | **Fast fall (↓ en aire)** | Apretar ↓ acelera la caída. Control total. | Muy fácil (8 líneas) | `if Input.is_action_pressed("move_down") and !is_on_floor(): g *= 1.7` |
| 10 | **Parallax ya hecho** | 4 capas 0.02-0.40, suelo a 1.0. | Hecho | `fondo_bosque.tscn` |

**Variaciones:**
- *Fácil:* solo 1+6+7 (3 líneas, se nota al toque).
- *Equilibrada (recomendada):* 1+2+4+6+7+9.
- *Pro:* todo + sonido por evento.

---

## 2. Movimiento y salto — que moverse sea un placer

### 2.1 Números actuales (referencia)

| Forma | Speed | Jump | Gravity | Jumps | Sensación |
|---|---|---|---|---|---|
| Humano | 520 | -465 | 1.0 | 1 | Base, ágil |
| Lobo | 560 | -500 | 0.9 | 2 | Más rápido, doble salto con zip 320 |
| Oso | 160 | -420 | 1.45 | 1 | Pesado, rompe |
| Murciélago | 330 | -560 | 0.8 | 1 | Alto, planeo |

Plataformas validadas: salto Humano ~130px alto, huecos ≤103px subible. Todo lo obligatorio es humano-alcanzable; bonus para Murciélago/Lobo.

### 2.2 Tres caminos para agilizar más (elegí uno)

**A) Sin nuevas mecánicas (pulir lo que hay):** las 10 de arriba + cámara vertical asimétrica (ya hecha: subida 1.8 / bajada 7.0). Es suficiente para 30 min. Riesgo cero con niveles actuales.

**B) Dash con doble-tap (recomendado si querés burst):** infraestructura `is_dashing()` ya existe pero ninguna forma la usa.
- Humano y Lobo: doble toque ←← o →→ → impulso 400px en 0.18s, cooldown 0.4s, invuln 0.1s.
- Oso: sin dash (identidad pesada).
- Código: detectar doble tap en `_physics_process` (ventana 0.18s), setear `_dash_timer` y `is_dashing()=true` en la forma, `velocity.x = facing * dash_speed`.

**C) Wall slide + wall jump (para plataformeo vertical):** solo Lobo (y Humano opcional).
- Detectar `is_on_wall() + input hacia la pared` → `velocity.y = min(velocity.y, 60)` (desliza lento) + polvo en pared.
- Saltar desde ahí → `velocity = Vector2(-facing*280, -460)` diagonal.
- Es la mecánica más “pro” pero pide testeo fino y un área de tutorial dedicada.

---

## 3. Combate — que cada forma importe

### 3.1 Balance actual

| Forma | Light | Heavy | Special | Knock | Rango |
|---|---|---|---|---|---|
| Humano | 10 | 18 | 22 | 150 | 78 / 102 |
| Lobo | 5 | 8 | 12 | 150 | 60 / 78 |
| Oso | 30 | 45 | 60 | 220 | 120 / 156 |
| Murciélago | 8 | 14 | 15 | 150 | 66 / 90 |

Enemigos: Cultista 40hp, Arquero 35hp (420 rango), Chamán 90hp (480, cura). Stun 0.15s, knock resist 0.3.

**Problema actual:** sin obligación de alternar, el jugador puede spamear una forma. La pregunta central *“¿qué forma es mejor acá?”* no se fuerza.

### 3.2 Cómo forzar la pregunta (sin frustrar)

**Variación fácil — resistencias por forma:**
- Cultista recibe +50% de Lobo (veloz lo acribilla), -30% de Oso (lento lo esquiva).
- Chamán solo vulnerable a Murciélago a distancia (disparo rompe escudo), o recibe 2× de Oso si se acerca.
- 3 líneas en `enemy.gd take_damage()`: `if attacker_form==LOB O and tipo=="cultista": cantidad*=1.5`

**Variación equilibrada (recomendada) — arquetipos que piden forma:**
- Horda de cultistas → Lobo (área veloz) brilla.
- Escudo del chamán → solo Oso lo rompe (heavy) o Murciélago a distancia.
- Arqueros en altura → Murciélago (planeo + disparo) o Lobo (doble salto).

**Variación pro — fases de oleada con requerimiento:**
- Ola 1: 2 cultistas (cualquiera).
- Ola 2: aparece chamán con escudo → HUD muestra “¡Usa al Oso!” vía `Dialogo.mostrar()`.

### 3.3 Feedback que falta
- **Blink de invulnerabilidad** al recibir daño (ya tenés `blocking`, falta `is_invulnerable` + timer 0.8s + `visual.visible = !visible` cada 0.08s).
- **Barra con delayed fill** (barra roja que baja lenta tras la verde) — se ve en `hud.gd` con un segundo `ProgressBar` que hace lerp.

---

## 4. Transformaciones y progresión — el corazón del juego

### 4.1 Cómo funciona hoy
- `Progresion` autoload: `fragmentos` (3 por nivel), `nivel` (1→4), `forma_desbloqueada = true` (temporal, todas desde inicio), `combos_desbloqueados` (1 por forma).
- Energía: 8/s drena transformado, 5/s regenera humano, +20 por kill, +30 pickup.

### 4.2 Tres visiones de progresión

**A) Gating por nivel (original, recomendado para 30 min):**
Volver a `form_index < nivel` (nivel2→Lobo, 3→Oso, 4→Murciélago). El `LevelUp` ya muestra bloqueadas grises y salta bloqueadas al navegar. Reactivar es 1 línea en `progresion.gd`.

**B) Gating por posición en mundo (más orgánico):**
Cada forma se gana al llegar a su altar en el nivel (ej. cueva del Lobo en Zona 1). Requiere colocar `santuario`-like que llame `Progresion.desbloquear_forma(idx)`. Más inmersivo, más trabajo de nivel.

**C) Todas desde inicio (actual):**
Libertad total, pero la pregunta central se diluye y el cartel “¡FORMA DESBLOQUEADO!” muere. Útil solo para testeo.

**Energía — ajustes para 30 min sin farm:**
- Si el jugador farmea rompibles (5 fragmentos en Zona 2), sube 2 niveles en una zona y rompe la curva. Capar a 3 fragmentos por zona o hacer que los rompibles de entrenamiento no den fragmentos (solo energía).
- Drenaje 8/s da 12.5s transformado. Para 30 min con 8 arenas, el jugador pasará ~40% del tiempo transformado → necesita ~6-7 pickups por zona (Zona 2 ya tiene 7, bien).

### 4.3 Controles (ya pulidos)
Cruceta directa (↑Murciélago →Lobo ←Oso ↓Humano), RT/E avanza preselección, LT retrocede, RB/T confirma (si ya estás en la seleccionada → vuelve Humano). W/S ya no seleccionan (evita accidentes). Todo en `project.godot` [input] + `player.gd`.

---

## 5. Enemigos y jefes — de 3 tipos a experiencia completa

### 5.1 Roster actual (bien diferenciado)
- **Cultista** (40hp, 75 speed): va al choque, rango 62.
- **Arquero** (35hp, 55 speed, 420 tiro): se queda y dispara.
- **Chamán** (90hp, 40 speed, 480 tiro, cura): prioridad.

### 5.2 Qué añadir para 30 min

| Nuevo | Rol | Mecánica simple | Dónde ponerlo |
|---|---|---|---|
| **Tanque poseído** | Esponja que avanza lento | 120hp, inmune a light, solo Oso heavy lo mueve | Zona 3, como mini-jefe de pasillo |
| **Acechador** | Flanquea | Corre fuera de rango y ataca por la espalda si estás quieto 2s | Zona 4, obliga a moverse |

**Jefe final — 3 fases obligatorias (la síntesis):**
- **Fase 1 (100%-66%):** escudo de raíces → solo **Oso** heavy lo rompe. Mientras, oleada de cultistas.
- **Fase 2 (66%-33%):** cristal en altura → solo **Murciélago** disparo sonico lo activa. Arqueros en plataformas.
- **Fase 3 (33%-0%):** arena con lava que sube → solo **Lobo** (velocidad + doble salto) esquiva y contraataca.
- Cada fase dura ~90s. Al morir → `Dialogo` + `victoria.tscn` con “¡Rescataste a tu hijo!”.

**Implementación mínima de jefe:** un `CharacterBody2D` con `fase: int`, `cambiar_fase()` al bajar hp, invulnerabilidad por forma (en `take_damage` checkea `player.current_form`), y spawnea `encounter` en cada fase.

---

## 6. Diseño de niveles — 30 minutos cronometrados

### 6.1 Principios (no negociables)
1. **Enseñar antes de exigir:** cada mecánica se presenta sola, luego con ayuda, luego sola bajo presión. Nunca pidas doble salto sin haberlo enseñado 2 pantallas antes.
2. **Ritmo 3:1:** por cada 3 minutos de acción, 1 de respiro (diálogo, exploración, pickup). Zona 2 ya lo hace (8 arenas separadas por plataformas).
3. **Todo lo obligatorio es Humano-alcanzable:** el salto máximo humano ~130px, huecos ≤103px. Bonus para formas.
4. **Sin pozos que maten por explorar:** el `limite_caida 3000` es red de seguridad, no castigo.

### 6.2 Mapa de 5 zonas (30 min)

```
[Zona 1 Bosque Exterior - 6 min]  Ya hecha (4390px)
Spawn → Rompible1 (enseña pegar) → Arena A 1 cultista → 2 plats → Arena B 2 cultistas
 → Rompible2 → Tronco (enseña Oso) → Torre 4 plats → Santuario

[Zona 2 Quebrada - 10 min]  Ya hecha (11000px, 8 arenas A-H)
Calentamiento (1 cultista) → Torre opcional con tesoro → Tronco → Arena C (chamán primero)
 → Meseta con Arena E en altura → Gauntlet F+G (5 enemigos) → Mini-jefe Hierofante → Santuario

[Zona 3 Aldea Corrompida - 6 min]  NUEVA
Intro con casas quemadas → Puzzle Lobo (rasgar enredaderas `interactable` con Oso? no, con Lobo) 
 → Arena con Tanque (enseña Oso pesado) → Cripta con planeo corto (enseña Murciélago)
 → Combo con arqueros en altura → Santuario

[Zona 4 Templo Interior - 7 min]  NUEVA
Entrada con sellos de forma (íconos `form_icon.gd`) → Puzzle mixto (raíces Lobo + roca Oso + cristal Murciélago)
 → Arena doble (6 enemigos, 2 olas) → Pasillo de lava con doble salto → Santuario antes del jefe

[Zona 5 Altar Final - 4 min]  NUEVA
Arena circular grande (scale 3.0, sin paredes que se cierren del todo) → Jefe 3 fases → Diálogo rescate → Victoria
```

**Métricas por zona:**
- Plataformas: escalones de 85-103px de subida, huecos <230px. Validar con query físico cada 250px (como `diag_zona2.gd`).
- Pickups: 6-7 por zona (sostiene 12s×7=84s de transformación total).
- Rompibles: exactamente 3 por zona que dan fragmentos (el resto son solo energía para no farmear nivel).
- Diálogos: 2-4 por zona, modo Zona (no Automático) para no pausar en medio de plataforma.

### 6.3 Cómo construir una zona nueva (paso a paso)
1. Duplicar `nivel_2.tscn` → `nivel_3.tscn`.
2. Borrar `Encounter*`, `Rompible*`, `Pickup*`, `Dialogo*`, `Tronco`, `Santuario`. Dejar `Ground*` y `Level` (suelos 3000x57 solapados 26px).
3. Mover `Ground` con `position.x += 2974` para extender.
4. Colocar `DialogoIntro` (Automatico, 0.6s) y plataformas con `Level/PA` etc. (ver §6.2).
5. Añadir `Encounter` nuevo: arrastrar `encounter.tscn`, estirar `Arena/ArenaShape` (scale), poner enemigos hijos con `tipo` y `ola_asignada` 0/1, `ArenaShape` scale deriva `arena_medio_ancho` automáticamente.
6. Validar: `godot --headless --script res://tests/diag_zona3.gd` (copiar de `diag_zona2.gd` y cambiar conteos).

---

## 7. Puzzles por forma — el diferencial que hoy falta

**Hoy solo Tronco/Oso.** Para que la pregunta central importe fuera de combate, necesitás 1 puzzle por forma mínimo.

| Forma | Puzzle | Objeto en escena | Cómo se resuelve | Símbolo en pared |
|---|---|---|---|---|
| **Lobo** | Enredaderas frágiles bloquean paso | `Area2D` con `Sprite` de enredadera + `CollisionShape2D` | Solo **Lobo** light ataca (range 60) las corta (3 golpes) | Garra |
| **Oso** | Roca pesada tapa interruptor | `RigidBody2D` 200kg con `Sprite` roca | Solo **Oso** puede empujar (en `player.gd` si `current_form==OSO` y `is_on_wall` + input, aplica fuerza) o romper con special | Pata |
| **Murciélago** | Abismo largo + cristal sónico | `Area2D` cristal + `StaticBody` abismo | Solo **Murciélago** planea el abismo y dispara cristal (`projectile.tscn` con `enemy_shot=false` que colisiona con cristal) | Ala |

**Implementación base (reusa `interactable.gd`):**
```gdscript
# enredadera.gd
@export var required_form := 1 # Lobo
@export var golpes_para_romper := 3
func recibir_golpe(forma): if forma==required_form: golpes-=1; if golpes<=0: queue_free()
```

**Tutorial de puzzle (3 pantallas):**
1. Ves el obstáculo y el símbolo, no podés pasarlo (frustración guiada).
2. A 2 pantallas, el amuleto dice “El Lobo rasga lo frágil” + te dan la forma.
3. Volvés y lo usás (satisfacción).

---

## 8. Narrativa y tutorial — que el amuleto guíe sin aburrir

**Narrativa actual:** padre busca hijo secuestrado por secta, collar de espíritus presta 3 formas. Diálogos en `dialog_trigger.tscn` (Intro auto + Tronco zona). Bien, pero incompleta.

**Tutorial que falta:**
- Zona 1: Lobo (doble salto) → poner `DialogoTrigger` en la torre con “El Lobo salta dos veces”.
- Zona 2: Murciélago (planeo) → trigger antes del abismo.
- Zona 3: Oso (empujar) → trigger antes de la roca.

**Regla:** cada vez que `Progresion.nivel_subio` o `combo_desbloqueado`, el `Dialogo.mostrar()` explica el combo nuevo con una línea del amuleto. Ya existe `hud.gd` con cola de avisos; enganchar ahí.

**No hacer:** tutorial con texto largo que pausa el juego 10s. Hacer: 1 línea, 1 mecánica, al lado del obstáculo.

---

## 9. Audio-visual — de placeholder vectorial a bosque creíble

**Audio (hoy 0 archivos):**
- Prioridad 1: `jump.ogg`, `hit_light.ogg`, `hit_heavy.ogg`, `projectile.ogg`, `ritual.ogg`, `pickup.ogg`, `santuario.ogg`, `victoria.ogg`, `derrota.ogg`.
- Prioridad 2: loops `bosque_noche.ogg` (viento + hojas), `templo.ogg`, `boss.ogg`.
- Implementación: un `AudioManager` autoload con `play_sfx(nombre)` que instancia `AudioStreamPlayer` (pool de 8), y `play_music(nombre, fade=1.0)`.

**Visual:**
- Parallax ya hecho (4 capas 0.02-0.40). El bloque verde 5par queda como suelo parallax opcional.
- Falta: VFX de transformación (flash + burst ya existe en `burst.tscn`, pulirlo con `self_modulate` por forma), estela al correr rápido (Line2D con `queue_free` en 0.3s), y paleta templo (reusar `form_icon.gd` con colores por zona).

---

## 10. UI/UX y meta-sistemas

**HUD ya sólido:** barras, fragmentos, racha, combo history, avisos, flash daño, sel label (◈ actual, [] preseleccionada). No tocar.

**Falta para 30 min jugable por evaluador sin instrucciones:**

| Sistema | Cómo | Archivo |
|---|---|---|
| **Guardado** | `ConfigFile` en `user://save.cfg`: `set_value("progreso","nivel",Progresion.nivel)`, `fragmentos`, `combos`. Cargar en `Progresion._ready()`. Botón Continuar en `main_menu.tscn`. | `scripts/save_manager.gd` |
| **Opciones** | Volumen master/SFX/música con `AudioServer.set_bus_volume_db`. | `scenes/options.tscn` |
| **Créditos** | Quién hizo qué, referencia Ben 10 solo mecánicas. | `scenes/credits.tscn` |
| **Accesibilidad** | Textos ≥22px (ya), contraste, opción “mantener para bloquear” vs toggle. | `project.godot` |
| **Build** | Exportar `SpiritKeeper.exe` 1920×1080, `snap/snap_2d_transforms_to_pixel=true` ya puesto. | `Export` |

---

## 11. Cierre de experiencia — cómo dejar sensación de juego redondo

1. **Últimos 60 segundos:** el jefe muere → `Dialogo` “¡Lo encontraste!” → fundido a blanco (ColorRect con tween) → `victoria.tscn` con “¡Bosque liberado!” + stats (tiempo, muertes, formas usadas).
2. **Recompensa:** mostrar qué combos se desbloquearon y dejar volver a jugar zonas con formas nuevas (New Game+ simple: `Progresion.reset()` no borra `user://save.cfg`).
3. **Trailer de 30s:** grabar Zona 2 G+H con el parallax (ya queda vistoso) + transformación Lobo→Oso con hitstop.

**Sensación clave:** el jugador debe terminar pensando *“cada pelea me hizo cambiar de forma por algo distinto”*, no *“spameé al Oso”*. Si testeás y un evaluador usa 80% una forma, el balance falló (ver §3.2).

---

## Anexo A — Checklist priorizado (pegá en tu tablero)

**Must (para 30 min jugable):**
- [ ] Zona 3 (6 min) con Tanque + puzzle Lobo
- [ ] Zona 4 (7 min) con puzzle mixto
- [ ] Jefe final 3 fases (scripts/boss.gd)
- [ ] Audio SFX 9 + música 3
- [ ] Guardado + Continuar
- [ ] Reactivar `forma_desbloqueada = form_index < nivel`

**Should (pulido que se nota):**
- [ ] Gravedad caída 1.18 + polvo al saltar
- [ ] Blink invulnerable + delayed bar
- [ ] 2 puzzles por forma (total 6)
- [ ] Tutorial por forma con DialogTrigger

**Nice (si sobra tiempo):**
- [ ] Dash doble-tap
- [ ] Wall jump Lobo
- [ ] Estela al correr
- [ ] Créditos + opciones volumen

---

## Anexo B — Roadmap de 2 meses (equipo de 3)

| Semana | Foco | Entregable testeable |
|---|---|---|
| 1-2 | Zonas 3 y 4 (gris) + puzzles Lobo/Oso | Nivel 3 jugable sin arte final |
| 3 | Jefe final + balance | Boss 3 fases peleable |
| 4 | Audio + guardado + tutorial | Build con sonido y Continuar |
| 5-6 | Arte templo + VFX + trailer | Build final 30 min |
| 7 | Playtest externo (3 evaluadores cronometrados) | Ajustes de curva |
| 8 | Export + pitch + GDD | Entrega |

---

## Anexo C — Plantilla de testeo de 30 min

Corre con cronómetro, sin consola:
1. Nuevo juego → Zona 1 → ¿cuánto tardás? (meta 6 min)
2. Zona 2 → ¿cuántas muertes? (meta 2-4)
3. Zona 3+4 → ¿usaste las 3 formas al menos 3 veces cada una?
4. Jefe → ¿entendiste sin leer instrucciones que Oso rompe escudo y Murciélago dispara cristal?

Si alguna respuesta es “no”, ajustá ese capítulo.

---

*Fin de la guía. Todo lo de arriba cabe en el scope actual: ningún sistema nuevo rompe lo que ya anda (`FALLOS=6` en autotest con `forma_desbloqueada true`), todo es `@export` y `.tscn` editable, y cada zona nueva reutiliza `encounter.tscn` + `interactable.gd` + `fondo_bosque.tscn` ya probados.*
