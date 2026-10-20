const fs=require('fs');
const {Document,Packer,Paragraph,TextRun,Table,TableRow,TableCell,ImageRun,AlignmentType,LevelFormat,HeadingLevel,BorderStyle,WidthType,VerticalAlign}=require('docx');
const FONT="Times New Roman", BROWN="8B4513", GRAY="555555";
const S0=(f)=>__dirname+"/"+f;
const dim=(f)=>{const b=fs.readFileSync(S0(f));return [b.readUInt32BE(16),b.readUInt32BE(20)];};
const r=(s,o={})=>new TextRun({text:s,font:FONT,...o});
const P=(runs,o={})=>new Paragraph({spacing:{after:200,line:276},...o,children:Array.isArray(runs)?runs:[r(runs)]});
const E=()=>new Paragraph({spacing:{after:0},children:[]});
const L=(label,txt,o={})=>P([r(label+": ",{bold:true}),r(txt)],o);
const D=(label,txt)=>new Paragraph({numbering:{reference:"dash",level:0},spacing:{after:80,line:276},children:label?[r(label+" - ",{bold:true}),r(txt)]:[r(txt)]});
const H=(s,brk=false)=>new Paragraph({heading:HeadingLevel.HEADING_2,keepNext:true,pageBreakBefore:brk,alignment:AlignmentType.CENTER,spacing:{before:200,after:240},children:[r(s,{bold:true,size:32,color:BROWN})]});
const H3=(s)=>new Paragraph({heading:HeadingLevel.HEADING_3,keepNext:true,spacing:{before:200,after:160},children:[r(s,{bold:true,size:24,color:BROWN})]});
const img=(f,w,o={})=>{const [iw,ih]=dim(f);return new ImageRun({type:"png",data:fs.readFileSync(S0(f)),transformation:{width:w,height:Math.round(w*ih/iw)},altText:{title:f,description:f,name:f}});};
const imgP=(f,w,o={})=>new Paragraph({alignment:AlignmentType.CENTER,spacing:{before:100,after:200},children:[img(f,w)]});
const none={style:BorderStyle.NONE,size:0,color:"FFFFFF"};const nb={top:none,bottom:none,left:none,right:none};
function entry(sprite,sw,label,txt,extra=[]){
  const left=new TableCell({width:{size:1700,type:WidthType.DXA},borders:nb,verticalAlign:VerticalAlign.CENTER,margins:{top:40,bottom:40,left:0,right:120},children:[new Paragraph({alignment:AlignmentType.CENTER,spacing:{after:0},children:[img(sprite,sw)]})]});
  const right=new TableCell({width:{size:6940,type:WidthType.DXA},borders:nb,verticalAlign:VerticalAlign.CENTER,margins:{top:40,bottom:40,left:120,right:0},children:[P([r(label+": ",{bold:true}),r(txt)],{spacing:{after:60,line:276}}),...extra]});
  return new TableRow({cantSplit:true,children:[left,right]});
}
const entries=(rows)=>new Table({width:{size:8640,type:WidthType.DXA},columnWidths:[1700,6940],borders:{top:none,bottom:none,left:none,right:none,insideHorizontal:none,insideVertical:none},rows});
function gallery(items,w=178){
  const cw=2880, cells=items.map(([f,cap])=>new TableCell({width:{size:cw,type:WidthType.DXA},borders:nb,margins:{top:40,bottom:40,left:40,right:40},children:[new Paragraph({alignment:AlignmentType.CENTER,spacing:{after:20},children:[img(f,w)]}),new Paragraph({alignment:AlignmentType.CENTER,spacing:{after:60},children:[r(cap,{italics:true,size:18,color:GRAY})]})]}));
  return new Table({width:{size:8640,type:WidthType.DXA},columnWidths:[2880,2880,2880],borders:{top:none,bottom:none,left:none,right:none,insideHorizontal:none,insideVertical:none},rows:[new TableRow({cantSplit:true,children:cells})]});
}
const c=[];
// ---------- Portada
c.push(new Paragraph({alignment:AlignmentType.CENTER,spacing:{before:200,after:0},children:[img("banner.png",576)]}));
for(let i=0;i<6;i++)c.push(E());
c.push(P([r("GDD (Game Design Document)",{color:GRAY})],{alignment:AlignmentType.CENTER,spacing:{after:0}}));
c.push(P([r("Spirit Keeper",{color:GRAY})],{alignment:AlignmentType.CENTER,spacing:{after:0}}));
c.push(E());c.push(E());
c.push(P("Alumnos:",{alignment:AlignmentType.CENTER,spacing:{after:0}}));
c.push(P("Córdoba, Micaela Alejandra - 47763620",{alignment:AlignmentType.CENTER,spacing:{after:0}}));
c.push(P("Hereñú, Franco",{alignment:AlignmentType.CENTER,spacing:{after:0}}));
c.push(P("Moreno, Tomás Matías - 47583852",{alignment:AlignmentType.CENTER,spacing:{after:0}}));
c.push(E());c.push(E());
c.push(P("Universidad Nacional de Rafaela (UNRaf)",{alignment:AlignmentType.CENTER,spacing:{after:0}}));
c.push(P("Materia: Taller de Producción de Videojuegos 2",{alignment:AlignmentType.CENTER,spacing:{after:0}}));
c.push(P("Docentes:",{alignment:AlignmentType.CENTER,spacing:{after:0}}));
c.push(P("Nazzetta, Sebastián",{alignment:AlignmentType.CENTER,spacing:{after:0}}));
c.push(P("Porello, Diego",{alignment:AlignmentType.CENTER,spacing:{after:0}}));
// ---------- Índice
c.push(H("Índice"));
const idx=[["Diagrama de flujo",3],["Descripción, Resumen y Core loop",4],["Pilares de diseño",5],["Niveles y Narrativa",6],["Controles",7],["Gameplay",8],["Formas (personajes) y Enemigos",9],["Progresión y Energía",10],["Jefe final",11],["Sistema de dificultad progresiva",11],["Apartado Visual",12],["Efectos visuales (FX) y Audio",13],["Datos Adicionales",14],["Público objetivo",14]];
for(const [n,p] of idx){
  const dots=" "+"-".repeat(Math.max(6,66-Math.round(n.length*1.25)))+" ";
  c.push(new Paragraph({spacing:{after:0},children:[r(n,{bold:true,size:28}),r(dots+p,{size:28})]}));
  c.push(new Paragraph({spacing:{after:0},children:[r("",{size:28})]}));
}
// ---------- Diagrama de flujo
c.push(new Paragraph({alignment:AlignmentType.CENTER,spacing:{after:0},children:[img("flujo.png",540)]}));
// ---------- Descripción
c.push(H("Descripción"));
c.push(P("Spirit Keeper es un videojuego de acción y plataformas 2D con vista lateral, en el cual el jugador controla a un padre que se interna en un bosque corrupto para rescatar a su hijo, secuestrado por una secta. Un amuleto con espíritus guardianes le presta tres transformaciones (Lobo, Murciélago y Oso) y cada una cambia la forma de moverse, pelear y resolver obstáculos."));
c.push(L("Género","Acción / Plataformas 2D (side-scroller)",{spacing:{after:0}}));
c.push(L("Ambientación","Bosque corrupto, cuevas y guarida de una secta",{spacing:{after:0}}));
c.push(L("Inspiraciones","Ben 10: Alien Force (referencia mecánica), Hollow Knight (jefe y atmósfera)"));
// ---------- Resumen
c.push(H("Resumen"));
c.push(P("El jugador comienza como el Humano, una forma débil pero técnica (bloquea y hace parry). A medida que avanza encuentra tótems que despiertan a los espíritus del amuleto y le otorgan nuevas formas. Cada forma abre ciertos caminos: el doble salto del Lobo, el planeo y el disparo sónico del Murciélago, la fuerza del Oso."));
c.push(P("Transformarse consume energía, que se recarga recogiendo almas y venciendo enemigos. Con los fragmentos que junta sube de nivel y elige el combo de una de sus formas. El juego tiene un final: la pelea contra el Arzobispo, jefe de la secta, que exige usar todas las formas aprendidas para liberar al hijo."));
// ---------- Core Loop
c.push(H("Core Loop"));
c.push(imgP("coreloop.png",330));
// ---------- Pilares de diseño
c.push(H("Pilares de diseño",true));
c.push(L("Cada forma importa","las formas no son skins: cambian el movimiento, el combate y qué obstáculos se pueden superar. La pregunta central es siempre qué forma conviene usar."));
c.push(L("Enseñar antes de exigir","cada habilidad nueva se presenta en un espacio seguro y se usa una o dos veces antes de exigirla para avanzar."));
c.push(L("Feedback","toda acción del jugador conlleva a su respectiva respuesta inmediata, sea visual o sonora, con el fin de brindar una buena experiencia."));
// ---------- Niveles y Narrativa
c.push(H("Niveles y Narrativa"));
c.push(L("Historia","un padre y su hijo pasaban la tarde juntos cuando unas voces extrañas llamaron al niño desde la espesura. El padre lo siguió dentro del bosque y quedó solo. Allí aparece el amuleto de los espíritus: “Humano… por fin alguien me encuentra. Juntos podremos salvarlo.” El juego abre con un cómic de seis viñetas que cuenta este comienzo."));
c.push(L("Final","al vencer al Arzobispo el sello cede y el hijo emerge de la luz. Padre y Amuleto dialogan brevemente, corte a negro y aparece la frase final: “Lo que el bosque se llevó, el bosque lo devuelve.”"));
c.push(L("Cinemáticas","el cómic de inicio, la intro de cada nivel, la cinemática de cada tótem (el sello viaja al jugador y aparece la tarjeta de la forma) y las del jefe (aparición y estallido final). Todas ocurren dentro del juego, sin cortar el ritmo."));
c.push(P("El juego tiene 3 niveles y un nivel de jefe, todos lineales y con checkpoints:"));
c.push(D("Nivel 1 - El Bosque","tutorial. Movimiento, combate, bloqueo y parry del Humano. Termina en una cueva donde está el tótem del Lobo; la salida es una zona de oscuridad con el nombre del siguiente nivel."));
c.push(D("Nivel 2 - Las Cuevas","cueva natural. Se desbloquea el Murciélago (planeo, aleteo, picada y sónico). Barreras de cristal, pinchos, un derrumbe, enemigos voladores, fogatas y niebla de cueva."));
c.push(D("Nivel 3 - El Latido","cueva profunda donde late el corazón del sello. Se desbloquea el Oso. El latido de la luz se acelera hacia el sello; hay puzzles que combinan las tres formas y rutas opcionales."));
c.push(D("Jefe - El Santuario","arena de la secta. Pelea contra el Arzobispo en 3 fases, con cinemáticas de entrada y de muerte."));
c.push(gallery([["g_n1.png","El Bosque"],["g_n2.png","Las Cuevas"],["g_n3.png","El Latido"]]));
c.push(gallery([["g_t1.png","Tótem del Lobo"],["g_t2.png","Tótem del Murciélago"],["g_t3.png","Tótem del Oso"]]));
c.push(P("Cada nivel arranca con una intro in-game (diálogo Humano-Amuleto) y un título de nivel. Todos los textos del juego están en español.",{spacing:{before:160}}));
// ---------- Controles
c.push(H("Controles"));
c.push(P("El juego está diseñado para PC y se controla con teclado o mando. Los controles son los mismos en todas las formas:"));
c.push(D("Mover","A / D o flechas (mando: stick / cruz)."));
c.push(D("Saltar","Espacio (mando: A)."));
c.push(D("Golpe / Golpe fuerte / Especial e interactuar","J / K / L (mando: X / Y / B)."));
c.push(D("Bloquear y parry (Humano)","Shift (mando: LB), justo al recibir el golpe para hacer parry."));
c.push(D("Aleteo y picada (Murciélago)","Espacio en el aire y S / flecha abajo en el aire."));
c.push(D("Elegir forma","Q / E (mando: Select)."));
c.push(D("Transformar o volver a Humano","T (mando: RB)."));
c.push(D("Transformar directo (teclas)","1 Humano / 2 Lobo / 3 Oso / 4 Murciélago."));
c.push(D("Pausa","Esc (mando: Start)."));
c.push(P("Combo: golpe ligero seguido de golpe fuerte (J, K). El juego guarda la segunda pulsación para que no se exija precisión extrema.",{spacing:{before:120}}));
// ---------- Gameplay
c.push(H("Gameplay"));
c.push(L("Movimiento","el jugador recorre el nivel de izquierda a derecha con salto, coyote time y buffer de salto. Cada forma tiene inercia y peso propios."));
c.push(L("Combate","golpe ligero, fuerte y especial. Ligero + fuerte ejecuta el combo de la forma. El Humano bloquea (solo de frente) y puede hacer parry con el timing justo, que devuelve proyectiles y da energía."));
c.push(L("Vida","las cuatro formas comparten una única barra de vida (100). Los orbes de vida curan 24."));
c.push(L("Arenas","al entrar a una zona de combate se cierran las paredes y aparecen oleadas de enemigos. Al vencerlas se abre el camino."));
c.push(L("Puzzles por forma","los obstáculos muestran el símbolo de la forma necesaria:"));
c.push(D("Lobo","enredaderas y muros trepables, túneles bajos."));
c.push(D("Murciélago","cristales de barrera que solo rompe el proyectil sónico."));
c.push(D("Oso","losas de peso y muros de piedra que solo él rompe o activa."));
c.push(L("Peligros","pinchos, pozos, plataformas frágiles y derrumbes."));
c.push(L("Muerte y reaparición","al morir se reaparece en el último checkpoint (santuario) del nivel. No hay límite de intentos."));
// ---------- Formas y Enemigos
c.push(H("Formas (personajes)"));
c.push(P("Contamos con 4 formas jugables que comparten la vida, pero tienen estadísticas distintas que afectan el gameplay:"));
c.push(entries([
 entry("s_humano.png",48,"Humano","Base (vel. 600, daño 8/14/24) - Forma inicial. Bloquea y hace parry. Combo: Remate."),
 entry("s_lobo.png",78,"Lobo","Veloz (vel. 690, daño 8/13/26) - Doble salto, trepa muros y cruza túneles bajos. Combo: Embestida."),
 entry("s_murci.png",46,"Murciélago","Aéreo (vel. 420, daño 9/14/15) - Planea, aletea, pica hacia abajo y dispara un proyectil sónico que rompe cristales. Combo: Ala Cortante."),
 entry("s_oso.png",80,"Oso","Pesado (vel. 350, daño 16/24/32) - Lento pero devastador. Activa losas de peso y rompe muros de piedra. Combo: Garra.")]));
c.push(P("Transformarse requiere al menos 25 de energía. La forma drena 4 de energía por segundo (menos fuera de las arenas) y al llegar a 0 el jugador vuelve a Humano.",{spacing:{before:160,after:200}}));
c.push(P("Además, contamos con un NPC:"));
c.push(L("Amuleto","el collar de los espíritus acompaña al jugador con globos de diálogo: cuenta la historia, aconseja y reacciona a lo que ocurre."));
c.push(H3("Enemigos"));
c.push(entries([
 entry("s_cultista.png",36,"Cultista","vida 75, daño 10 - Cuerpo a cuerpo. Persigue al jugador, se prepara con una anticipación visible y se lanza con un tajo. Máximo 2 atacando a la vez."),
 entry("s_arquero.png",30,"Arquero","vida 60, daño 12 - Dispara proyectiles desde lejos y retrocede si lo acorralan. En niveles avanzados aparece flotando sobre un aura mística y recibe más daño del sónico.")]));
c.push(P("Los ataques enemigos se telegrafían con un destello y un breve retroceso, para que el jugador pueda leerlos y reaccionar.",{spacing:{before:160}}));
// ---------- Progresión y Energía
c.push(H("Progresión y Energía"));
c.push(L("Formas","Humano y Lobo desde el Nivel 1; el Murciélago se desbloquea en el Nivel 2 y el Oso en el Nivel 3, con un tótem y una pequeña cinemática en cada uno."));
c.push(L("Fragmentos","orbes repartidos por los niveles. Al acumular 8, 28, 34 y 46 el jugador sube de nivel y elige la forma cuyo combo desbloquea (un combo por forma)."));
c.push(L("Energía","se gasta al transformarse (4 por segundo) y se recarga con almas de energía, enemigos derrotados y parrys exitosos."));
// ---------- Jefe final
c.push(H("Jefe final"));
c.push(P("El Arzobispo es el líder de la secta, ya transformado: una estrella de ocho puntas con un ojo central, unida al piso por un tallo. Nunca se le pega al cuerpo directamente; hay que atacar sus puntas y su ojo en cada fase. Al derrotarlo, el niño sale de adentro de él."));
c.push(D("Fase 1","aparecen llaves en el tallo; el Oso debe romper el nudo del tallo (golpe ≥ 24, 3 golpes) para bajar el ojo y poder dañarlo. El jefe lanza tajos con aviso que el Humano puede devolver con parry."));
c.push(D("Fase 2","el piso se rompe y cae al foso; el Lobo cruza el pozo y el Murciélago alcanza el ojo alto. Aparecen torretas (ojos acorazados que solo rompe el Oso) y barridos de luz que hay que esquivar o parryear."));
c.push(D("Fase 3","la estrella se arranca del tallo y se clava de punta; el Oso la arranca y los ojos caen con coraza (solo el Oso la rompe). Es el duelo directo, sin ojos flotantes."));
c.push(P("Tiene 600 puntos de vida (200 por fase) y se corrompe al bajar de 66 % y de 33 %: más ataques, orbes más frecuentes y el latido acelera. Los orbes se pueden devolver con parry. Entre fases hay valles sin ataques para respirar.",{spacing:{before:120}}));
c.push(P("Entrada: el jefe no se muestra de entrada; al llegar a la arena emerge desde atrás y abajo, temblando, entre polvo y piedras del techo. Muerte: estalla con grietas de luz y el hijo aparece desde adentro, mientras el padre (Humano) lo contiene."));
// ---------- Sistema de dificultad progresiva
c.push(H("Sistema de dificultad progresiva"));
c.push(P("La dificultad escala conforme se avanza en los niveles:"));
c.push(D("","El Bosque (nivel 1): tutorial. Pocos enemigos, sin presión, y se enseña el Lobo."));
c.push(D("","Las Cuevas (nivel 2): aparecen la oscuridad y los enemigos voladores; el Murciélago es la llave."));
c.push(D("","El Latido (nivel 3): el nivel más largo y vertical, con más arenas, rutas opcionales y puzzles que combinan las tres formas."));
c.push(D("","El Santuario (jefe): exige dominar todas las formas, el parry y la gestión de energía."));
c.push(P("Los niveles alternan combate, plataformeo y puzzles, con espacios de respiro entre arenas. La dificultad está diseñada para que el jugador sienta progreso sin llegar a ser frustrante.",{spacing:{before:120}}));
// ---------- Apartado Visual
c.push(H("Apartado Visual"));
c.push(P("Utilizamos un estilo 2D ilustrado, con colores planos y siluetas claras, para todos los elementos visuales del juego:"));
c.push(D("Personajes","sprites animados cuadro a cuadro (reposo, correr, saltar, ataques y daño). Cada forma tiene un tamaño distinto para reforzar su identidad."));
c.push(D("Fondos","parallax scrolling con capas por nivel (bosque, cueva natural y cueva profunda), más luciérnagas, niebla, rayos de luz y polvo de cueva."));
c.push(D("Interfaz","menú principal, pausa, controles, opciones, créditos, derrota y victoria."));
c.push(D("HUD","arriba a la izquierda el retrato del Amuleto con la barra de vida (roja) y la de energía de transformación; el selector de formas, los fragmentos acumulados y una pila de golpes de combo aparecen cuando corresponde."));
c.push(D("Textos","colores funcionales: verde para el bosque y lo vivo, azul y violeta para la cueva profunda, rojo para el peligro y el jefe."));
c.push(gallery([["hud.png","HUD en partida"],["menu.png","Menú principal"],["g_ctrl.png","Pantalla de controles"]]));
// ---------- FX
c.push(H3("Efectos visuales (FX)"));
c.push(D("Hitstop y screen shake","temblor de cámara y pausa breve al golpear, aterrizar y cambiar de fase del jefe."));
c.push(D("Telegrafía de ataques","destello y retroceso del enemigo antes de pegar."));
c.push(D("Transformación","onda expansiva y ráfaga de partículas al cambiar de forma."));
c.push(D("Squash & stretch","achatado al aterrizar y estirado al saltar."));
c.push(D("Parry","destello y efecto blanco y negro al desviar un golpe justo."));
c.push(D("Latido de la cueva","la luz del nivel 3 pulsa y se tiñe según la zona, con venas luminosas."));
c.push(D("Jefe","grietas de luz y cámara lenta al cambiar de fase; estallido final."));
// ---------- Audio
c.push(H3("Audio"));
c.push(P("Ambiente sonoro por zona (bosque y cuevas) y efectos de sonido para saltos, golpes, parry y transformaciones. La música está pendiente de definir."));
// ---------- Datos Adicionales
c.push(H("Datos Adicionales"));
c.push(L("Motor de desarrollo","Godot 4.7 (GDScript)",{spacing:{after:0}}));
c.push(L("Resolución","1920x1080",{spacing:{after:0}}));
c.push(L("Plataforma objetivo","PC (Windows), con teclado y mando",{spacing:{after:0}}));
c.push(L("Duración estimada","aproximadamente 30 minutos",{spacing:{after:0}}));
c.push(L("Alcance","3 niveles de juego y 1 nivel de jefe, 4 formas, 2 tipos de enemigo y 1 jefe de 3 fases",{spacing:{after:0}}));
c.push(L("Equipo","3 integrantes, 2 meses de desarrollo"));
// ---------- Público objetivo
c.push(H("Público objetivo"));
c.push(P("Jugadores de 12 años en adelante aficionados a la acción y las plataformas 2D. El juego es accesible (controles simples, checkpoints frecuentes, ayudas del Amuleto) pero tiene profundidad suficiente para quienes disfrutan del timing del parry, los combos y la gestión de energía entre formas."));

const doc=new Document({
  creator:"Córdoba, Hereñú, Moreno",title:"GDD Spirit Keeper",
  styles:{default:{document:{run:{font:FONT,size:22}}},paragraphStyles:[
    {id:"Heading2",name:"Heading 2",basedOn:"Normal",next:"Normal",quickFormat:true,run:{size:32,bold:true,font:FONT,color:BROWN},paragraph:{outlineLevel:1}},
    {id:"Heading3",name:"Heading 3",basedOn:"Normal",next:"Normal",quickFormat:true,run:{size:24,bold:true,font:FONT,color:BROWN},paragraph:{outlineLevel:2}}]},
  numbering:{config:[{reference:"dash",levels:[{level:0,format:LevelFormat.BULLET,text:"-",alignment:AlignmentType.LEFT,style:{paragraph:{indent:{left:540,hanging:270}},run:{font:FONT}}}]}]},
  sections:[{properties:{page:{size:{width:12240,height:15840},margin:{top:1440,bottom:1440,left:1800,right:1800}}},children:c}]
});
Packer.toBuffer(doc).then(b=>{fs.writeFileSync(S0("GDD Spirit Keeper.docx"),b);console.log("ok")});
