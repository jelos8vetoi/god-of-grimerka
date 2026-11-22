## Видеонаблюдение «5 НОЧЕЙ С ПАХАНОМ»: одна камера в маленьком SubViewport (480×270) переезжает между
## точками камер — рисуется только выбранная и только пока поднят монитор (8 камер одновременно не рендерятся).
## Картинка идёт через шейдер старого видеонаблюдения: зерно, строки, бегущие полосы помех, грязно-зелёный
## монохром, виньетка, редкие потери сигнала. Помехи BOT, «одержимость» GHOST и подмена картинки MOD —
## параметры того же шейдера. Подменённая картинка — снимок камеры, сделанный, пока в комнате было пусто.
class_name FNCams
extends Node

const SIZE := Vector2i(480, 270)
const SHADER := """
shader_type canvas_item;
uniform sampler2D feed : filter_linear;
uniform float t = 0.0;
uniform float noise_k = 0.18;
uniform float jam = 0.0;          // помехи BOT: 0..1
uniform float haunt = 0.0;        // GHOST: картинка плывёт, краснеет
uniform float switch_k = 0.0;     // вспышка помех при переключении
uniform float lost = 0.0;         // потеря сигнала
uniform float fx = 1.0;           // интенсивность эффектов (настройка)
float h(vec2 p) { return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453); }
void fragment() {
	vec2 uv = UV;
	float roll = fract(t * 0.07);
	float band = smoothstep(0.0, 0.03, abs(uv.y - roll)) ;
	uv.x += (1.0 - band) * 0.012 * fx;
	uv.x += sin(uv.y * 40.0 + t * 9.0) * 0.004 * (jam + haunt * 1.5) * fx;
	uv.y += (h(vec2(floor(t * 24.0), 0.0)) - 0.5) * 0.02 * jam * fx;
	vec3 c = texture(feed, uv).rgb;
	if (haunt > 0.0) {
		vec3 c2 = texture(feed, uv + vec2(0.012, 0.0) * haunt).rgb;
		c = mix(c, vec3(c2.r, c.g * 0.5, c.b * 0.5), haunt * 0.6);
	}
	float l = dot(c, vec3(0.3, 0.55, 0.15));
	l = pow(l, 0.85) * 1.35;
	vec3 tint = vec3(0.62, 0.78, 0.62);
	vec3 col = vec3(l) * tint;
	col = mix(col, vec3(l * 1.3, l * 0.2, l * 0.15), haunt * 0.55);
	float n = h(UV * 900.0 + t * 37.0);
	col += (n - 0.5) * (noise_k + jam * 0.8 + switch_k * 1.5) * fx;
	col *= 0.86 + 0.14 * sin(UV.y * 540.0);
	col *= 1.0 - (1.0 - band) * 0.25;
	vec2 d = UV - 0.5;
	col *= 1.0 - dot(d, d) * 1.3;
	col = mix(col, vec3(n * 0.8), clamp(jam * 0.85 + switch_k + lost, 0.0, 1.0));
	COLOR = vec4(col, 1.0);
}
"""

var fac: FNFacility
var vp: SubViewport
var cam: Camera3D
var view: TextureRect             # картинка на мониторе (ставит FNUI)
var mat: ShaderMaterial
var cur := ""
var switch_t := 0.0
var lost_t := 0.0
var frozen := {}                  # id камеры → ImageTexture (подмена MOD)
var t := 0.0
var fx_k := 1.0
var base_basis := Basis()          # куда смотрит камера без поворота
var sway := 0.0                    # размах медленного поворота поворотной камеры, рад
var turn_t := 0.0

func build(f: FNFacility, world: World3D) -> void:
	fac = f
	vp = SubViewport.new()
	vp.size = SIZE
	vp.world_3d = world
	vp.msaa_3d = Viewport.MSAA_DISABLED
	vp.render_target_update_mode = SubViewport.UPDATE_DISABLED
	add_child(vp)
	cam = Camera3D.new()
	cam.far = 60.0
	cam.environment = preload("res://scenes/five_nights/materials/cctv_environment.tres")
	vp.add_child(cam)
	mat = ShaderMaterial.new()
	var sh := Shader.new()
	sh.code = SHADER
	mat.shader = sh
	mat.set_shader_parameter("feed", vp.get_texture())

func set_cam(id: String) -> void:
	if not fac.cams.has(id):
		return
	cur = id
	var c: Dictionary = fac.cams[id]
	cam.global_position = c["pos"]
	cam.look_at(c["look"], Vector3.UP)
	cam.fov = float(c["fov"])
	base_basis = cam.global_basis
	sway = deg_to_rad(float(c.get("sway", 0.0)))
	switch_t = 0.22

## аномалия «self»: на миг камера показывает будку со спины охранника
func peek_office() -> void:
	cam.global_position = Vector3(1.7, 2.45, 1.45)
	cam.look_at(Vector3(-0.2, 1.0, -0.7), Vector3.UP)
	cam.fov = 76.0
	base_basis = cam.global_basis
	sway = 0.0
	switch_t = 0.12

## снимки всех камер в начале ночи — их подсовывает MOD («старая картинка»: на ней всё как было в полночь)
func capture_all() -> void:
	frozen.clear()
	var keep := cur
	for c in FNData.CAMS + [FNData.CAM9]:
		var id: String = c["id"]
		if not fac.cams.has(id):
			continue
		set_cam(id)
		vp.render_target_update_mode = SubViewport.UPDATE_ONCE
		await RenderingServer.frame_post_draw
		frozen[id] = ImageTexture.create_from_image(vp.get_texture().get_image())
	if keep != "":
		set_cam(keep)
	switch_t = 0.0

func tick(st: FNNight, dt: float) -> void:
	t += dt
	switch_t = maxf(0.0, switch_t - dt)
	lost_t -= dt
	if lost_t < -randf_range(14.0, 40.0):
		lost_t = randf_range(0.08, 0.25)            # редкая потеря сигнала
	var on := st.monitor and not st.cams_dead() and not st.cam_broken(cur)
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS if on and not st.cam_lies(cur) else SubViewport.UPDATE_DISABLED
	if st.cam != cur:
		set_cam(st.cam)
	# поворотная камера: медленно ходит туда-обратно и замирает у краёв (как настоящий привод)
	turn_t += dt
	if sway > 0.0:
		var k := sin(turn_t * 0.22)
		k = signf(k) * pow(absf(k), 0.6)
		cam.global_basis = base_basis.rotated(Vector3.UP, k * sway)
	if view == null:
		return
	var lying := st.cam_lies(cur) and frozen.has(cur)
	mat.set_shader_parameter("feed", frozen[cur] if lying else vp.get_texture())
	mat.set_shader_parameter("t", t)
	mat.set_shader_parameter("jam", 0.92 if st.jammed(cur) else 0.0)
	var g: FNGhost = st.enemies["ghost"]
	mat.set_shader_parameter("haunt", clampf(g.haunt, 0.0, 1.0))
	mat.set_shader_parameter("switch_k", switch_t / 0.22)
	mat.set_shader_parameter("lost", 1.0 if (lost_t > 0.0 or st.cams_dead() or st.cam_broken(cur)) else 0.0)
	mat.set_shader_parameter("fx", fx_k)
