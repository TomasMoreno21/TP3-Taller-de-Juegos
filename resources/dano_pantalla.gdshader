shader_type canvas_item;
// Recibir daño: la pantalla pierde el color un instante y se enrojece por los bordes.

uniform sampler2D pantalla : hint_screen_texture, filter_linear;
uniform float cantidad : hint_range(0.0, 1.0) = 1.0;      // intensidad global (0 = nada)
uniform float desaturar : hint_range(0.0, 1.0) = 0.6;    // cuánto color se pierde
uniform float borde : hint_range(0.0, 1.0) = 0.6;         // fuerza del rojo en los bordes
uniform vec3 color_borde : source_color = vec3(0.85, 0.04, 0.04);

void fragment() {
	vec3 c = texture(pantalla, SCREEN_UV).rgb;
	float g = dot(c, vec3(0.299, 0.587, 0.114));
	vec3 base = mix(c, vec3(g) * 1.15, desaturar * cantidad);
	float v = smoothstep(0.5, 1.05, length((SCREEN_UV - 0.5) * vec2(1.25, 1.0)) * 1.45);
	base = mix(base, color_borde, v * borde * cantidad);
	COLOR = vec4(base, 1.0);
}
