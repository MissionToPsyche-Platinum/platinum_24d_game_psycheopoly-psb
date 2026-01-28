shader_type canvas_item;

uniform vec4 target_color : source_color;
uniform float color_intensity : hint_range(0.0, 1.0) = 1.0;

void fragment() {
    vec4 tex_color = texture(TEXTURE, UV);
    
    // Calculate luminance of the original texture
    float lum = dot(tex_color.rgb, vec3(0.299, 0.587, 0.114));
    
    float bright_lum = clamp(lum * 2.0 + 0.1, 0.0, 1.0);
    
    // Mix the target color with the brightness
    vec3 colored = target_color.rgb * bright_lum;
    
    // Boost saturation in the midtones/shadows
    colored = mix(colored, target_color.rgb, 0.10 * (1.0 - lum));
    
    vec3 result = mix(tex_color.rgb, colored, color_intensity);
    COLOR = vec4(result, tex_color.a);
}
