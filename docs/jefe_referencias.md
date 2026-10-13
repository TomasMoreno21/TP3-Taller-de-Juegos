# Jefe final — Referencias (etapa 1, 13/10)

> Etapa de **referencias**: todavía no hay fases ni mecánicas decididas. Este documento junta qué hacen jefes reales, qué tomamos y qué queda abierto.
> Lore fijado: el jefe es **el líder del culto ya transformado**. Al derrotarlo, **el niño sale de adentro de él**.
> Boceto: [`jefe_boceto.jpg`](jefe_boceto.jpg).

---

## 0. Marco: el jugador y la sala

### Ficha del jugador (de `scripts/forms/*.gd`)
| Forma | Velocidad | Salto (alto / largo)* | Caja de colisión | Daño ligero / fuerte / especial | Lo propio |
|---|---|---|---|---|---|
| Humano | 600 | ~178 / 510 px | 190×318 | 10 / 18 / 22 | **parry** (ventana 0.16 s), devuelve proyectiles; combo Remate 52 |
| Lobo | 690 | **2 saltos**, ~354 / 1495 px | 360×160 (largo y **bajo**) | 8 / 13 / 18 | el más rápido; las mordidas avanzan (el ligero llega a 205 px) |
| Oso | 310 | ~52 / 155 px | 470×324 (**enorme**) | 16 / 24 / 32 | **pisotón**: onda de 230 px (también hacia atrás); recibe ×0.75 |
| Murciélago | 380 | aleteo (cuesta energía) + planeo | 135×133 (**chico**) | 9 / 14 / sónico 15 | **único con ataque a distancia** (sónico); picada con onda de 170 px; recibe ×1.1 |

\* Medidos en sesiones anteriores; se vuelven a medir antes de la etapa de mecánicas.
**Energía:** transformarse pide ≥25 y en combate drena 4/s (el Oso ×1.3). A 0 vuelve a Humano. Hoy la energía se recarga matando enemigos (almas).

### Lectura del boceto (escala aproximada a 1920×1080)
Las medidas salen de pasar el lienzo del boceto a 1080 px de alto, así que son aproximadas.
- **Estrella:** ~900 px de ancho × ~620 px de alto. Ocupa la mitad del ancho de la pantalla. **El ojo central queda a ~550 px del piso.**
- **Jugador dibujado:** ~275 px de alto. Coincide con la caja real del Humano (318), así que el boceto está casi a escala.
- **Hueco bajo las puntas inferiores:** ~265 px del piso → **pasan el Lobo (160) y el Murciélago (133); el Humano (318) y el Oso (324) NO entran.**
- **Altura del ojo vs el jugador:** desde el piso el Humano llega a ~500 px (cuerpo + salto) y no alcanza el ojo. El Lobo con doble salto queda justo al límite. **El Murciélago llega sin problema.**
- **Ojos verdes:** ~15, a alturas de ~100 a ~900 px. Los bajos se alcanzan a pie; los altos piden doble salto o vuelo.
- **Sala:** una pantalla, techo con raíces y estalactitas (~90 px), piso con pinchos y rocas en los bordes.

---

## 1. Ben 10: Alien Force (Wii/PS2, 2008) — referencia obligatoria
**Qué hace:** los jefes del juego (p. ej. el Comandante Highbreed, jefe del nivel 7; Kevin mutado como mini-jefe del nivel 5) **no se vencen solo pegándoles**. Según guías de jugadores, contra el Highbreed hay que romper contenedores para soltar un gas que lo aturde y, mientras está aturdido, activar interruptores. El escenario incluso se da vuelta. La versión DS lo plantea como una persecución en la que hay que cargarle golpes a un láser grande. Ojo: esta información viene de foros y wikis de fans; las guías detalladas no se pudieron abrir.
**Qué tomamos:**
- **El escenario es el arma.** El daño real llega por interactuar con la sala (aturdir y después activar), no por desgastar una barra a golpes.
- **Patrón de 2 tiempos:** primero se abre una ventana (aturdir) y después se aprovecha (golpear el punto débil o activar algo).
- **Cada alien tiene su verbo.** Aplicado al jugador: Oso = romper o empujar algo pesado, Murciélago = llegar alto o pegar a distancia, Lobo = cruzar rápido o pasar por lo bajo.
**Qué no:** la persecución lateral (nuestro boceto es una sala de una pantalla) y la pelea larga contra esponjas de vida.
**Relación con el boceto:** los ojos verdes podrían ser los "contenedores" o interruptores que abren la ventana sobre el ojo central.

## 2. Blasphemous — Escribar / Último Hijo del Milagro (jefe final)
**Qué hace:**
- **Forma 1 (Escribar humano):** no ataca cuerpo a cuerpo. Se teletransporta y lanza 4 hechizos, y **el color del símbolo frente a él anuncia cuál viene**: dardos, lluvia de fuego, burbujas tóxicas y tormenta eléctrica. Es invulnerable mientras lanza.
- **Forma 2 (Último Hijo del Milagro):** un gigante acorazado más alto que el jugador. **Su único punto débil es la cara carmesí**, y aparece cuando la máscara se abre. La máscara se abre al **pegarle al ojo de una daga dorada gigante**; con el tiempo vuelve a cerrarse y la daga reaparece, así que el ciclo se repite.
- Aparecen **plataformas flotantes** que sirven para llegar a la cara y para cubrirse. Se apagan y vuelven a aparecer por grupos.
- Los ataques se anuncian **de a uno**, con dos símbolos de color y una marca en el piso donde va a caer. **Por debajo del 50 % de vida se suma un ataque nuevo** (bolas de fuego).
- El rayo púrpura es peligroso, pero a la vez es una **ventana para pegarle varias veces a la cara**.
- **Lore:** el jefe lleva un collar con **el cuerpo humano de Escribar encerrado en vidrio**. Al morir, la cara se derrite y queda expuesto el cuerpo mutado.
**Qué tomamos:**
- **El humano encerrado dentro del monstruo:** es casi exactamente nuestro final. El niño puede verse desde el principio, encerrado en el ojo como en el vidrio de Escribar, y eso cuenta la historia sin palabras.
- **Punto débil que se abre y se cierra** (máscara → ojo): el ojo central se abre al cumplir una condición y se cierra con el tiempo.
- **Cada ataque se anuncia con un color y con su lugar marcado en el piso**, y nunca hay dos anuncios a la vez.
- **El ataque peligroso es a la vez la ventana para pegar:** se arriesga para ganar daño.
- **Un ataque nuevo al pasar cierto umbral de vida**, sin cambiar todo.
- **Plataformas que aparecen y desaparecen** para llegar al punto alto: le dan sentido al Lobo (doble salto) y al Murciélago (vuelo) para alcanzar el ojo a ~550 px.
**Qué no:** el teletransporte (nuestro jefe es una estrella enorme) y la máscara con daga como objeto suelto.

## 3. Hollow Knight — Hollow Knight + Radiance (final verdadero)
**Qué hace:**
- **Hollow Knight:** es un **recipiente que tiene a la Radiancia adentro**. En sus fases finales deja de usar el cuerpo a cuerpo y lanza hechizos, **se apuñala a sí mismo en el pecho** y termina cayendo de rodillas mientras Hornet lo sujeta. Entonces el jugador entra en él con el aguijón onírico.
- **Radiancia, fase 1:** sala amplia. **No hace daño por contacto**, así que conviene quedarse cerca. Ataca con espadas que salen del piso o caen del cielo y **encierran al jugador en partes de la sala**, rayos de luz y un orbe que persigue.
- **Radiancia, fase 2:** **el piso desaparece** y aparecen plataformas en el cielo. Al final viene una **subida vertical** con rayos desde arriba y niebla negra que sube desde abajo, hasta quedar cara a cara con ella: **un solo golpe la mata**.
- **Ritmo:** los rayos son peligrosos solo ~0.25 s, en su momento más ancho, y salen cada 1.5 s.
- **Curación:** en Hollow Knight el alma con la que te curás se gana **pegando**. El que ataca bien se mantiene vivo.
**Qué tomamos:**
- **El jefe se daña a sí mismo y "deja salir" lo que tiene adentro.** Es una transición dramática para la última fase, contada sin diálogo.
- **El entorno cambia la sala entre fases:** el piso se rompe (¿pinchos?) y aparecen plataformas. Así el Oso, fuerte en el piso, y el Murciélago, fuerte en el aire, tienen cada uno su fase.
- **Final de subida vertical** hasta el ojo con **golpe final único y cinematográfico**. Es un buen momento para que salga el niño.
- **Avisos cortos y precisos:** el peligro dura poco y está bien marcado.
- **El recurso se gana atacando:** la energía de transformación podría ganarse pegándoles a los ojos verdes, así nunca te quedás sin poder transformarte.
- **Sin daño por contacto con el cuerpo:** con una estrella que ocupa media pantalla, si tocarla dañara, la sala sería injugable.
**Qué no:** la cantidad de fases (son 5 + Hollow Knight, demasiado para el alcance del proyecto) y tener que repetir la pelea anterior si morís.

## 4. Cuphead — análisis de Game Maker's Toolkit + jefes concretos
**Qué hace:**
- **Los ataques existen para hacerte mover.** La pelea pone a prueba el movimiento y el parry mientras disparás; no deja quedarse quieto.
- **Jefe enorme, a pantalla completa y mayormente fijo.** Cambia de forma en cada fase (2-4 fases), y cada fase tiene identidad visual y ataques propios.
- **Avisos muy visuales:** Goopy echa el cuerpo atrás antes del puñetazo y en la fase 2 aparece un guante rojo. A Grim Matchstick **se le abre la boca antes de la llamarada**.
- **Jefe por secciones (Robot del Dr. Kahl):** cabeza con láser (**esquivar**), pecho con lanzador (**hacer parry**) y panza con hangar que suelta drones (**derribar**). **Cada sección se puede destruir y se convierte en un arma nueva.** Un corazón que aparece avisa el cambio de fase.
- **El parry como control:** en el Phantom Express, las válvulas rosas sirven para moverse a izquierda o derecha.
- **Sin curación en la pelea.** La vida es fija y al morir te muestran cuánto avanzaste.
**Qué tomamos:**
- **Un jefe dividido en partes, y cada parte con su forma.** Con las 8 puntas de la estrella, cada grupo de puntas o de ojos puede tener un verbo: **esquivar = Lobo** (rápido y bajo, pasa bajo las puntas), **devolver = Humano** (parry), **romper = Oso** (pisotón, golpe pesado) y **derribar a distancia = Murciélago** (sónico).
- **Las partes destruidas cambian el ataque:** una punta rota deja de atacar o ataca distinto, y el jugador ve su progreso en el cuerpo del jefe.
- **Avisos en la propia anatomía:** el ojo se abre, una punta brilla, los ojos verdes giran hacia el jugador.
- **Cada fase con identidad visual propia:** color, forma y ataques.
- **Mostrar el avance al morir** (¿cuánto le faltaba al jefe?): baja la frustración en una pelea difícil.
**Qué no:** la falta total de curación (tenemos el valle de respiro y la energía, más justo para un público de taller) y la vida del jugador de 3 puntos.

---

## 5. Síntesis por eje
| Eje | Lo que dicen las referencias | Propuesta a discutir (sin decidir) |
|---|---|---|
| **1. Estructura y formas** | AF: el escenario es el arma. Cuphead: partes con un verbo cada una. Blasphemous: punto débil que se abre | Ciclo de **abrir → castigar**: con una forma se abre el ojo y con otra se aprovecha. Cada forma tiene un rol que las otras **no pueden** cumplir, por tamaño o alcance (ver ficha y espacios) |
| **2. Tiempos** | HK: peligro de ~0.25 s, rayos cada 1.5 s. Blasphemous: un aviso por vez. Pelea de Escribar ~1 min si sos agresivo | Pelea total de **4 a 6 min**, fases de 1.5 a 2 min. Avisos de 0.4 a 0.9 s (como hoy, con un mínimo de 0.4). Respiro corto tras cada ventana de castigo |
| **3. Cambio de fase** | Por vida (Blasphemous 50 %, Cuphead por fase). HK: el jefe cae y se rompe. Cuphead: un objeto que avisa | Por **vida**, con un evento visible: puntas que se rompen, el ojo que sangra luz, temblor. Cinemática breve sin cortar el control, o cortándolo ≤2 s. `JefeCine.grieta` ya existe |
| **4. Entorno** | HK: el piso desaparece y aparecen plataformas, cierre con subida vertical. Blasphemous: plataformas intermitentes. AF: el escenario se da vuelta | Fase de **piso** (Oso protagonista) → fase con **plataformas o piso roto** (Lobo/Murciélago) → **subida final** al ojo. Raíces y estalactitas del techo como peligro que cae |
| **5. Cambios del jefe** | Cuphead: cambia de forma por fase y las partes rotas cambian el ataque. Blasphemous: la máscara se derrite. HK: se apuñala | Las puntas se rompen de a poco y la estrella pierde forma. El ojo pasa de cerrado a abierto a desgarrado. **El niño se ve cada vez más** dentro del ojo |
| **6. Movimiento del jefe** | Cuphead: fijo y enorme. HK: se reubica entre ataques. AF (DS): persigue | **A definir.** Opción A: fijo y enraizado, gira sobre su eje (cambian las puntas que dan al jugador). Opción B: fijo en F1 y se arranca del tallo y flota en la última fase |
| **7. Cámara** | Cuphead: fija a pantalla completa. HK: sigue al jugador en la subida | Sala fija (`modo_arena`/`encuadre_arena`). **Zoom-out** si la sala crece, **subida vertical** con la cámara siguiendo al jugador, **zoom-in** para el golpe final y la salida del niño (`modo_cine`, `punch`, `shake`) |
| **8. Consumibles** | HK: la curación se gana pegando. Blasphemous: frascos limitados. Cuphead: sin curación | **Energía al pegarle a los ojos verdes** (siempre podés transformarte). **Vida** solo en los respiros o al terminar una fase (hoy: valle que cura 15 si la vida está bajo el 50 %). Evitar ítems sueltos al azar |
| **9. Avisos y dificultad** | Blasphemous: color + marca en el piso. Cuphead: aviso en la anatomía. HK: peligro corto | Cada ataque con **color fijo + lugar marcado + sonido**. Uno por vez en F1; se combinan en F3. La dificultad sube por combinación, no por velocidad pura |
| **10. Narrativa** | Blasphemous: el humano en vidrio dentro del monstruo. HK: el recipiente contiene a otro ser | **El niño se ve en el ojo desde el principio** (silueta). El Amuleto lo reconoce en la entrada. Al final, golpe único al ojo, el ojo se abre y sale el niño, cinemática y victoria |
| **11. Sala** | Una pantalla (Cuphead) o que crece en vertical (HK) | 1920×1080 con techo y piso peligrosos en los bordes. **Hueco bajo las puntas: ~265 px** (Lobo y Murciélago pasan, Humano y Oso no). **Ojo a ~550 px** del piso |

## 6. Qué hacer con los ojos verdes (opciones a partir de las referencias)
> **Decidido (usuario, 13/10): opción 4, una función distinta en cada fase.** El reparto por fase se define en la etapa de mecánicas.

1. **Llaves (AF + Blasphemous):** hay que cerrar o romper N ojos para que se abra el ojo central. Los altos piden Murciélago o Lobo y los bajos los resuelve cualquier forma.
2. **Fuente de energía (HK):** pegarles da energía de transformación y mantiene vivo el sistema de formas.
3. **Torretas (Cuphead):** cada ojo dispara un tipo de proyectil (el Humano los devuelve con parry, el Murciélago los derriba de lejos).
4. **Mezcla:** cumplen una función distinta en cada fase (F1 llaves, F2 torretas, F3 se cierran y caen).

## 7. Preguntas abiertas para la etapa de mecánicas
1. ~~**Ojos verdes:** ¿cuál de las opciones de §6?~~ → una función distinta en cada fase (falta el reparto).
2. **Movimiento de la estrella:** ¿fija, gira o se arranca del tallo en algún momento?
3. **¿Cuántas fases?** Recomiendo 3 (piso, aire, subida final) por el alcance del proyecto.
4. **Rol exclusivo de cada forma:** ¿qué hace el Oso que nadie más pueda (romper puntas o raíces, aguantar un barrido)? ¿Y el Lobo (pasar bajo las puntas a 265 px, cruzar la sala a 690)? ¿Y el Murciélago (llegar al ojo a 550 px, pegar a distancia)?
5. **¿El Humano tiene rol propio** (parry) o queda como forma de transición?
6. **¿Hay enemigos invocados** (cultistas) o la pelea es solo contra el jefe?
7. **Consumibles:** ¿energía por pegar a los ojos y vida solo entre fases?
8. **Duración objetivo** y cantidad de vida del jefe.
9. **Final:** ¿el niño sale con el control del jugador (caminar hasta él) o en cinemática?
10. **¿Se reemplaza el Arzobispo por completo** (nombre, `boss.gd`) o se reutilizan piezas?

## 8. Piezas existentes reutilizables (no se tocan en esta etapa)
`JefeCine` (`scripts/jefe_cine.gd`: entrada, grieta, destello final) · `ataque_jefe.tscn` (zona con aviso parpadeante + daño único) · Encounter · barra del jefe del HUD (`hud.gd::_boss_bar_mostrar`, con eco) · parry del Humano (devuelve orbes) · cristal `solo_murcielago` · enemigo `acorazado` (solo la Garra del Oso lo daña de verdad) · cámara (`modo_arena`, `encuadre_arena`, `fijar_zoom`, `modo_cine`, `punch`, `tilt`, `shake`) · `victoria_jefe.tscn` · `nivel_jefe.tscn`.

---

## 9. Mecánicas: propuesta inicial (aprobada por el usuario el 13/10, base para iterar)
> **Estado (13/10):** F1 implementada (`scripts/jefe_estrella.gd`). Números: vida 600 (200 por fase, el daño de una ventana no saltea fases), ventana 4.5 s, lanza 15, energía 12 por ojo, orbe +25 por fase. F2 implementada (torretas 8, barrido 12, foso 10, parry 30, ventana aérea 4 s a 680 px). La F3 todavía repite la F2.
Regla: ninguna fase se gana sin la habilidad que la protagoniza (**Oso: fuerza bruta · Lobo: doble salto · Murciélago: vuelo**). La estrella ataca siempre desde el fondo y **no hace daño por contacto**.

| | **F1: El ojo que vigila** (100-66 %) | **F2: La mirada** (66-33 %) | **F3: La caída** (33-0 %) |
|---|---|---|---|
| **Estrella** | Fija en el tallo, gira despacio. **Lanza:** una punta brilla 0.8 s y se estira hasta el piso, con el lugar marcado antes | Fija. **Barrido de luz** horizontal desde el ojo, a una altura avisada en la pared | **Se arranca del tallo**, flota y se mueve de lado a lado. **Se clava de punta** contra el piso (golpe con onda) |
| **Ojos verdes** | **Llaves:** 4 que hay que cerrar | **Torretas** que disparan | **Caen con coraza** |
| **Oso (fuerza bruta)** | Con las 4 llaves cerradas, el ojo se abre a ~550 px, fuera de alcance → el Oso rompe un **nudo del tallo** (solo él puede, como `muro_piedra`) → la estrella se inclina y **el ojo baja a la altura de un golpe** | Rompe los ojos acorazados del piso | La punta queda clavada → el Oso la **arranca a golpes** → la estrella cae aturdida con el ojo a ras del piso = ventana de castigo |
| **Lobo (doble salto)** | Llaves altas (~500 px) | **El centro del piso se rompe y quedan pinchos:** hay que cruzar un pozo de ~600 px (el Lobo salta 1495 px de largo, el Humano 510) | Salta la onda del golpe y esquiva los ojos que caen |
| **Murciélago (vuelo)** | Llaves muy altas (~750 px) | **El ojo abierto queda alto (~650 px):** solo se llega volando. El sónico derriba las torretas altas | Si la estrella se recupera antes del castigo, vuela alto y hay que seguirla en el aire |
| **Humano** | Forma de transición | Devuelve con **parry** los disparos de las torretas al ojo central | — |

- **Tiempos:** cada fase dura entre 1 y 1.5 min, unos 4-5 min en total. Avisos de 0.4 a 0.9 s y un respiro corto después de cada castigo.
- **Cambio de fase:** por vida (66 % / 33 %). F1→F2: la estrella grita y el piso se quiebra en el centro. F2→F3: se arranca del tallo y caen raíces del techo. Cada cambio corta el control menos de 2 s (`JefeCine.grieta` + temblor).
- **Movimiento:** fija en F1 y F2 (solo gira) y libre en F3.
- **Cámara:** F1 sala fija (`modo_arena`). F2 alejamiento suave para ver el pozo y la altura del ojo (`fijar_zoom`). F3 sigue a la estrella un poco hacia los lados. Al final, acercamiento al ojo (`modo_cine`, `punch`).
- **Consumibles:** golpear un ojo **siempre da energía** (nunca quedás sin poder transformarte ni volar). El último ojo de cada fase suelta un **orbe de vida**.
- **Final:** la estrella cae, el ojo se abre y **sale el niño** (golpe final cinematográfico).
- **Pendiente de definir:** daño y vida de la estrella, duración real de las ventanas, alturas exactas (medirlas con la ficha), cómo se ve al niño en el ojo durante la pelea, enemigos invocados (sí o no), si se reutiliza `boss.gd` o se escribe un script nuevo.

### Fuentes
- [Ben 10: Alien Force (videojuego) — Wikipedia](https://en.wikipedia.org/wiki/Ben_10:_Alien_Force_(video_game))
- [Highbreed (PSP) — respuestas en GameFAQs](https://gamefaqs.gamespot.com/psp/946125-ben-10-alien-force/answers/185211-how-do-i-beat-highbreed-from-ben-10-alien-force) · [Guía de la versión DS, mundo 4 — Ben 10 Omniverse Wiki](https://ben10omniverseref.fandom.com/wiki/Ben_10:_Alien_Force:_The_Game/DS_Walkthrough/World_4:_Tower) · [Highbreed Commander — Ben 10 Wiki](https://ben10.fandom.com/wiki/Highbreed_Commander_(Alien_Force_Video_Game))
- [Last Son of the Miracle — Blasphemous Wiki (Fextralife)](https://blasphemous.wiki.fextralife.com/Last+Son+of+the+Miracle)
- [Guía de la Radiancia — TheGamer](https://www.thegamer.com/hollow-knight-radiance-boss-guide/) · [Absolute Radiance — Hollow Knight Wiki](https://hollowknight.wiki/w/Absolute_Radiance)
- [How Cuphead's Bosses (Try to) Kill You — Game Maker's Toolkit](https://amara.org/v/C3BEq) · [Guía de Goopy Le Grande — TrueAchievements](https://www.trueachievements.com/game/Cuphead/walkthrough/7) · [Jefes difíciles de Cuphead — Green Man Gaming](https://www.greenmangaming.com/intel-feature/cuphead-hub/cuphead-bosses/)
