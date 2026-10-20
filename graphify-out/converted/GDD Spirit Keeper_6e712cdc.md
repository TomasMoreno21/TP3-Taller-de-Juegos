<!-- converted from GDD Spirit Keeper.docx -->


GDD (Game Design Document)
Spirit Keeper
Alumnos:
Córdoba, Micaela Alejandra - 47763620
Hereñú, Franco
Moreno, Tomás Matías - 47583852
Universidad Nacional de Rafaela (UNRaf)
Materia: Taller de Producción de Videojuegos 2
Docentes:
Nazzetta, Sebastián
Porello, Diego
## Índice
Diagrama de flujo --------------------------------------------- 3
Descripción, Resumen y Core loop -------------------------- 4
Pilares de diseño --------------------------------------------- 5
Niveles y Narrativa ------------------------------------------ 5
Controles ------------------------------------------------------- 7
Gameplay -------------------------------------------------------- 7
Formas (personajes) y Enemigos ---------------------------- 8
Progresión y Energía ----------------------------------------- 9
Jefe final ----------------------------------------------------- 9
Sistema de dificultad progresiva -------------------------- 10
Apartado Visual ----------------------------------------------- 10
Efectos visuales (FX) y Audio ------------------------------ 11
Datos Adicionales --------------------------------------------- 11
Público objetivo ---------------------------------------------- 11

## Descripción
Spirit Keeper es un videojuego de acción y plataformas 2D con vista lateral, en el cual el jugador controla a un padre que se interna en un bosque corrupto para rescatar a su hijo, secuestrado por una secta. Un amuleto con espíritus guardianes le presta tres transformaciones (Lobo, Murciélago y Oso) y cada una cambia la forma de moverse, pelear y resolver obstáculos.
Género: Acción / Plataformas 2D (side-scroller)
Ambientación: Bosque corrupto, cuevas y guarida de una secta
Inspiraciones: Ben 10: Alien Force (referencia mecánica), Hollow Knight (jefe y atmósfera)
## Resumen
El jugador comienza como el Humano, una forma débil pero técnica (bloquea y hace parry). A medida que avanza encuentra tótems que despiertan a los espíritus del amuleto y le otorgan nuevas formas. Cada forma abre ciertos caminos: el doble salto del Lobo, el planeo y el disparo sónico del Murciélago, la fuerza del Oso.
Transformarse consume energía, que se recarga recogiendo almas y venciendo enemigos. Con los fragmentos que junta sube de nivel y elige el combo de una de sus formas. El juego tiene un final: la pelea contra el Arzobispo, jefe de la secta, que exige usar todas las formas aprendidas para liberar al hijo.
## Core Loop

## Pilares de diseño
Cada forma importa: las formas no son skins: cambian el movimiento, el combate y qué obstáculos se pueden superar. La pregunta central es siempre qué forma conviene usar.
Enseñar antes de exigir: cada habilidad nueva se presenta en un espacio seguro y se usa una o dos veces antes de exigirla para avanzar.
Feedback: toda acción del jugador conlleva a su respectiva respuesta inmediata, sea visual o sonora, con el fin de brindar una buena experiencia.
## Niveles y Narrativa
Historia: un padre y su hijo pasaban la tarde juntos cuando unas voces extrañas llamaron al niño desde la espesura. El padre lo siguió dentro del bosque y quedó solo. Allí aparece el amuleto de los espíritus: “Humano… por fin alguien me encuentra. Juntos podremos salvarlo.” El juego abre con un cómic de seis viñetas que cuenta este comienzo.

Cómic de inicio
Final: al vencer al Arzobispo el sello cede y el hijo emerge de la luz. Padre y Amuleto dialogan brevemente, corte a negro y aparece la frase final: “Lo que el bosque se llevó, el bosque lo devuelve.” Antes de los créditos, un segundo cómic de seis viñetas muestra el estallido de la estrella, el reencuentro y la confesión del niño.

Cómic final
Cinemáticas: el cómic de inicio y el final, la intro de cada nivel, la cinemática de cada tótem (el sello viaja al jugador y aparece la tarjeta de la forma) y las del jefe (aparición y estallido final). Todas ocurren dentro del juego, sin cortar el ritmo.
El juego tiene 3 niveles y un nivel de jefe, todos lineales y con checkpoints:
- Nivel 1 - El Bosque - tutorial. Movimiento, combate, bloqueo y parry del Humano. Termina en una cueva donde está el tótem del Lobo; la salida es una zona de oscuridad con el nombre del siguiente nivel.
- Nivel 2 - Las Cuevas - cueva natural. Se desbloquea el Murciélago (planeo, aleteo, picada y sónico). Barreras de cristal, pinchos, un derrumbe y enemigos voladores
- Nivel 3 - El Latido - cueva profunda donde late el corazón del sello. Se desbloquea el Oso. El latido de la luz se acelera hacia el sello; hay puzzles que combinan las tres formas y rutas opcionales.
- Jefe - El Santuario - arena de la secta. Pelea contra el Arzobispo en 3 fases, con cinemáticas de entrada y de muerte.
| El Bosque | Las Cuevas | El Latido |
| --- | --- | --- |
| Tótem del Lobo | Tótem del Murciélago | Tótem del Oso |
Cada nivel arranca con una intro in-game (diálogo Humano-Amuleto) y un título de nivel. Todos los textos del juego están en español.
## Controles
El juego está diseñado para PC y se controla con teclado o mando. Los controles son los mismos en todas las formas:
- Mover - A / D (mando: stick izquierdo).
- Cámara - flechas (mando: stick derecho).
- Saltar - Espacio (mando: A).
- Golpe / Golpe fuerte / Especial e interactuar - J / K / L (mando: X / Y / B).
- Bloquear y parry (Humano) - Shift (mando: LB), justo al recibir el golpe para hacer parry.
- Aleteo y picada (Murciélago) - Espacio en el aire y S en el aire (mando: A en el aire y stick hacia abajo).
- Elegir forma - Q / E (mando: LT o Select / RT).
- Transformar o volver a Humano - T (mando: RB).
- Transformar directo - 1 Humano / 2 Lobo / 3 Oso / 4 Murciélago (mando, cruceta: izquierda Oso, derecha Lobo, arriba Murciélago, abajo Humano).
- Adelantar diálogo - Enter (mando: L3).
- Omitir cinemática o intro - X, manteniéndola presionada.
- Pausa - Esc (mando: Start).
Combo: golpe ligero seguido de golpe fuerte (J, K). El juego guarda la segunda pulsación para que no se exija precisión extrema.
## Gameplay
Movimiento: el jugador recorre el nivel de izquierda a derecha con salto, coyote time y buffer de salto. Cada forma tiene inercia y peso propios.
Combate: golpe ligero, fuerte y especial. Ligero + fuerte ejecuta el combo de la forma. El Humano bloquea (solo de frente) y puede hacer parry con el timing justo, que devuelve proyectiles y da energía.
Vida: las cuatro formas comparten una única barra de vida (100). Los orbes de vida curan 24.
Arenas: al entrar a una zona de combate se cierran las paredes y aparecen oleadas de enemigos. Al vencerlas se abre el camino.


Puzzles por forma: los obstáculos muestran el símbolo de la forma necesaria:
- Lobo - enredaderas y muros trepables, túneles bajos.
- Murciélago - cristales de barrera que solo rompe el proyectil sónico.
- Oso - losas de peso y muros de piedra que solo él rompe o activa.
Peligros: pinchos, pozos, plataformas frágiles y derrumbes.
Muerte y reaparición: al morir se reaparece en el último checkpoint (santuario) del nivel. No hay límite de intentos.
## Formas (personajes)
Contamos con 4 formas jugables que comparten la vida, pero tienen estadísticas distintas que afectan el gameplay:
|  | Humano: Base (vel. 600, daño 8/14/24) - Forma inicial. Bloquea y hace parry. Combo: Remate. |
| --- | --- |
|  | Lobo: Veloz (vel. 690, daño 8/13/26) - Doble salto, trepa muros y cruza túneles bajos. Combo: Embestida. |
|  | Murciélago: Aéreo (vel. 420, daño 9/14/15) - Planea, aletea, pica hacia abajo y dispara un proyectil sónico que rompe cristales. Combo: Ala Cortante. |
|  | Oso: Pesado (vel. 350, daño 16/24/32) - Lento pero devastador. Activa losas de peso y rompe muros de piedra. Combo: Garra. |
Transformarse requiere al menos 25 de energía. La forma drena 4 de energía por segundo (menos fuera de las arenas) y al llegar a 0 el jugador vuelve a Humano.
Además, contamos con un NPC:
Amuleto: el collar de los espíritus acompaña al jugador con globos de diálogo: cuenta la historia, aconseja y reacciona a lo que ocurre.

### Enemigos
|  | Cultista: vida 75, daño 10 - Cuerpo a cuerpo. Persigue al jugador, se prepara con una anticipación visible y se lanza con un tajo. Máximo 2 atacando a la vez. |
| --- | --- |
|  | Arquero: vida 60, daño 12 - Dispara proyectiles desde lejos y retrocede si lo acorralan. En niveles avanzados aparece flotando sobre un aura mística y recibe más daño del sónico. |
Los ataques enemigos se telegrafían con un destello y un breve retroceso, para que el jugador pueda leerlos y reaccionar.
## Progresión y Energía
Formas: Humano y Lobo desde el Nivel 1; el Murciélago se desbloquea en el Nivel 2 y el Oso en el Nivel 3, con un tótem y una pequeña cinemática en cada uno.
Fragmentos: orbes repartidos por los niveles. Al acumular 8, 28, 34 y 46 el jugador sube de nivel y elige la forma cuyo combo desbloquea (un combo por forma).
Energía: se gasta al transformarse (4 por segundo) y se recarga con almas de energía, enemigos derrotados y parrys exitosos.
## Jefe final
|  | Arzobispo: vida 450 (150 por fase) - Líder de la secta, ya transformado: una estrella de siete puntas con un ojo central, unida al piso por un tallo. La cabeza nunca se rompe: la vida se lee en el ojo, que se llena de venas al recibir daño. Solo se lo daña cuando muestra el ojo, y cada fase pide una forma distinta. Al derrotarlo, el niño sale de adentro de él. |
| --- | --- |
- Fase 1 - los ojos satélite disparan rayos con aviso, que el Humano puede devolver con parry. El Oso debe romper con un golpe fuerte el círculo del nudo del tallo para bajar el ojo central y poder dañarlo.
- Fase 2 - la sala se abre con plataformas a los lados y ojos flotantes por tandas a distintas alturas: el Lobo y el Humano alcanzan los bajos y el Murciélago los altos (su sónico los cierra). Las torretas acorazadas solo las rompe el Oso. Hay rayos finos y un rayo grueso que se esquiva o se devuelve con parry.
- Fase 3 - la estrella se arranca del tallo y se clava de punta; absorbe a tres cultistas y ataca en combos (picada, embestida, orbes y estalactitas). Al agotarse cierra el ojo tras un caparazón que solo el Oso rompe, y a veces el niño aparece como escudo: ahí el padre no debe atacar.
Cambia de fase al bajar de 66 % y de 33 % de vida: más ataques y el latido de la sala se acelera. Al cambiar de fase aparece un orbe de vida, y durante la pelea la energía se gasta mucho más lento (“el Amuleto arde”). Entre ataques hay valles para respirar.
Entrada: el jefe no se muestra de entrada; al llegar a la arena emerge desde atrás y abajo, temblando, entre polvo y piedras del techo. Muerte: estalla en grietas de luz, corte a blanco y negro y comienza el cómic final.
| El Arzobispo, fase 1 | Fase 2: ojos y rayos |
| --- | --- |
## Sistema de dificultad progresiva
La dificultad escala conforme se avanza en los niveles:
- El Bosque (nivel 1): tutorial. Pocos enemigos, sin presión, y se enseña el Lobo.
- Las Cuevas (nivel 2): aparecen la oscuridad y los enemigos voladores; el Murciélago es la llave.
- El Latido (nivel 3): el nivel más largo y vertical, con más arenas, rutas opcionales y puzzles que combinan las tres formas.
- El Santuario (jefe): exige dominar todas las formas, el parry y la gestión de energía.
Los niveles alternan combate, plataformeo y puzzles, con espacios de respiro entre arenas. La dificultad está diseñada para que el jugador sienta progreso sin llegar a ser frustrante.
## Apartado Visual
Utilizamos un estilo 2D ilustrado, con colores planos y siluetas claras, para todos los elementos visuales del juego:
- Personajes - sprites animados cuadro a cuadro (reposo, correr, saltar, ataques y daño). Cada forma tiene un tamaño distinto para reforzar su identidad.
- Fondos - parallax scrolling con capas por nivel (bosque, cueva natural y cueva profunda), más luciérnagas, niebla, rayos de luz y polvo de cueva.
- Interfaz - menú principal con el logo dibujado a mano y la luna, pausa, controles, opciones, créditos, derrota y victoria. Los cómics de inicio y final usan viñetas en blanco y negro con globos de texto.
- HUD - arriba a la izquierda el retrato del Amuleto con la barra de vida (roja) y la de energía de transformación; el selector de formas, los fragmentos acumulados y una pila de golpes de combo aparecen cuando corresponde.
- Textos - colores funcionales: verde para el bosque y lo vivo, azul y violeta para la cueva profunda, rojo para el peligro y el jefe.
| HUD en partida | Menú principal | Pantalla de controles |
| --- | --- | --- |
### Efectos visuales (FX)
- Hitstop y screen shake - temblor de cámara y pausa breve al golpear, aterrizar y cambiar de fase del jefe.
- Telegrafía de ataques - destello y retroceso del enemigo antes de pegar.
- Transformación - onda expansiva y ráfaga de partículas al cambiar de forma.
- Squash & stretch - achatado al aterrizar y estirado al saltar.
- Parry - destello y efecto blanco y negro al desviar un golpe justo.
- Latido de la cueva - la luz del nivel 3 pulsa y se tiñe según la zona, con venas luminosas.
- Jefe - grietas de luz y cámara lenta al cambiar de fase; estallido final.
### Audio
Ambiente sonoro por zona (bosque y cuevas) y efectos de sonido para saltos, golpes, parry y transformaciones. La música está pendiente de definir.
## Datos Adicionales
Motor de desarrollo: Godot 4.7 (GDScript)
Resolución: 1920x1080
Plataforma objetivo: PC (Windows), con teclado y mando
Duración estimada: aproximadamente 30 minutos
Alcance: 3 niveles de juego y 1 nivel de jefe, 4 formas, 2 tipos de enemigo y 1 jefe de 3 fases
Equipo: 3 integrantes, 2 meses de desarrollo
## Público objetivo
Jugadores de 12 años en adelante aficionados a la acción y las plataformas 2D. El juego es accesible (controles simples, checkpoints frecuentes, ayudas del Amuleto) pero tiene profundidad suficiente para quienes disfrutan del timing del parry, los combos y la gestión de energía entre formas.