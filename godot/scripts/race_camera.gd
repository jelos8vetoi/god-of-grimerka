## Камера локального гонщика. Сглаживание и проверка препятствий применяются к конечному ракурсу.
extends Camera3D

const C := RaceData.CAMERA
const BLUR := preload("res://assets/shaders/race_speed_blur.gdshader")
var screen := ColorRect.new()
var blur_material := ShaderMaterial.new()
var probe := PhysicsShapeQueryParameters3D.new()
var follow := Vector3.ZERO
var chase_yaw := 0.0
var arm := 0.0
var filtered_speed := 0.0
var boost_amount := 0.0
var boost_peak := 0.0
var boost_sources := 0
var acceleration_amount := 0.0
var vibration_phase := 0.0
var roll := 0.0
var initialized := false

func _ready() -> void:
	fov = C.fov_idle
	near = 0.10
	var sphere := SphereShape3D.new()
	sphere.radius = C.clearance
	probe.shape = sphere
	probe.collision_mask = 1
	probe.margin = 0.025
	var layer := CanvasLayer.new()
	layer.layer = 1                 # дорога уже отрисована, HUD гонки рисуется на слое 20
	add_child(layer)
	layer.add_child(screen)
	screen.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	screen.mouse_filter = Control.MOUSE_FILTER_IGNORE
	screen.visible = false
	blur_material.shader = BLUR
	blur_material.set_shader_parameter("clear_radius", C.blur_clear_radius)
	blur_material.set_shader_parameter("edge_radius", C.blur_edge_radius)
	screen.material = blur_material

func clear_position(head: Vector3, wanted: Vector3) -> Vector3:
	probe.transform = Transform3D(Basis.IDENTITY, head)
	probe.motion = wanted - head
	var space := get_world_3d().direct_space_state
	var sweep := space.cast_motion(probe)
	return head + probe.motion * sweep[0]

func chase(who: RaceRider, pos: Vector3, forward: Vector3, rear: bool, snap: bool, trauma: float, dt: float) -> void:
	var motion := who.get_real_velocity()
	var actual := Vector2(motion.x, motion.z).length()
	var yaw := atan2(forward.x, forward.z)
	if not initialized or snap:
		follow = pos
		chase_yaw = yaw
		filtered_speed = actual
		arm = 0.0
		roll = 0.0
		acceleration_amount = 0.0
		boost_amount = 0.0
		boost_peak = 0.0
		boost_sources = 0
		initialized = true
	var impact := smoothstep(0.0, float(RaceData.PHYS.wall_drive_recover), who.wall_drive_t)
	var response := float(C.speed_response) if actual >= filtered_speed else lerpf(float(C.slow_response), float(C.impact_speed_response), impact)
	var previous := filtered_speed
	filtered_speed = lerpf(filtered_speed, actual, 1.0 - exp(-response * dt))
	var acceleration := (filtered_speed - previous) / maxf(0.0001, dt)
	var load_target := smoothstep(float(C.accel_start), float(C.accel_full), acceleration)
	acceleration_amount = lerpf(acceleration_amount, load_target, 1.0 - exp(-float(C.accel_response) * dt))
	var fast := smoothstep(float(C.speed_start), float(C.speed_full), filtered_speed)
	_update_boost(who, dt)
	var moving := smoothstep(0.0, float(C.accel_view_full_speed), filtered_speed)
	var boost := boost_amount * moving
	var accel := acceleration_amount * moving
	fov = lerpf(float(C.fov_idle), float(C.fov_fast), fast) + float(C.fov_boost) * boost + float(C.fov_accel) * accel

	var tracking := 1.0 - exp(-float(C.follow_response) * dt)
	var old_y := follow.y
	var follow_response := lerpf(float(C.follow_response), float(C.impact_follow_response), impact)
	follow = follow.lerp(pos, 1.0 - exp(-follow_response * dt))
	var lag := lerpf(float(C.follow_lag_max), float(C.impact_lag_max), impact)
	follow = pos + (follow - pos).limit_length(lag)
	follow.y = lerpf(old_y, pos.y, 1.0 - exp(-float(C.vertical_response) * dt))
	chase_yaw = lerp_angle(chase_yaw, yaw, tracking)
	var facing := Vector3(sin(chase_yaw), 0.0, cos(chase_yaw))
	if rear:
		facing = -facing
	var dist := lerpf(float(C.near_arm), float(C.far_arm), fast) + float(C.boost_arm) * boost + float(C.accel_arm) * accel
	var height := float(C.height) + float(C.height_fast) * fast
	var head := pos + Vector3.UP * 1.25
	var wanted := follow - facing * dist + Vector3.UP * height
	var clear := clear_position(head, wanted)
	var safe_length := head.distance_to(clear)
	arm = safe_length if arm <= 0.0 or safe_length < arm else lerpf(arm, safe_length, 1.0 - exp(-float(C.arm_release) * dt))
	global_position = head + (wanted - head).normalized() * arm
	var focus := pos.lerp(follow, impact)
	focus.y = lerpf(follow.y, pos.y, 0.45)
	var look := focus + Vector3.UP + facing * float(C.look_ahead)
	look_at(look, Vector3.UP)
	roll = lerpf(roll, -who.drift_dir * who.drift_blend * float(C.drift_roll), 1.0 - exp(-float(C.roll_response) * dt))
	rotate_object_local(Vector3.FORWARD, roll)
	var shake := float(Opts.v("shake")) if RaceSave.v("camera_shake") else 0.0
	if shake > 0.0:
		rotate_object_local(Vector3.RIGHT, -float(C.impact_pitch) * trauma * trauma)
		_vibrate(dt, accel, boost, shake)

	var periphery := smoothstep(float(C.blur_start), float(C.blur_full), filtered_speed)
	var amount := periphery * (1.0 + float(C.blur_boost) * boost)
	screen.visible = amount > 0.006 and bool(RaceSave.v("speed_blur"))
	if screen.visible:
		blur_material.set_shader_parameter("span", float(C.blur_span) * amount)

func _update_boost(who: RaceRider, dt: float) -> void:
	var sources := int(who.turbo_on) | (int(who.drift_boost_t > 0.0) << 1) | (int(who.item_boost_t > 0.0 or who.pad_boost_t > 0.0) << 2)
	if (sources & ~boost_sources) != 0:
		boost_peak = 1.0
	boost_sources = sources
	boost_peak *= exp(-float(C.boost_decay) * dt)
	var target := lerpf(float(C.boost_sustain), 1.0, boost_peak) if sources != 0 else 0.0
	var response: float = C.boost_attack if target > boost_amount else C.boost_release
	boost_amount = lerpf(boost_amount, target, 1.0 - exp(-response * dt))

func _vibrate(dt: float, accel: float, boost: float, setting: float) -> void:
	var high := smoothstep(float(C.vibration_start), float(C.vibration_full), filtered_speed)
	if high <= 0.0:
		return
	var hz := lerpf(float(C.vibration_hz_low), float(C.vibration_hz_high), high)
	vibration_phase = fmod(vibration_phase + TAU * hz * dt, TAU)
	var amplitude := high * setting * (1.0 + float(C.vibration_accel) * accel + float(C.vibration_boost) * boost)
	var pitch := sin(vibration_phase) * deg_to_rad(float(C.vibration_pitch_deg))
	var bank := sin(2.0 * vibration_phase + 0.6) * deg_to_rad(float(C.vibration_roll_deg))
	rotate_object_local(Vector3.RIGHT, amplitude * pitch)
	rotate_object_local(Vector3.FORWARD, amplitude * bank)
