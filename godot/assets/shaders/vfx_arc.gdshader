// Дуга удара: след оружия в момент попадания (fx.gd → arc). Один материал на все дуги —
// всё, что отличает удар от удара, задаётся параметрами экземпляра (set_instance_shader_parameter),
// поэтому сотня разных ударов не плодит материалов и не ломает пакетную отрисовку.
// Сетка дуги (fx._arc_mesh): UV.x — вдоль дуги от хвоста (0) к голове (1), UV.y — поперёк от внутреннего края (0) к внешнему (1).
shader_type spatial;
render_mode unshaded, blend_add, cull_disabled, depth_draw_never, shadows_disabled, fog_disabled;

instance uniform float progress = 0.0;       // 0 → 1 за жизнь дуги
instance uniform vec4 tint : source_color = vec4(1.0, 0.8, 0.45, 1.0);
instance uniform vec4 core : source_color = vec4(1.0, 1.0, 1.0, 1.0);   // цвет режущей кромки
instance uniform float width = 0.45;         // доля полосы (0.05 — тонкая нить, 1 — широкий мазок)
instance uniform float edge = 0.6;           // 0 — мягкий мазок, 1 — жёсткое лезвие
instance uniform float grain = 0.0;          // рваность: 0 — гладко, 1 — клочья (стекло, гранж, дерево)
instance uniform float bands = 0.0;          // поперечные полосы: звуковая волна гитары, порывы воздуха
instance uniform float seed = 0.0;
instance uniform float span = 2.4;           // раствор дуги, радианы

// сетка — плоскость с подразбиением (UV — сетка), форму дуги задаём здесь: раствор у каждой дуги свой
void vertex() {
	float ang = (UV.x - 0.5) * span;
	float rad = mix(0.45, 1.0, UV.y);
	VERTEX = vec3(sin(ang) * rad, 0.0, -cos(ang) * rad);
}

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7)) + seed * 17.13) * 43758.5453);
}

float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), f.x), mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), f.x), f.y);
}

void fragment() {
	float k = clamp(progress, 0.0, 1.0);
	// голова уходит вперёд быстро, хвост догоняет — дуга «прочерчивается» и тает
	float head = min(1.0, 0.55 + k * 1.6);
	float tail = clamp(k * 1.35 - 0.25, 0.0, 1.0);
	float along = smoothstep(tail, tail + 0.25, UV.x) * (1.0 - smoothstep(head - 0.04, head, UV.x));
	// толщина: у головы полная, к хвосту сходит на нет
	float w = width * mix(0.25, 1.0, UV.x) * (1.0 - k * 0.45);
	float inner = 1.0 - w;
	float soft = mix(0.5, 0.06, edge);
	float across = smoothstep(inner, inner + soft * w + 0.001, UV.y) * (1.0 - smoothstep(0.93, 1.0, UV.y));
	// кромка — яркая нить у внешнего края
	float rim = smoothstep(0.78, 0.95, UV.y) * (1.0 - smoothstep(0.96, 1.0, UV.y));
	float g = 1.0;
	if (grain > 0.0) {
		float n = noise(vec2(UV.x * 26.0 - k * 6.0, UV.y * 5.0));
		g = smoothstep(grain * 0.75, grain * 0.75 + 0.18, n);
	}
	float b = 1.0;
	if (bands > 0.0) {
		b = 0.55 + 0.45 * sin((UV.x * bands - k * 3.0) * 6.2831);
	}
	float a = along * across * g * b * (1.0 - k * k);
	ALBEDO = mix(tint.rgb, core.rgb, rim * (0.55 + 0.45 * edge));
	ALPHA = clamp(a * tint.a * (1.0 + rim * 0.8), 0.0, 1.0);
}
