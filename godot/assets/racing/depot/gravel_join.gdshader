shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx;

uniform sampler2D gravel : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D relief : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D rough_map : filter_linear_mipmap_anisotropic, repeat_enable;
uniform float wetness = 0.0;

void fragment() {
	vec2 uv = UV / 1.45;
	float grain = texture(rough_map, uv).r;
	// Signed clearance to the edge of the main road, interpolated across the
	// actual shortcut mesh. Erode its overlap so the asphalt shows through.
	float patches = texture(rough_map, uv * 0.27).r;
	float fringe = (patches - 0.6) * 1.8 + (grain - 0.5) * 0.75;
	if (UV2.x + fringe < 0.0) { discard; }
	ALBEDO = texture(gravel, uv).rgb * vec3(0.58, 0.63, 0.65) * mix(1.0,0.72,wetness);
	NORMAL_MAP = texture(relief, uv).rgb;
	NORMAL_MAP_DEPTH = 0.67;
	ROUGHNESS = mix(0.68+0.30*grain, 0.53, wetness);
}
