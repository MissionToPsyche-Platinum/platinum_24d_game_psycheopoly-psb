shader_type canvas_item;

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
    vec4 tint = COLOR;

    float lum = dot(tex_color.rgb, vec3(0.299, 0.587, 0.114));
    float mask = clamp(lum * 1.8 + 0.55, 0.0, 1.0);

    vec3 dark_tint = tint.rgb * 0.88;
    vec3 bright_tint = min(tint.rgb * 1.55, vec3(1.0));
    vec3 result = mix(dark_tint, bright_tint, mask);

    if (use_outline && tex_color.a < 0.1 && outline > 0.0) {
        COLOR = outline_color;
    } else {
        COLOR = vec4(result, tex_color.a * tint.a);
    }
}