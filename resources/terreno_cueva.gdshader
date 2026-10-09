shader_type canvas_item;
// Terreno de cueva: re-tiñe la tierra violeta del tileset (como tinte_terreno) pero con vida propia:
// manchas minerales de dos tonos, estratos suaves, vetas claras y destellos de mica, todo en coordenadas
// de mundo (sin costuras entre tiles). El musgo verde de los bordes no se toca.
uniform vec3 color_oscuro : source_color = vec3(0.22, 0.24, 0.34);   // zonas hundidas / sombras minerales
uniform vec3 color_medio  : source_color = vec3(0.34, 0.36, 0.45);   // tono base de la roca
uniform vec3 color_claro  : source_color = vec3(0.50, 0.53, 0.60);   // zonas más secas / lavadas
uniform vec3 color_calido : source_color = vec3(0.27, 0.40, 0.41);   // parches húmedos verde azulados (como el musgo/cristales)
uniform vec3 color_veta   : source_color = vec3(0.55, 0.62, 0.72);   // vetas húmedas y mica
uniform float matiz_min = 0.68;
uniform float matiz_max = 1.0;
uniform float matiz_rojo_max = 0.04;
uniform float escala_manchas = 190.0;   // px por mancha mineral
uniform float fuerza_manchas : hint_range(0.0, 1.0) = 0.85;
uniform float fuerza_estratos : hint_range(0.0, 1.0) = 0.35;   // bandas horizontales deformadas
uniform float fuerza_calido : hint_range(0.0, 1.0) = 0.6;
uniform float fuerza_vetas : hint_range(0.0, 1.0) = 0.4;
uniform float fuerza_mica : hint_range(0.0, 1.0) = 0.5;
uniform float base : hint_range(0.0, 1.5) = 0.62;
uniform float contraste : hint_range(0.0, 6.0) = 2.0;   // cuánto resalta el punteado del tile
uniform float brillo : hint_range(0.3, 2.0) = 1.0;

// Posición de mundo del fragmento: los quadrants del TileMap dibujan en coordenadas locales, así que la
// cámara (terreno_mundo.gd) pasa su centro y cuánto mundo se ve para reconstruirla desde SCREEN_UV.
uniform vec2 cam_centro = vec2(0.0);
uniform vec2 vista_mundo = vec2(1920.0, 1080.0);

float hash(vec2 p) {
	p = fract(p * vec2(123.34, 456.21));
	p += dot(p, p + 45.32);
	return fract(p.x * p.y);
}

float vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * f * (f * (f * 6.0 - 15.0) + 10.0);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), f.x),
			   mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), f.x), f.y);
}

float fbm(vec2 p) {
	float v = 0.0;
	float a = 0.5;
	// Cada octava se rota para que la grilla del value noise no se note como rectángulos.
	mat2 rot = mat2(vec2(1.6, 1.2), vec2(-1.2, 1.6));
	for (int i = 0; i < 3; i++) {
		v += a * vnoise(p);
		p = rot * p + vec2(17.3, 9.1);
		a *= 0.5;
	}
	return v / 0.875;
}

void fragment() {
	vec2 wpos = cam_centro + (SCREEN_UV - 0.5) * vista_mundo;
	vec4 c = texture(TEXTURE, UV);
	float mx = max(c.r, max(c.g, c.b));
	float mn = min(c.r, min(c.g, c.b));
	float d = mx - mn;
	float h = 0.0;
	if (d > 0.0001) {
		if (mx == c.r) h = mod((c.g - c.b) / d, 6.0);
		else if (mx == c.g) h = (c.b - c.r) / d + 2.0;
		else h = (c.r - c.g) / d + 4.0;
		h = mod(h / 6.0 + 1.0, 1.0);
	}
	float es_tierra = clamp(step(matiz_min, h) * step(h, matiz_max) + step(h, matiz_rojo_max), 0.0, 1.0) * step(0.08, d);

	vec2 q = wpos / escala_manchas;
	float n = fbm(q);
	float estrato = sin(wpos.y * 0.035 + fbm(q * 0.6) * 6.0) * 0.5 + 0.5;
	float t = clamp(n + (estrato - 0.5) * fuerza_estratos, 0.0, 1.0);
	t = mix(0.5, smoothstep(0.3, 0.7, t), fuerza_manchas);
	// oscuro -> medio -> claro según la mancha
	vec3 roca = t < 0.5 ? mix(color_oscuro, color_medio, smoothstep(0.1, 0.5, t) )
						: mix(color_medio, color_claro, smoothstep(0.5, 0.9, t));
	// vetas de óxido en parches
	float calido = smoothstep(0.5, 0.72, fbm(q * 1.3 + vec2(40.0, 7.0)));
	roca = mix(roca, color_calido, calido * fuerza_calido);
	// vetas húmedas: líneas finas donde el ruido cruza 0.5
	float vv = abs(fbm(wpos / (escala_manchas * 0.45) + vec2(3.0, 11.0)) - 0.5);
	float zona_vetas = smoothstep(0.45, 0.65, fbm(q * 0.8 + vec2(80.0, 3.0)));   // solo en algunas zonas
	float veta = (1.0 - smoothstep(0.0, 0.012, vv)) * fuerza_vetas * zona_vetas;
	// mica: destellos pequeños y escasos
	vec2 cel = floor(wpos / 5.0);
	float mica = step(0.985, hash(cel)) * fuerza_mica * (0.5 + 0.5 * vnoise(wpos / 40.0));

	float lum = dot(c.rgb, vec3(0.299, 0.587, 0.114));
	vec3 tierra = roca * (base + lum * contraste) * brillo;
	tierra = mix(tierra, color_veta * (base + lum * contraste) * brillo * 1.25, veta * 0.55);
	tierra += color_veta * mica * 0.35;
	COLOR = vec4(mix(c.rgb, tierra, es_tierra), c.a);
}
