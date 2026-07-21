shader_type canvas_item;

uniform float pixel_size : hint_range(1.0, 64.0) = 8.0;
uniform sampler2D screen_texture : hint_screen_texture, filter_nearest;

void fragment() {
    vec2 screen_size = 1.0 / SCREEN_PIXEL_SIZE;
    
    // Coordenadas de pantalla actuales
    vec2 uv = SCREEN_UV;
    
    // Tamaño de cada "celda" pixel en UV de pantalla
    vec2 cell = pixel_size / screen_size;
    
    // Redondeamos al centro de la celda más cercana
    vec2 pixelated_uv = floor(uv / cell) * cell + cell * 0.5;
    
    COLOR = texture(screen_texture, pixelated_uv);
}