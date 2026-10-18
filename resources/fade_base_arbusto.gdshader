shader_type canvas_item;
// Arbustos del frente: la base se oscurece y se desvanece para camuflarse con el degradado del piso (no parecen flotar).
uniform float alto_fade : hint_range(0.0, 1.0) = 0.3;        // fracción inferior de la textura que se desvanece
uniform float oscurecer : hint_range(0.0, 1.0) = 0.8;        // cuánto se hunde en el color del piso antes de desaparecer
uniform vec3 color_piso : source_color = vec3(0.03, 0.025, 0.02);

void fragment() {
	vec4 c = texture(TEXTURE, UV);
	float k = smoothstep(1.0 - alto_fade, 1.0, UV.y);
	c.rgb = mix(c.rgb, color_piso, k * oscurecer);
	c.a *= 1.0 - k;
	COLOR = c;
}
