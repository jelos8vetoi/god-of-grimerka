shader_type spatial;
render_mode blend_add, unshaded, depth_draw_never, cull_back;

// Инфракрасная подсветка камер наблюдения: прибавка к кадру только когда рисует камера, чья позиция записана в fn_ir
// (xyz — положение камеры, w — сила). Будка и фонари её не видят: враг в будке освещён только настоящим светом.
global uniform vec4 fn_ir;
uniform sampler2D tex : source_color, filter_linear_mipmap;
uniform float gain = 1.0;

void fragment() {
	float on = step(distance(CAMERA_POSITION_WORLD, fn_ir.xyz), 0.05);
	float f = clamp(1.0 - length(VERTEX) / 26.0, 0.0, 1.0);
	float lum = dot(texture(tex, UV).rgb, vec3(0.3, 0.59, 0.11));
	float facing = pow(max(dot(NORMAL, VIEW), 0.0), 0.6);
	ALBEDO = vec3(lum * fn_ir.w * gain * f * facing) * on;
}
