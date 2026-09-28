shader_type canvas_item;
// Re-tiñe SOLO la tierra violeta del tileset (matiz púrpura) a un tono de tierra,
// dejando intacto el musgo verde de los bordes.
uniform vec3 tierra_color : source_color = vec3(0.26, 0.19, 0.13);
uniform float matiz_min = 0.68;
uniform float matiz_max = 1.0;
uniform float matiz_rojo_max = 0.04;  // los puntos del dither son rojizos (matiz cerca de 0/1)
uniform float mezcla : hint_range(0.0, 1.0) = 1.0;
uniform float brillo : hint_range(0.3, 2.0) = 1.0;

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
	// Se conserva el relieve (luminosidad) del tile y se lo pinta con el color de tierra.
	float lum = dot(c.rgb, vec3(0.299, 0.587, 0.114));
	vec3 tierra = tierra_color * (0.55 + lum * 3.2) * brillo;
	COLOR = vec4(mix(c.rgb, tierra, es_violeta * mezcla), c.a);
}
