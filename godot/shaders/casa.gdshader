// Tampa redonda da casa: arte da categoria dentro de um círculo com borda branca.
shader_type spatial;

uniform sampler2D arte : source_color, filter_linear_mipmap, repeat_disable;
uniform vec4 cor : source_color = vec4(1.0);
uniform float tem_arte = 1.0;
uniform float brilho = 0.0;

void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	float r = length(p);
	if (r > 1.0) {
		discard;
	}
	float k = 112.0 / 126.0;
	vec3 c = vec3(1.0);
	if (r < k) {
		vec2 uv = p / k * 0.5 + 0.5;
		c = mix(cor.rgb, texture(arte, uv).rgb, tem_arte);
	}
	ALBEDO = c;
	ROUGHNESS = 0.6;
	EMISSION = c * brilho;
}
