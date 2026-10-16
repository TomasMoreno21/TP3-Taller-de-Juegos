# Revisión final — 16/10 (7 subagentes, solo lectura)

Base: `docs/INFORMES_BUGS_15-10.md` (lo corregido ayer). Todo sigue **sin commit**; hay un commit nuevo del equipo en el remoto (`5055660`) sin bajar.
## ESTADO (16/10, tras corregir)
Pedido del usuario: arreglar todo menos los checkpoints que faltan. Hecho (autotest 0; diags: solo los fallos viejos de siempre):
- Regresiones: slowmo (curva del parry), `CheckpointLazoOeste` → (-3150,3400) (piso 3584, celda libre), opciones `_exit_tree`.
- Interfaz: 1-8, 10, 11, 12 (precarga anulada en `transicion.precargar`), blips con `preload`.
- Jugador: 1-5, 7, 8. Enemigos: 1-7 (dormido sin `move_and_slide`, orbe cae para todos, proyectiles enemigos en grupo "proyectil_enemigo" que limpia `reiniciar()`).
- N2: `DialogoPlaneo` (n2_planeo) en (1500,-119); `rayo_luz` no titila en el editor; streaming duerme `CPUParticles2D` sueltas.
- N3: `Niebla11/20` borradas; pinchos reparentados (`PinchosArenaB`, `PinchosArenaB2`, `PinchosLatido`); terreno: 149 088 → 77 826 celdas (+21 747 bloques, `tile_bloques_n3`, tileset `tileset_bloques_n3`), RAM 216 → 187 MB, ready ~475 → 366 ms, dibujo igual (capturas: solo difieren luciérnagas). `rampas_suaves.gd` cuenta `Profundo` como roca (sacó ~200 rampas falsas dentro de la roca: N3 691, N1 199, N2 500). `tools/hornear_bloques.gd` ahora quita las celdas enterradas tapadas por `Profundo`.
- Tests: `diag_checkpoints_niveles` cubre N1/N2/N3/jefe y detecta checkpoints dentro de la roca; `diag_nivel3` margen del fondo 400 y umbral de celdas 50 000.
- Jefe: 2 (grupo "victoria" desde la muerte + timer pausable), 3 (rayo vertical dir 0), 4 (`foso.dano = 0` y el foso no llama `take_damage` con 0), silueta de la victoria sin redibujar.
- Cámara/audio: 3 (`noche_profunda` sin hojas), 4 (`_zoom_velocidad` en arena), 5 (`ambiente_zonas` ya no borra el bus).
**Sin hacer:** checkpoints que faltan (pedido); todas las (D); optimizaciones de `lista_tareas` y `ojo_verde` (el dibujo depende de animaciones: riesgo de congelarlas); luces/niebla de N2 (cambian el aspecto).

---
Estado original: **PENDIENTE DE CORREGIR**. ☐ = pendiente · (D) = decisión de diseño / complicado.

## Rendimiento medido (RTX 3050, ventana, 1920×1080)
| Nivel | load / _ready / 1er frame | FPS (ms) | Nodos / luces / partículas | RAM / VRAM |
|---|---|---|---|---|
| main_menu | 13 / 5 / 193 ms | 1755 (0,57) | 15 / 0 / 0 | 90 / 51 MB |
| N1 | 1121 / 136 / 342 ms | 268-312 (3,2-3,7) | 3008 / 28 / 41 | 195 / 333 MB |
| N2 | 1164 / 417 / 579 ms | 208-227 (4,4-4,8) | 1997 / 52 / 40 | 196 / 209 MB |
| N3 | 1203 / 492 / 582 ms | 178-237 (4,2-5,6) | 3648 / 69 / 49 | 251 / 327 MB |
| Jefe | 945 / 24 / 135 ms | 1392 (0,72) | 249 / 4 / 3 | 103 / 259 MB |
- Peor caso N3 5,6 ms de 16,6 (p99 < 9,7 ms). Lo más caro: luces (N3 ~1 ms, N2 ~0,6 ms; 0,1-0,16 ms por PointLight2D en pantalla) y niebla de partículas grandes de N2 (~1,1 ms GPU). Scripts: nada destaca. 1er frame tapado por el fundido.

## Regresiones de ayer
1. ☐ **Slowmo del parry pierde el tramo 0,5** (`hitstop.gd:51`: "gana el más fuerte" se come la curva 0,25→0,5→0,8). Arreglo: `_slow_scale = minf(_slow_scale, escala) if _slow_restore_ms > ahora and hasta <= _slow_restore_ms else escala` (sigue cubriendo la muerte del jefe). (cámara#1, jefe#1)
2. ☐ **`CheckpointLazoOeste` de N3 enterrado en roca** (-3150,4104): nunca se activa y se ve dentro de la roca. Mover a ≈(-2600,4210) (piso 4368-4400, pinchos a 260-380 px) o pasillo superior (-3150,3400). (N3#1)
3. ☐ Opciones: guardado diferido se pierde si se sale con `quit()` antes de 0,5 s → `_exit_tree(): if _guardado_pendiente: _guardar()` en `opciones.gd`. (UI#13, cámara#2)
4. ☐ Checkpoint N1 nuevo quedó a 3k px del `Checkpoint4b`: el tramo largo (Checkpoint4 → subsuelo, ~20k px) sigue sin cubrir. (N12#1)

## Interfaz y flujo
1. ☐ **Cinemática del tótem cortada (reiniciar/menú durante ella) deja `Dialogo.visible=false` para siempre + barras negras colgadas** (`unlock_forma.gd:173-176,196,205-226,312`): guardar capa y dlg; en `_exit_tree` restaurar; `visible = true` en `Dialogo.limpiar()`. ALTA
2. ☐ **Cómic/menú marcan "saltar" como hecho → N1 salta `tut_saltar`** (`dialogo.gd:624-635`): en `_rastrear_acciones` `return` si pausado o sin jugador. ALTA
3. ☐ Confirmar con A/Espacio hace saltar al jugador al despausar (pausa, LevelUp, Reintentar): `Input.action_release("jump")` tras despausar (`pause.gd:96-101`, `levelup.gd:74-85`, `derrota.gd:83-88`).
4. ☐ El diálogo sigue escribiendo/avanzando con el juego pausado (`dialogo.gd:362`): `return` si pausado salvo con grupo "victoria".
5. ☐ Charla en espera que vence (30 s) no emite `dialogo_terminado` → tutorial colgado (`dialogo.gd:534-543`, `tutorial_paso.gd:82-85`): emitir si quedó libre.
6. ☐ Lista de tareas invisible si se corta la intro (`intro_nivel.gd:83,287-292`): `_exit_tree` restaura; `limpiar()` pone `lista.modulate.a = 1`.
7. ☐ Salida en modo oscuridad cambia de nivel con la pausa abierta (`salida_nivel.gd:88-90`): no sumar tiempo en pausa.
8. ☐ Cinemáticas que corren en pausa por `create_timer(x)` (`unlock_forma.gd`, `derrumbe_disparador.gd`, `titulo_nivel.gd`, lambda de `dialog_trigger.gd:56`): `create_timer(x, false)`.
9. ☐ (D) `TransicionPantalla.recargar()` no limpia el diálogo (¿la lista de tareas debe persistir al reintentar?).
10. ☐ LevelUp: solo ↑↓ con opciones en fila; `_es_joypad` arranca false → aceptar ←→ y tomar `Dialogo._usa_joypad`.
11. ☐ Controles: falta LT/RT (mando) y R (teclado).
12. ☐ Precarga en hilo activa pero nunca usada (`main_menu.gd:31`, `salida_nivel.gd:64-66`, `transicion.gd:48-67`): carga doble + hilo cargando mientras se juega. Quitar o usar `_esperar_carga` + `change_scene_to_packed`. (también N12#4, cámara#9)
13. Optimizaciones: `lista_tareas.gd:192` redibuja cada frame; blips `dialogo.gd:422,427` hacen `load()` cada 2 letras → `preload`.

## Jugador
1. ☐ **Lianas activas en cinemáticas y muerte** (`player.gd:555`, `_handle_enredadera`): solo si `not dialogo_bloquea`; si trepando y bloqueado, soltar.
2. ☐ Fantasma del aro de energía congelado (`hud_dial.gd:255-260`: tween recreado cada frame).
3. ☐ Planeo del Murciélago gasta energía y planea en cinemáticas (`player.gd:648-654`): `and not dialogo_bloquea`.
4. ☐ Rendimiento: `linea_libre` (hasta 12 raycasts) por cada enemigo antes del filtro de distancia (`player.gd:3007-3018`, `projectile.gd:199-204`): filtrar por distancia primero.
5. ☐ Rendimiento: `_dialogo_bloquea_input()` busca un autoload cuya `esta_activo()` siempre da false: `return cinematica_activa or _derrota_activa`.
6. ☐ (D) Parry de proyectiles ignora invulnerabilidad/god_mode/cinemática (`player.gd:2661-2665`): ¿encadenar parrys contra ráfagas es intencional?
7. ☐ Especial en el aire queda en buffer y se reintenta al aterrizar (`player.gd:886-890, 745-749`).
8. ☐ `projectile.gd:221-223` lee `n.global_position` antes de `is_instance_valid` (zona pendiente del autor).

## Enemigos
1. ☐ **Melee tiembla debajo del jugador en otro piso** (178 giros en 180 frames; `enemy.gd:675`, `_mirar_jugador:687`): quieto si |dx|<30; girar solo si |dx|>8.
2. ☐ Enemigos ocultos de olas pendientes cuentan como "peligro" (`dialogo.gd:519,559`, `ambiente.gd:71`, `player.gd:2028` en_calma): saltar `_activo == false` (+ `health` en dialogo). (D: ¿la tensión previa a la arena era intencional?)
3. ☐ Optimización: el "dormido" de enemigos en espera nunca se activa (`enemy.gd:536` pide `is_on_floor()` con la colisión apagada; 86-225 µs/frame): devolver sin `move_and_slide` en la rama `not _activo` y quitar `is_on_floor()` del guard.
4. ☐ Orbe sin piso debajo (pozo > 2500 px) queda en el aire; orbe de enemigo de tierra muerto en el aire no cae: aplicar la caída a todos.
5. ☐ Latente: olas automáticas no pasan por `_agregar_manual` (`limite_caida`).
6. ☐ Proyectiles enemigos en vuelo sobreviven a `reiniciar()`: grupo "proyectil_enemigo" y liberarlos.
7. ☐ `preparar_ola` no limpia `_pausa_impacto_t`, `_en_flinch`, `_attack_anim_timer`.

## Nivel 1 y 2
1. ☐ (= regresión 4) N1: checkpoint entre `Pinchos_38` (18267) y `Subsuelo_B/Pinchos_01` (20039) a y≈3550 y otro en la bajada antes de `Subsuelo_A` inferior.
2. ☐ **N2: ~16k px de `CheckpointAntesDerrumbe` a `CheckpointCueva5`**: checkpoint después de `FinDerrumbe` **por encima de y=2747** (ej. rampa ≈(12150,1990), piso 2048). Ojo: por debajo de 2747 el derrumbe sigue activo.
3. ☐ (D) **`PremioA1_3` regala ~5 fragmentos** (`forzar_subida` completa hasta 28 en el alma ~13 de 17 de N2 → la 3.ª y 4.ª subida llegan antes). Opción: `forzar_subida()` = solo `subir_nivel()` sin sumar fragmentos, o quitar `da_subida_de_nivel`.
4. ☐ N2: tutorial de planeo `n2_planeo` sin disparador (poner `DialogTrigger` tras `UnlockMurcielago` (613,-91)). Otros ids huérfanos: `n2_aleteos`, `n2_intro`, `n2_pozo`, `n2_mirador`, `n1_intro`, `n1_zona2`, `n1_santuario`, `p1_plataformas`.
5. ☐ Primer tramo sin checkpoint: N2 spawn→`Checkpoint2` 11,8k px (checkpoint cerca de `DialogoMurcielago` (1073,-119)); N1 spawn→`Checkpoint` (9517) ~10k px (checkpoint ≈x5000).
6. ☐ `rayo_luz.gd:41` (@tool) guarda su `modulate` animado en la escena (ruido en git): no titilar en el editor.
7. ☐ Optimización: el streaming no duerme partículas (N1 ~382 partículas de niebla/luciérnagas siempre; N2 ~174; N3 nieblas 290): gestionar `CPUParticles2D` en `streaming_zonas.gd::_recolectar`. (también N3#4)
8. (D) Anidados pendientes (editor): N1 `PlataformaFragil4/PlataformaFragil4`; N2 12 tiras de pinchos (`Pinchos17/Pinchos16/...`), en la ruta del derrumbe.

## Nivel 3
1. ☐ (= regresión 2) `CheckpointLazoOeste`.
2. ☐ `diag_checkpoints_niveles` no cubre N3 y el rayo no detecta puntos dentro de roca: agregar N3 y exigir celda vacía en `TileMap` y `Profundo`.
3. ☐ `Niebla11` (18228,15) y `Niebla20` (-2252,111) dentro de roca: moverlas o borrarlas.
4. ☐ Optimización terreno: borrar las 14 191 celdas del `TileMap` bajo bloques `Profundo` (2 369 colisiones inútiles; no se ven) y luego agrupar 3 715 bloques más → 149k → ~79k celdas (−47 %). Hacer el borrado ANTES de `hornear_bloques` (si no, aborta).
5. ☐ (D) `n3_liana` no dice cómo llegar: "Volá con el Murciélago hasta la enredadera y trepá." + `create_timer(retraso, false)` en `dialog_trigger.gd:57`.
6. ☐ Pinchos anidados en nodos ajenos (`EncounterB/Pinchos`, `EncounterB/Pinchos2` a ~3800 px de la arena; `Latido/Pinchos`): reparentar a la raíz.
7. ☐ `diag_nivel3` "fondo cubre": falso positivo (pide 1000 px de margen, hay 516) → bajar a 400.

## Jefe
- Verificado: bot completa F1→F2→interludio→F3→muerte; 8 reinicios limpios; plataformas F2 nuevas: ojos bajos/medios las 4 formas, 700 las 4, 900 sin Oso, 1080 y ventana aérea solo Murciélago (diseño cumplido).
1. ☐ (= regresión 1) slowmo del parry.
2. ☐ **Se puede pausar entre la muerte del jefe y la victoria (~3,3 s reales) y "Continuar" despausa con la victoria en curso** (`nivel_jefe.gd:16-25`): `add_to_group("victoria")` al empezar `_on_boss_died` y cerrar la pausa si quedó abierta.
3. ☐ Parry del rayo de un ojo casi encima depende de hacia dónde mirás (`lanza_estrella.gd:120`): si el rayo es casi vertical, `dir = 0`.
4. ☐ Morir en el foso tras matar al jefe: derrota y victoria se pisan (`foso_pinchos.gd:62-68`): `foso.dano = 0` en `jefe_estrella._morir()`.
5. ☐ (D) Sónico persigue ojos verdes inmunes (`projectile.gd:221-226`, cambio del compañero) y el test no lo detecta.
6. Optimizaciones: `victoria_jefe.gd:110` redibuja la silueta cada frame; `ojo_verde.gd:74-85` redibuja y busca al jugador cada frame aunque esté cerrado.

## Cámara, audio y efectos
1. ☐ (= regresión 1) slowmo.
2. ☐ (= regresión 3) opciones.
3. ☐ `Ambiente.hay_hojas` nunca es false: salen hojas verdes en lianas de cueva → `activa = false` en `noche_profunda.tscn > HojasAmbiente` (N3); N2 consultar (tiene superficie).
4. ☐ Zoom por velocidad congelado durante la arena: `_zoom_velocidad = 1.0` en `modo_arena()`.
5. ☐ Aviso de fuga al cerrar desde N2 (`ambiente_zonas.gd:69-72` borra el bus con loops sonando): no borrar el bus o parar las capas antes.
6. (D) Cámara a 60 Hz en monitores de 120/144 (sin interpolación física): `physics/common/physics_interpolation=true` + probar. COMPLICADO.
7. ☐ Optimización: luces decorativas (bajar `texture_scale` o fusionar) y niebla de partículas de N2 (bajar `amount`/`scale_amount_max`): ~1 ms cada una. Cambia el aspecto: OK del usuario.
