shader_type canvas_item;

uniform sampler2D screen_texture : hint_screen_texture, filter_nearest;

// Curvatura de pantalla
uniform float curvature : hint_range(0.0, 10.0) = 4.0;

// Scanlines (líneas horizontales)
uniform float scanline_count : hint_range(50.0, 800.0) = 240.0;
uniform float scanline_intensity : hint_range(0.0, 1.0) = 0.3;

// Aberración cromática
uniform float chromatic_aberration : hint_range(0.0, 0.02) = 0.003;

// Viñeta
uniform float vignette_strength : hint_range(0.0, 2.0) = 0.8;
uniform float vignette_softness : hint_range(0.1, 2.0) = 0.5;

// Ruido/estática
uniform float noise_amount : hint_range(0.0, 0.2) = 0.03;

// Brillo general
uniform float brightness : hint_range(0.5, 2.0) = 1.1;

float random(vec2 uv) {
    return fract(sin(dot(uv, vec2(12.9898, 78.233))) * 43758.5453);
}

vec2 curve_uv(vec2 uv) {
    uv = uv * 2.0 - 1.0;
    vec2 offset = abs(uv.yx) / curvature;
    uv = uv + uv * offset * offset;
    uv = uv * 0.5 + 0.5;
    return uv;
}

void fragment() {
    vec2 uv = curve_uv(SCREEN_UV);
    
    bool out_of_bounds = uv.x < 0.0 || uv.x > 1.0 || uv.y < 0.0 || uv.y > 1.0;
    
    if (out_of_bounds) {
        COLOR = vec4(0.0, 0.0, 0.0, 1.0);
    } else {
        // Aberración cromática: separamos los canales RGB
        float r = texture(screen_texture, uv + vec2(chromatic_aberration, 0.0)).r;
        float g = texture(screen_texture, uv).g;
        float b = texture(screen_texture, uv - vec2(chromatic_aberration, 0.0)).b;
        vec3 color = vec3(r, g, b);
        
        // Scanlines
        float scanline = sin(uv.y * scanline_count * PI) * 0.5 + 0.5;
        color *= 1.0 - scanline_intensity * scanline;
        
        // Ruido/estática
        float noise = random(uv + vec2(TIME * 0.01, 0.0)) * noise_amount;
        color += noise;
        
        // Viñeta
        vec2 vignette_uv = uv * (1.0 - uv.yx);
        float vignette = vignette_uv.x * vignette_uv.y * 15.0;
        vignette = pow(vignette, vignette_strength * vignette_softness);
        color *= clamp(vignette, 0.0, 1.0);
        
        // Brillo
        color *= brightness;
        
        COLOR = vec4(color, 1.0);
    }
}