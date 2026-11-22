shader_type spatial;
render_mode unshaded;

// The large tube shows the station signal. The auxiliary tube carries static.
uniform bool static_channel = false;
uniform float brightness : hint_range(0.0, 1.5) = 0.65;
uniform vec4 phosphor : source_color = vec4(0.50, 0.78, 0.65, 1.0);
uniform sampler2D dust : repeat_enable, filter_linear_mipmap;

void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	vec2 corner = max(abs(p) - vec2(0.88, 0.84), vec2(0.0));
	if (length(corner) > 0.16) {
		discard;
	}
	vec2 uv = 0.5 + 0.5 * p * (1.0 + 0.065 * dot(p, p));
	float scan = 0.85 + 0.15 * cos(uv.y * 340.0);
	float grid = max(step(0.97, fract(uv.x * 12.0)), step(0.96, fract(uv.y * 8.0)));
	float wave = 0.51 + 0.08 * sin(uv.x * 25.0 + TIME) + 0.025 * sin(uv.x * 83.0);
	float signal = 0.06 + 0.11 * grid + 0.80 * exp(-abs(uv.y - wave) * 90.0);
	if (static_channel) {
		vec2 cell = floor(uv * vec2(170.0, 110.0));
		float snow = fract(sin(dot(cell, vec2(12.9898, 78.233)) + floor(TIME * 19.0)) * 4375.85);
		signal = 0.055 + 0.42 * snow;
	}
	float falloff = max(0.18, 1.0 - 0.48 * dot(p, p));
	float vig = 1.0 - 0.28 * smoothstep(0.55, 1.15, length(p));
	float speck = smoothstep(0.93, 0.99, texture(dust, UV * 7.0).r) * 0.05;
	ALBEDO = vec3(0.005, 0.008, 0.007) + phosphor.rgb * (signal * scan * falloff * vig + speck) * brightness;
}
