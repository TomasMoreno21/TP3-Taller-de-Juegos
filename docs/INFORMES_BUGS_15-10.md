# Informes de caza de bugs — 15/10 (7 subagentes, solo lectura)

## ESTADO TRAS LA CORRECCIÓN (15/10)
**Corregido** (autotest 0; 76 diag: solo quedan los fallos viejos de abajo):
- Interfaz: UI#1 (LevelUp pausado + doble subida en `pickup.gd`), #3 (`Dialogo.limpiar()` llamado desde `TransicionPantalla.cambiar_escena` y `Progresion.reset()`, `lista_tareas.vaciar()`), #4 (`_get_jugador()` conecta señales), #5 (grupo "victoria" + guardia en `pause.gd`), #6 (`Progresion.almas_recogidas`), #7/#8 (textos), #9 (`muertes`).
- Enemigos: #1 (`Encounter._agregar_manual` sube `limite_caida`), #2/#3/#4 (`preparar_ola`), #5 (`antesala.gd` altura).
- Jugador: #2 step-up, #3 empuje del bloqueo, #4 imán melee sin voladores, #6 sónico pegado a pared, #7 ataque colgado en cinemática, #8 onda vs voladores, #9 energía congelada en charla/muerte, #12 `health_changed` al caer.
- Cámara/audio: #3 `modo_normal(true)` limpia estado, #4 slowmo (`hitstop.gd`; arregla también jefe#8), #5 `hojas_ambiente`, #6 guardado diferido de opciones (`diag_opciones` espera 0,8 s), #7 `Ambiente` resetea tensión al cambiar de escena, #9 tween del cultista.
- Jefe: #1 plataformas F2 (±1150,-200 / ±650,-420), #3 orbes ("orbe_jefe"), #7 `_ventana_t`, tests viejos (`diag_fase2`, `diag_ojos_oso`, `diag_muro_especial`).
- Niveles: checkpoints nuevos (N1 `CheckpointSubsueloFinal` (21500,5784); N2 `CheckpointAntesDerrumbe` (5100,3496); N3 `CheckpointZ2` (5400,1264), `CheckpointZ4` (8800,4050), `CheckpointLazoOeste` (-3150,4104)); nodos anidados reparentados (N1 `Checkpoint4b`, N2 `VidaMiradorB`, `VidaCampamentoB`); N1 decoración enterrada borrada (`Pasto14`, `Pasto55`, `Piedra60`) y `Pinchos_20` +60 px; N3 `AtmosferaNivel3` en (0,0), `ObjetivoSello.origen = ../MuroDerrumbe`, `limit_bottom = 6928`; `diag_nivel2` ignora pinchos rotados.

**Dejado para verlo después** (diseño/complicado/sin verificar): cruceta del mando (UI#2/Jugador#1); saltos al transformarse en el aire; parry de proyectiles; jump cut del aleteo; Encounter D `ArenaShape` (el usuario lo está editando); orbe de vida de voladores; N3 `Profundo` superpuesto (re-agrupar); `modo_arena` salta 363 px; techo F2 del jefe; sónico imantado a ojos verdes (confirmar con el autor); F3 rampa y final a créditos; enredaderas/Enredadera2 de N3, nodos anidados de pinchos y `PlataformaFragil4` de N1 (tiene hijos); decorados fuera de lugar de N2 y decoración flotante de N3; enemigos incrustados 2-34 px; progresión 49/48 orbes; latido/diálogos n3_* sin trigger; `pinchos30` en dos; `diag_nivel3` desactualizado; `diag_colision_enterrada` NIVEL=3 (artefacto); `diag_eco_hijo` (N1 ya no tiene `EcoHijo`: falta verlo con el usuario); `diag_rampa_pixel` y `diag_sync_golpes` (fallos viejos).

---
Estado original: **PENDIENTE DE CORREGIR** (el usuario pidió guardarlos y corregir cuando se restablezca el límite de uso).
Regla acordada: arreglar todo lo SIMPLE sin preguntar; lo COMPLICADO / decisión de diseño se deja anotado y se ve después.
Antes de tocar `player.gd`, `projectile.gd`, `nivel1.tscn`, `nivel_jefe.tscn`: están modificados en el working tree por otros (el usuario/compañeros); releer y no pisar. Borrar siempre los `tests/tmp_*` que se creen.

## Ya aplicado en esta sesión (antes de la interrupción)
- `scripts/levelup.gd::cerrar()`: si `abrir()` no abre panel (sin forma elegible), ahora despausa (antes quedaba pausado). (UI#1)
- `scripts/player.gd::_try_step_up`: usa `dir_mov` (dirección real: velocity.x o input) en vez de `facing`. (Jugador#2)
- Antes en la sesión: `enemy.gd` (orbe de vida diferido con `call_deferred`, sin `move_and_slide` en la pausa de impacto), `tests/diag_colision_enterrada.gd` (cuenta bloques `Profundo` como roca).
- NO aplicados (el usuario rechazó el lote): items marcados abajo con ☐.

---
## 1. Interfaz y flujo
1. ✔ Softlock LevelUp pausado sin panel (`levelup.gd:66-72`). Además `forzar_subida` puede sumar otra subida al cruzar el umbral (nivel 4 dentro del N2): hacer que `forzar_subida` no sume si `add_fragmentos(1)` ya subió. ☐ (parte 2)
2. ☐ **Cruceta del mando mueve y transforma a la vez** (`project.godot` botones 11-14 en `move_*` y `forma_*`). DECISIÓN DE DISEÑO: se dejó pendiente. Propuesta: quitar la cruceta de `move_*` (el stick mueve; la cruceta transforma, como en `_handle_formas_cruceta`) y corregir el texto de Controles. Ojo: recargar proyecto en el editor antes de guardar.
3. ☐ `Dialogo` no se limpia al cambiar de escena (`dialogo.gd`; `pause._volver_menu`, `victoria*.gd`): agregar `Dialogo.limpiar()` (vaciar `_cola`, `_en_espera`, `_item`, `_fase=LIBRE`, ocultar globo/gema, `ancla_hablante=null`, vaciar lista) y llamarla desde `Progresion.reset()` y antes de volver al menú.
4. ☐ `Dialogo` no conecta señales del jugador (`dialogo.gd:410-413, 493-495, 537`): helper `_get_jugador()` que llame `_conectar_jugador()`. Consecuencia: nunca se emite `accion_hecha` de golpe/parry/transformar; el globo no espera calma tras daño.
5. ☐ Esc durante final/victoria despausa el mundo (`pause.gd:55-60, 96-100`; `nivel_jefe.gd`, `santuario.gd`): grupo "victoria" en `victoria.gd` y `victoria_jefe.gd` + guardia en `pause.gd::_unhandled_input`. (También jefe#7)
6. ☐ **Reiniciar nivel / reintentar duplica fragmentos** (`pickup.gd:150-159`, `progresion.gd`; `derrota.gd:90`, `pause.gd:171`, `player.gd:2561` usan `reload_current_scene`). Rompe umbrales `[8,28,34,48]`. Arreglo: `Progresion.almas_recogidas` (se limpia en `reset()`), clave `scene_file_path + get_path()`; en `pickup._ready` `queue_free()` si ya recogida; marcar en `_recoger`. (Niveles#2) — COMPLICADO-medio.
7. ☐ Controles con datos falsos (`controls.tscn:114-130`): dice "A / D · ← →" pero flechas no mueven; "Picada: S / ↓"; no menciona LT/RT.
8. ☐ Hints "A elegir" con teclado (`levelup.tscn:84`, `main_menu.tscn:180`, `pause.tscn:196`): mostrar "Enter" si no es joypad.
9. ☐ `Progresion.muertes` nunca se incrementa (sumar en `player._handle_death` o borrar).
- Sin verificar: `tutorial_paso.activar` podría colgarse si una charla en `_en_espera` vence 30 s; `mejoras_diferidas` no se canjea en el jefe.

## 2. Enemigos y encuentros
1. ☐ **N2 `EncuentroGuardia`: 6 enemigos mueren en el primer frame** (`limite_caida` 6000 con y≈7000; nodos `Expansion/E/EncuentroGuardia/Enemy`, `Enemy2..6`). Arreglo robusto: en `Encounter._agregar_manual` → `e.limite_caida = maxf(e.limite_caida, e.global_position.y + 1500.0)`; o `limite_caida=9500` en los 6 nodos. (N1 `EncounterE` en y≈5930 con margen 65 px: frágil.) ALTA
2. ☐ `Enemy.preparar_ola` no resetea `_telegraph_timer` etc. (`enemy.gd:245`): tras `reiniciar()` en pleno ritual el enemigo queda activo con la arena INACTIVE. Resetear `_telegraph_timer=0, _windup_timer=0, _lunge_timer=0, _windup_disparo=0, _stun_timer=0`, `_cancelar_aviso()`, liberar `_ritual`.
3. ☐ Enemigo oculto/inactivo conserva `velocity` y deriva (`enemy.gd:547-551`): `velocity = Vector2.ZERO` en `preparar_ola` y al inicio de la rama `not _activo`.
4. ☐ Aura del volador visible sin enemigo tras reiniciar: ocultar `_aura` en `preparar_ola`, mostrarla en `activar()`.
5. ☐ `antesala.gd:56`: ignora la altura (viñeta/silencio por arenas a miles de px): `if absf(jugador.y - _enc.arena_center.y) > 900: return 0.0`.
6. ☐ N3 `Encounter D`: `ArenaShape` muy alta para el piso más bajo (arena_center.y 2848, base 3098; pisos en 3296-3505): agrandar el rect hasta y≈3550. (cambio de escena)
7. ☐ Orbe de vida del volador puede quedar a ≈660 px sobre el piso (fuera de alcance): sumar la altura elevada. (estimado)
- Latentes (olas vacías hoy): spawn automático usa `arena_center.y` y no soporta voladores. Olas vacías en medio: N2 EncuentroGuardia ola 2, N3 Guardian/Guardian2 ola 0.

## 3. Jugador y formas
1. ☐ (= UI#2) cruceta.
2. ✔ Step-up usa `facing` (aplicado).
3. ☐ Empuje al bloquear va hacia el enemigo (`player.gd:2592`): `velocity.x = dir * bloqueo_empuje` (quitar el signo).
4. ☐ Imán del melee apunta a voladores (`player.gd:1095, 1112, 922` vía `_buscar_enemigo_homing`): parámetro `melee := false` que salte `flotante == true`.
5. ☐ Transformarse en el aire devuelve los saltos (`player.gd:1892, 1906` → `reset_form_state`). DISEÑO: decidir cuántos saltos; código: `if not is_on_floor(): data.perder_salto_suelo()`.
6. ☐ Sónico del Murciélago atraviesa pared si estás pegado a ≤5 px (`player.gd:2947`, `projectile.gd:154`): si `Projectile.linea_libre(self, centro_cuerpo, pos_proyectil)` es falso, instanciarlo en el centro del cuerpo.
7. ☐ Cinemática que empieza en pleno ataque deja `_attacking` colgado (`player.gd:792`): en la rama `dialogo_bloquea` llamar `_cancelar_recuperacion(true)` si `_attacking`.
8. ☐ `onda_area` rebota contra voladores y empuja al jugador (`player.gd:2704-2717`): `continue` si `flotante` y `solo_proyectil`.
9. ☐ Energía se gasta en diálogos y animación de muerte (`player.gd:1736-1740`): congelar con `cinematica_activa or _derrota_activa or _dialogo_bloquea_input()`.
10. ☐ Parry de proyectiles ignora el lado/invulnerabilidad (`projectile.gd:245`). DISEÑO.
11. ☐ Jump cut recorta el aleteo del Murciélago (`player.gd:641-643`), dudoso/intencional.
12. ☐ Caer al vacío: `health=0` sin `health_changed.emit` (`player.gd:806`).
13. ☐ Lambdas de timers capturan al jugador (`player.gd:1285, 2693`): guardia `is_instance_valid`.
- Menores: `hud_dial.gd:23` `cooldown_total=3.0` vs `COOLDOWN_AGOTADA=2.0`; mantener L con Murciélago repite `_try_interact`; `is_gliding` lee Input crudo; `_checkpoint_vida` sin uso; `goteo_techo.gd:59` warning de normalizar vector no finito; Oso en bucle da AoE gratis (diseño).

## 4. Cámara, audio y efectos
1. ☐ N3: capa `Profundo` se superpone y toca aire (`nivel3.tscn` `TileMap/Profundo`: 14191 subceldas dentro de bloques, 2369 con colisión; 583 bloques tocan aire). COMPLICADO: re-agrupar N3 con `tools/hornear_bloques.gd` (sin bloques bajo tiles de superficie/junto al aire); además `terreno_mundo.gd:61-67` comparar x e y contra el rect.
2. ☐ La cámara salta ~363 px al empezar cada arena (`camera.gd:316`, `modo_arena` pone `global_position`). Quitar la línea si el corte no es intencional (probable DISEÑO).
3. ☐ `modo_normal(true)` no limpia estado viejo (`camera.gd:347-362, 132, 352`): resetear `_apex_look`, `_piso_extra`, `_offset_descenso`, `_mirar_abajo_extra`, `_punch_scale`, `_shake_timer`, `_tilt`, `rotation`; línea 352 mirar `_escala_tween`.
4. ☐ Slowmo débil pisa a uno fuerte (`hitstop.gd:49-53`): `_slow_scale = minf(...)` si hay uno activo.
5. ☐ `hojas_ambiente.gd:63` `current_scene.add_child` revienta si no es current_scene (solo tests).
6. ☐ Opciones escribe a disco en cada tick del slider (`opciones.gd:37-47`, `opciones_panel.gd:22`): guardar en `drag_ended`/al cerrar.
7. ☐ Tensión del autoload `Ambiente` sobrevive a recargar nivel (`ambiente.gd:26, 34`): resetear `tension=0`, `hay_hojas=true` al cambiar/recargar escena.
8. ☐ `nivel_jefe.tscn` sin Noche ni ambiente sonoro (probable diseño).
9. ☐ `cultista_arrepentido.gd`: guardar `tw_cam` en miembro y matarlo en `_entregar_control`.
- Verificado limpio: consola de N1/N2/N3/jefe/menús, fugas de nodos, hitstop vuelve a 1, NodePaths, uniforms de shaders, buses.

## 5. Jefe y su sala
1. ☐ **Regresión de merge: plataformas F2 vueltas atrás** (`jefe_estrella.tscn:182,198,214,230`): deben ser (±1150,-200) y (±650,-420) ("pocas y altas", pedido del usuario 15/10, ver MEMORY.md); hoy (±1000,-250)/(±650,-380). Comentario en `jefe_estrella.gd:78` dice 420.
2. ☐ Techo F2: Collision/Visual asimétricos y fuera de cámara (`jefe_estrella.tscn:161-178`; test asume 940/1520). DECISIÓN con el usuario.
3. ☐ Orbes de vida del jefe se acumulan tras reiniciar (`jefe_estrella.gd:697-707`): grupo "orbe_jefe" y liberarlos en `preparar_ola`.
4. ☐ Pausar durante la victoria (= UI#5).
5. ☐ Cámara lenta de la muerte sale a 0.4 y no 0.2 (`jefe_estrella.gd:1146`, `encounter.gd:285,296-299`): mover `_slowmo(2.6, 0.2)` después de `died.emit()`.
6. ☐ Sónico imantado a ojos verdes abiertos (`projectile.gd:221-226`, cambio sin commit ajeno): contradice la decisión 14/10 (cerrarlos cuerpo a cuerpo). CONFIRMAR con el autor antes de borrar esas 6 líneas.
7. ☐ `_ventana_t` obsoleto → parpadeo/temblor falsos (`jefe_estrella.gd:404-411, 215-243`): `_ventana_t = 0.0` en `preparar_ola` y antes de asignar `_estado` en castigo/ventana_aérea.
8. ☐ La F3 reinicia la rampa (`_transicion_fase`, `jefe_estrella.gd:676`): DISEÑO. Final vuelve al menú, no a créditos (`victoria_jefe.gd:44`): DISEÑO. `enemy_data` del jefe sin efecto; `Cabeza`/`Nucleo` no coinciden con `_pintar` (cosmético).
9. Tests viejos: `diag_fase2` (poner `p.energia = 1.0`, `tests/diag_fase2.gd:53-56`), `diag_ojos_oso` (los ojos del Humano ya arrancan visibles: invertir el check), `diag_muro_especial` (`print` sin `is_instance_valid(muro)`, `:34`, se cuelga).
- Código muerto: `boss.gd`, `jefe.tscn`, `zona_jefe.gd`, `ataque_jefe.*` ya no se instancian (solo tests obsoletos).
- Descartado: la lógica del jefe es sólida (bot jugó F1→F2→interludio→F3→muerte, 7 reinicios limpios).

## 6. Niveles 1 y 2
- Terreno agrupado en bloques: verificado sin huecos ni diferencias (0 celdas cambiadas).
1. ☐ (= Enemigos#1) 6 enemigos de la guardia final de N2 nacen muertos.
2. ☐ (= UI#6) fragmentos duplicados al reintentar (N1 `Pickup2/3` antes del primer checkpoint x=9517; N2 "Reiniciar nivel" +17).
3. ☐ N1: ~20 000 px sin checkpoint en el subsuelo (entre `Checkpoint4` (26711,2407) y el anidado (18444,5832)) y ~13 700 px hasta la salida: agregar `Checkpoint` ≈(15700,3300) y ≈(21500,5900); validar piso (`_hay_piso_bajo`).
4. ☐ N2 zona C: ~10 800 px sin checkpoint (desde `CheckpointAbismo1` (1536,3492) hasta `FinDerrumbe` (12325,2747)): `Checkpoint` ≈(5000-5300, 3472) antes de `DisparadorDerrumbe`.
5. ☐ Nodos anidados por error en el editor (arreglar en el editor con Reparent + Keep Global Transform): N1 `Checkpoint4/Checkpoint4`, `PlataformaFragil4/PlataformaFragil4`; N2 `Expansion/A/PremioMirador1/VidaMirador`, `Expansion/D/VidaCampamento/VidaCampamento`, varias tiras `Pinchos` anidadas (`Pinchos17/Pinchos16/Pinchos16/Pinchos15`, `Pinchos13/Pinchos15`). Efecto: el hijo se duerme con el padre (streaming) y se libera con él.
6. ☐ `diag_nivel2` "Pinchos asentado -75 px": falso positivo del test (pinchos rotados -66.8°; lanzar el rayo en `n.global_transform.y` o saltear rotación > 0.2).
7. ☐ `diag_nivel2` 8 decorados fuera de lugar (reales, menores): D27, D33, D44, D54 (anclas 16-30 px dentro del techo), D38 (estalactita sobre roca de piso, (1088,3712)), D45 (6002,3704), D50 (10585,6239), D53 (10751,5198, invisible).
8. ☐ N1 decoración enterrada (borrar): `Decoracion/Pasto14` (12093,6150), `Pasto55` (27448,5638), `Piedra60` (32925,2054).
9. ☐ Diálogos huérfanos en `dialogos.json` (sin trigger): `n1_intro`, `n1_santuario`, `n1_zona2`, `n2_intro`, `n2_aleteos`, `n2_planeo`, `n2_mirador`, `n2_pozo`, `p1_plataformas` (¿tutorial de planeo/aleteo del Murciélago quedó sin trigger en N2?). `diag_nivel2` los exige.
10. ☐ N1 `Pinchos/Subsuelo_A/Pinchos_20` (15717,3311): 3 de 6 pinchos dentro de pared; correr ~60 px a la derecha.
11. ☐ `diag_checkpoints_niveles` solo recorre hijos directos de la raíz (no cubre N1 ni `Expansion/*/Checkpoint*`).
- Latente: `terreno.gd::_en_profunda` cuenta los bloques planos de N2 como roca: al re-hornear en el editor podría perderse colisión de borde.

## 7. Nivel 3
- Completable con las 4 formas (modelo de alcance propio); el terreno horneado marcado por `diag_colision_enterrada` NIVEL=3 es artefacto del test (bolsillos sellados), no bug de colisión → arreglar el test contando solo celdas adyacentes a aire alcanzable desde el spawn.
1. ☐ **`AtmosferaNivel3` desplazado** (`nivel3.tscn:~1688`, pos (412,1251), cambió de (-312,487) en el commit fdb323c): luces/nieblas en roca o bajo el terreno (9 de 31 en roca, 4 bajo el mapa). `LuzEstatuaOso` local (331,4666) cae sobre `UnlockOso` (331,4866) con offset 0 → poner `position = Vector2(0,0)`. Ojo: `tests/diag_nieblas.gd` usa posiciones locales como mundo (consistente con offset 0).
2. ☐ Tramo obligatorio arena Guardián → chimenea exige ≥832 px de ascenso con aleteo del Murciélago sin pista (`Enredadera2` (5926,2848) cuelga 704 px sobre el piso; solo el Humano trepa y salta ~190). Arreglo recomendado: bajar `Enredadera2` a y≈4050 o `alto`≈2700; o `dialog_trigger` en ~(5900,4200) con pista de volar. COMPLICADO (diseño).
3. ☐ `ObjetivoSello` nunca aparece (`nivel3.tscn:739`): sin `origen` → `origen = NodePath("../MuroDerrumbe")`, `senal = &"roto"` (o el muro que corresponda). Es la única guía de que el Oso rompe muros.
4. ☐ Sin checkpoint antes de arenas/tramos largos: spawn (512,639) → `CheckpointInicio` (10120,1296) (~9600 px, con `EncounterA` en medio); `CheckpointCaida` (14621,3852) → `EncounterGuardian` (~8200 px); `CheckpointZ7c` → `CheckpointMadriguera2` (~6700 px, ≥12 pinchos); `CheckpointMadriguera2` → `CheckpointPostGuardian` (~4700 px). Agregar ≈(5400,1300), ≈(8800,4350), ≈(-3000,4300); validar piso (`checkpoint.gd` ray 400 px).
5. ☐ Progresión 4→5 con margen de 1 orbe: N3 tiene 21 almas (no 23): 11+17+21 = 49 vs umbral 48. Agregar 2 `Pickup`, bajar `FRAGMENTOS_NIVEL[3]` a 46, o corregir comentarios/MEMORY/CLAUDE.md. DISEÑO (balance).
6. ☐ Enredaderas inalcanzables (cuelgan 650-970 px sobre el piso): Enredadera2, 4 (9618,5302), 5 (11481,5325), 6 (10923,5178); la principal (20485,2745) a 536 px. Bajar `y`/subir `alto` o borrar. DISEÑO.
7. ☐ Enemigos de arena incrustados 2-34 px en el piso (EncounterA/Enemy1,2; EncounterGuardian/*; EncounterB/*; Encounter D/Enemy, Enemy6, Enemy7, Enemy10; Enemy4 y 5 apilados ≈(-5298,2446)). Godot despenetra solo; subir `position.y`.
8. ☐ Latido/atmósfera sin cubrir la mitad inferior (los 6 `zona_latido` en y<3040); ~20 ids `n3_*` sin trigger (n3_cristal, n3_sala, n3_guardian —habla de una losa que ya no existe—, n3_ascenso, n3_pozo...). Solo se usan n3_rastro, n3_volar, n3_aviso_continuar, n3_cultista.
9. ☐ `limit_bottom` de cámara 7232 pasa 304 px del terreno (fin 6928): `limit_bottom = 6928` (`nivel3.tscn:82`).
10. ☐ `Pinchos30` (14984,6477, cantidad 110 → 4400 px) se duerme por streaming en los últimos ~400 px: partir en dos nodos.
11. ☐ Decoración flotando: DH2 (-1793,5046), DH7 (9716,3544), DH12 (18459,2685), DH13 (10213,2841), DR8 (11659,2080), D25 (7360,5958), D26 (6202,4415), D36 (574,1968), D41 (8266,2786), D42 (8369,2031).
- `diag_nivel3` (17 fallos): 14 son checks desactualizados (datos de `tests/nivel3_datos.json` del diseño anterior: checkpoints ≥18, arenas/enemigos 25, almas ≥45, compuerta con losa, `Santuario` ahora en `Latido/Santuario`, barrera rotada, camino principal...), 3 reales menores (límites de cámara #9, enemigos apoyados #7, decoración #11).
- Descartado: muros/barreras sellan piso a techo; sin pinchos sobre checkpoints/pickups/altar/salida; la salida funciona; plataformas frágiles intencionales.
