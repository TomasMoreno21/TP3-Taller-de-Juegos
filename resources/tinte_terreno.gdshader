shader_type canvas_item;
// Re-tiñe SOLO la tierra violeta del tileset (matiz púrpura), dejando intacto el musgo verde de los bordes.
// La tierra deja de ser un color sólido: varía suavemente por zonas (dos tonos + manchas húmedas + guijarros
// claros) usando la posición del MUNDO, así no se ven repeticiones de tile. Bajo `y_cueva` pasa a una paleta
// fría (la de la cueva) en vez de la cálida del bosque.
uniform vec3 tierra_color : source_color = vec3(0.26, 0.19, 0.13);
uniform vec3 tierra_color_b : source_color = vec3(0.26, 0.19, 0.13);    // segundo tono (variación por zonas)
uniform vec3 tierra_humeda : source_color = vec3(0.26, 0.19, 0.13);     // manchas de humedad
uniform float humedad : hint_range(0.0, 1.0) = 0.0;
uniform float y_cueva = 100000.0;                                        // altura del mundo desde la que rige la paleta de cueva
uniform float tramo_cueva = 700.0;
uniform vec3 tierra_cueva : source_color = vec3(0.15, 0.15, 0.2);
uniform vec3 tierra_cueva_b : source_color = vec3(0.12, 0.16, 0.19);
uniform vec3 tierra_cueva_humeda : source_color = vec3(0.08, 0.17, 0.2);
uniform float escala_zonas = 170.0;                                      // px de cada "mancha" grande
uniform float brillo_guijarros = 0.05;
uniform float matiz_min = 0.68;
uniform float matiz_max = 1.0;
uniform float matiz_rojo_max = 0.04;  // los puntos del dither son rojizos (matiz cerca de 0/1)
uniform float mezcla : hint_range(0.0, 1.0) = 1.0;
uniform float brillo : hint_range(0.3, 2.0) = 1.0;
uniform float base : hint_range(0.0, 1.5) = 0.55;        // luminosidad mínima de la tierra
uniform float contraste : hint_range(0.0, 6.0) = 3.2;    // cuánto resalta el punteado del tile

varying vec2 wpos;

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 0.0, 1.0)).xy;
}

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), f.x), mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), f.x), f.y);
}

float fbm(vec2 p) {
	float v = 0.0;
	float a = 0.5;
	for (int i = 0; i < 3; i++) {
		v += a * vnoise(p);
		p *= 2.0;
		a *= 0.5;
	}
	return v;
}

void fragment() {
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
	float es_violeta = clamp(step(matiz_min, h) * step(h, matiz_max) + step(h, matiz_rojo_max), 0.0, 1.0) * step(0.08, d);
	// Variación por zonas (posición del mundo).
	float zonas = fbm(wpos / escala_zonas);
	float manchas = fbm(wpos / (escala_zonas * 0.35) + vec2(7.3, 2.1));
	float cueva = smoothstep(y_cueva, y_cueva + tramo_cueva, wpos.y);
	vec3 t_a = mix(tierra_color, tierra_cueva, cueva);
	vec3 t_b = mix(tierra_color_b, tierra_cueva_b, cueva);
	vec3 t_h = mix(tierra_humeda, tierra_cueva_humeda, cueva);
	vec3 col = mix(t_a, t_b, smoothstep(0.35, 0.65, zonas));
	col = mix(col, t_h, smoothstep(0.55, 0.8, manchas) * humedad);
	// Se conserva el relieve (luminosidad) del tile y se lo pinta con el color de tierra.
	float lum = dot(c.rgb, vec3(0.299, 0.587, 0.114));
	vec3 tierra = col * (base + lum * contraste) * brillo;
	// Guijarros claros dispersos.
	tierra += step(0.9, vnoise(wpos / 7.0)) * brillo_guijarros;
	COLOR = vec4(mix(c.rgb, tierra, es_violeta * mezcla), c.a);
}
