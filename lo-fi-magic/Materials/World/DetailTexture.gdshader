// Modified from:
// https://github.com/solarstrings/Godot4.x_Shader_TextureSplatting/blob/main/Scenes/TextureSplatting/texture_splatting.gdshader
shader_type spatial;

uniform sampler2D texture1;										// The texture above
uniform float tex1blend_amount:hint_range(-0.1, 1.0, 0.01) = 1;	// How much to blend the two textures together
uniform float tex1_resolution:hint_range(0.01, 10.0, 0.1) = 1.0;
uniform vec2 tex1_uvscale = vec2(1,1);
uniform vec2 tex1_offset = vec2(0,0);
uniform float tex1_rotation:hint_range(0.0,360,1) = 0;
uniform sampler2D texture2;										// The texture below
uniform float tex2blend_amount:hint_range(-0.1, 1.0, 0.01) = 1;	// How much to blend the two textures together
uniform float tex2_resolution:hint_range(0.01, 10.0, 0.1) = 1.0;
uniform vec2 tex2_uvscale = vec2(1,1);
uniform vec2 tex2_offset = vec2(0,0);
uniform float tex2_rotation:hint_range(0.0,360,1) = 0;

// https://forum.godotengine.org/t/simple-texture-rotation-shader/24198
vec2 rotateUV(vec2 uv, float rotation) {
	rotation *= (PI / 180.0); // deg_to_rad if it existed for shader scripts...
    vec2 pivot = vec2(0.5);
    mat2 rotation_matrix=mat2(	vec2(sin(rotation),-cos(rotation)),
								vec2(cos(rotation),sin(rotation))
								);
    uv -= pivot;
    uv= uv*rotation_matrix;
    uv += pivot;
    return uv;
}

void fragment() {
	vec2 tex1UV = (UV + tex1_offset) * tex1_uvscale;
	vec2 tex2UV = (UV + tex2_offset) * tex2_uvscale;
    vec4 tex1 = texture(texture1, rotateUV(tex1UV, tex1_rotation) * tex1_resolution);			// Get the first texture
    vec4 tex2 = texture(texture2, rotateUV(tex2UV, tex2_rotation) * tex2_resolution);			// Get the second texture	
	vec4 blended_color = ((tex1 * tex1blend_amount) * (tex2 * tex2blend_amount));					// Blend the two textures with the blended pixel	
	ALBEDO = blended_color.rgb;										// Set the albedo	
}
