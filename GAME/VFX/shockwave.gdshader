shader_type canvas_item;

// Onda de choque: un anillo que se expande y deforma lo que hay detrás.
// El anillo lo mueve el uniform 'progreso' (0 a 1) desde shockwave.gd.
// El nodo tiene que ser CUADRADO o el anillo saldrá ovalado.

uniform sampler2D pantalla : hint_screen_texture, filter_linear;

uniform float progreso : hint_range(0.0, 1.0) = 0.0;
uniform float grosor : hint_range(0.005, 0.5) = 0.08;   // ancho del anillo
uniform float fuerza : hint_range(0.0, 80.0) = 24.0;    // px que empuja la imagen
uniform vec4 color_borde : source_color = vec4(1.0, 1.0, 1.0, 0.25);


void fragment() {
	vec2 centro = vec2(0.5);
	float d = distance(UV, centro);

	// El radio crece de 0 al borde del rectángulo
	float radio = progreso * 0.5;

	// Una banda de grosor 'grosor' justo por dentro del radio:
	// entra suave y sale suave, así no se ve el corte
	float anillo = smoothstep(radio - grosor, radio - grosor * 0.5, d)
	             * (1.0 - smoothstep(radio - grosor * 0.5, radio, d));

	// Se va apagando conforme se expande
	float mascara = anillo * (1.0 - progreso);

	// Fuera del anillo el nodo es invisible del todo
	if (mascara <= 0.001) {
		discard;
	}

	// Empujamos la imagen hacia fuera, en la dirección del centro al píxel
	vec2 direccion = normalize(UV - centro + vec2(0.00001));
	vec2 uv = SCREEN_UV + direccion * mascara * fuerza * SCREEN_PIXEL_SIZE;

	vec3 col = texture(pantalla, uv).rgb;

	// Un brillo tenue en la cresta para que se lea el anillo
	col = mix(col, color_borde.rgb, mascara * color_borde.a);

	COLOR = vec4(col, 1.0);
}
