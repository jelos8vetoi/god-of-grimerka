@tool
extends Node3D

# The beam and the curtain stay in their original plane. The guide channels
# overlap the narrower curtain, leaving clearance from both masonry jambs.
const TRAVEL := 2.15
const WIDTH := 1.074
const SLAT_COUNT := 15
const PITCH := TRAVEL / SLAT_COUNT
const HOOD_SLOT := 2.15
const PULL_HEIGHT := 0.091
const CURTAIN := preload("res://assets/fn_curated/materials/painted_metal_shutter.tres")
const RAIL := preload("res://assets/fn_curated/materials/rusty_painted_metal.tres")

@onready var pull: Node3D = $PullRail
var slats: Array[MeshInstance3D] = []
var last_opening := -1.0

func _ready() -> void:
	var finish := CURTAIN.duplicate() as StandardMaterial3D
	finish.albedo_color = Color("#777d74")
	finish.normal_scale = 0.65
	finish.metallic_specular = 0.20
	var profile := PackedVector2Array([
		Vector2(0, -0.0325), Vector2(PITCH, -0.0325), Vector2(PITCH, -0.012),
		Vector2(PITCH - 0.010, -0.013), Vector2(PITCH - 0.023, 0.012),
		Vector2(0.071, 0.0325), Vector2(0.042, 0.030),
		Vector2(0.018, 0.012), Vector2(0.007, -0.012), Vector2(0, -0.012),
	])
	for index in SLAT_COUNT:
		var slat := MeshInstance3D.new()
		slat.name = "Slat%02d" % (index + 1)
		slat.mesh = _section(profile, WIDTH, finish, index * PITCH, true)
		add_child(slat)
		slats.append(slat)
	var rail_finish := RAIL.duplicate() as StandardMaterial3D
	rail_finish.albedo_color = Color("#7d796d")
	var rail := MeshInstance3D.new()
	rail.name = "FoldedSteel"
	rail.mesh = _section(PackedVector2Array([
		Vector2(0, -0.038), Vector2(PULL_HEIGHT, -0.038), Vector2(PULL_HEIGHT, 0.005),
		Vector2(0.077, 0.037), Vector2(0.025, 0.037), Vector2(0.011, 0.026), Vector2(0, 0.026),
	]), 1.079, rail_finish, 0.0, false)
	pull.add_child(rail)
	set_opening(0.0 if Engine.is_editor_hint() else 1.0)

func set_opening(opening: float) -> void:
	if opening == last_opening:
		return
	last_opening = opening
	var bottom := opening * TRAVEL
	for i in slats.size():
		var height := bottom + i * PITCH
		slats[i].position.y = height
		# Stop drawing each slat only after it has passed the slot into the hood.
		slats[i].visible = height < HOOD_SLOT
	pull.position.y = bottom
	pull.visible = bottom < HOOD_SLOT

# Extrusion across X. The front and rear of adjacent slats meet at the
# interlock. They share an edge with no overlapping horizontal faces.
func _section(profile: PackedVector2Array, width: float, finish: Material, rise: float, interlock: bool) -> ArrayMesh:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	surface.set_material(finish)
	var half := width * 0.5
	for i in profile.size():
		if interlock and (i == 1 or i == profile.size() - 1):
			continue
		var a := profile[i]
		var b := profile[(i + 1) % profile.size()]
		var normal := Vector3(0, b.y - a.y, a.x - b.x).normalized()
		var va := Vector3(-half, a.x, a.y)
		var vb := Vector3(half, a.x, a.y)
		var vc := Vector3(half, b.x, b.y)
		var vd := Vector3(-half, b.x, b.y)
		for point in [va, vb, vc, va, vc, vd]:
			_vertex(surface, point, normal, Vector2(point.x / width + 0.5, (point.y + rise) * 0.92 + point.z * 0.20))
	var triangles := Geometry2D.triangulate_polygon(profile)
	for side in [-1, 1]:
		for i in range(0, triangles.size(), 3):
			var order := [0, 1, 2] if side < 0 else [0, 2, 1]
			for corner in order:
				var p := profile[triangles[i + corner]]
				_vertex(surface, Vector3(side * half, p.x, p.y), Vector3(side, 0, 0), Vector2(p.y * 2.0, p.x + rise))
	surface.generate_tangents()
	return surface.commit()

func _vertex(surface: SurfaceTool, point: Vector3, normal: Vector3, uv: Vector2) -> void:
	surface.set_normal(normal)
	surface.set_uv(uv)
	surface.add_vertex(point)
