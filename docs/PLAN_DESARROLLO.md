# Plan de desarrollo — Spirit Keeper (10/10 → 19/10)

Base: timeline del equipo (10/10, 13/10, 16/10, 19/10) + estado real verificado el 10/10.
Leyenda de responsable: **[C]** lo hago yo (Claude) · **[J]** en conjunto (yo implemento, vos decidís/probás) · **[U]** vos o el equipo (arte, música, decisiones, pruebas a mano).

## 0. Punto de partida (verificado 10/10)

| Área | Estado |
|---|---|
| Autotest, `diag_nivel2`, `diag_jefe`, `diag_comic`, `diag_interfaz`, `diag_hud`, `diag_checkpoints_niveles`, `diag_derrota` | 0 fallos |
| `diag_nivel3` | **5 fallos** (checkpoints/pickups/enemigos mal apoyados: 4; decoración flotando: 2; muros que no cierran el pasillo: 3; compuertas con sus losas; barreras con cristales: 6) |
| `diag_nivel3_oso` | **1 fallo** (el pisotón del Oso no abre la compuerta; el jugador de test vuelve al spawn) |
| Errores del motor | `legacy_docks` (import) y `current_scene is null` (autotest): del motor, no bloquean |
| Intros | N1, N2, N3 hechas (in-game, globos Humano–Amuleto) + título de nivel (acortado) |
| Cómic de inicio | existe versión vectorial de reemplazo (`comic_intro.tscn`, 6 viñetas, `textura` opcional para el arte final del artista) |
| Jefe | prototipo jugable; cine de aparición y de estallido hechos **sin probar con ventana**; falta visual, hijo y gameplay completo |
| Git | todo commiteado el 09/10 (`5310a72`); desde entonces: cine del jefe, arreglo de `matar_por_caida`, título de nivel — **sin commit** |
| Sesión paralela activa | "Balance de daños, vidas y energía": toca valores de balance; coordinar antes de tocar `player.gd`/`enemy.gd`/`boss.gd` |

Estructura del juego: **3 niveles + nivel del jefe** (N1 Humano+Lobo, N2 Murciélago, N3 Oso, jefe). No hay nivel 4/5 de juego.

---

## 1. Reglas de trabajo para todo el plan

1. **Verificación:** `powershell -File tests/verificar.ps1 [-Diag ...]` después de cada cambio de código/escena. Reportar el resultado.
2. **Commit diario** (cuando lo pidas): uno por jornada, mensaje descriptivo; tag `v0.x` en cada hito (10/10, 13/10, 16/10, 19/10).
3. **Un solo dueño por escena:** `nivel2.tscn` y `nivel3.tscn` los tocaron varias sesiones. Si abrís el editor, avisame; recargar antes de guardar. **No regenerar nivel 3 por script** si lo editás a mano.
4. **Nada de pulido de mecánicas del jefe** hasta tener su visual (decisión tuya del 09/10).
5. **Todo valor editable** va como `@export`/escena (regla de edición del proyecto).
6. **Buffer:** el 18/10 queda libre para imprevistos; el 19/10 es solo revisión.

---

## 2. Hito 10/10 — Cinemáticas + Nivel 2

### 2.1 Cinemáticas
| # | Tarea | Resp. | Detalle |
|---|---|---|---|
| C1 | Probar el cine del jefe con ventana (aparición + estallido) | **[U]** | Jugar `nivel_jefe`; anotar si la tensión (2,2 s), la subida (2,6 s) y el rugido se sienten bien. Los tiempos son `@export` |
| C2 | Ajustar tiempos/intensidad según tu feedback | **[J]** | Cambios chicos, sin tocar arte |
| C3 | Revisar las intros de N1, N2, N3: duración, globos, destello, que el título no pise la intro | **[C]** | Con `diag_intro_nivel*` + captura; informo qué cambié |
| C4 | Confirmar que el título de nivel nuevo (5,9 s) se ve bien en los 3 niveles | **[U]** | Si queda corto/largo, ajusto los 4 `@export` |
| C5 | Guion del final (hijo + padre) | **[J]** | Yo propongo 3 variantes de globos; vos elegís. Depende de que confirmes la historia (el hijo está atrapado detrás del sello) |
| C6 | Cierre del juego tras vencer al jefe: pantalla `victoria_jefe` con corte a negro y frase final | **[C]** | Reusa `victoria_jefe.tscn`; solo texto/corte hasta que haya sprite del hijo |

### 2.2 Nivel 2
| # | Tarea | Resp. |
|---|---|---|
| N2-1 | Jugarlo de punta a punta; lista de lo que se siente mal (ritmo, dificultad, cámara, secciones largas) | **[U]** |
| N2-2 | Aplicar la lista (terreno, enemigos, pickups, checkpoints) | **[C]** |
| N2-3 | Revisión de checkpoints: uno antes del derrumbe y otro antes de la salida | **[J]** |
| N2-4 | `diag_nivel2` + `diag_checkpoints_niveles` en 0 después de cada ajuste | **[C]** |
| N2-5 | Elementos del entorno del nivel 2 (13/10): lista de piezas faltantes (props, luces, partículas); lo existente ya cubre decoración apoyada, cristales y ambiente | **[J]** |

**Criterio de cierre 10/10:** intros revisadas, nivel 2 jugado sin bloqueos, 0 fallos en sus diag, commit + tag.

---

## 3. Hito 13/10 — Jefe definido, Nivel 3, Nivel 1, Diseños finales

### 3.1 Nivel 3 (prioridad máxima: es lo que más pesa)
| # | Tarea | Resp. | Detalle |
|---|---|---|---|
| N3-1 | **Decidir si los diag de N3 están viejos o la escena está mal.** `nivel3.tscn` se editó a mano; los tests leen `tests/nivel3_datos.json` | **[J]** | Yo comparo test vs escena y te muestro cada discrepancia; vos decidís si se corrige la escena o el dato del test |
| N3-2 | Corregir los 4 elementos mal apoyados (checkpoints/pickups/enemigos) | **[C]** | |
| N3-3 | Apoyar decoraciones D18 y D42 | **[C]** | 56–61 px de diferencia |
| N3-4 | 3 muros que no cierran el pasillo de piso a techo | **[J]** | Pueden ser intencionales (pasajes); confirmar cuáles |
| N3-5 | Compuertas con sus losas + 6 cristales/barreras mal apoyados | **[C]** | |
| N3-6 | `diag_nivel3_oso`: el pisotón del Oso no abre la compuerta (el test manda al jugador al spawn en vez de la losa) | **[C]** | Investigar: ¿límite del mapa/respawn?, ¿el jugador de test cae por un cambio sin commitear? Confirmar jugando que en juego sí abre |
| N3-7 | Jugar N3 completo con Oso: ritmo, puzzles de compuerta, dificultad, checkpoints | **[U]** | |
| N3-8 | Aplicar ajustes de N3-7 | **[C]** | |
| N3-9 | Cinemática de intro N3 en ventana (10,3 s; Oso mencionado como «fuerza bruta») | **[U]** | |

### 3.2 Nivel 1 (revisión)
| # | Tarea | Resp. |
|---|---|---|
| N1-1 | Revisión de diseño: tutorial de Humano+Lobo, ritmo, primeras muertes, checkpoints, curva de dificultad | **[J]** (vos jugás, yo ajusto) |
| N1-2 | Tutorial/tips: que enseñen parry, transformación y energía sin saturar | **[J]** |
| N1-3 | Medir FPS en ventana (hoy sólo se midió carga headless) | **[C]** |

### 3.3 Jefe — diseño en papel (sin pulir código)
| # | Tarea | Resp. |
|---|---|---|
| J-1 | Documento de la batalla: 3 fases, ataques por fase, qué forma sirve en cada barrera (legión/cristales/zona), duración objetivo (3–5 min), respiros | **[J]** (yo redacto la propuesta desde lo que ya hay; vos corregís) |
| J-2 | Lista de necesidades de arte del jefe (sprite, fases, ataques, hijo) para pasarle al artista | **[C]** redacta · **[U]** entrega |
| J-3 | Sala del boss: dimensiones, plataformas, cobertura, dónde emerge el jefe | **[J]** |

### 3.4 Diseños finales / animaciones
| # | Tarea | Resp. |
|---|---|---|
| A-1 | Animaciones D: salida de ataque del Humano (idle de 1 frame, run en frame 0) y piso de velocidad de piernas 0.35 | **[C]** |
| A-2 | Animaciones E: reacción al daño en pleno ataque sin pisar la animación del golpe | **[C]** |
| A-3 | Arte final de personaje + transformaciones (Oso/Murciélago sin anim de ataque) | **[U]** |
| A-4 | Arte final de enemigos (arquero y chamán con 1 frame) | **[U]** |
| A-5 | Integrar los sprites finales apenas lleguen: `SpriteFrames`, escala, offset, anclar pies | **[C]** (≈ medio día por tanda) |

**Criterio de cierre 13/10:** `diag_nivel3` y `diag_nivel3_oso` en 0, N3 jugable sin bloqueos, documento de jefe aprobado, N1 revisado, commit + tag.

---

## 4. Hito 16/10 — Jefe terminado, Menús, HUD, Cómic

### 4.1 Jefe
| # | Tarea | Resp. |
|---|---|---|
| J-4 | Integrar visual del jefe (3 fases con color/forma) en `jefe.tscn`; que `activar()` use el nuevo sprite | **[C]** |
| J-5 | Cerrar gameplay completo: ajustar `umbral_garra`, `mult_garra`, intervalos, spawn de legión, orbes, onda, barrido | **[J]** (sesiones de juego de 15 min: tú jugás, yo ajusto valores) |
| J-6 | Escena del hijo: aparecer desde adentro del jefe al estallar y padre (Humano) conteniéndolo | **[C]** con sprite del artista · **[U]** arte |
| J-7 | Probar derrota/reintento en el jefe: reaparición, `preparar_ola`, que no queden cinemáticas colgadas | **[C]** |
| J-8 | Test automático del cine de aparición con ventana (`tests/medir_*.gd`) | **[C]** |
| J-9 | Checkpoint pre-jefe verificado (`CheckpointPreJefe`) | **[C]** |

### 4.2 Menús y HUD
| # | Tarea | Resp. |
|---|---|---|
| M-1 | Revisar menú principal, pausa, controles, derrota, victoria, victoria del jefe contra el estilo final del juego | **[J]** |
| M-2 | Pantalla de opciones mínima (volumen música/efectos, pantalla completa) si no existe | **[J]** (propongo → confirmás) |
| M-3 | Pantalla de créditos | **[J]** |
| M-4 | HUD: revisar vida/energía/formas con el balance nuevo; legibilidad a 1920×1080 y a 1280×720 | **[C]** |
| M-5 | Diseño visual final de menús (si el artista lo entrega) | **[U]** arte · **[C]** integra |
| M-6 | `diag_interfaz`, `diag_hud` en 0 tras cada cambio | **[C]** |

### 4.3 Cómic de inicio
| # | Tarea | Resp. |
|---|---|---|
| CO-1 | El artista entrega las viñetas (imágenes) | **[U]** |
| CO-2 | Integrar: asignar `textura` en cada viñeta (nodo ya editable), reajustar tamaños/posiciones/texto, tiempos de revelado | **[C]** |
| CO-3 | Si el arte no llega para el 16/10: dejar la versión vectorial B/N actual como definitiva | **[J]** decisión |
| CO-4 | `diag_comic` en 0 + precarga de nivel1 sin tirones | **[C]** |

**Criterio de cierre 16/10:** jefe con visual y gameplay completo (aunque falte pulido), menús finales integrados, cómic integrado (arte final o versión vectorial), commit + tag.

---

## 5. Hito 19/10 — Sala del boss, pulido y revisión general

| # | Tarea | Resp. |
|---|---|---|
| F-1 | Sala del boss terminada (decoración, luz, partículas, cámara, límites) | **[J]** |
| F-2 | Pasada completa de punta a punta: cómic → N1 → N2 → N3 → jefe → créditos, con el jugador muriendo, pausando y reintentando en cada tramo | **[U]** juega · **[C]** corrige |
| F-3 | Revisión de audio: música/FX del compañero integrados, volúmenes, silencios en cinemáticas | **[U]** entrega · **[C]** integra |
| F-4 | Pase final de texto en español (ortografía, tono, consistencia de nombres: Amuleto, Arzobispo) | **[C]** |
| F-5 | Build exportado (Windows) probado en otra PC | **[J]** |
| F-6 | Limpieza del repo: tests obsoletos, `nivel1oficial`/`main` duplicados, `.uid` huérfanos | **[C]** (con tu OK) |
| F-7 | MEMORY.md ordenado (resumen de cierre + lecciones) | **[C]** |
| F-8 | Commit final + tag `v1.0` + push | **[C]** (cuando lo pidas) |

---

## 6. Mejoras, optimización y bugs (se hacen en paralelo, sin romper los hitos)

### 6.1 Optimización
| # | Tarea | Resp. | Prioridad |
|---|---|---|---|
| O-1 | Medir FPS reales con ventana en N1, N2, N3 y jefe (hoy no hay datos) | **[C]** | Alta, primero |
| O-2 | Primer frame de N1 tarda 2–12 s por ~12 texturas de fondo de 4000–6000 px sin compresión VRAM. Importar `Sprites/Fondos/Bosque/*.png` con VRAM Compressed | **[J]** (pide tu OK: puede variar el color) | Alta |
| O-3 | Optimizar decoración (949 nodos) y primer plano (727 nodos) de N1 con el mismo método que los pinchos (dibujo por lotes) | **[C]** | Media; validar con captura |
| O-4 | Aplicar la misma auditoría de nodos a N2, N3 y jefe (contar nodos por tipo) | **[C]** | Media |
| O-5 | Cuidar picos: partículas del estallido (90) y cinemáticas en equipos flojos; opción de reducir efectos | **[C]** | Baja |
| O-6 | `JuiceFx.precalentar` revisado: que todos los shaders nuevos (daño, parry, jefe) se precalienten | **[C]** | Media |

### 6.2 Bugs conocidos
| # | Bug | Resp. |
|---|---|---|
| B-1 | `diag_nivel3_oso` (ver N3-6) | **[C]** |
| B-2 | Oso en rampas de peldaños < 8 px de ancho (límite conocido) | **[J]**: ¿se corrige el terreno o la física? |
| B-3 | `muro_lobo.gd`: `test_move` roto hace que el asistente suba siempre | **[J]**: decisión consciente de no tocar; reevaluar |
| B-4 | `nivel2`/`jefe` sin checkpoint en alguna zona (revisar con `diag_checkpoints_niveles`) | **[C]** |
| B-5 | Mensajes `legacy_docks` / `current_scene is null`: confirmar que son sólo del motor | **[C]** |
| B-6 | Revisar que el cine del jefe no deje al jugador bloqueado si se reinicia (`cinematica_activa`) | **[C]** (ya cubierto en `_cine_emerger`; falta probar con ventana) |
| B-7 | Ronda general de bugs en ventana (jugador, enemigos, UI, escenas) con `diag_bugs` ampliado | **[C]** |

### 6.3 Mejoras opcionales (sólo si sobra tiempo; todas piden OK tuyo)
- Juice pendiente: zoom de remate (2), cámara por forma (5), rango de estilo (9).
- Música reactiva por fase del jefe.
- Pantalla de "puntaje/resumen" tras el jefe.
- Accesibilidad: remapeo de controles, tamaño de texto de globos.
- Pase de balance con la sesión "Balance de daños, vidas y energía": integrar sus resultados antes del 16/10.

---

## 7. Calendario resumido

| Día | Foco principal | Cierre |
|---|---|---|
| **Sáb 10/10** | C1–C4, N2-1…N2-4, baseline de FPS | commit + tag |
| **Dom 11/10** | N3-1…N3-6 (fallos de N3 y Oso), O-1, O-2 | N3 en 0 fallos |
| **Lun 12/10** | N3-7…N3-8, N1-1…N1-3, J-1, A-1 | N3 jugado |
| **Mar 13/10** | J-2, J-3, A-2, N2-5, revisión del hito | commit + tag 13/10 |
| **Mié 14/10** | J-4, J-5 (primera tanda), M-1, M-4 | jefe con visual |
| **Jue 15/10** | J-5, J-6, J-7, M-2, M-3, CO-2 | jefe jugable completo |
| **Vie 16/10** | J-8, J-9, M-5, M-6, CO-4, revisión del hito | commit + tag 16/10 |
| **Sáb 17/10** | F-1, F-3, O-3, O-4, B-7 | sala del boss |
| **Dom 18/10** | **Buffer** + F-2 (pasada completa) + F-4 | sin cambios grandes |
| **Lun 19/10** | F-5…F-8, revisión final | v1.0 |

---

## 8. Dependencias externas y riesgos

| Riesgo | Impacto | Mitigación |
|---|---|---|
| Visual del jefe llega tarde | No se cierra el gameplay del 16/10 | Prototipo ya jugable; trabajo en valores, no en arte; fecha límite de arte: 14/10 |
| Cómic no llega | Menú de inicio sin arte | Versión vectorial actual como plan B (CO-3) |
| Sprites de Oso/Murciélago y enemigos incompletos | Combate sin animación de ataque | Animaciones actuales como fallback; integrar por tandas |
| Varias sesiones tocando las mismas escenas | Sobreescrituras | Un dueño por escena y recarga en editor |
| Sin FPS medidos | Sorpresas el último día | O-1 el primer día |
| Build en otra PC falla | Entrega en riesgo | F-5 con margen (18/10) |
| Pruebas a mano insuficientes | Bugs que sólo ve el jugador | Sesiones cortas de juego dirigido, con lista de lo que ves |

## 9. Reparto de esfuerzo (estimado)

- **[C] solo:** correcciones de N3, animaciones D/E, optimización, tests, integración de arte, textos, limpieza, build de pruebas.
- **[J] en conjunto:** decisiones de diseño (jefe, N1, N2, N3), balance, menús, cómic de reemplazo, sala del boss.
- **[U] usuario/equipo:** jugar y dar feedback (el cuello de botella real), arte (jefe, hijo, enemigos, personaje, cómic, menús), música/FX, decisiones de historia.
