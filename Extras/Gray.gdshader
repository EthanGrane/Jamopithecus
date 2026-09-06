shader_type canvas_item;

uniform float gray_amount : hint_range(0.0, 1.0) = 1.0;

void fragment() {
    vec4 tex_color = texture(TEXTURE, UV);
    
    float gray = dot(tex_color.rgb, vec3(0.299, 0.587, 0.114));
    

    COLOR.rgb = mix(tex_color.rgb, vec3(gray), gray_amount);
    COLOR.a = tex_color.a;
}