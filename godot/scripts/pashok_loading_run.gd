extends Control
## The loading view reuses the gameplay skeleton and unarmed run clip.

const MODEL := "res://assets/models/pahan.glb"
const RUN := "RunBare"
const HEIGHT := 1.85

@onready var run_view: SubViewport = $Preview/RunView
var rig: Rig

func _ready() -> void:
	rig = Rig.new()
	run_view.add_child(rig)
	rig.rotation.y = PI / 2.0
	rig.setup(MODEL, HEIGHT, {RUN: Poses.pahan_armed()[RUN]}, false)
	var silhouette := StandardMaterial3D.new()
	silhouette.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	silhouette.albedo_color = Color.WHITE
	for node in rig.model.find_children("*", "MeshInstance3D", true, false):
		var mesh := node as MeshInstance3D
		mesh.material_override = silhouette
	set_running(false)


func set_running(active: bool) -> void:
	visible = active
	rig.process_mode = Node.PROCESS_MODE_INHERIT if active else Node.PROCESS_MODE_DISABLED
	run_view.render_target_update_mode = SubViewport.UPDATE_ALWAYS if active else SubViewport.UPDATE_DISABLED
	if active:
		rig.play(RUN, 0.0)
		rig.player.seek(0.0, true)
	else:
		rig.player.stop()
