// Mar em volta da ilha tropical, sumindo nas bordas para emendar com o fundo.
shader_type spatial;
render_mode blend_mix, depth_draw_never, cull_disabled;

uniform vec4 cor : source_color = vec4(0.16, 0.76, 0.84, 1.0);
uniform float opacidade = 0.85;

void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	float r = length(p);
	float onda = sin((p.x + p.y) * 18.0 + TIME * 1.4) * 0.03;
	ALBEDO = cor.rgb + onda;
	ROUGHNESS = 0.15;
	METALLIC = 0.1;
	ALPHA = opacidade * (1.0 - smoothstep(0.55, 1.0, r));
}
