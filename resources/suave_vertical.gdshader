shader_type canvas_item;
// Desplaza el dibujo una fracción de píxel en vertical (el motor redondea la posición de los nodos a
// píxeles enteros, así que un desnivel de 1 px siempre se vería como un salto). El script del jugador
// pone la parte entera en la posición y la fracción acá.

uniform float desfase_px = 0.0;   // px de pantalla (+ = el dibujo se ve más abajo)
uniform float escala_y = 1.0;     // escala vertical del sprite (px de pantalla por texel)

varying vec4 modulado;

void vertex() {
	modulado = COLOR;
}

void fragment() {
	vec4 nitido = texture(TEXTURE, UV);
	float s = desfase_px;
	if (abs(s) < 0.001) {
		COLOR = nitido * modulado;
	} else {
		vec2 d = vec2(0.0, TEXTURE_PIXEL_SIZE.y / max(escala_y, 0.01));
		// Caja de 1 px de pantalla alrededor del punto desplazado: movimiento sub-píxel sin dientes.
		vec4 a = texture(TEXTURE, UV - d * (s - 0.3));
		vec4 b = texture(TEXTURE, UV - d * s);
		vec4 c = texture(TEXTURE, UV - d * (s + 0.3));
		vec4 suave = (a + b + c) / 3.0;
		COLOR = mix(nitido, suave, clamp(abs(s) * 4.0, 0.0, 1.0)) * modulado;
	}
}
