shader_type canvas_item;

uniform sampler2D pantalla : hint_screen_texture, filter_linear;

uniform vec4 color_agua : source_color = vec4(0.35, 0.55, 0.62, 1.0);
uniform vec4 color_linea : source_color = vec4(0.60, 0.75, 0.80, 1.0);
uniform float opacidad : hint_range(0.0, 1.0) = 0.7;
uniform float amplitud : hint_range(0.0, 0.1) = 0.02;
uniform float velocidad : hint_range(0.0, 4.0) = 1.0;
uniform float distorsion : hint_range(0.0, 0.02) = 0.004;
uniform float grosor_linea : hint_range(0.0, 0.05) = 0.008;

void fragment() {
	
	// Waves
	float ola = sin(UV.x * 11.0 + TIME * velocidad) * amplitud
	          + sin(UV.x * 23.0 - TIME * velocidad * 0.6) * amplitud * 0.5;
	float superficie = amplitud * 2.0 + ola;

	if (UV.y < superficie) {
		discard;
	}

	// Back Distorision
	vec2 uv = SCREEN_UV;
	uv.x += sin(UV.y * 30.0 + TIME * 0.8) * distorsion;
	vec3 fondo = texture(pantalla, uv).rgb;

	// Tint
	vec3 col = mix(fondo, fondo * color_agua.rgb, opacidad);

	// Foam Line
	if (UV.y < superficie + grosor_linea) {
		col = color_linea.rgb;
	}

	COLOR = vec4(col, 1.0);
}
