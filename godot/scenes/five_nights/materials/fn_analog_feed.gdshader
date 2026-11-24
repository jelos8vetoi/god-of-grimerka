shader_type canvas_item;
render_mode unshaded;

uniform sampler2D feed : filter_linear, repeat_disable;
uniform float t = 0.0;
uniform float noise_k = 0.055;
uniform float gain = 1.0;
uniform vec3 tint = vec3(0.94, 1.0, 0.91);
uniform float wobble = 0.8;
uniform float fx = 1.0;
uniform bool stage_detail = false;

uniform float switch_k = 0.0;
uniform float switch_phase = 0.0;
uniform float interference = 0.0;
uniform float jam = 0.0;
uniform float haunt = 0.0;
uniform float spoof = 0.0;
uniform float lost = 0.0;
uniform float recovery = 0.0;

// Sample the signal, not the output pixels. A field advances on a 50 Hz clock.
const vec2 GRAIN_GRID = vec2(968.0, 544.0);
const float LINES = 360.0;

float hash(vec2 p) {
	vec3 q = fract(vec3(p.xyx) * vec3(0.1031, 0.11369, 0.13787));
	q += dot(q, q.yzx + 19.19);
	return fract((q.x + q.y) * q.z);
}

float luma(vec3 c) {
	return dot(c, vec3(0.25, 0.62, 0.13));
}

float line_sample(float x, float row, float field) {
	vec2 cell = vec2(floor(x), row) + field * vec2(19.0, 37.0);
	return mix(hash(cell), hash(cell + vec2(1.0, 0.0)), fract(x));
}

// Black-level clamp with a soft shoulder: black stays black and hard highlights stay legible.
float encode_luma(float source) {
	float y = max(source - 0.013, 0.0);
	y *= mix(0.80, 1.08, smoothstep(0.015, 0.23, y));
	return y / (1.0 + 0.85 * max(y - 0.49, 0.0));
}

void fragment() {
	vec2 uv = UV;
	vec2 texel = 1.0 / vec2(textureSize(feed, 0));
	float field = mod(floor(t * 50.0), 1024.0);
	float row = floor(uv.y * LINES);
	float line_clock = hash(vec2(row, field));
	float coarse_clock = hash(vec2(floor(row / 5.0), field));
	float tear = (coarse_clock - 0.5) * step(0.58, coarse_clock);
	float roll_y = fract(uv.y + t * 0.72);
	float sync_bar = 1.0 - smoothstep(0.02, 0.105, abs(roll_y - 0.5));
	float switch_bar = 1.0 - smoothstep(0.04, 0.38, abs(uv.y - mix(0.93, 0.025, switch_phase)));
	float bot_band = 1.0 - smoothstep(0.05, 0.24, abs(fract(uv.y - t * 0.43) - 0.5));
	float desync = max(interference, max(lost, recovery));

	uv.x += fx * ((line_clock - 0.5) * 0.00145 * wobble
		+ sync_bar * sin(t * 1.2) * 0.0018
		+ tear * (0.32 * desync + 0.40 * switch_k * switch_bar)
		+ sin(uv.y * 52.0 + t * 17.0) * 0.022 * bot_band * jam
		+ sin(uv.y * 13.0 - t * 3.2) * 0.020 * haunt);
	uv.y += fx * (switch_k * (hash(vec2(field, 3.0)) - 0.5) * 0.13
		+ recovery * (hash(vec2(field, 9.0)) - 0.5) * 0.075);

	// A narrow horizontal aperture preserves the person and room silhouette.
	vec2 tap = vec2(texel.x * 0.71, 0.0);
	float aperture = stage_detail ? 0.065 : 0.105;
	vec3 rgb = texture(feed, uv).rgb * (1.0 - 2.0 * aperture);
	rgb += (texture(feed, uv - tap).rgb + texture(feed, uv + tap).rgb) * aperture;
	float source_y = luma(rgb);
	float signal = encode_luma(pow(max(source_y, 0.0), 0.91) * gain);
	signal *= 1.0 + wobble * fx * (0.023 * sin(t * 1.39) + 0.011 * sin(t * 4.2));
	vec3 picture = (vec3(signal) + (rgb - source_y) * (stage_detail ? 0.23 : 0.17)) * mix(vec3(1.0), tint, 0.67);

	// MOD's splice and GHOST's echo belong to the existing game events.
	float splice = 1.0 - smoothstep(0.0, 0.009, abs(UV.y - (0.966 + sin(t * 5.8) * 0.007)));
	picture *= 1.0 - splice * 0.23 * spoof * fx;
	if (haunt > 0.0) {
		float echo = luma(texture(feed, uv + vec2(0.033, 0.004) * haunt * fx).rgb);
		picture = mix(picture, vec3(max(signal, echo * 1.18), signal * 0.53, signal * 0.42), haunt * 0.77);
	}

	float dark = 1.0 - smoothstep(0.04, 0.43, signal);
	vec2 grain_uv = UV * GRAIN_GRID;
	float grain = line_sample(grain_uv.x, floor(grain_uv.y), field) - 0.5;
	float streak = line_sample(UV.x * 126.0 + 31.0 * line_clock, row + 71.0, field) - 0.5;
	float streak_gate = smoothstep(0.42, 0.99, line_clock);
	float grain_strength = (0.025 + 0.57 * noise_k) * mix(0.35, 1.15, dark);
	float streak_strength = (0.008 + 0.064 * streak_gate) * mix(0.32, 0.95, dark);
	picture += (grain * grain_strength + streak * streak_strength) * fx;
	float trace = 0.5 - 0.5 * cos(UV.y * LINES * 6.283185);
	float visibility = 1.0 - smoothstep(0.31, 0.78, fwidth(UV.y * LINES));
	picture *= 1.0 - fx * (trace * visibility * (0.022 + 0.027 * line_clock) + 0.016 * sync_bar);
	vec2 edge = UV - 0.5;
	picture *= 1.0 - 0.20 * smoothstep(0.03, 0.45, dot(edge, edge));

	float rf = jam * (0.79 + 0.19 * bot_band);
	float rf_noise = 0.068 + 0.16 * bot_band + grain * (0.10 + 0.33 * bot_band) * fx;
	picture = mix(picture, vec3(0.79, 0.92, 0.93) * rf_noise, rf);

	// Loss of horizontal lock exposes snow and a moving set of torn rows.
	vec2 bad_uv = vec2(UV.x + tear * 0.28, fract(UV.y + t * 0.84 + tear * 0.1));
	float snow_row = floor(bad_uv.y * LINES);
	float snow = line_sample(bad_uv.x * 492.0, snow_row, field);
	float loss_streak = line_sample(bad_uv.x * 27.0, snow_row + 23.0, field);
	float dropout = smoothstep(0.38, 0.94, coarse_clock);
	float static_y = 0.042 + snow * snow * 0.42 + smoothstep(0.50, 1.0, loss_streak) * 0.20;
	static_y *= mix(1.0, 0.45, dropout) * (0.76 + sync_bar * 0.49);
	vec3 static_rgb = vec3(static_y);
	float dropout_mix = max(lost, max(interference * (0.92 + 0.08 * dropout),
		recovery * (0.28 + 0.72 * smoothstep(0.16, 0.70, roll_y))));
	float tuning = switch_k * (0.12 + 0.84 * switch_bar);
	picture = mix(picture, mix(vec3(0.088), static_rgb, 0.27 + 0.73 * fx), max(dropout_mix, tuning));
	COLOR = vec4(max(picture, vec3(0.0)), 1.0);
}
