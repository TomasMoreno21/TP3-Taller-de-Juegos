# Fuente del GDD (docs/GDD Spirit Keeper.docx)
Regenerar el Word: `npm install docx` (una vez) y `node build.js` en esta carpeta. El texto está en `build.js`; el índice lleva números de página a mano (abrir en Word, ver en qué página cae cada título y corregir `idx`).
- `imgs.py`: regenera banner, diagrama de flujo, core loop y sprites (lee `Sprites/`). Necesita Pillow.
- `g_n1/n2/n3.png` (niveles) y `g_t1/t2/t3.png` (tótems): capturas del juego, hechas con `tests/captura_nivel.gd`:
  `godot --path . --resolution 1920x1080 --script res://tests/captura_nivel.gd -- res://scenes/nivel1.tscn <dir> "x,y,1"` (posiciones usadas: N1 9517,802 y 25700,2374; N2 -3680,-61 y 600,-91; N3 -266,1760 y 331,4866).
- `hud.png`, `menu.png`, `g_ctrl.png`: de `docs/capturas_menus/`.
Ver pendientes para el cierre del proyecto en `../GDD_PENDIENTES.md`.
