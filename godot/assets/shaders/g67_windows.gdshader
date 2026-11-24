// «ГОЛДА 67», новый двор: свет в окнах жилых домов. Окна у моделей запечены в текстуру фасада, отдельного материала нет,
// поэтому второй проход (next_pass) берёт ту же текстуру и подсвечивает тёмные участки (стёкла) в части «клеток» фасада.
// Клетка — примерно одно окно (cell_w × cell_h в метрах мира); какие клетки горят — по хешу клетки и seed дома.
shader_type spatial;
render_mode blend_add, unshaded, depth_draw_never, shadows_disabled;

uniform sampler2D tex : source_color, filter_linear_mipmap;
uniform float seed = 0.0;
uniform float cell_w = 3.2;
uniform float cell_h = 2.8;
uniform float share = 0.3;      // доля горящих окон
uniform float power = 1.5;

varying vec3 wp;
varying vec3 wn;

void vertex() {
	wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	wn = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

float hsh(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7)) + seed) * 43758.5453);
}

void fragment() {
	vec3 c = texture(tex, UV).rgb;
	float lum = dot(c, vec3(0.299, 0.587, 0.114));
	float glass = smoothstep(0.26, 0.10, lum);
	float along = abs(wn.x) > abs(wn.z) ? wp.z : wp.x;
	vec2 cell = floor(vec2(along / cell_w, wp.y / cell_h));
	float on = step(1.0 - share, hsh(cell));
	float wall = step(abs(wn.y), 0.35);
	float up = step(1.6, wp.y);
	vec3 warm = mix(vec3(1.0, 0.70, 0.34), vec3(0.72, 0.84, 1.0), step(0.9, hsh(cell + 7.0)));
	ALBEDO = warm * glass * on * wall * up * power;
}
