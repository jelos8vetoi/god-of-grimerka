## Материалы и свет трассы. Каждый заезд получает отдельные экземпляры материалов для погоды.
extends RefCounted

const ASPHALT_TILE_M := 1.95
const ROOT := "res://assets/racing/surfaces/"
const ROAD_SHADER := preload("res://assets/racing/surfaces/asphalt.gdshader")
const GROUND_SHADER := preload("res://assets/racing/surfaces/terrain.gdshader")

const DAY := {
	"top": Color(0.29, 0.49, 0.73), "horizon": Color(0.73, 0.79, 0.83),
	"ambient": Color(0.70, 0.79, 0.93), "ambient_energy": 0.58,
	"sun": Color(1.0, 0.91, 0.78), "sun_energy": 1.28,
	"fog": Color(0.61, 0.69, 0.76), "exposure": 1.06,
}
const NIGHT := {
	"top": Color(0.052, 0.075, 0.145), "horizon": Color(0.17, 0.23, 0.34),
	"ambient": Color(0.56, 0.65, 0.84), "ambient_energy": 0.62,
	"sun": Color(0.64, 0.75, 1.0), "sun_energy": 0.27,
	"fog": Color(0.14, 0.19, 0.29), "exposure": 1.15,
}
const RAIN := {
	"top": Color(0.30, 0.36, 0.43), "horizon": Color(0.56, 0.61, 0.66),
	"ambient": Color(0.64, 0.72, 0.82), "ambient_energy": 0.69,
	"sun": Color(0.83, 0.89, 0.98), "sun_energy": 0.48,
	"fog": Color(0.44, 0.50, 0.57), "exposure": 1.10,
}

static func make_materials(mats: Dictionary) -> void:
	var asphalt := ShaderMaterial.new()
	asphalt.shader = ROAD_SHADER
	asphalt.set_shader_parameter("tile_m", ASPHALT_TILE_M)
	asphalt.set_shader_parameter("color_map", _texture("asphalt", "color"))
	asphalt.set_shader_parameter("normal_map", _texture("asphalt", "normal"))
	asphalt.set_shader_parameter("rough_map", _texture("asphalt", "rough"))
	asphalt.set_shader_parameter("wear_map", load(ROOT + "asphalt_wear.jpg"))
	mats["road"] = asphalt

	var terrain := ShaderMaterial.new()
	terrain.shader = GROUND_SHADER
	for surface in ["ground", "gravel"]:
		for channel in ["color", "normal", "rough"]:
			terrain.set_shader_parameter(surface + "_" + channel, _texture(surface, channel))
	mats["ground"] = terrain
	var approach := ShaderMaterial.new()
	approach.shader = preload("res://assets/racing/depot/gravel_join.gdshader")
	approach.set_shader_parameter("gravel", _texture("gravel", "color"))
	approach.set_shader_parameter("relief", _texture("gravel", "normal"))
	approach.set_shader_parameter("rough_map", _texture("gravel", "rough"))
	mats["approach"] = approach
	_apply_pbr(mats["short"], "gravel", 1.0, 0.7)
	_apply_pbr(mats["shoulder"], "gravel", 1.35, 0.55)
	(mats["short"] as StandardMaterial3D).albedo_color = Color(0.86, 0.77, 0.66)
	(mats["shoulder"] as StandardMaterial3D).albedo_color = Color(0.76, 0.68, 0.57)
	_apply_pbr(mats["barrier"], "concrete", 1.0, 0.57, true)
	(mats["barrier"] as StandardMaterial3D).albedo_color = Color(0.93, 0.85, 0.83)
	_apply_pbr(mats["curb_r"], "concrete", 1.0, 0.38)
	_apply_pbr(mats["curb_w"], "concrete", 1.0, 0.38)
	(mats["curb_r"] as StandardMaterial3D).albedo_color = Color(0.77, 0.27, 0.21)
	(mats["curb_w"] as StandardMaterial3D).albedo_color = Color(0.96, 0.93, 0.86)

static func _texture(surface: String, channel: String) -> Texture2D:
	var ext := ".jpg" if channel == "color" else ".webp"
	return load(ROOT + surface + "_" + channel + ext) as Texture2D

static func _apply_pbr(mat: StandardMaterial3D, surface: String, scale: float, bump: float, triplanar := false) -> void:
	mat.albedo_texture = _texture(surface, "color")
	mat.normal_enabled = true
	mat.normal_texture = _texture(surface, "normal")
	mat.normal_scale = bump
	mat.roughness = 1.0
	mat.roughness_texture = _texture(surface, "rough")
	mat.roughness_texture_channel = BaseMaterial3D.TEXTURE_CHANNEL_RED
	mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	mat.uv1_scale = Vector3.ONE * scale
	mat.uv1_triplanar = triplanar

static func configure_light(env: Environment, sun: DirectionalLight3D, weather: String) -> void:
	var profile := NIGHT if weather == "night" else (RAIN if weather == "rain" else DAY)
	var sky := env.sky.sky_material as ProceduralSkyMaterial
	if weather in ["clear", "rain", "night"]:
		sky.sky_top_color = profile.top
		sky.sky_horizon_color = profile.horizon
		sky.ground_horizon_color = (profile.horizon as Color).darkened(0.18)
		sky.ground_bottom_color = (profile.fog as Color).darkened(0.53)
		env.fog_light_color = profile.fog
	sky.sky_curve = 0.29
	sky.sun_angle_max = 16.0 if weather != "rain" else 48.0
	sky.sun_curve = 0.12 if weather != "rain" else 0.04
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = profile.ambient
	env.ambient_light_energy = profile.ambient_energy
	env.ambient_light_sky_contribution = 0.18
	env.tonemap_exposure = profile.exposure
	env.fog_sky_affect = 0.35 if weather == "clear" else 0.77
	env.glow_intensity = 0.28 if weather != "night" else 0.45
	env.glow_hdr_threshold = 1.35
	var advanced := RenderingServer.get_current_rendering_method() == "forward_plus" and bool(RaceSave.v("detailed_lighting"))
	env.ssao_enabled = advanced
	env.ssao_radius = 1.5
	env.ssao_intensity = 1.15
	env.ssao_power = 1.4
	env.ssr_max_steps = 28
	env.ssr_depth_tolerance = 0.18
	env.ssr_enabled = advanced and weather == "rain"
	sun.light_color = profile.sun
	if weather in ["clear", "rain", "night"]:
		sun.light_energy = profile.sun_energy
	sun.light_angular_distance = 0.7 if weather == "clear" else 1.25
	sun.directional_shadow_max_distance = 100.0
	sun.directional_shadow_blend_splits = true
	sun.rotation_degrees = Vector3(-38, -39, 0) if weather != "night" else Vector3(-29, 142, 0)
	if weather in ["clear", "rain"]:
		var panorama := ShaderMaterial.new()
		panorama.shader = preload("res://assets/racing/depot/depot_sky.gdshader")
		var file := "depot_day.hdr" if weather == "clear" else "depot_rain.hdr"
		panorama.set_shader_parameter("panorama", load("res://assets/racing/depot/" + file))
		panorama.set_shader_parameter("exposure", 0.78 if weather == "clear" else 0.43)
		env.sky.sky_material = panorama
		env.fog_sky_affect = 0.18 if weather == "clear" else 0.39
		env.ambient_light_sky_contribution = 0.34
		if weather == "clear":
			# Solar disk in the source panorama is at u=.5947, elevation 48 degrees.
			sun.rotation_degrees = Vector3(-48, -42, 0)

static func set_wet(mats: Dictionary, wet: bool, frozen: bool) -> void:
	(mats["road"] as ShaderMaterial).set_shader_parameter("wetness", 1.0 if wet else 0.0)
	(mats["road"] as ShaderMaterial).set_shader_parameter("frost", 1.0 if frozen else 0.0)
	(mats["approach"] as ShaderMaterial).set_shader_parameter("wetness", 1.0 if wet else 0.0)
	(mats["ground"] as ShaderMaterial).set_shader_parameter("frost", 1.0 if frozen else 0.0)
