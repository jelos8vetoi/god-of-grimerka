// Ударное кольцо (fx.gd → shock): волна от попадания, лучи-удар, эхо звуковой волны, «цифровые» разрывы.
// Квадрат 1×1; лицом к камере (bill = 1) или лёжа на земле (bill = 0). Параметры — на экземпляр, материал один.
shader_type spatial;
render_mode unshaded, blend_add, cull_disabled, depth_draw_never, shadows_disabled, fog_disabled;

instance uniform float progress = 0.0;
instance uniform vec4 tint : source_color = vec4(1.0, 0.8, 0.45, 1.0);
instance uniform float thick = 0.18;         // толщина кольца в начале (доля радиуса)
instance uniform float rays = 0.0;           // лучей звезды (0 — без них)
instance uniform float waves = 0.0;          // колец-эха внутри (звук, давление воздуха)
instance uniform float segs = 0.0;           // разрывы по кругу: 0 — сплошное, 4…12 — пунктир
instance uniform float bill = 1.0;
instance uniform float seed = 0.0;

void vertex() {
	if (bill > 0.5) {
		// лицом к камере, масштаб узла сохраняется
		float s = length(MODEL_MATRIX[0].xyz);
		MODELVIEW_MATRIX = VIEW_MATRIX * mat4(INV_VIEW_MATRIX[0] * s, INV_VIEW_MATRIX[1] * s, INV_VIEW_MATRIX[2] * s, MODEL_MATRIX[3]);
	}
}

void fragment() {
	float k = clamp(progress, 0.0, 1.0);
	vec2 c = UV * 2.0 - 1.0;
	float r = length(c);
	float ang = atan(c.y, c.x);
	float R = 1.0 - pow(1.0 - k, 3.0);               // радиус волны: быстро наружу, затем медленно
	float t = thick * (1.0 - k * 0.8) + 0.015;
	float ring = smoothstep(R - t, R - t * 0.35, r) * (1.0 - smoothstep(R, R + 0.02, r));
	float echo = 0.0;
	if (waves > 0.0) {
		for (int i = 1; i <= 4; i++) {
			if (float(i) > waves) break;
			float Ri = R * (1.0 - 0.2 * float(i));
			float ti = t * 0.45;
			echo += (smoothstep(Ri - ti, Ri, r) - smoothstep(Ri, Ri + ti, r)) * (1.0 - 0.2 * float(i));
		}
	}
	float star = 0.0;
	if (rays > 0.0) {
		float s = abs(cos(ang * rays * 0.5 + seed * 6.2831));
		s = pow(s, 18.0);
		star = s * (1.0 - smoothstep(0.0, mix(0.35, 1.0, k), r)) * (1.0 - k);
	}
	float gap = 1.0;
	if (segs > 0.0) {
		gap = step(0.32, fract(ang / 6.2831 * segs + seed));
	}
	float a = (ring * gap + echo * 0.8) * (1.0 - k * k) + star;
	ALBEDO = mix(tint.rgb, vec3(1.0), clamp(star * 0.8 + ring * (1.0 - k) * 0.35, 0.0, 1.0));
	ALPHA = clamp(a * tint.a, 0.0, 1.0) * step(r, 1.0);
}
