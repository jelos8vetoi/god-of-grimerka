extends Node3D

const ROOMS := [
	preload("cam1_stage_proposal.tscn"), preload("cam2_arcade_proposal.tscn"),
	preload("cam3_storage_proposal.tscn"), preload("cam6_server_proposal.tscn"),
	preload("cam8_power_proposal.tscn")
]
const NAMES := ["CAM 1   ГЛАВНЫЙ ЗАЛ", "CAM 2   ИГРОТЕКА", "CAM 3   КОСТЮМЕРНАЯ", "CAM 6   СЕРВЕРНАЯ", "CAM 8   ЭЛЕКТРОЩИТОВАЯ"]
static var ir_registered := false
var index := 0
var room: Node3D
var night := false
var filtered := false
var cameras := FNCams.new()
var facility := FNFacility.new()
var energies := {}

func _ready() -> void:
	if not ir_registered:
		ir_registered = true
		RenderingServer.global_shader_parameter_add("fn_ir", RenderingServer.GLOBAL_VAR_TYPE_VEC4, Vector4(0, -999, 0, 0))
	add_child(facility)
	add_child(cameras)
	cameras.build(facility, get_world_3d())
	cameras.vp.canvas_cull_mask = 1
	$Overlay/Feed.material = cameras.mat
	select_room(0)

func select_room(next: int) -> void:
	if room:
		remove_child(room)
		room.free()
	index = wrapi(next, 0, ROOMS.size())
	room = ROOMS[index].instantiate()
	add_child(room)
	var anchor: Camera3D = room.get_node("CameraAnchor")
	anchor.make_current()
	var id: String = room.get_meta("room_id")
	facility.cams[id] = {"pos": anchor.global_position, "look": anchor.global_position - anchor.global_basis.z, "fov": anchor.fov, "sway": room.get_meta("sway_degrees")}
	cameras.set_cam(id)
	energies.clear()
	for light: Light3D in room.find_children("*","Light3D",true,false):
		energies[light] = light.light_energy
	apply_view()

func apply_view() -> void:
	for light: Light3D in energies:
		var reserve := 0.51 if ("Spill" in light.name or "Leak" in light.name) else 0.22
		light.light_energy = energies[light] * (reserve if night else 1.0)
	var env: Environment = room.get_node("Lighting/RoomEnvironment").environment
	env.ambient_light_energy = 0.065 if night else 0.24
	$Overlay/Feed.visible = filtered
	cameras.vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS if filtered else SubViewport.UPDATE_DISABLED
	if filtered:
		cameras._ir()
	else:
		RenderingServer.global_shader_parameter_set("fn_ir", Vector4(0,-999,0,0))
	$Overlay/Controls.text = NAMES[index] + "      ← →   камера       N   свет       C   CCTV"

func _process(delta: float) -> void:
	if filtered:
		cameras.t += delta
		cameras.mat.set_shader_parameter("t", cameras.t)

func _unhandled_key_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_LEFT: select_room(index-1)
			KEY_RIGHT: select_room(index+1)
			KEY_N:
				night = not night
				apply_view()
			KEY_C:
				filtered = not filtered
				apply_view()


func _exit_tree() -> void:
	RenderingServer.global_shader_parameter_set("fn_ir", Vector4(0, -999, 0, 0))
