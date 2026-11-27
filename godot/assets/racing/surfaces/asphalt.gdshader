shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx;

uniform sampler2D color_map : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D normal_map : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D rough_map : filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D wear_map : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform float tile_m = 1.95;
uniform float wetness = 0.0;
uniform float frost = 0.0;
uniform float dry_normal = 0.82;

varying vec2 world_xz;

void vertex() {
	world_xz = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xz;
}

void fragment() {
	vec2 uv = UV / tile_m;
	// A second, low-frequency sample of the scanned surface breaks up long runs of tiling.
	float wear = textureLod(wear_map, world_xz / 26.0 + vec2(0.37, 0.73), 4.0).r;
	float patches = smoothstep(0.079, 0.123, wear);
	float water_film = wetness * mix(0.50, 1.0, 1.0 - patches);
	vec3 aggregate = texture(color_map, uv).rgb * 2.45;
	vec3 weathered = texture(wear_map, mat2(vec2(0.916, 0.401), vec2(-0.401, 0.916)) * world_xz / 3.2).rgb * 0.55;
	vec3 surface_color = mix(aggregate, weathered, mix(0.18, 0.44, patches));
	// Worn edge paint and dust accumulate outside the wheel paths of the depot street.
	float edge_m = abs(UV2.x);
	float edge_dust = smoothstep(0.76, 1.0, edge_m) * mix(0.1, 0.32, patches);
	float stripe_width = max(fwidth(edge_m), 0.0015);
	float paint = 1.0 - smoothstep(0.005, 0.005 + stripe_width, abs(edge_m - 0.929));
	float grain = smoothstep(0.026, 0.085, weathered.r);
	surface_color = mix(surface_color, vec3(0.24, 0.185, 0.127), edge_dust * UV2.y);
	surface_color = mix(surface_color, vec3(0.62, 0.62, 0.51), paint * grain * UV2.y * 0.84);
	ALBEDO = mix(surface_color * mix(1.0, 0.73, water_film), vec3(0.27, 0.31, 0.35), frost * 0.32);
	NORMAL_MAP = texture(normal_map, uv).rgb;
	NORMAL_MAP_DEPTH = mix(dry_normal, dry_normal * 0.43, max(water_film, frost));
	float dry_roughness = mix(0.70, 0.94, texture(rough_map, uv).r);
	ROUGHNESS = mix(mix(dry_roughness, 0.26, water_film), 0.42, frost);
	METALLIC = 0.0;
	SPECULAR = mix(0.32, 0.49, water_film);
}
