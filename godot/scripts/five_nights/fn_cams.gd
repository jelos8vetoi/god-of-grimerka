## Один SubViewport: камера переезжает между точками, а старый канал
## держится до срыва синхронизации. MOD получает исходный снимок пустой комнаты.
class_name FNCams
extends Node

enum SignalState { NORMAL, SWITCHING, INTERFERENCE, LOST, RECOVERY }

const SIZE := Vector2i(960, 540)
const OFFICE_PEEK_ENV := preload("res://scenes/five_nights/materials/cctv_environment.tres")
const DEFAULT_ENV := preload("res://scenes/five_nights/materials/room_camera_environment.tres")
const STAGE_ENV := preload("res://scenes/five_nights/materials/cam01_environment.tres")
const FEED_SHADER := preload("res://scenes/five_nights/materials/fn_analog_feed.gdshader")
const SWITCH_TIME := 0.22
const TUNE_TIME := 0.075
const RECOVERY_TIME := 0.42
const IR := 0.85

## Яркость, оттенок люминофора, шум и нестабильность усиления отдельных линий.
const LOOKS := {
	"stage": [1.21, Vector3(1.02, 1.0, 0.97), 0.031, 0.42],
	"arcade": [1.23, Vector3(0.94, 1.00, 0.96), 0.046, 0.62],
	"storage": [1.20, Vector3(1.02, 0.99, 0.91), 0.040, 0.52],
	"hall_l": [1.18, Vector3(1.00, 0.99, 0.94), 0.039, 0.56],
	"hall_r": [1.22, Vector3(0.97, 1.00, 0.94), 0.044, 0.62],
	"server": [1.25, Vector3(0.89, 0.98, 1.01), 0.038, 0.51],
	"vent": [1.24, Vector3(0.95, 1.00, 0.93), 0.049, 0.64],
	"power": [1.21, Vector3(1.02, 0.98, 0.89), 0.045, 0.60],
	"room9": [1.18, Vector3(1.02, 0.93, 0.87), 0.048, 0.59],
}

var fac: FNFacility
var vp: SubViewport
var cam: Camera3D
var mat: ShaderMaterial
var cur := ""
var pending := ""
var switch_t := 0.0
var lost_t := 0.0
var lost_next := randf_range(40.0, 90.0)
var signal_state := SignalState.NORMAL
var recovery_t := 0.0
var was_lost := false
var capturing := false
var ir_strength := IR
var frozen := {}
var t := 0.0
var fx_k := 1.0
var base_basis := Basis()
var sway := 0.0
var turn_t := 0.0

func build(f: FNFacility, world: World3D) -> void:
	fac = f
	vp = SubViewport.new()
	vp.size = SIZE
	vp.world_3d = world
	vp.msaa_3d = Viewport.MSAA_2X
	vp.render_target_update_mode = SubViewport.UPDATE_DISABLED
	add_child(vp)
	cam = Camera3D.new()
	cam.far = 60.0
	cam.environment = DEFAULT_ENV
	vp.add_child(cam)
	mat = ShaderMaterial.new()
	mat.shader = FEED_SHADER
	mat.set_shader_parameter("feed", vp.get_texture())

func _ir() -> void:
	RenderingServer.global_shader_parameter_set("fn_ir", Vector4(cam.global_position.x, cam.global_position.y, cam.global_position.z, ir_strength))

func _place_cam(id: String) -> void:
	if id != cur:
		was_lost = false
		recovery_t = 0.0
	cur = id
	var c: Dictionary = fac.cams[id]
	_source_profile(id == "stage")
	cam.global_position = c["pos"]
	cam.look_at(c["look"], Vector3.UP)
	cam.fov = float(c["fov"])
	base_basis = cam.global_basis
	_ir()
	var look: Array = LOOKS[id]
	mat.set_shader_parameter("gain", look[0])
	mat.set_shader_parameter("tint", look[1])
	mat.set_shader_parameter("noise_k", look[2])
	mat.set_shader_parameter("wobble", look[3])
	sway = deg_to_rad(float(c.get("sway", 0.0)))

func _source_profile(stage: bool) -> void:
	ir_strength = 0.61 if stage else IR
	cam.environment = STAGE_ENV if stage else DEFAULT_ENV

## Menu, snapshots and anomalies position the camera immediately. Player channel selection uses _tune().
func set_cam(id: String) -> void:
	if not fac.cams.has(id):
		return
	pending = ""
	_place_cam(id)
	switch_t = SWITCH_TIME

## Аномалия «self»: на миг камера показывает будку со спины охранника.
func peek_office() -> void:
	if pending != "":
		set_cam(pending)
	ir_strength = IR
	cam.environment = OFFICE_PEEK_ENV
	cam.global_position = Vector3(1.7, 2.45, 1.45)
	cam.look_at(Vector3(-0.2, 1.0, -0.7), Vector3.UP)
	cam.fov = 76.0
	base_basis = cam.global_basis
	_ir()
	sway = 0.0
	switch_t = 0.12

## Снимки в начале ночи. Пока идёт захват, tick не меняет точку или режим рендера.
func capture_all() -> void:
	capturing = true
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
	lost_t = -1.0
	was_lost = false
	recovery_t = 0.0
	signal_state = SignalState.NORMAL
	capturing = false

## Кадр срывается на sec секунд, когда враг вошёл в кадр или вышел из него.
func blip(sec: float) -> void:
	lost_t = maxf(lost_t, sec)

func _tune(st: FNNight, dt: float) -> void:
	if st.cam == cur:
		pending = ""
	elif fac.cams.has(st.cam):
		if not st.monitor or cur == "":
			set_cam(st.cam)
			switch_t = 0.0
		else:
			if pending == "":
				switch_t = SWITCH_TIME
			pending = st.cam
	switch_t = maxf(0.0, switch_t - dt)
	if pending != "" and switch_t <= SWITCH_TIME - TUNE_TIME:
		_place_cam(pending)
		pending = ""

func tick(st: FNNight, dt: float) -> void:
	if capturing:
		return
	t += dt
	lost_t = maxf(lost_t - dt, -1.0)
	lost_next -= dt
	if lost_next <= 0.0:
		lost_t = randf_range(0.08, 0.25)
		lost_next = randf_range(40.0, 90.0)
	_tune(st, dt)

	var no_signal := st.cams_dead() or st.cam_broken(cur)
	var lying := st.cam_lies(cur) and frozen.has(cur)
	var on := st.monitor and not no_signal and not st.cam_lies(cur)
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS if on else SubViewport.UPDATE_DISABLED
	turn_t += dt
	if sway > 0.0:
		var k := sin(turn_t * 0.22)
		k = signf(k) * pow(absf(k), 0.6)
		cam.global_basis = base_basis.rotated(Vector3.UP, k * sway)

	var jammed := st.jammed(cur)
	var g: FNGhost = st.enemies["ghost"]
	var haunt := clampf(g.haunt, 0.0, 1.0)
	_update_signal(no_signal, jammed or haunt > 0.2, dt)
	var switch_phase := 1.0 - switch_t / SWITCH_TIME
	var tear := smoothstep(0.0, 0.28, switch_phase) * (1.0 - smoothstep(0.34, 1.0, switch_phase))
	mat.set_shader_parameter("feed", frozen[cur] if lying else vp.get_texture())
	mat.set_shader_parameter("t", t)
	mat.set_shader_parameter("jam", 0.92 if jammed else 0.0)
	mat.set_shader_parameter("haunt", haunt)
	mat.set_shader_parameter("spoof", 1.0 if lying else 0.0)
	mat.set_shader_parameter("switch_phase", switch_phase)
	mat.set_shader_parameter("switch_k", tear)
	mat.set_shader_parameter("lost", 1.0 if no_signal else 0.0)
	mat.set_shader_parameter("interference", 1.0 if lost_t > 0.0 else 0.0)
	mat.set_shader_parameter("recovery", smoothstep(0.0, 1.0, recovery_t / RECOVERY_TIME))
	mat.set_shader_parameter("fx", fx_k)

func _update_signal(no_signal: bool, noise: bool, dt: float) -> void:
	if no_signal:
		recovery_t = 0.0
	elif was_lost:
		recovery_t = RECOVERY_TIME
	else:
		recovery_t = maxf(0.0, recovery_t - dt)
	was_lost = no_signal

	if no_signal:
		signal_state = SignalState.LOST
	elif switch_t > 0.0:
		signal_state = SignalState.SWITCHING
	elif recovery_t > 0.0:
		signal_state = SignalState.RECOVERY
	elif noise or lost_t > 0.0:
		signal_state = SignalState.INTERFERENCE
	else:
		signal_state = SignalState.NORMAL
