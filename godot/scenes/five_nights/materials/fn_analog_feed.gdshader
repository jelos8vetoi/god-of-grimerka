shader_type canvas_item;
render_mode unshaded;

uniform sampler2D feed : filter_linear, repeat_disable;
uniform float t = 0.0;
uniform float noise_k = 0.055;
uniform float gain = 1.0;
uniform vec3 tint = vec3(0.94, 1.0, 0.91);
uniform float wobble = 0.8;
uniform float fx = 1.0;

uniform float switch_k = 0.0;
uniform float switch_phase = 0.0;
uniform float interference = 0.0;
uniform float jam = 0.0;
uniform float haunt = 0.0;
uniform float spoof = 0.0;
uniform float lost = 0.0;
uniform float recovery = 0.0;

float hash(vec2 p) {
	vec3 q = fract(vec3(p.xyx) * vec3(0.1031, 0.11369, 0.13787));
	q += dot(q, q.yzx + 19.19);
	return fract((q.x + q.y) * q.z);
}

float luma(vec3 c) {
	return dot(c, vec3(0.25, 0.62, 0.13));
}

void fragment() {
	vec2 uv = UV;
	vec2 px = 1.0 / vec2(textureSize(feed, 0));
	float field = mod(floor(t * 50.0), 1024.0);
	float row = floor(uv.y / px.y);
	float line_noise = hash(vec2(row, field));
	float sync_y = fract(uv.y + t * 0.72);
	float sync_bar = 1.0 - smoothstep(0.035, 0.115, abs(sync_y - 0.5));
	float tear = hash(vec2(floor(row / 5.0), field));
	float tear_shift = (tear - 0.5) * step(0.57, tear);
	float switch_bar = 1.0 - smoothstep(0.05, 0.41, abs(uv.y - mix(0.92, 0.03, switch_phase)));
	float bot_band = 1.0 - smoothstep(0.05, 0.24, abs(fract(uv.y - t * 0.43) - 0.5));
	float desync = max(interference, max(lost, recovery));

	// Luma bandwidth is lower horizontally. Line timing varies independently of pixel grain.
	uv.x += fx * ((line_noise - 0.5) * 0.0015 * wobble
		+ sync_bar * sin(t * 1.2) * 0.002
		+ tear_shift * (0.37 * desync + 0.36 * switch_k * switch_bar)
		+ sin(uv.y * 52.0 + t * 17.0) * 0.022 * bot_band * jam
		+ sin(uv.y * 13.0 - t * 3.2) * 0.020 * haunt);
	uv.y += fx * (switch_k * (hash(vec2(field, 3.0)) - 0.5) * 0.17
		+ recovery * (hash(vec2(field, 9.0)) - 0.5) * 0.08);
	vec3 sample_rgb = texture(feed, uv).rgb * 0.56;
	sample_rgb += (texture(feed, uv - vec2(px.x * 0.92, 0.0)).rgb
		+ texture(feed, uv + vec2(px.x * 0.92, 0.0)).rgb) * 0.22;
	float light = pow(max(luma(sample_rgb), 0.0), 0.88) * gain;
	light *= 1.0 + wobble * fx * (0.026 * sin(t * 1.39) + 0.012 * sin(t * 4.2));
	vec3 picture = (vec3(light) + (sample_rgb - luma(sample_rgb)) * 0.21) * tint;

	// GHOST carries a red image echo. MOD still supplies the original frozen frame, with a quiet sync seam.
	if (haunt > 0.0) {
		float echo = luma(texture(feed, uv + vec2(0.033, 0.004) * haunt * fx).rgb);
		picture = mix(picture, vec3(max(light, echo * 1.23), light * 0.51, light * 0.39), haunt * 0.79);
	}
	float splice = (1.0 - smoothstep(0.0, 0.009, abs(UV.y - (0.966 + sin(t * 5.8) * 0.007))));
	picture *= 1.0 - splice * 0.23 * spoof * fx;

	// Grain is sampled in camera space and advances by field. The line mask is filtered on small windows.
	vec2 grain_at = UV / px + vec2(fract(t * 11.0), 0.0);
	vec2 grain_key = floor(grain_at) + field * vec2(19.0, 33.0);
	float grain = mix(hash(grain_key), hash(grain_key + vec2(1.0, 0.0)), fract(grain_at.x)) - 0.5;
	float scan = cos(UV.y * 6.283185 / px.y);
	float visible_lines = 1.0 - smoothstep(0.29, 0.67, fwidth(UV.y / px.y));
	picture += grain * noise_k * fx;
	picture *= 1.0 - fx * (0.037 * visible_lines * (0.5 - scan * 0.5) + 0.026 * sync_bar);
	vec2 edge = UV - 0.5;
	picture *= 1.0 - 0.53 * dot(edge, edge);

	// BOT adds a rolling RF band. The source remains dimly present between the bands.
	float rf = jam * (0.79 + 0.19 * bot_band);
	float rf_noise = 0.073 + 0.16 * bot_band + grain * (0.11 + 0.37 * bot_band) * fx;
	picture = mix(picture, vec3(0.73, 0.91, 0.93) * rf_noise, rf);

	// A disconnected line has tearing, short streaks and a travelling field offset.
	vec2 snow_uv = vec2(UV.x + tear_shift * 0.32, fract(UV.y + t * 0.84 + tear_shift * 0.1));
	vec2 sample_at = snow_uv / px;
	float snow = hash(floor(sample_at * vec2(0.74, 1.0)) + field * vec2(23.0, 7.0));
	float streak = hash(floor(sample_at * vec2(0.052, 0.73)) + field * vec2(7.0, 13.0));
	float dropout = smoothstep(0.40, 0.94, tear);
	float snow_luma = 0.073 + snow * snow * 0.38 + smoothstep(0.56, 1.0, streak) * 0.22;
	snow_luma *= mix(1.0, 0.47, dropout) * (0.79 + sync_bar * 0.46);
	vec3 static_rgb = vec3(snow_luma) * vec3(0.91, 1.0, 0.98);
	float dropout_mix = max(lost, max(interference * (0.93 + 0.07 * dropout),
		recovery * (0.28 + 0.72 * smoothstep(0.16, 0.69, sync_y))));
	float tuning = switch_k * (0.16 + 0.80 * switch_bar);
	picture = mix(picture, mix(vec3(0.105), static_rgb, 0.27 + 0.73 * fx), max(dropout_mix, tuning));
	COLOR = vec4(max(picture, vec3(0.0)), 1.0);
}
