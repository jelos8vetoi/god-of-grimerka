shader_type spatial;

uniform vec4 tile : source_color = vec4(0.40, 0.415, 0.39, 1.0);
uniform vec4 joint : source_color = vec4(0.095, 0.10, 0.10, 1.0);
uniform sampler2D grain : source_color, repeat_enable, filter_linear_mipmap;
uniform float tile_size : hint_range(0.2, 1.0) = 0.45;
varying vec2 floor_pos;

void vertex() {
	floor_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xz;
}

void fragment() {
	vec2 uv = floor_pos / tile_size;
	vec2 edge = 0.5 - abs(fract(uv) - 0.5);
	vec2 aa = max(fwidth(uv), vec2(0.0001));
	vec2 face = smoothstep(vec2(0.004) - aa, vec2(0.004) + aa, edge);
	float grain_value = texture(grain, floor_pos * 1.9).r;
	float variation = fract(dot(floor(uv), vec2(0.37, 0.61)));
	ALBEDO = mix(joint.rgb, tile.rgb * (0.67 + 0.23 * grain_value + 0.10 * variation), face.x * face.y);
	ROUGHNESS = 0.73 + 0.18 * grain_value;
}
