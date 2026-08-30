# Documento de Concepto — Puzzles y Plataformeo (Spirit Keeper)

> **Estado:** DOCUMENTO DE CONCEPTO (temporal, solo referencia). No es guía de implementación. Los temas acá planteados se tocarán más adelante. Fecha: 16/08.

---

## 1. Contexto narrativo

Cada transformación se concibe como **despertar / aliar a un espíritu guardián del bosque**. La progresión los entregó de a uno según la historia.

- **El bosque enseña**: las primeras zonas actúan como "prueba del guardián" donde el jugador aprende cada habilidad.
- **La guarida de la secta aplica**: los poderes aprendidos se usan para abrir los **sellos corruptos** que la secta dejó en su templo.

Total: el desbloqueo avanza linealmente de "aprender en el bosque" a "usar contra la secta".

---

## 2. Principios de referencia (Ben 10: Alien Force)

1. Cada forma/alien se desbloquea **uno a uno** según la historia (progresión lineal).
2. **Enseñar antes de exigir**: al conseguir una forma nueva hay un espacio seguro donde se muestra su habilidad y luego se exige.
3. **Transformarte es la solución**: a veces el camino se abre transformándose en la forma correcta, no golpeando.
4. **Transformación con límite de tiempo** (base ya implementada: `transform_duration` + señal `transformacion_agotada` → vuelve a Humano).
5. **Humano = base débil + recolección de energía** (fragmentos/pickups) para volver a transformarse.
6. **Variedad de ritmo**: alternar combate ↔ plataformeo ↔ resolucion de puzzles para que ninguna actividad se empaste.

---

## 3. Modelo de aprendizaje por forma (3 fases)

| Fase | Qué es | Exigencia | Tiempo de transformación |
|---|---|---|---|
| 1. Descubrimiento | La narrativa otorga el espíritu guardián | — | — |
| 2. Tutoría natural | Zona acotada de plataformeo/puzzle donde la habilidad se usa 1-2 veces | Baja (solo aprender) | **Sin límite** (para no frustrar) |
| 3. Aplicación / reto ligero | Obstáculo clave que exige la forma para abrir camino (gating) | Media (reto adicional) | **Con límite en tramos largos**: si se agota, vuelve a Humano y hay que recargar y reintentar |

El reto adicional del punto 3 es doble: dominar la habilidad nueva **y** gestionar el tiempo de transformación mientras se supera el tramo.

---

## 4. Indicación visual requerida (forma necesaria)

Cada sello/puerta muestra el **símbolo / ícono de la forma requerida** encima (decisión tomada, estilo "cristales" del original). Hace el puzzle legible sin frustrar.

---

## 5. Mapa de aplicación por entorno

### Bosque (aprender)
| Forma | Tutoría (F2) | Reto de aplicación (F3) |
|---|---|---|
| Humano | Leer el terreno: troncos/ramas one-way, saltos justos | Desviar un tronco o reorientar la luz para abrir el sendero (naturaleza por encima de golpear) |
| Lobo | Saltos dobles por cornisas y rocas altas | Raíces/salientes escalonados donde el doble salto es el único paso, manteniendo la forma 2 tramos |
| Murciélago | Plantear por un barranco + eco que enciende cristales | Abismo largo a cruzar planeando y activar un cristal a distancia (gastando la forma hasta llegar) |
| Oso | Derribar un tronco/roca pequeño | Roca enorme que bloquea la guarida: derribarla en Oso (reto de fuerza al final del bosque) |

### Guarida de la secta (aplicar)
- **Lobo** — pasadizos verticales del templo y trampas de espinas (doble salto preciso).
- **Murciélago** — la oscuridad: la ecolocación enciende sellos/antorchas a distancia y se planea por abismos de la cámara ceremonial.
- **Oso** — romper los sellos/ídolos que contienen a los espíritus y descorrer portones de piedra.
- **Humano** — leer el ritual (orden correcto de tótems/símbolos según las pistas del bosque) para desactivar una protección mágica antes de continuar.

**Corazón de los sellos:** "resolver con la forma correcta + gestionar el tiempo de transformación". Los puzzles funcionan como maestro de bloqueo del poder nuevo y dan variedad frente al combate.

---

## 6. Notas de progresión futura

- `forma_desbloqueada()` hoy devuelve **siempre `true`** (todas disponibles, solo para pruebas). Cuando se integre el desbloqueo progresivo, deberá volver a `form_index < nivel` (o el esquema que definas) para que el gateo por transformación tenga sentido.

---

## 7. Recursos a reutilizar cuando llegue el momento

- `scripts/interactable.gd` — patrón `required_form` + `interact_range` + `try_interact` (puertas/rocas).
- `scripts/rompible.gd` — base de golpes/`registrar_golpe`/`_romper` (base para la roca del Oso).
- `scripts/projectile.gd` — flag `sonico` para el proyectil del Murciélago (activar interruptores a distancia).
- `player.gd::fire_projectile()` — disparo del Murciélago.
- `transform_duration` / `transformacion_agotada` — límite de tiempo con retorno a Humano.
- Nodo `Arena` + cerco del Encounter (Plan B) — para acotar tutoriales/retos si hacen falta.
- `forma.gd` — `jumps` (doble salto del Lobo), `is_gliding()` (planeo del Murciélago).
