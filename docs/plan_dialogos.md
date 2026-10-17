# Plan: diálogos, narrativa y presentación

Estado: **borrador para aprobar** (sin código tocado). Decisiones ya tomadas por el usuario:
- Tips de controles/mecánicas salen del diálogo → aviso discreto de HUD.
- Amuleto: guía misterioso y cálido. Humano: padre preocupado, pocas líneas cargadas.
- Cantidad de narrativa se mantiene; sube la calidad (los tips se van, no cuentan).
- Visual: identidad propia por hablante; globo en el mundo para todo salvo cinemáticas (esas con caja fija).

## 1. Diagnóstico (lo que hay hoy)
- `data/dialogos.json`: ~75 entradas, todas del Amuleto salvo el cultista. ~26 son `tipo: tip` (controles/mecánicas) y hablan con la misma voz que la historia → la narrativa se diluye.
- **Duplicados**: planear (`n2_planeo`, `n3_pozo`, `n4_abismo`), trepar (`n1_zona3`, `n2_mirador`, `n3_ascenso`), Lobo (`n1_lobo`, `p1_lobo`, `n3_foso`, `n3_sala_lobo`), Murciélago/voladores (`n2_voladores`, `n2_voladores2`, `n4_murcielago`, tip hardcodeado en `player.gd:3008`).
- **Vacías**: `main_intro`, `main_tronco`, `n4_*`, `n5_*` (lineas `[]`).
- **Textos hardcodeados fuera del JSON** (rompe la regla de edición): `boss.gd` (`_hablar`, `_tip_una_vez`, ~l.237, 438-483, 652-654, 785-877), `jefe_estrella.gd:504`, `player.gd:3008`, `victoria_jefe.gd`, `comic_intro.gd`.
- **Repetición narrativa**: "tu hijo pasó" (n2_intro y n3_intro), "¿Oís eso?" (n1_bosque1, n2_aleteos), "algo respira/late" ×3. Una línea `"......"` en `n3_cultista`.
- **Voz plana**: el Amuleto da órdenes ("Cambiá…", "Usá…") en vez de acompañar; el humano casi no existe (4 líneas).
- **Visual** (`globo_dialogo.gd`): globo cómic blanco/negro, fuente `SystemFont` ("Comic Sans MS"…), TODO EN MAYÚSCULAS. Choca con el arte vectorial minimalista del juego y la fuente **puede faltar en el .exe exportado** (SystemFont). Un solo estilo para todos los hablantes.

## 2. Arco narrativo propuesto (mínimo, a confirmar)
- Hilo: padre busca a su hijo; el Amuleto sabe más de lo que dice. `victoria_jefe.gd` ya sugiere que el Amuleto se sacrifica ("Sostenelo. Yo contengo lo que queda") → sembrar pistas: cansancio del Amuleto al prestar fuerza, silencios, "el corazón" (n3) como lo que el Arzobispo necesita.
- Tratamiento: el Amuleto llama **"Humano"** al principio; tras el tutorial pasa a **"Guardián"** (ya dice "así se mueve un guardián").
- Nivel 1 bosque: esperanza + inquietud. Nivel 2 guarida: miedo, huellas. Nivel 3 cuevas antiguas: revelación (diario) y cercanía del jefe.

## 3. Guion reescrito (formato: id → líneas). `[humano]`, `[susurro]`, `[alerta]`, `[grito]` se mantienen.

**Nivel 1**
- `n1_intro` (auto): "Humano… soy el Amuleto. Dormía bajo estas raíces." / "Una secta me quiere. Se llevaron a tu hijo para llegar a mí." / "Te presto mi fuerza. Es poca, pero alcanza para empezar."
- `n1_combate`: "[alerta]Cultistas. Siempre en grupo." / "[alerta]No dejes que te rodeen." / "Cada alma que liberes vuelve a vos como aliento."
- `n1_bosque1`: "[humano][susurro]Qué silencio… ni un pájaro." / "Huyeron. Algo oscuro pasó por acá." / "[humano][susurro]Mi hijo estuvo en este camino." / "Lo sé. Su rastro sigue tibio. Caminá conmigo."
- `n1_final`: "El bosque se acaba. Adelante, la guarida." / "[humano]¿Y si llegamos tarde?" / "No vamos a llegar tarde."
- `n1_santuario`: "[susurro]Hasta las raíces callan acá."

**Nivel 2**
- `n2_intro` (auto): "La guarida. Huele a humo y a cera." / "Huellas pequeñas entre las grandes: tu hijo caminó acá." / "[susurro]Despacio. Las paredes oyen."
- `n2_aleteos`: "[susurro]Alas en la oscuridad. Nos vigilan."
- `n2_murcielago`: "Los murciélagos no nos temen. Me reconocen." / "Pedímelo y su forma es tuya."
- `n2_voladores`: "[alerta]Arqueros suspendidos en un aura corrupta." / "Tus golpes no los alcanzan. Necesitás algo que vuele."
- `n2_abismo`: "El suelo se termina. El techo, no." / "Quien vuela, cruza."
- `n2_campamento`: "[susurro]Un respiro. Aprovechalo, no habrá muchos."
- `n2_calma_d3`: "El sonido quiebra lo que la fuerza no puede." / "Probá con un grito."
- `n2_derrumbe_fin`: "[susurro]Eso estuvo cerca." / "Las lianas bajan hacia lo más hondo. Sigamos."
- `n2_final`: "El santuario está cerca." / "[susurro]Algo grande respira allá abajo."

**Nivel 3**
- `n3_intro` (auto): "Más hondo que la guarida. Esta roca es más vieja que la secta." / "[humano]Esta tela… es de mi hijo." / "Entonces vamos bien. No te detengas."
- `n3_guardian`: "[alerta]Un espíritu encadenado. Sufre." / "Vencé a sus guardias y que el Oso rompa la losa."
- `n3_cultista` (cultista): "[susurro]Shh. Soy de ellos… pero ya no." / "[susurro]No quiero este ritual. No con niños de por medio." / "[susurro]Seguí. Y no digas que me viste." — después: "Podría ser una trampa." / "[humano]Aunque lo sea. Es mi hijo." / "Entonces no hay trampa que valga. Vamos." (se elimina `"......"`)
- `n3_latido`: "[susurro]¿Lo sentís? Algo late bajo la roca."
- `n3_rastro`: "Huellas de cultistas. Bajaron hace poco." / "[susurro]Van hacia el corazón de la cueva."
- `n3_campamento`: "Un campamento vacío." / "[susurro]Huyeron de algo. No de nosotros."
- `n3_cristal`: "Una barrera sella el altar." / "Los cristales vibran: el sonido los quiebra." / "[alerta]Murciélago."
- `n3_sala` (se funde con `n3_sala_lobo`): "Dos sellos, dos formas." / "Cristales abajo, un muro alto arriba."
- `n3_madriguera`: "[susurro]Una grieta baja en el muro. Solo el Lobo pasa."
- `n3_volar`: "[humano]Tendremos que volar para esquivar esto."
- `n3_ala_oso`: "Una cámara de piedra, sellada." / "Solo la fuerza del Oso la abre."
- `n3_ala_fin`: "[susurro]El recuerdo de un Oso ancestral." / "Esperó siglos a quien lo despertara."
- `n3_diario`: "Un diario cultista, medio quemado:" / "\"El sello se debilita.\"" / "\"El Arzobispo necesita el corazón.\"" / **[opción A, a confirmar]** "[susurro]…El corazón soy yo." (Amuleto revela).
- `n3_corazon`: "[susurro]El latido se acelera." / "Estamos cerca del sello."
- `n3_aviso_continuar`: "El camino al corazón se abrió." / "Volvamos a la sala principal y rompamos esos muros."
- `n3_final`: "El sello cayó. El corazón late libre." / "Más allá espera el Arzobispo." / "[alerta]Usá todo lo que aprendiste."

**Jefe** (`jefe_intro`, marcado): "[alerta]El Arzobispo." / "Sus fieles lo cubren. Rompé su guardia, esquivá, buscá altura." / "[humano]Devolveme a mi hijo." / "[grito]¡Ahora!". Las frases de `boss.gd` (`_hablar`) se mueven al JSON con ids `jefe_*` y se acortan igual.

**Pendiente de redactar** (requiere leer antes): `comic_intro.gd`, `intro_nivel.gd`, `victoria_jefe.gd`, `eco_hijo.gd`, `totem_lobo.gd`, tutorial (`tut_*` queda como lista de tareas, solo pulir "pista/cierre").

## 4. Tips → aviso de HUD (ya no los dice el Amuleto)
- Se mantienen en JSON (`tipo: tip`), así `dialog_trigger.gd` no cambia; solo cambia cómo se dibujan.
- Se fusionan duplicados. Resultado (~12 avisos): mover cámara `{camara}`; trepar `{trepar}` (soltarse `{jump}`); cambiar forma `{forma_swap}`/`{transform}`; Lobo: doble salto/salto largo; Murciélago: mantener salto = planear, `{special}` dispara; Oso: rompe muros, las tablas no lo aguantan; parry (jefe); onda del suelo / barrido (jefe); enemigos flotantes (solo proyectiles).
- Textos de tips de nivel con "premio/atajo" (`n2_mirador`, `n3_cuenco`) se eliminan: la exploración se descubre.
- Los tips hardcodeados de `boss.gd`, `jefe_estrella.gd`, `player.gd` pasan al JSON.

## 5. Presentación visual
- **Globos en el mundo (gameplay)**: se conserva la mecánica (cola, tonos susurro/alerta/grito, esquiva HUD, modo peligro). Cambia el estilo:
  - Fuente **embebida** (.ttf en `assets/`), no SystemFont; texto en mayúscula/minúscula normal (legibilidad, acentos).
  - Paleta + borde por hablante (a definir contra la paleta real del juego): Amuleto (luz fría/ámbar, borde con runa), Humano (papel claro, sobrio), Cultista (granate), Arzobispo (dorado oscuro, angular), Hijo/eco (azul pálido).
  - Nombre/ícono del hablante solo cuando no sea Amuleto/Humano (ya existe).
  - Voz (blip) distinta por hablante (ya hay pitch Amuleto/Humano; sumar cultista/jefe).
- **Aviso HUD**: tira pequeña abajo-centro, glifo de tecla/botón + texto corto, aparece 3-4 s, se guarda en `Progresion.ayuda_vista` (ya existe) y respeta `nivel_ayuda`.
- **Cinemáticas** (`comic_intro`, `intro_nivel`, `victoria_jefe`): caja fija con el mismo set de estilos, para unificar con los globos.
- Todo valor visual como `@export` (regla de edición del proyecto).

## 6. Fases
1. **Tips**: aviso HUD + fusión + mover hardcodeados al JSON. (menor riesgo, mayor limpieza)
2. **Guion**: aplicar sección 3 al JSON (+ nuevos ids de jefe), borrar entradas vacías/obsoletas y sus triggers en `nivel*.tscn`.
3. **Estilo**: fuente, paleta por hablante, cajas de cinemática.
4. **Verificación**: `tests/diag_dialogos.gd`, `powershell -File tests/verificar.ps1 -Diag diag_dialogos`; 1 captura de globo y 1 del aviso.

## 7. A confirmar
1. ¿Opción A del diario (el Amuleto es "el corazón")? Condiciona el tono del nivel 3 y el final.
2. ¿El jefe es el cierre del nivel 3 (`nivel_jefe.tscn`)? `n2_final` ya anticipa "algo grande" y `jefe_intro` nombra al Arzobispo.
3. ¿`n4_*`, `n5_*`, `main_*` (vacías) se borran o se escriben? ¿Existen esos niveles en el alcance de 3 niveles?
4. ¿"Humano" → "Guardián" te gusta?
5. Fuente: ¿tenés alguna en mente o elijo una legible y libre (OFL)?
