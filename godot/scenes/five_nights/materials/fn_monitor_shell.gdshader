shader_type canvas_item;
render_mode unshaded;

uniform vec2 plate;
uniform vec3 upper_left;
uniform vec3 upper_right;
uniform vec3 lower_left;
uniform vec3 lower_right;

varying vec3 projective_uv;

void vertex() {
	vec3 corner = mix(mix(upper_left, upper_right, UV.x), mix(lower_left, lower_right, UV.x), UV.y);
	VERTEX = corner.xy;
	projective_uv = vec3(UV, 1.0) * corner.z;
}

float rounded_box(vec2 p, vec2 extent, float radius) {
	vec2 d = abs(p) - extent + radius;
	return length(max(d, 0.0)) + min(max(d.x, d.y), 0.0) - radius;
}

float hash(vec2 p) {
	vec3 q = fract(vec3(p.xyx) * vec3(0.1031, 0.11369, 0.13787));
	q += dot(q, q.yzx + 19.19);
	return fract((q.x + q.y) * q.z);
}

vec3 diode(vec3 col, vec2 p, vec2 center, float radius, vec3 light) {
	vec2 lens = (p - center) / vec2(radius * 0.78, radius);
	float d = length(lens);
	vec3 spill = 0.075 * exp(-d * d * 0.32) * light;
	col = mix(col + spill, vec3(0.018), 1.0 - smoothstep(1.12, 1.43, d));
	float bulb = 1.0 - smoothstep(0.78, 1.06, d);
	float gleam = exp(-12.0 * dot(lens + vec2(0.22, 0.28), lens + vec2(0.22, 0.28)));
	return mix(col, (0.25 + 0.67 * (1.0 - min(d * d, 1.0))) * light + gleam * vec3(0.31), bulb);
}

void fragment() {
	vec2 uv = projective_uv.xy / projective_uv.z;
	vec2 p = (uv - 0.5) * plate;
	float h = plate.y;
	float contour = rounded_box(p, plate * 0.5 - vec2(2.0), h * 0.043);
	float opening = rounded_box(p - vec2(plate.x * 0.005, -h * 0.002),
		plate * 0.5 - vec2(plate.x * 0.054, h * 0.047), h * 0.031);

	// Soft roll-off on the molded outer edge and in the recessed seat around the glass.
	float inward = -contour;
	float top = 1.0 - smoothstep(0.01, 0.82, uv.y);
	float rounded_rim = smoothstep(1.0, h * 0.011, inward) * (1.0 - smoothstep(h * 0.012, h * 0.034, inward));
	float warm_key = exp(-3.7 * pow(uv.x - 0.47, 2.0)) * top;
	float grain = (hash(floor(p * 0.72)) - 0.5) * 0.012;
	float recess = 1.0 - smoothstep(1.0, h * 0.017, max(opening, 0.0));
	float plastic = 0.076 + warm_key * 0.077 + rounded_rim * (0.017 + top * 0.095) + grain;
	plastic *= smoothstep(-1.0, h * 0.009, inward) * (1.0 - recess * 0.73);
	vec3 color = plastic * vec3(1.02, 0.99, 0.97);
	float glint = exp(-9.0 * dot((uv - vec2(0.87, 0.87)) * vec2(1.1, 0.88),
		(uv - vec2(0.87, 0.87)) * vec2(1.1, 0.88)));
	vec3 glass = vec3(0.006, 0.006, 0.007) + glint * vec3(0.012, 0.014, 0.017);
	color = mix(glass, color, smoothstep(-1.0, 1.0, opening));
	color = diode(color, p, (vec2(0.027, 0.119) - 0.5) * plate, h * 0.0085, vec3(0.91, 0.11, 0.095));
	color = diode(color, p, (vec2(0.027, 0.164) - 0.5) * plate, h * 0.0085, vec3(0.27, 0.70, 0.16));

	float antialias = max(fwidth(contour), 1.0);
	COLOR = vec4(color, 1.0 - smoothstep(-antialias, antialias, contour));
}
