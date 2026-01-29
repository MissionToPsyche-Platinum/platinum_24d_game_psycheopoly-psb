shader_type canvas_item;

uniform vec4 target_color : source_color;
uniform float color_intensity : hint_range(0.0, 1.0) = 1.0;
uniform bool use_outline = false;
uniform vec4 outline_color : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform float outline_width : hint_range(0.0, 10.0) = 1.0;

void fragment() {
    vec2 size = TEXTURE_PIXEL_SIZE * outline_width;
    float outline = 0.0;
    
    if (use_outline) {
        outline += texture(TEXTURE, UV + vec2(size.x, 0.0)).a;
        outline += texture(TEXTURE, UV + vec2(-size.x, 0.0)).a;
        outline += texture(TEXTURE, UV + vec2(0.0, size.y)).a;
        outline += texture(TEXTURE, UV + vec2(0.0, -size.y)).a;
        outline = step(0.01, outline);
    }
    
    vec4 tex_color = texture(TEXTURE, UV);
    
    // Calculate luminance of the original texture
    float lum = dot(tex_color.rgb, vec3(0.299, 0.587, 0.114));
    
    float bright_lum = clamp(lum * 2.0 + 0.1, 0.0, 1.0);
    
    // Mix the target color with the brightness
    vec3 colored = target_color.rgb * bright_lum;
    
    // Boost saturation in the midtones/shadows
    colored = mix(colored, target_color.rgb, 0.10 * (1.0 - lum));
    
    vec3 result = mix(tex_color.rgb, colored, color_intensity);
    
    if (use_outline && tex_color.a < 0.1 && outline > 0.0) {
        COLOR = outline_color;
    } else {
        COLOR = vec4(result, tex_color.a);
    }
}
