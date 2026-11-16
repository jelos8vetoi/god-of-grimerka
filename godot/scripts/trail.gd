## След оружия: лента между кулаком и концом оружия за последние доли секунды.
## Рисуется сама, когда конец оружия движется быстро (на замахе её нет, на ударе — яркая дуга), и гаснет к хвосту.
## Во время стоп-кадра время игры почти стоит — дуга «замерзает» вместе с ударом.
class_name Trail
extends MeshInstance3D

const CODE := """
shader_type spatial;
render_mode unshaded, blend_add, cull_disabled, depth_draw_never, shadows_disabled;
uniform vec4 tint : source_color = vec4(1.0, 0.8, 0.4, 1.0);
void fragment() {
	float age = clamp(UV.x, 0.0, 1.0);
	float v = clamp(UV.y, 0.0, 1.0);
	// у самого оружия ленты нет (иначе балон выглядит засвеченным), дальше — яркая кромка по дуге конца и слабое тело
	float fade = pow(max(1.0 - age, 0.0), 1.6) * smoothstep(0.0, 0.12, age);
	float edge = pow(v, 3.5);
	float body = smoothstep(0.0, 0.6, v) * 0.2;
	ALBEDO = mix(tint.rgb, vec3(1.0), edge * fade * 0.7) * (1.0 + 0.8 * edge * fade);
	ALPHA = COLOR.a * fade * (body + edge) * tint.a;
}
"""
static var _shader: Shader

var rig: Rig
var enabled := false
var life := 0.17
var min_speed := 4.5
var full_speed := 13.0
var from := 0.2
var boost := 1.0          # яркость: растёт на заряженных ударах
var pts: Array = []       # [у кулака, у конца, время, яркость]
var clock := 0.0
var im: ImmediateMesh
var mat: ShaderMaterial

func setup(r: Rig, col: Color, from_frac := 0.2) -> void:
	rig = r
	from = from_frac
	top_level = true
	transform = Transform3D.IDENTITY
	if _shader == null:
		_shader = Shader.new()
		_shader.code = CODE
	mat = ShaderMaterial.new()
	mat.shader = _shader
	mat.set_shader_parameter("tint", col)
	material_override = mat
	im = ImmediateMesh.new()
	mesh = im
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	extra_cull_margin = 100.0

func set_color(col: Color) -> void:
	mat.set_shader_parameter("tint", col)

func _process(dt: float) -> void:
	if not enabled and pts.is_empty():
		return
	clock += dt
	var wp := rig.weapon_points(from, 1.0)
	if wp.is_empty():
		return
	var a := 0.0
	if not pts.is_empty() and dt > 0.0:
		var jump: float = ((wp[1] as Vector3) - (pts[-1][1] as Vector3)).length()
		if jump > 3.0:
			pts.clear()
		elif enabled:
			a = clampf((jump / dt - min_speed) / (full_speed - min_speed), 0.0, 1.0) * boost
	if dt > 0.0:
		pts.append([wp[0], wp[1], clock, a])
	while not pts.is_empty() and clock - float(pts[0][2]) > life:
		pts.pop_front()
	im.clear_surfaces()
	var n := pts.size()
	var vis := false
	for p in pts:
		if float(p[3]) > 0.01:
			vis = true
			break
	if not vis:
		if not enabled:
			pts.clear()
		return
	if n < 3:
		return
	im.surface_begin(Mesh.PRIMITIVE_TRIANGLE_STRIP)
	for i in n - 1:
		var p0: Array = pts[max(i - 1, 0)]
		var p1: Array = pts[i]
		var p2: Array = pts[i + 1]
		var p3: Array = pts[min(i + 2, n - 1)]
		var sub := 5
		for s in (sub + 1 if i == n - 2 else sub):
			var u := float(s) / sub
			var b: Vector3 = (p1[0] as Vector3).cubic_interpolate(p2[0], p0[0], p3[0], u)
			var t: Vector3 = (p1[1] as Vector3).cubic_interpolate(p2[1], p0[1], p3[1], u)
			var age := clampf((clock - lerpf(p1[2], p2[2], u)) / life, 0.0, 1.0)
			var al := lerpf(p1[3], p2[3], u)
			im.surface_set_color(Color(1, 1, 1, al))
			im.surface_set_uv(Vector2(age, 0.0))
			im.surface_add_vertex(b)
			im.surface_set_color(Color(1, 1, 1, al))
			im.surface_set_uv(Vector2(age, 1.0))
			im.surface_add_vertex(t)
	im.surface_end()
