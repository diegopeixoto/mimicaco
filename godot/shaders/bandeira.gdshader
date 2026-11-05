// Bandeirinha quadriculada balançando com o vento.
shader_type spatial;
render_mode cull_disabled;

uniform sampler2D xadrez : source_color, filter_nearest;

void vertex() {
	float x = UV.x;
	VERTEX.z += sin(x * 6.0 * 0.7 + TIME * 5.0) * 0.05 * (x * 0.7 + 0.0) * 1.4;
}

void fragment() {
	ALBEDO = texture(xadrez, UV).rgb;
	ROUGHNESS = 0.7;
}
