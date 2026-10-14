# GDD — qué actualizar al final del proyecto
Documento: `docs/GDD Spirit Keeper.docx` (fuente en `docs/gdd_fuente/`). Estado: redactado con el prototipo del 13/10.

## Datos a confirmar / actualizar
- Autores: Franco Hereñú sin DNI (solo está en el concepto TP3); completar.
- Público objetivo "12+" y duración "~30 min": supuestos, confirmar con el equipo.
- Música: figura "pendiente de definir".
- Números de balance (velocidad, daño, vida de enemigos, vida del jefe 600, fragmentos 8/28/38/64, energía 4/s, orbes de vida 24): salen del código al 13/10; revisar si cambió el balance.
- Nivel 3 (El Latido): descrito en general porque el usuario lo rehízo a mano; revisar contra el nivel final.
- Cómic de inicio: hoy 6 viñetas vectoriales de reemplazo; actualizar cuando entre el arte del artista.

## Imágenes a rehacer con arte final
- Sprites de enemigos/personaje definitivos (`Sprites/`), hijo y Arzobispo (no hay visual del jefe aún): agregar sección del jefe con imagen.
- Capturas de niveles (`gdd_fuente/g_*.png`), HUD y menús: volver a capturar cuando estén los menús finales.
- Logo: la portada usa un banner generado con texto (`imgs.py`); reemplazar por el logo real.

## Secciones que se pueden agregar
- Cuántos enemigos/arenas/checkpoints hay por nivel (contar sobre las escenas finales).
- Créditos, opciones y guardado, si se implementan.
- Estado de verificación (autotest en 0) y plataforma/build final.
