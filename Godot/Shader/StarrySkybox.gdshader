shader_type sky;

uniform sampler2D noise_texture : source_color, hint_default_white;
uniform float star_threshold : hint_range(0.0, 1.0) = 0.85; // Higher = fewer stars
uniform float star_brightness : hint_range(0.0, 10.0) = 2.0;
uniform float star_sharpness : hint_range(1.0, 64.0) = 16.0; // Edge falloff
uniform vec4 sky_color_top : source_color = vec4(0.02, 0.02, 0.08, 1.0);
uniform vec4 sky_color_horizon : source_color = vec4(0.05, 0.03, 0.10, 1.0);
uniform float horizon_blend : hint_range(0.0, 8.0) = 3.0;

void sky() {
    // --- UV mapping for the noise texture ---
    // Convert spherical direction to equirectangular UV
    vec3 dir = EYEDIR;
    float u = atan(dir.z, dir.x) / (2.0 * PI) + 0.5;
    float v = asin(clamp(dir.y, -1.0, 1.0)) / PI + 0.5;
    vec2 uv = vec2(u, v);

    // --- Sample noise and extract stars ---
    float noise = texture(noise_texture, uv).r;

    // Remap noise above threshold into a 0..1 star mask
    float star_mask = smoothstep(star_threshold, star_threshold + (1.0 - star_threshold) / star_sharpness, noise);
    vec3 star_color = vec3(star_mask * star_brightness);

    // --- Sky gradient (top to horizon) ---
    float horizon_factor = pow(1.0 - abs(dir.y), horizon_blend);
    vec3 sky = mix(sky_color_top.rgb, sky_color_horizon.rgb, horizon_factor);

    // --- Hide stars below the horizon ---
    float above_horizon = step(0.0, dir.y);
    star_color *= above_horizon;

    // --- Combine ---
    COLOR = sky + star_color;
}