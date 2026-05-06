shader_type spatial;

// Your two textures
uniform sampler2D top_texture : source_color, repeat_enable;   // e.g. grass
uniform sampler2D side_texture : source_color, repeat_enable;  // e.g. stone wall

// Controls how sharp the transition is between top and sides
uniform float blend_sharpness : hint_range(1.0, 20.0) = 8.0;

// Texture tiling scale
uniform float top_scale : hint_range(0.1, 10.0) = 1.0;
uniform float side_scale : hint_range(0.1, 10.0) = 1.0;

// Where the top texture ends and side texture begins (0.0 = equator, 1.0 = very top only)
uniform float top_threshold : hint_range(0.0, 1.0) = 0.5;

varying vec3 world_pos;
varying vec3 world_normal;

void vertex() {
    // Pass world-space position and normal to fragment shader
    world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
    world_normal = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

void fragment() {
    // Sample the side texture using triplanar projection (from X and Z axes)
    vec4 side_x = texture(side_texture, world_pos.zy * side_scale);
    vec4 side_z = texture(side_texture, world_pos.xy * side_scale);

    // Blend weights for the side faces based on the normal
    vec3 blend = pow(abs(world_normal), vec3(blend_sharpness));
    blend = blend / (blend.x + blend.y + blend.z);

    // Combine the two side projections (x and z contribute to sides)
    vec4 side_color = side_x * blend.y + side_z * blend.x;
    // Note: we'll override blend.y (top face) with the top texture below

    // Sample top texture using the Y-axis projection (top-down)
    vec4 top_color = texture(top_texture, world_pos.xz * top_scale);

    // Blend factor: how much does this fragment face upward?
    // world_normal.y goes from -1 (bottom) to 1 (top)
    float top_blend = smoothstep(top_threshold - 0.1, top_threshold + 0.1, world_normal.y);

    // Mix: top_blend=1 means fully top texture, 0 means fully side texture
    vec4 final_color = mix(side_color, top_color, top_blend);

    ALBEDO = final_color.rgb;
}