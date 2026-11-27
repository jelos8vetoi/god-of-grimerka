shader_type spatial;
render_mode diffuse_burley;

uniform sampler2D ground_color : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D ground_normal : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D ground_rough : filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D gravel_color : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D gravel_normal : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D gravel_rough : filter_linear_mipmap_anisotropic, repeat_enable;
uniform float frost = 0.0;

varying vec2 world_xz;

void vertex() {
	world_xz = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xz;
}

void fragment() {
	vec2 grass_uv = world_xz / 2.10;
	vec2 stone_uv = world_xz / 1.10;
	// Mix real ground and gravel maps using a broad sample of the ground's roughness.
	float patches = textureLod(ground_rough, world_xz / 36.0 + vec2(0.23, 0.58), 3.8).r;
	float stone = smoothstep(0.42, 0.55, patches);
	vec3 grass = texture(ground_color, grass_uv).rgb;
	grass = mix(vec3(dot(grass, vec3(0.2126, 0.7152, 0.0722))), grass, 0.64) * vec3(0.73, 0.78, 0.64);
	vec3 gravel = texture(gravel_color, stone_uv).rgb * vec3(0.82, 0.78, 0.69);
	vec3 base_color = mix(grass, gravel, stone) * mix(0.80, 1.13, patches);
	ALBEDO = mix(base_color, vec3(0.69, 0.74, 0.79), frost * 0.84);
	NORMAL_MAP = mix(texture(ground_normal, grass_uv).rgb, texture(gravel_normal, stone_uv).rgb, stone);
	NORMAL_MAP_DEPTH = mix(0.55, 0.28, frost);
	ROUGHNESS = mix(0.78, 1.0, mix(texture(ground_rough, grass_uv).r, texture(gravel_rough, stone_uv).r, stone));
}
