// Предупреждение об ударе врага на земле (fx.gd → tell): форма — ровно зона попадания из enemy.gd.
// Сектор (half_ang — половина угла, радиус = дальность удара) или круг (half_ang ≥ π), или полоса (lane > 0: рывок, луч).
// Заполнение растёт от врага к краю за время замаха (progress 0 → 1): дошло до края — удар.
// Узор по типу врага (pattern): 0 — сплошной, 1 — «цифровые» клетки (BOT, MOD), 2 — косые надрезы (CLIPPER),
// 3 — «дизлайки»-крестики (HATER), 4 — трещины (TROLL), 5 — волны (GHOST), 6 — строки (LAWYER).
// Квадрат 1×1 на земле, центр — враг; локальный «вперёд» — +UV.y (fx поворачивает узел по взгляду врага).
shader_type spatial;
render_mode unshaded, blend_mix, cull_disabled, depth_draw_never, shadows_disabled, fog_disabled;

instance uniform float progress = 0.0;
instance uniform vec4 tint : source_color = vec4(1.0, 0.2, 0.12, 1.0);
instance uniform float half_ang = 1.1;          // половина угла сектора, радианы
instance uniform float lane = 0.0;           // ширина полосы (доля), 0 — сектор/круг
instance uniform float pattern = 0.0;
instance uniform float fade = 1.0;           // общая прозрачность (исчезание после удара)

void fragment() {
	vec2 c = UV * 2.0 - 1.0;                  // -1…1, +y — вперёд
	c.y = -c.y;
	float r = length(c);
	float ang = abs(atan(c.x, c.y));
	float inside;
	float edge_d;
	if (lane > 0.0) {
		inside = step(abs(c.x), lane) * step(0.0, c.y) * step(c.y, 1.0);
		edge_d = min(lane - abs(c.x), min(c.y, 1.0 - c.y));
		r = c.y;
	} else {
		inside = step(r, 1.0) * step(ang, half_ang);
		// у круга боковых краёв нет — только внешний
		edge_d = half_ang >= 3.1 ? 1.0 - r : min(1.0 - r, (half_ang - ang) * max(r, 0.05));
	}
	if (inside < 0.5) {
		discard;
	}
	float k = clamp(progress, 0.0, 1.0);
	float rim = 1.0 - smoothstep(0.0, 0.035, edge_d);
	float fill = step(r, k);                                   // заливка от врага к краю
	float front = (1.0 - smoothstep(0.0, 0.06, abs(r - k))) * step(0.02, k);   // фронт заливки
	float pat = 0.0;
	vec2 p = UV * 14.0;
	if (pattern > 0.5 && pattern < 1.5) {
		vec2 g = fract(p);
		pat = step(0.12, g.x) * step(0.12, g.y) * step(0.5, fract(sin(dot(floor(p), vec2(12.9898, 78.233))) * 43758.5453));
	} else if (pattern < 2.5 && pattern > 1.5) {
		pat = step(0.82, fract((UV.x + UV.y) * 9.0));
	} else if (pattern < 3.5 && pattern > 2.5) {
		vec2 g = fract(p) - 0.5;
		pat = (1.0 - smoothstep(0.03, 0.07, abs(g.x - g.y))) + (1.0 - smoothstep(0.03, 0.07, abs(g.x + g.y)));
		pat *= step(length(g), 0.35);
	} else if (pattern < 4.5 && pattern > 3.5) {
		pat = step(0.9, fract(ang * 7.0 + r * 3.0));
	} else if (pattern < 5.5 && pattern > 4.5) {
		pat = 0.5 + 0.5 * sin(r * 30.0 - TIME * 6.0);
	} else if (pattern > 5.5) {
		pat = step(0.75, fract(UV.y * 12.0)) * step(0.2, fract(UV.x * 3.0));
	}
	float a = 0.18 + rim * 0.7 + fill * (0.22 + pat * 0.18) + front * 0.6;
	ALBEDO = mix(tint.rgb, vec3(1.0), front * 0.5 + rim * 0.15);
	ALPHA = clamp(a, 0.0, 0.95) * tint.a * fade;
}
