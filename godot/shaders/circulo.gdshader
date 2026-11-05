// Recorta a imagem em círculo com borda branca (as artes redondas do jogo web).
shader_type canvas_item;

uniform float borda = 0.05;
uniform vec4 cor_borda : source_color = vec4(1.0);

void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	float r = length(p);
	float aa = max(fwidth(r), 0.002);
	vec4 c = texture(TEXTURE, UV);
	float dentro = 1.0 - smoothstep(1.0 - borda - aa, 1.0 - borda, r);
	float fora = 1.0 - smoothstep(1.0 - aa, 1.0, r);
	vec4 col = mix(cor_borda, c, dentro);
	col.a *= fora;
	COLOR = col;
}
