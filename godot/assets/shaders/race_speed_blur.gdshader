shader_type canvas_item;
render_mode unshaded, blend_disabled;

uniform sampler2D scene_color : hint_screen_texture, repeat_disable, filter_linear_mipmap;
uniform float span = 0.0;
uniform float clear_radius = 0.46;
uniform float edge_radius = 1.06;

void fragment() {
	vec2 uv = SCREEN_UV;
	vec2 delta = uv - vec2(0.5, 0.55);
	float mask = smoothstep(clear_radius, edge_radius, length(delta * vec2(2.12, 1.30)));
	vec2 offset = delta * (span * mask);
	vec3 color = textureLod(scene_color, uv, 0.0).rgb;
	if (mask > 0.001) {
		// Подбираем детализацию соседних выборок по длине следа в пикселях.
		float lod = clamp(log2(max(1.0, length(offset / SCREEN_PIXEL_SIZE) / 3.0)), 0.0, 2.0);
		color *= 0.22;
		color += (textureLod(scene_color, uv - offset / 3.0, lod).rgb +
		          textureLod(scene_color, uv + offset / 3.0, lod).rgb) * 0.19;
		color += (textureLod(scene_color, uv - offset * 0.67, lod).rgb +
		          textureLod(scene_color, uv + offset * 0.67, lod).rgb) * 0.14;
		color += (textureLod(scene_color, uv - offset, lod).rgb +
		          textureLod(scene_color, uv + offset, lod).rgb) * 0.06;
	}
	COLOR = vec4(color, 1.0);
}
