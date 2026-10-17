# Plan: autoexplicación de mecánicas y controles

Estado: propuesto (16/10). Sin código tocado. Aprobado por el usuario: enfoque "auditar y rehacer", fases chicas, no bloqueante, nivel tutorial guiado (N1) + mini-pasos por forma nueva.

## 1. Problema (palabras del usuario)
- Se explica **vago**, y **a destiempo** (aparece tarde/temprano, dura poco).
- Lo que más se pierde: **transformaciones** (energía/drenaje, para qué sirve cada forma) y **ataques** (especial, combos).

## 2. Qué existe hoy (verificado en código)
- `scripts/tutorial_paso.gd` + `scenes/tutorial_paso.tscn`: paso en lista de tareas, `Accion` = MOVER, SALTAR, GOLPE_LIGERO, GOLPE_FUERTE, BLOQUEAR, PARRY, TRANSFORMAR. Texto desde `data/dialogos.json` (`paso_id` → `lineas[0]`, `pista`, `cierre`). Se marca visto en `Progresion.dialogos_vistos`. Pista tras `segundos_pista` (20 s).
- Solo hay **5 pasos colocados**, todos en `scenes/nivel1.tscn` (`tut_mover/saltar/ligero/fuerte/bloqueo`). `TRANSFORMAR` existe en el enum pero **no se usa**; no existe acción ESPECIAL.
- Consejos sueltos (`Dialogo.mostrar_tip`): en `player.gd` (`_tip_una_vez`: bloqueo L587, energía L2147, parry L2773, enemigo flotante L2987, combo L3432), `boss.gd`, `jefe_estrella.gd`. Cada uno decide solo cuándo salir.
- Cola/tiempos en `scripts/dialogo.gd`: `seg_calma_tras_dano=2`, `seg_entre_charlas=7`, `seg_tip_vence=25`, `SEG_POR_CARACTER=0.016`, permanencia tras escribir = `max(1.6, chars*0.04)` s para tips (L~420).
- "Ayuda del Amuleto" (`ayuda_panel.gd`): nivel de ayuda 0/1/2 y relectura de `Progresion.ayuda_vista`.
- `Dialogo._rastrear_acciones` marca `mover/saltar/bloquear/golpe_*` en `Progresion.acciones_hechas` (no `transformar` ni `especial`).
- Estructura real: N1 tutorial (Humano+Lobo), N2 introduce Murciélago, N3 Oso, N4 jefe (ver MEMORY.md).

## 3. Causas probables de "mal timing" (hipótesis a medir en Fase 1)
1. Tips esperan `en_calma()` y **vencen a los 25 s**: si hay pelea larga, llegan tarde o se pierden.
2. El tip de energía sale **al transformarse**, durante hitstop/slowmo/flash/zoom (`_zoom_transform`), justo cuando el jugador mira el efecto, y solo dice "gastan energía".
3. Permanencia ≈ 25 car/s tras escribir; un tip de ~110 caracteres dura ~6 s en total. Puede quedar corto si el jugador está peleando mirando otra cosa.
4. Cada tip se dispara desde su propio script: no hay noción de "lo necesita ahora" (ej. el combo se explica al elegirlo en el LevelUp, no al poder usarlo).

## 4. Principios (reglas del diseño)
- **No bloqueante**: nunca frena el juego ni exige acción para avanzar; el paso se tacha solo si el jugador ya lo hizo.
- **Enseñar en el momento de uso**, tras una acción del jugador o al entrar a la zona donde se usa; nunca durante efectos de transformación o daño.
- **Una idea por mensaje**, concreta (qué botón, qué pasa, para qué). Ej.: "Transformate con {transform} (cuesta 25 de energía)" en vez de "las formas gastan energía".
- **Duración por largo**: `seg = escritura + max(mínimo, chars / cps_lectura)`, valores `@export` en `dialogo.gd` (regla de edición del proyecto).
- **Tips críticos no vencen**; los de relleno sí. Todo texto en español, vía `dialogos.json`.
- Respetar `nivel_ayuda` (0 nada, 1 ligera, 2 completa).

## 5. Fases

### Fase 1 — Auditoría y reglas de timing
Objetivo: medir y arreglar el cuándo/cuánto antes de agregar contenido.
- Tarea 1.1: inventario de **todos** los consejos (`_tip_una_vez` en player/boss/jefe_estrella, `dialog_trigger`, `dialogos.json`) → tabla en este archivo: id, texto, disparador, longitud, duración efectiva. Script: `tests/diag_tips_tiempos.gd` que calcula duración con la fórmula actual y marca los de < 5 s por tip o > 120 caracteres.
- Tarea 1.2: en `dialogo.gd`, exportar `cps_lectura` (≈ 15) y `seg_minimo_tip`; reemplazar `max(1.6, chars*0.04)` por la fórmula nueva.
- Tarea 1.3: marcar tips **críticos** (`critico: true` en la API de `mostrar_tip`): no vencen por `seg_tip_vence`, esperan calma.
- Tarea 1.4: bloquear tips mientras haya hitstop/slowmo/cinemática de transformación (reutilizar flag existente de `player.gd`, ver `_freeze_*`); reintentar al terminar.
- Hecho cuando: tabla del inventario completa, `diag_tips_tiempos` sin marcas, `verificar.ps1` en 0, un tip largo se lee entero en prueba manual.

### Fase 2 — Transformación y especial en el nivel tutorial (N1)
- Tarea 2.1: `Accion.ESPECIAL` en `tutorial_paso.gd` (CLAVES + `_conectar` con `attack_performed` tipo "special") y rastreo `transformar`/`especial` en `Dialogo._rastrear_acciones` para que se tachen solos si ya lo hizo.
- Tarea 2.2: textos nuevos en `dialogos.json` (`tut_transformar`, `tut_energia`, `tut_especial`) con `pista` y `cierre`. Mensajes: cómo transformarse (selector de forma + {transform}), costo mínimo 25, drena 4/s y a 0 vuelve a Humano, vida compartida; especial: botón {special}, cuándo conviene.
- Tarea 2.3: colocar pasos en `nivel1.tscn` tras el desbloqueo del Lobo (zona de `UnlockLobo`/`n1_lobo`), encadenados con `paso_siguiente`; que activen **después** de la cinemática de desbloqueo.
- Tarea 2.4: pista visual de energía: pulso breve en la barra de energía del HUD cuando se explica el drenaje (`@export` duración/color).
- Hecho cuando: `diag_tutorial` cubre los 3 pasos nuevos (se activan, se tachan solos, no se repiten tras morir) y autotest 0.

### Fase 3 — Formas nuevas y combos
- Tarea 3.1: mini-paso al desbloquear **Murciélago** (N2) y **Oso** (N3): rol de la forma (qué hace distinto), su ataque especial y una situación de uso. Sin lista larga: 1 a 2 pasos por forma.
- Tarea 3.2: combos: mover `_tip_combo_nuevo` de "al elegir en LevelUp" a "la primera vez que el jugador ataca en esa forma tras elegirlo", con la secuencia ligero→fuerte concreta. Si hay mejoras diferidas, avisar cuando se desbloquea la forma.
- Tarea 3.3: aviso breve de **fragmentos/nivel** la primera vez que se obtienen (qué son, qué dan).
- Hecho cuando: `diag_tutorial`/`diag_ayuda` pasan, el flujo de N2 y N3 muestra los mini-pasos una sola vez.

### Fase 4 — Glosario y pulido
- Tarea 4.1: en Ayuda del Amuleto, fichas por forma (rol, ataque ligero/fuerte/especial, costo) y por mecánica (energía, bloqueo/parry, combos). Texto desde `dialogos.json`, no hardcodeado.
- Tarea 4.2: revisar y reescribir los textos vagos de la tabla de Fase 1; reducir a lo esencial.
- Tarea 4.3: `controls.tscn`: alinear nombres y botones con lo que enseña el tutorial.
- Hecho cuando: `diag_ayuda` pasa, partida completa N1→N3 sin tips pisados ni descartados.

## 6. Verificación por fase
`powershell -File tests/verificar.ps1 -Diag diag_tutorial,diag_ayuda,diag_tips_tiempos` (Import limpio → smoke limpio → autotest FALLOS = 0). Captura solo si cambia algo visual (pulso de barra de energía, fichas).

## 7. Riesgos
- Tocar el timing de `dialogo.gd` afecta charlas y jefes (`boss.gd`, `jefe_estrella.gd` usan `mostrar_tip`): probar un jefe.
- `nivelN1.tscn` es grande: editar solo los nodos nuevos de tutorial.
- Los pasos nuevos dependen de `acciones_hechas` y `dialogos_vistos` (se reinician con "nueva partida"; verificarlo).

## 8. Decisiones abiertas
- Ritmo exacto de lectura (`cps_lectura`): probar 12 vs 15.
- ¿Pulso de la barra de energía o texto flotante? Recomendado: pulso (menos texto).
