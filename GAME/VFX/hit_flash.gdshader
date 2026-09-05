shader_type canvas_item;

// Destello de impacto: tiñe el sprite de blanco sin perder su silueta.
// 'blanco' va de 0 (normal) a 1 (todo blanco) y lo mueve un Tween.

uniform float blanco : hint_range(0.0, 1.0) = 0.0;
uniform vec4 color_flash : source_color = vec4(1.0, 1.0, 1.0, 1.0);

void fragment() {
	vec4 col = texture(TEXTURE, UV);

	// Solo el color, el alpha se respeta: así el destello
	// tiene exactamente la forma del sprite
	col.rgb = mix(col.rgb, color_flash.rgb, blanco);

	COLOR = col;
}
