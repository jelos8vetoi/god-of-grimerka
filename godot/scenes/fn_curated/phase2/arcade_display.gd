extends Node3D

const SIDE_FINISH := preload("res://assets/fn_curated/materials/oak_wood_planks.tres")

func _ready() -> void:
	var laminate := SIDE_FINISH.duplicate() as StandardMaterial3D
	laminate.uv1_triplanar = true
	laminate.uv1_scale = Vector3(0.5, 0.65, 0.5)
	laminate.albedo_color = Color(0.43, 0.35, 0.28)
	for cabinet in [$Cabinet, $CabinetIdle]:
		for surface in cabinet.find_children("*", "MeshInstance3D", true, false):
			var original: Material = surface.get_active_material(0)
			if original and original.resource_name.begins_with("ArcadeSide"):
				surface.material_override = laminate
	var glass := $Cabinet.find_child("Screen", true, false) as MeshInstance3D
	if glass:
		var phosphor := StandardMaterial3D.new()
		phosphor.albedo_color = Color(0.065, 0.115, 0.108)
		phosphor.roughness = 0.31
		phosphor.emission_enabled = true
		phosphor.emission = Color(0.17, 0.38, 0.32)
		phosphor.emission_energy_multiplier = 0.65
		glass.material_override = phosphor
