shader_type canvas_item;

// Agua sencilla: tinte, distorsión del fondo y oleaje.
// Va en un ColorRect, detrás del player y delante del fondo.
//
// Todo se calcula en PÍXELES DE MUNDO, así que puedes estirar el
// rectángulo o poner varios pegados en X y la ola continúa sin cortes.

uniform sampler2D pantalla : hint_screen_texture, filter_linear;

uniform vec4 color_agua : source_color = vec4(0.35, 0.55, 0.62, 1.0);
uniform vec4 color_linea : source_color = vec4(0.60, 0.75, 0.80, 1.0);
uniform float opacidad : hint_range(0.0, 1.0) = 0.7;

uniform float longitud_ola : hint_range(10.0, 500.0) = 90.0;  // píxeles de cresta a cresta
uniform float amplitud : hint_range(0.0, 40.0) = 4.0;         // píxeles de alto
uniform float velocidad : hint_range(0.0, 4.0) = 1.0;

uniform float grosor_linea : hint_range(0.0, 20.0) = 2.0;     // píxeles
uniform float distorsion : hint_range(0.0, 20.0) = 3.0;       // píxeles
uniform float longitud_temblor : hint_range(10.0, 300.0) = 60.0;

varying vec2 mundo;     // posición en el mundo, en píxeles
varying vec2 local_px;  // posición dentro del rectángulo, en píxeles


void vertex() {
	// En un ColorRect, VERTEX ya viene en píxeles: 0,0 es su esquina superior izquierda
	local_px = VERTEX;
	mundo = (MODEL_MATRIX * vec4(VERTEX, 0.0, 1.0)).xy;
}


void fragment() {
	// Dos senos con longitudes que no son múltiplos entre sí,
	// así el patrón tarda mucho en repetirse y no canta.
	// Al ir sobre 'mundo.x', dos charcos pegados encajan solos.
	float ola = sin(mundo.x / longitud_ola * TAU + TIME * velocidad) * amplitud
	          + sin(mundo.x / (longitud_ola * 0.43) * TAU - TIME * velocidad * 0.6) * amplitud * 0.5;

	// Altura de la superficie medida desde el borde de arriba del rectángulo
	float superficie = amplitud * 2.0 + ola;

	// Por encima de la ola no hay nada
	if (local_px.y < superficie) {
		discard;
	}

	// El fondo, temblando
	vec2 uv = SCREEN_UV;
	uv.x += sin(mundo.y / longitud_temblor * TAU + TIME * 0.8) * distorsion * SCREEN_PIXEL_SIZE.x;
	vec3 fondo = texture(pantalla, uv).rgb;

	// Oscurecer y teñir el fondo, no pintar encima
	vec3 col = mix(fondo, fondo * color_agua.rgb, opacidad);

	// La línea de superficie
	if (local_px.y < superficie + grosor_linea) {
		col = color_linea.rgb;
	}

	COLOR = vec4(col, 1.0);
}
