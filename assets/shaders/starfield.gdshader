shader_type canvas_item;

uniform vec4 bg_color : source_color = vec4(0.0, 0.0, 0.0, 0.0);
uniform float star_density : hint_range(0.0, 1.0) = 0.01;
uniform float pixel_size : hint_range(1.0, 10.0) = 2.0;

float hash(vec2 p) {
    vec3 p3  = fract(vec3(p.xyx) * 0.1031);
    p3 += dot(p3, p3.yzx + 33.33);
    return fract((p3.x + p3.y) * p3.z);
}

void fragment() {
    vec2 grid_uv = floor(FRAGCOORD.xy / pixel_size);
    float h = hash(grid_uv);
    
    vec4 color = bg_color;
    
    if (h < star_density) {
        float brightness = fract(h * 1337.0);
        vec3 star_color = vec3(1.0, 1.0, 0.9 + 0.1 * fract(h * 42.0));
        color = vec4(star_color * (0.8 + 0.2 * brightness), 1.0);
    }
    
    COLOR = color;
}
