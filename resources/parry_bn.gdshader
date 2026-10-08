shader_type canvas_item;
// Parry perfecto: el mundo pasa a blanco y negro de alto contraste salvo un círculo de color alrededor del jugador.

uniform sampler2D pantalla : hint_screen_texture, filter_linear;
uniform float cantidad : hint_range(0.0, 1.0) = 1.0;      // 0 = color normal, 1 = blanco y negro completo
uniform vec2 centro = vec2(0.5, 0.5);                      // posición del jugador en pantalla (0..1)
uniform float radio : hint_range(0.0, 1.5) = 0.2;          // radio del círculo de color (fracción del alto)
uniform float suavizado : hint_range(0.001, 0.5) = 0.08;
uniform float aspecto = 1.7778;
uniform float contraste : hint_range(0.5, 3.0) = 1.4;
uniform float brillo : hint_range(0.5, 4.0) = 1.9;       // levanta las sombras para que el blanco y negro se lea

void fragment() {
	vec3 c = texture(pantalla, SCREEN_UV).rgb;
	float g = dot(c, vec3(0.299, 0.587, 0.114));
	g = clamp((g * brillo - 0.5) * contraste + 0.5, 0.0, 1.0);
	vec2 d = (SCREEN_UV - centro) * vec2(aspecto, 1.0);
	float m = smoothstep(radio, radio + suavizado, length(d));
	COLOR = vec4(mix(c, vec3(g), cantidad * m), 1.0);
}
