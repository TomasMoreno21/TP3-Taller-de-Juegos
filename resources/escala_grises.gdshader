shader_type canvas_item;
// Desatura hacia grises conservando la luminosidad. gris=0 → color original; gris=1 → escala de grises pura.
// `brillo` y `contraste` levantan un poco el resultado para que plataformas e interactuables se sigan despegando del fondo.
uniform float gris : hint_range(0.0, 1.0) = 0.7;
uniform float brillo : hint_range(0.5, 2.0) = 1.0;
uniform float contraste : hint_range(0.5, 2.0) = 1.0;

void fragment() {
	float lum = dot(COLOR.rgb, vec3(0.299, 0.587, 0.114));
	vec3 g = mix(COLOR.rgb, vec3(lum), gris);
	g = (g - 0.5) * contraste + 0.5;
	COLOR.rgb = clamp(g * brillo, 0.0, 1.0);
}
