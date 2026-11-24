## Проекция лицевой плиты монитора. Траектория проходит снизу вверх с поворотом
## по тангажу и небольшим приближением к глазам.
extends ColorRect

const PLASTIC := preload("res://scenes/five_nights/materials/fn_monitor_shell.gdshader")

var plastic: ShaderMaterial

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	plastic = ShaderMaterial.new()
	plastic.shader = PLASTIC
	material = plastic

func pose(progress: float, frame: Vector2) -> void:
	size = frame
	var travel := smoothstep(0.0, 1.0, progress)
	var plate := frame * Vector2(1.11, 1.19)
	var focal := frame.y * 2.35
	var center := Vector3(frame.x * 0.5, frame.y * lerpf(1.65, 0.55, travel), frame.y * lerpf(0.43, -0.35, pow(travel, 2.85)))
	var tilt := Basis.from_euler(Vector3(lerpf(-0.65, -0.20, travel), 0.04 * (1.0 - travel), -0.065 * (1.0 - travel)))
	plastic.set_shader_parameter("plate", plate)
	plastic.set_shader_parameter("upper_left", _project(-plate * 0.5, tilt, center, focal))
	plastic.set_shader_parameter("upper_right", _project(plate * Vector2(0.5, -0.5), tilt, center, focal))
	plastic.set_shader_parameter("lower_left", _project(plate * Vector2(-0.5, 0.5), tilt, center, focal))
	plastic.set_shader_parameter("lower_right", _project(plate * 0.5, tilt, center, focal))

func _project(p: Vector2, tilt: Basis, center: Vector3, focal: float) -> Vector3:
	var point := tilt * Vector3(p.x, p.y, 0.0)
	var reciprocal_depth := focal / (focal + center.z + point.z)
	var at := Vector2(center.x, center.y) + Vector2(point.x, point.y) * reciprocal_depth
	return Vector3(at.x, at.y, reciprocal_depth)
