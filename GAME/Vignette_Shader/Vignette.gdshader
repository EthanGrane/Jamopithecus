shader_type canvas_item;

uniform vec2 circle_position = vec2(0.5, 0.5);
uniform float radius = 0.2;
uniform vec4 color = vec4(0,0,0,0);

void fragment() {
    vec2 pos = UV - circle_position;

    // Compensar que la pantalla no sea cuadrada
    pos.x *= (SCREEN_PIXEL_SIZE.y / SCREEN_PIXEL_SIZE.x) * 0.5;

    float dist = length(pos);

    float circle =step(radius, dist);

    COLOR = vec4(color.xyz, circle);
}