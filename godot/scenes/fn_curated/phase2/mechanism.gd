extends Node3D

@export var hinged := false
@export var cycle_seconds := 6.0
var elapsed := 0.0

func _process(delta: float) -> void:
	elapsed += delta
	set_open_fraction(smoothstep(0.15, 0.85, 0.5 - 0.5 * cos(TAU * elapsed / cycle_seconds)))

func set_open_fraction(value: float) -> void:
	var fraction := clampf(value, 0.0, 1.0)
	if hinged:
		$HingePivot.rotation.y = deg_to_rad(-84.0) * fraction
	else:
		$SliderOrigin.position = $ClosedTransform.position.lerp($OpenTransform.position, fraction)
