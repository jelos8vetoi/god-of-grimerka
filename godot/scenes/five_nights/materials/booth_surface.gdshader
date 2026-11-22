shader_type spatial;

// Стены, потолок, эмаль, сталь будки и коридора: одна мировая трипланарная поверхность без своих текстур.
// Грязь, подтёки, сырость от пола, копоть к потолку, ржавчина и сколы считаются шумом из surface_grain.
uniform vec4 base : source_color = vec4(0.5, 0.5, 0.5, 1.0);
uniform sampler2D grain : source_color, repeat_enable, filter_linear_mipmap;
uniform float grain_scale = 0.7;
uniform float rough : hint_range(0.0, 1.0) = 0.9;
uniform float metal : hint_range(0.0, 1.0) = 0.0;
uniform float grime : hint_range(0.0, 1.0) = 0.0;
uniform float streaks : hint_range(0.0, 1.0) = 0.0;
uniform float damp : hint_range(0.0, 1.0) = 0.0;
uniform float damp_height = 0.5;
uniform float soot : hint_range(0.0, 1.0) = 0.0;
uniform float soot_from = 1.9;
uniform vec4 stain : source_color = vec4(0.04, 0.035, 0.03, 1.0);
uniform float rust : hint_range(0.0, 1.0) = 0.0;
uniform vec4 rust_color : source_color = vec4(0.32, 0.15, 0.07, 1.0);
uniform float chips : hint_range(0.0, 1.0) = 0.0;
uniform vec4 chip_color : source_color = vec4(0.5, 0.47, 0.4, 1.0);
varying vec3 wpos;
varying vec3 wnrm;

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	wnrm = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

float nz(float r) {
	return clamp((r - 0.75) / 0.23, 0.0, 1.0);
}

float tri(vec3 p, float s, vec3 w) {
	return nz(texture(grain, p.zy * s).r) * w.x + nz(texture(grain, p.xz * s).r) * w.y + nz(texture(grain, p.xy * s).r) * w.z;
}

void fragment() {
	vec3 w = abs(wnrm);
	w /= (w.x + w.y + w.z);
	float g = tri(wpos, grain_scale, w);
	vec3 albedo = base.rgb * (0.72 + 0.5 * g);
	float rgh = rough;
	float mtl = metal;
	float blotch = tri(wpos, 0.11, w);
	albedo *= 1.0 - grime * 0.6 * smoothstep(0.3, 0.8, blotch);
	float vertical = 1.0 - abs(wnrm.y);
	float sx = nz(texture(grain, vec2((wpos.x + wpos.z) * 3.1, wpos.y * 0.05)).r);
	float streak = smoothstep(0.55, 0.9, sx) * (0.35 + 0.65 * clamp(wpos.y / 2.5, 0.0, 1.0)) * vertical;
	albedo = mix(albedo, stain.rgb, streaks * streak * 0.75);
	float edge = tri(wpos, 0.6, w) - 0.5;
	float band = 1.0 - smoothstep(damp_height - 0.12 + edge * 0.3, damp_height + edge * 0.3, wpos.y);
	albedo *= 1.0 - 0.55 * damp * band;
	rgh = mix(rgh, max(0.12, rgh - 0.35), damp * band);
	albedo *= 1.0 - soot * 0.55 * smoothstep(soot_from, 2.55, wpos.y) * (0.6 + 0.4 * g);
	float rs = smoothstep(0.55, 0.8, tri(wpos, 0.33, w)) * rust;
	albedo = mix(albedo, rust_color.rgb * (0.7 + 0.5 * g), rs);
	rgh = mix(rgh, min(1.0, rgh + 0.3), rs);
	mtl *= 1.0 - rs;
	float ch = smoothstep(0.7, 0.76, tri(wpos, 1.25, w)) * chips * step(0.6, tri(wpos, 0.5, w));
	albedo = mix(albedo, chip_color.rgb * (0.6 + 0.4 * g), ch);
	rgh = mix(rgh, 0.95, ch);
	ALBEDO = albedo;
	ROUGHNESS = rgh;
	METALLIC = mtl;
}
